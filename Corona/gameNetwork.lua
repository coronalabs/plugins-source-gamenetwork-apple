-- gameNetwork.lua
-- Base gameNetwork library module
-- Loads the appropriate provider plugin when init() is called

local Library = require "CoronaLibrary"

local lib = Library:new{ name='gameNetwork', publisherId='com.coronalabs' }

local _baseInit
_baseInit = function(providerName, ...)
	local providerModule = "CoronaProvider.gameNetwork." .. providerName
	local success, errMsg = pcall(require, providerModule)

	if not success then
		print("ERROR: gameNetwork provider '" .. tostring(providerName) .. "' could not be loaded: " .. tostring(errMsg))
		return
	end

	if lib.init ~= _baseInit then
		return lib.init(providerName, ...)
	else
		print("WARNING: gameNetwork provider '" .. tostring(providerName) .. "' did not register correctly.")
	end
end

lib.init = _baseInit

return lib
