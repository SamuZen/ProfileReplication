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

--
local ProfileReplication = {}
ProfileReplication.__index = ProfileReplication

ProfileReplication.Signals = {
	playerProfileLoaded = Signal.new(),
	beforePlayerRemoving = Signal.new(),
}

function ProfileReplication:init(databaseName: string, profileTemplate: table)
    ProfileStore = ProfileService.GetProfileStore(
        databaseName,
        profileTemplate
    )

    Players.PlayerAdded:Connect(function(player)
        self:_loadPlayerProfile(player)
    end)

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

function ProfileReplication:start()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_loadPlayerProfile(player)
		end)
	end
end

-- ### API

function ProfileReplication:ChangeValueOnProfile(_player: Player, _path, _newValue)
	local function ChangeValue(parent, key, value)
		parent[key] = value
	end
	
	if Profiles[_player] then
		ProfileReplication:_recursiveAction(Profiles[_player].Data, _path, _newValue, ChangeValue)
		onDataChanged:Fire(_player, _path, true)
		return Profiles[_player].Data
	else
		warn("Failed to change value on " .. _player.DisplayName .. " there is no profile loaded")
	end

end

function ProfileReplication:AppendTableToProfileInPath(_player, _path, _value, _key)
	assert(_player ~= nil, "To create a replicated folder, the argument needs to be a player, got nil")
	assert(typeof(_player) == "Instance", "To create a replicated folder, the argument needs to be a player Instance")
	assert(_player:IsA("Player") , "Argument instance needs to be a 'Player'")
	assert(Profiles[_player], "No profile found with passed player" )

	local function AddTable(parent, key, value)
		assert(type(parent[key]) == "table", "The final of the path value needs to be a table. Got a " .. type(parent[key]) )
		table.insert(parent[key], value)
	end

	local function AddTableWithKey(parent, key, value)
		assert(type(parent[key]) == "table", "The final of the path value needs to be a table. Got a " .. type(parent[key]) )
		parent[key][_key] = value
	end

	if _key ~= nil then
		assert(type(_key) == "string", "Table key needs to be a string, got " .. type(_key))

		ProfileReplication:_recursiveAction(Profiles[_player].Data, _path, _value, AddTableWithKey)
	else
		ProfileReplication:_recursiveAction(Profiles[_player].Data, _path, _value, AddTable)

	end

	onDataChanged:Fire(_player, _path, true)
	return Profiles[_player].Data
end

function ProfileReplication:IncrementDataValueInPath(_player, _path, _value)
	assert(type(_path) == "string", "Path needs to be a string")
	assert(_value ~= nil, "Value needs to be different of nil")
	assert(type(_value) == "number", "Value needs to be a number")

	if Profiles[_player] == nil then
		return
	end

	local Folder, Attribute = ProfileReplication:_navigateOnReplicatedDataFolder(_player, _path)
	local function Increment(parent, key, value)

		assert(type(parent[key]) == "number", "Data value needs to be a number")

		parent[key] += value 
	end
	ProfileReplication:_recursiveAction(Profiles[_player].Data, _path, _value, Increment)
	onDataChanged:Fire(_player, _path, true)     
	return Profiles[_player].Data
end

function ProfileReplication:DeleteDataValueInPath(_player, _path)
	local function Delete(parent, key, value)
		if string.match(key, '[0-9]+') ~= nil and string.len(string.match(key, '[0-9]+')) == string.len(key) then
			table.remove(parent, key)
		elseif type(key) == "string" then
			parent[key] = nil
		end 
		onDataChanged:Fire(_player, _path, false, key)
	end
	ProfileReplication:_recursiveAction(Profiles[_player].Data, _path, nil, Delete)

	return Profiles[_player].Data
end

function ProfileReplication:GetPlayerData(_player)
	if Profiles[_player] ~= nil then
		return TableUtil.Copy(Profiles[_player].Data)
	end
end

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

function ProfileReplication:GetPlayerProfileAsync(player)
	return Profiles[player]
end

-- ### Private

function ProfileReplication:_loadPlayerProfile(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	
	if profile ~= nil then
		profile:AddUserId(player.UserId) 
		profile:Reconcile() 
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(game:GetService('Players')) == true then
			warn("Player profile loaded! ", profile)

			Profiles[player] = profile
			ProfileReplication:_renderReplicatedFolder(player)

			ProfileReplication.Signals.playerProfileLoaded:Fire(player, profile)
			return player, profile
		else
			profile:Release()
		end
	else
		player:Kick() 
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

function ProfileReplication:_recursiveAction(datastructure, path, value, action)
	if typeof(path) == "string" then
		path = ProfileReplication:_stringToArray(path)
	end
	local function travel(parent, subpath)
		local key = subpath[1]
		if tonumber(key) and #subpath > 1 then 
			key = tonumber(key) 
		end 
		if #subpath == 1 then
			action(parent, key, value)
		else
			table.remove(subpath, 1)		
			if parent[key] ~= nil then
				travel(parent[key], subpath)
			end
			
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

--ProfileReplication:init()
--ProfileReplication:start()

return ProfileReplication