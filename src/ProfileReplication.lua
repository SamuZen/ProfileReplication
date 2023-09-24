-- ### Roblox Services
local Players = game:GetService("Players")

-- ### Packages
local Packages = script.Packages
local Signal = require(Packages.signal)
local TableUtil = require(Packages["table-util"])
local Promise = require(Packages.promise)
local ProfileService = require(Packages.profileservice)

-- ### Variables
local ProfileStore
local Profiles = {}
local onDataChanged = Signal.new()
local profileAdjustmentHandler = nil

--[=[
	@class ProfileService
	Main Class.
]=]

local ProfileReplication = {}
ProfileReplication.__index = ProfileReplication

--- @interface Signals
--- @within ProfileService
--- .playerProfileLoaded Signal -- fires when a player profile is loaded
--- .beforePlayerRemoving Signal -- fires before a player profile is being released
---

--[=[
	@within ProfileService
	@prop Signals Signals
	
]=]
ProfileReplication.Signals = {
	playerProfileLoaded = Signal.new(),
	beforePlayerRemoving = Signal.new(),
}

--[=[
	@within ProfileService
	Initialize the system

	@param databaseName string -- The name of the database
	@param profileTemplate table -- The data template
	@param _profileAdjustmentHandler function -- callback to adjust the data before using the loaded data
]=]
function ProfileReplication:init(databaseName: string, profileTemplate: table, _profileAdjustmentHandler: (table) -> table)
	if _profileAdjustmentHandler ~= nil then
		profileAdjustmentHandler = _profileAdjustmentHandler
	end
    ProfileStore = ProfileService.GetProfileStore(
        databaseName,
        profileTemplate
    )
end

--[=[
	@within ProfileService
	Start the system, load player profiles, register player added and data changed
]=]
function ProfileReplication:start()

	-- load player profile
	Players.PlayerAdded:Connect(function(player)
        self:_loadPlayerProfile(player)
    end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_loadPlayerProfile(player)
		end)
	end

	-- release player profile
    Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if profile ~= nil then
			ProfileReplication.Signals.beforePlayerRemoving:Fire(player)
			profile:Release()
		end
    end)

	onDataChanged:Connect(function(_player, _path, _state, _key)
        --print(_player, _path, _state, _key)
        if _state then
            ProfileReplication:_createOrUpdateOnReplicatedFolder(_player, _path)
        else
            ProfileReplication:_deleteOnReplicatedFolder(_player, _path, _key)
        end
    end)
end

-- ### API

--[=[
	@within ProfileService
	Set value on path.
	Cannot set tables directly

	@param player Player -- Target player
	@param path string -- path to the data
	@param newValue string | number | boolean -- value to set
]=]
function ProfileReplication:Set(player: Player, path, newValue)
	assert(typeof(newValue) ~= "table", "Cannot 'Set' a value with table.")
	local function ChangeValue(parent, key, value)
		if typeof(parent[key]) == "table" then
			warn(parent, key, value)
			error("Cannot use 'Set' on a table path.")
		end

		parent[key] = value
	end
	
	if Profiles[player] then
		ProfileReplication:_recursiveAction(Profiles[player].Data, path, newValue, ChangeValue)
		onDataChanged:Fire(player, path, true)
		return Profiles[player].Data
	else
		warn("Failed to change value on " .. player.DisplayName .. " there is no profile loaded")
	end
end

--[=[
	@within ProfileService
	Set value on path

	@param player Player -- Target player
	@param path string -- path to the data
	@param value table -- table to append
	@param key string -- optional key to insert the table
]=]
function ProfileReplication:AddTable(player, path, value, key)
	assert(player ~= nil, "To create a replicated folder, the argument needs to be a player, got nil")
	assert(typeof(player) == "Instance", "To create a replicated folder, the argument needs to be a player Instance")
	assert(player:IsA("Player") , "Argument instance needs to be a 'Player'")
	assert(Profiles[player], "No profile found with passed player" )

	local function AddTable(parent, _key, value)
		assert(type(parent[_key]) == "table", "The final of the path value needs to be a table. Got a " .. type(parent[_key]) )
		table.insert(parent[_key], value)
	end

	local function AddTableWithKey(parent, _key, value)
		assert(type(parent[_key]) == "table", "The final of the path value needs to be a table. Got a " .. type(parent[_key]) )
		parent[_key][key] = value
	end

	if key ~= nil then
		assert(type(key) == "string", "Table key needs to be a string, got " .. type(key))

		ProfileReplication:_recursiveAction(Profiles[player].Data, path, value, AddTableWithKey)
	else
		ProfileReplication:_recursiveAction(Profiles[player].Data, path, value, AddTable)

	end

	onDataChanged:Fire(player, path, true)
	return Profiles[player].Data
end

--[=[
	@within ProfileService
	Increment number on path

	@param player Player -- Target player
	@param path string -- path to the data
	@param value number -- number to increment
]=]
function ProfileReplication:Increment(player, path, value)
	assert(type(path) == "string", "Path needs to be a string")
	assert(value ~= nil, "Value needs to be different of nil")
	assert(type(value) == "number", "Value needs to be a number")

	if Profiles[player] == nil then
		return
	end

	local Folder, Attribute = ProfileReplication:_navigateOnReplicatedDataFolder(player, path)
	local function Increment(parent, key, value)

		assert(type(parent[key]) == "number", "Data value needs to be a number")

		parent[key] += value 
	end
	ProfileReplication:_recursiveAction(Profiles[player].Data, path, value, Increment)
	onDataChanged:Fire(player, path, true)     
	return Profiles[player].Data
end

--[=[
	@within ProfileService
	Delete value on path

	@param player Player -- Target player
	@param path string -- path to the data
]=]
function ProfileReplication:Delete(player, path)
	local function Delete(parent, key, value)
		if string.match(key, '[0-9]+') ~= nil and string.len(string.match(key, '[0-9]+')) == string.len(key) then
			table.remove(parent, key)
		elseif type(key) == "string" then
			parent[key] = nil
		end 
		onDataChanged:Fire(player, path, false, key)
	end
	ProfileReplication:_recursiveAction(Profiles[player].Data, path, nil, Delete)

	return Profiles[player].Data
end

--[=[
	@within ProfileService
	Return the player profile data

	@param player Player -- Target player
	@return {any}
]=]
function ProfileReplication:GetPlayerData(player: Player)
	if Profiles[player] ~= nil then
		return TableUtil.Copy(Profiles[player].Data)
	end
end

--[=[
	@within ProfileService
	Return the player profile within a Promise

	@param player Player -- Target player
	@return Promise<ProfileService.Profile>
]=]
function ProfileReplication:GetPlayerDataAsync(player)
	assert(player, "Player object expect, got nil")
	assert(player:IsA("Player"), "Player object expected, got " .. type(player))

	return Promise.new(function(resolve, reject)
		task.spawn(function()
			local trys = 0
			local maxTrys = 100
			while trys < maxTrys do
				if Profiles[player] ~= nil then
					resolve(TableUtil.Copy(Profiles[player].Data)) 
				end
				trys+=1
				task.wait(1)
			end
			reject("No profile found")
		end)
	end)
end

--[=[
	@within ProfileService
	Return the player profile

	@param player Player -- Target player
	@return ProfileService.Profile
]=]
function ProfileReplication:GetPlayerProfile(player)
	return Profiles[player]
end

-- ### Private

function ProfileReplication:_loadPlayerProfile(player: Player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile == nil then
		player:Kick("Failed to load your data. Try again")
		return
	end
	
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		Profiles[player] = nil
		player:Kick("Releasing loaded data!")
	end)

	if profileAdjustmentHandler ~= nil then
		profile = profileAdjustmentHandler(profile)
	end

	if player:IsDescendantOf(game:GetService('Players')) == true then
		warn("Player profile loaded! ", profile)

		Profiles[player] = profile
		ProfileReplication:_renderReplicatedFolder(player)

		ProfileReplication.Signals.playerProfileLoaded:Fire(player, profile)
		return player, profile
	else
		profile:Release()
	end

end

function ProfileReplication:_renderReplicatedFolder(player)
	assert(player ~= nil, "To create a replicated folder, the argument needs to be a player, got nil")
	assert(typeof(player) == "Instance", "To create a replicated folder, the argument needs to be a player Instance")
	assert(player:IsA("Player") , "Argument instance needs to be a 'Player'")
	assert(Profiles[player], "No profile found with passed player" )

	local ReplicationFolder = Instance.new("Folder")
	ReplicationFolder.Name = "_replicationFolder"
	local function mapArray(array, folder)
		for i, j in pairs(array) do
			if type(j) == "table" then
				local newFolder = Instance.new("Folder")
				newFolder.Name = i
				mapArray(j, newFolder)
				newFolder.Parent = folder
			else
				folder:SetAttribute(i, j)				
			end
		end
	end
	mapArray(Profiles[player].Data, ReplicationFolder)
	if player:FindFirstChild("_replicationFolder") ~= nil then
		player["_replicationFolder"]:Destroy()
	end
	ReplicationFolder.Parent = player
end

function ProfileReplication:_getDataFromPath(datastructure, path)

	if typeof(path) == "string" then
		path = ProfileReplication:_stringToArray(path)
	end
	local function travel(parent, subpath)
		local key = subpath[1]
		if tonumber(key) and #subpath > 1 then 
			key = tonumber(key) 
		end
		if #subpath == 1 then
			return parent[key]

		else
			table.remove(subpath, 1)
			if parent[key] ~= nil then
				return travel(parent[key], subpath)
			else
				return
			end
		end
	end
	
	return travel(datastructure, path)
end

function ProfileReplication:_createOrUpdateOnReplicatedFolder(_player, _path)
	local function SetFolderData(_data, _folder)
		for i, j in pairs(_data) do
			if type(j) ~= "table" then
				_folder:SetAttribute(i, j)
			else
				if not _folder:FindFirstChild(i) then
					local newFolder = Instance.new("Folder")
					newFolder.Name = i
					newFolder.Parent = _folder
				end
				SetFolderData(j, _folder[i])
			end 
		end
	end
	local Folder, AttributeName = ProfileReplication:_navigateOnReplicatedDataFolder(_player, _path)
	local data = ProfileReplication:_getDataFromPath(Profiles[_player].Data, _path)
	if AttributeName then
		Folder:SetAttribute(AttributeName, data)
	else
		SetFolderData(data, Folder)
	end
end

function ProfileReplication:_navigateOnReplicatedDataFolder(player, path)
	local Steps = string.split(path, ".")
	local ActualStep = player:FindFirstChild("_replicationFolder")
	local function TestIfExistFolder(_parent, _seekedName)
		local folder = _parent:FindFirstChild(_seekedName)
		if folder then
			return folder
		else
			return 'false'
		end
	end
	if ActualStep then

		for i, j in pairs(Steps) do

			if i == #Steps then
				local attributeTest = ActualStep:GetAttribute(j)
				if attributeTest ~= nil then
					return ActualStep, j
				else
					local result = TestIfExistFolder(ActualStep, j)
					if result ~= 'false' then
						ActualStep = result
					end
				end
			else
				local result = TestIfExistFolder(ActualStep, j)
				if result ~= 'false' then
					ActualStep = result
				end
			end
		end
	end

	return ActualStep, nil
end

function ProfileReplication:_stringToArray(str)
	local arr = {}
	for s in string.gmatch(str, "[^.]+") do arr[#arr+1] = s end
	return arr
end

function ProfileReplication:_arrayToString(arr)
	return table.concat(arr, ".")
end

function ProfileReplication:_recursiveAction(datastructure, _path, value, action)
	local path = _path
	if typeof(path) == "string" then
		path = ProfileReplication:_stringToArray(path)
	end
	local function travel(parent, subpath)
		local key = subpath[1]
		if tonumber(key) and #subpath > 1 then 
			key = tonumber(key)
		end 
		if #subpath == 1 then
			return action(parent, key, value)
		else
			table.remove(subpath, 1)
			if parent[key] ~= nil then
				return travel(parent[key], subpath)
			end
			
			warn(_path, datastructure)
			error("Failed to find path on datastructure.")
			return
		end
	end
	return travel(datastructure, path)
end

function ProfileReplication:_deleteOnReplicatedFolder(_player, _path, key)

	local Folder, AttributeName = ProfileReplication:_navigateOnReplicatedDataFolder(_player, _path)
	local folderParent = Folder.Parent

	if AttributeName then
		Folder:SetAttribute(AttributeName, nil)
	elseif string.match(key, '[0-9]+') ~= nil and string.len(string.match(key, '[0-9]+')) == string.len(key) then
		folderParent[key]:Destroy()
		for i = tonumber(key) + 1, #folderParent:GetChildren() + 1 , 1 do
			folderParent[i].Name = 	i - 1			
		end
	else
		folderParent[key]:Destroy()
	end

end

return ProfileReplication