local skynet = require "skynet"
local logger = require "logger"
local aoi = require "misc.aoi"

local world = ...
local conf

local online_character = {}
local CMD = {}

function CMD.init (c)
	conf = c

	local bbox = conf.bbox
	aoi.init (bbox)
end

function CMD.character_enter (character, pos, agent)
	logger.log (string.format ("character (%d) entering map (%s)", character, conf.name))
	online_character[character] = agent
	skynet.call (agent, "lua", "map_enter", conf.name, pos)

	local ok, list = aoi.insert (character, pos)
	if not ok then
		skynet.call (world, "lua", "kick", character)
	end

	skynet.call (agent, "lua", "map", "map_follow", list)
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, source, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
end)
