--[=[
	Service which manages central access to datastore. This datastore will refresh pretty frequently and
	can be used for configuration and other components, such as Twitter codes or global settings.

	@class GameDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")

local GameDataStoreService = {}
GameDataStoreService.ServiceName = "GameDataStoreService"

function GameDataStoreService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))

	self._maid = Maid.new()
end

function GameDataStoreService:PromiseDataStore()
	if self._dataStorePromise then
		return self._dataStorePromise
	end

	self._dataStorePromise = self:_promiseRobloxDataStore()
		:Then(function(robloxDataStore)
			local dataStore = DataStore.new(robloxDataStore, self:_getKey())
			self._maid:GiveTask(dataStore)

			self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
				return dataStore:Save()
			end))

			return dataStore
		end)

	return self._dataStorePromise
end

function GameDataStoreService:_promiseRobloxDataStore()
	if self._robloxDataStorePromise then
		return self._robloxDataStorePromise
	end

	self._robloxDataStorePromise = self._maid:GivePromise(DataStorePromises.promiseDataStore("GameDataStore", "Version1"))

	return self._robloxDataStorePromise
end

function GameDataStoreService:_getKey()
	return "version1"
end

function GameDataStoreService:Destroy()
	self._maid:DoCleaning()
end

return GameDataStoreService