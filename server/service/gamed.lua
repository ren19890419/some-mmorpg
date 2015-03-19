local gameserver = require "gameserver"
local skynet = require "skynet"
local logger = require "logger"
local config = require "config.system"

local logind = tonumber (...)

local gamed = {}

local pending_agent = {}
local pool = {}

function gamed.open (name)
	logger.log ("gamed opened")

	local self = skynet.self ()

	local n = config.gamed.pool
	for i = 1, n do
		table.insert (pool, skynet.newservice ("agent", self))
	end

	skynet.call (logind, "lua", "register", name, self)	
	skynet.call (logind, "lua", "open", config.logind)	
end

function gamed.command_handler (cmd, ...)
	local CMD = {}

	function CMD.close (agent)	
		table.insert (pool, agent)
	end

	local f = assert (CMD[cmd])
	return f (...)
end

function gamed.auth_handler (account, token)
	return skynet.call (logind, "lua", "verify", account, token)	
end

function gamed.login_handler (fd, account)
	local agent
	if #pool == 0 then
		agent = skynet.newservice ("agent", skynet.self ())
	else
		agent = table.remove (pool, 1)
	end

	pending_agent[fd] = agent
	skynet.call (agent, "lua", "open", fd, account)
	gameserver.forward (fd, agent)
	pending_agent[fd] = nil
end

function gamed.message_handler (fd, msg, sz)
	local agent = pending_agent[fd]
	if agent then
		skynet.rawcall(agent, "client", msg, sz)
	else
		logger.warning (string.format ("unknown message from fd (%d), size (%d)", fd, sz))
	end
end

gameserver.start (gamed)
