--!strict
--!optimize 2

--[[
	matcher

	Fuzzy ranking in the style of fzy, with per-character match traceback. It is
	pure, plain strings in and ranked matches out, with no Fusion and no Roblox.
	One dynamic program finds the optimal alignment of the query, and the score
	and the highlight positions are both read off that same alignment.
]]

-- Constants -------------------------------------------------------------------------

--[[
	Additive bonuses and penalties, tuned so a boundary hit outranks a mid-word
	one and a tight run outranks a scattered match of the same characters.
]]
local BONUS_FIRST = 12
local BONUS_BOUNDARY = 10
local BONUS_CAMEL = 8
local BONUS_CONSECUTIVE = 4
local PENALTY_GAP = 1
local LENGTH_WEIGHT = 0.05

-- Field weights: a name hit matters most, then aliases, then description text.
local WEIGHT_NAME = 1
local WEIGHT_ALIAS = 0.9
local WEIGHT_DESCRIPTION = 0.4

local SEPARATOR = "[%s%-_/%.]"

local NEG = -math.huge

-- Types -----------------------------------------------------------------------------

export type Candidate = {
	name: string,
	description: string,
	aliases: { string },
}

export type Match = {
	index: number,
	--[[
		Byte positions (1-based) in the candidate's name matched by the best
		alignment. Nil when only an alias or the description matched, or when
		the query is empty.
	]]
	positions: { number }?,
}

-- Private ---------------------------------------------------------------------------

--[[
	Optimal subsequence alignment. The text argument keeps its original case for
	boundary and camelCase detection, and the lower argument is matched against
	the lowercased query. Returns nil when the query is not a subsequence.
]]
local function align(
	text: string,
	lower: string,
	query: string,
	wantPositions: boolean
): (number?, { number }?)
	local n = #query
	if n == 0 then
		return 0, nil
	end
	local m = #text
	if m < n then
		return nil, nil
	end

	-- Early-out: without the query as a subsequence there is no alignment to score.
	do
		local qi = 1
		local queryByte = string.byte(query, 1)
		for ti = 1, m do
			if string.byte(lower, ti) == queryByte then
				qi += 1
				if qi > n then
					break
				end
				queryByte = string.byte(query, qi)
			end
		end
		if qi <= n then
			return nil, nil
		end
	end

	-- Per-position bonus: first char, word boundary, or camelCase hump.
	local bonus = table.create(m, 0) :: { number }
	for j = 2, m do
		local previous = text:sub(j - 1, j - 1)
		local current = text:sub(j, j)
		if previous:match(SEPARATOR) ~= nil then
			bonus[j] = BONUS_BOUNDARY
		elseif previous:match("%l") ~= nil and current:match("%u") ~= nil then
			bonus[j] = BONUS_CAMEL
		end
	end
	bonus[1] = BONUS_FIRST

	--[[
		matchedAt[i][j] is the best alignment of the first i query chars whose
		char i sits at text position j. bestUpTo[i][j] is the best matchedAt[i][k]
		for k up to j, less one gap penalty per step since k. Every row is kept
		so the winning alignment can be walked back afterwards.
	]]
	local matchedAt: { { number } } = table.create(n)
	local bestUpTo: { { number } } = table.create(n)
	local prevD: { number } = table.create(m, NEG)
	local prevM: { number } = table.create(m, 0)

	for i = 1, n do
		local currD = table.create(m, NEG) :: { number }
		local currM = table.create(m, NEG) :: { number }
		local queryByte = string.byte(query, i)
		for j = 1, m do
			local d = NEG
			if string.byte(lower, j) == queryByte then
				--[[
					Char i may only land at position 1 when it is the first query
					char. Any later char needs everything before it aligned
					somewhere to its left.
				]]
				local fromGap = if j > 1 then prevM[j - 1] elseif i == 1 then 0 else NEG
				local fromRun = if j > 1 and prevD[j - 1] > NEG
					then prevD[j - 1] + BONUS_CONSECUTIVE
					else NEG
				d = math.max(fromGap, fromRun) + 1 + bonus[j]
			end
			currD[j] = d
			currM[j] = math.max(d, if j > 1 then currM[j - 1] - PENALTY_GAP else NEG)
		end
		matchedAt[i] = currD
		bestUpTo[i] = currM
		prevD = currD
		prevM = currM
	end

	-- Best full-query alignment ending anywhere (no trailing-gap penalty).
	local lastRow = matchedAt[n]
	local best = NEG
	local bestEnd = 0
	for j = 1, m do
		if lastRow[j] > best then
			best = lastRow[j]
			bestEnd = j
		end
	end

	local positions: { number }? = nil
	if wantPositions then
		local trace = table.create(n) :: { number }
		local i = n
		local j = bestEnd
		while i >= 1 do
			trace[i] = j
			if i == 1 then
				break
			end
			local sourceScore = matchedAt[i][j] - 1 - bonus[j]
			local aboveD = matchedAt[i - 1]
			local aboveM = bestUpTo[i - 1]
			-- Prefer the consecutive-run parent on ties, for tighter highlight runs.
			if
				j > 1
				and aboveD[j - 1] > NEG
				and aboveD[j - 1] + BONUS_CONSECUTIVE == sourceScore
			then
				j -= 1
			else
				-- Came through a gap: walk left along the M chain to its source match.
				j -= 1
				while aboveM[j] ~= aboveD[j] do
					j -= 1
				end
			end
			i -= 1
		end
		positions = table.freeze(trace)
	end

	-- Break ties toward shorter, tighter candidates.
	return best - m * LENGTH_WEIGHT, positions
end

-- Keeps the higher of two optional scores (nil = no match).
local function better(best: number?, value: number?): number?
	if value == nil then
		return best
	end
	if best == nil or value > best then
		return value
	end
	return best
end

--[[
	Best field score for one candidate against the query, or nil when nothing
	matches. Positions come from the name field only. Other fields rank but
	never highlight.
]]
local function scoreCandidate(
	candidate: Candidate,
	lowerName: string,
	query: string
): (number?, { number }?)
	local nameScore, positions = align(candidate.name, lowerName, query, true)
	local best: number? = if nameScore ~= nil then nameScore * WEIGHT_NAME else nil

	for _, alias in candidate.aliases do
		local aliasScore = align(alias, alias:lower(), query, false)
		if aliasScore ~= nil then
			best = better(best, aliasScore * WEIGHT_ALIAS)
		end
	end

	local descriptionScore =
		align(candidate.description, candidate.description:lower(), query, false)
	if descriptionScore ~= nil then
		best = better(best, descriptionScore * WEIGHT_DESCRIPTION)
	end

	return best, positions
end

-- Public ----------------------------------------------------------------------------

local matcher = {}

--[[
	Ranks candidates against a query, best first. An empty query keeps every
	candidate in alphabetical order, and ties fall back to the name so the
	order is stable across recomputes.
]]
function matcher.rank(candidates: { Candidate }, query: string): { Match }
	local trimmed = query:match("^%s*(.-)%s*$") or ""
	local token = trimmed:lower()

	local scored: { { index: number, score: number, name: string, positions: { number }? } } = {}
	for index, candidate in candidates do
		local lowerName = candidate.name:lower()
		if token == "" then
			table.insert(scored, { index = index, score = 0, name = lowerName, positions = nil })
			continue
		end
		local value, positions = scoreCandidate(candidate, lowerName, token)
		if value ~= nil then
			table.insert(
				scored,
				{ index = index, score = value, name = lowerName, positions = positions }
			)
		end
	end

	table.sort(scored, function(a, b): boolean
		if a.score == b.score then
			return a.name < b.name
		end
		return a.score > b.score
	end)

	local order = table.create(#scored) :: { Match }
	for rankIndex, item in scored do
		order[rankIndex] = table.freeze({ index = item.index, positions = item.positions })
	end
	return order
end

return table.freeze(matcher)
