--!strict
--!optimize 2

--[[
	Flow

	The argument-entry flow for one activated command. It owns the pure Session
	and the command being entered. Begin, submit, back and exit are the only
	mutations, and each one mirrors the session into the store's entry Value.
	Every other piece of view state is computed from that, so nothing is
	mirrored by hand.
]]

local Registry = require("@palette/Registry")
local Session = require("@core/Session")
local Store = require("@palette/Store")
local arguments = require("@core/arguments")
local fusion = require("@runtime/fusion")
local types = require("@vanta/types")

export type EntryState = Store.EntryState

-- Private ---------------------------------------------------------------------------

local function leadTokenMatches(command: Registry.Command, token: string): boolean
	local lowered = token:lower()
	for _, alias in command.aliases do
		if alias:lower() == lowered then
			return true
		end
	end
	return fusion.peek(command.name):lower():sub(1, #lowered) == lowered
end

-- Public ----------------------------------------------------------------------------

local Flow = {}
Flow.__index = Flow

export type Flow = typeof(setmetatable(
	{} :: {
		_store: Store.Store,
		_session: Session.Session?,
		_command: Registry.Command?,
	},
	{} :: typeof(Flow)
))

function Flow.new(store: Store.Store): Flow
	return setmetatable({
		_store = store,
		_session = nil,
		_command = nil,
	}, Flow)
end

function Flow.isActive(self: Flow): boolean
	return self._session ~= nil
end

-- Snapshot the pure session into the reactive entry (or clear it when finished).
function Flow._sync(self: Flow): ()
	local session = self._session
	local command = self._command
	local arg = if session then session:current() else nil
	if session == nil or command == nil or arg == nil then
		self._store.entry:set(nil)
		return
	end
	self._store.entry:set({
		command = fusion.peek(command.name),
		icon = fusion.peek(command.icon),
		arg = arg,
		index = session:index(),
		total = session:total(),
		collected = session:collected(),
	})
end

function Flow.exit(self: Flow): ()
	self._session = nil
	self._command = nil
	self._store.entry:set(nil)
	-- Exit is symmetric with entry, search returns with its selection at the top.
	self._store.selectedIndex:set(1)
end

function Flow._finish(self: Flow): ()
	local session = self._session
	local command = self._command
	if session == nil or command == nil then
		return
	end
	local values, count = session:values()
	--[[
		Exit back to search first, then run. The store's run owns the lifecycle
		afterwards, staying open and resetting, or closing if the command opted
		in.
	]]
	self:exit()
	self._store:run(command, values, count)
end

--[[
	Enter argument entry for a command that has parameters. Trailing query
	tokens pre-fill the session (the "ws 50" power-user path), stopping at the
	first that fails to validate. A command fully satisfied inline runs
	immediately.
]]
function Flow.begin(self: Flow, command: Registry.Command): ()
	local session = Session.new(command.arguments)
	self._session = session
	self._command = command

	local store = self._store
	local queryTokens = arguments.tokenize(fusion.peek(store.query))
	if #queryTokens >= 2 and leadTokenMatches(command, queryTokens[1]) then
		local index = 2
		while index <= #queryTokens do
			--[[
				The last argument, if a string, absorbs the rest of the line so
				a value can contain spaces, as in "notify hello world".
			]]
			local current = session:current()
			local raw: string
			if
				current ~= nil
				and current.Type == "string"
				and session:index() == session:total()
			then
				raw = table.concat(queryTokens, " ", index)
				index = #queryTokens + 1
			else
				raw = queryTokens[index]
				index += 1
			end

			local outcome = session:submit(raw)
			if not outcome.ok then
				break
			end
			if outcome.value then
				self:_finish()
				return
			end
		end
	end

	store:clearField()
	store.selectedIndex:set(1)
	store:refocus()
	self:_sync()
end

--[[
	Commit the current field. Invalid input keeps everything in place, because
	the store's validity Computed already shows the error live. Roblox releases
	TextBox focus natively on Enter, so every path that stays in entry must
	refocus or the user is stranded unfocused mid-flow.
]]
function Flow.submit(self: Flow, raw: string): ()
	local session = self._session
	if session == nil then
		return
	end
	local outcome = session:submit(raw)
	if not outcome.ok then
		-- Select the rejected text, so the correction replaces it.
		self._store:refocus(true)
		return
	end
	self._store:clearField()
	if outcome.value then
		self:_finish()
	else
		self._store.selectedIndex:set(1)
		self:_sync()
		self._store:refocus()
	end
end

function Flow.pickOption(self: Flow, option: types.EnumOption): ()
	-- A pick commits, so an armed preview must not restore over it.
	self._store:notePickCommitted()
	self:submit(option.Label)
end

--[[
	Step back a parameter, exiting to search when already at the first.
	Returns whether it stepped, so false means it exited. Both outcomes keep
	the palette open, so both refocus the field.
]]
function Flow.back(self: Flow): boolean
	local session = self._session
	if session == nil then
		return false
	end
	if session:back() then
		self._store:clearField()
		self._store.selectedIndex:set(1)
		self:_sync()
		self._store:refocus()
		return true
	end
	self:exit()
	self._store:refocus()
	return false
end

return table.freeze(Flow)
