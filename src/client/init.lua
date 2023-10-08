-- ### External Types
-- Signal types
export type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnections: (self: Signal<T...>) -> { Connection },
	Destroy: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

-- ### Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ### Packages
local Packages = script.Packages
local Signal = require(Packages.signal)
local Promise = require(Packages.promise)

export type Class = {
    dataFolderAdded: () -> any, -- is a Promise
    getDataFolder: () -> Folder,
    -- callbacks
    onPlayerDataAdded:(callback: (player: Player, folder: Folder) -> nil) -> RBXScriptSignal,
    onPlayerDataRemoved:(callback: (player: Player, folder: Folder) -> nil) -> RBXScriptSignal,
    onLocalDataAdded:(callback: (folder: Folder) -> nil) -> RBXScriptSignal,
}

export type PrivateClass = {
    profilesFolder: Folder,
    playerToFolder: {[Player]: Folder},
    signals: {
        playerDataAdded: Signal,
        playerDataRemoved: Signal,
        otherPlayerDataAdded: Signal,
        otherPlayerDataRemoved: Signal,
        localDataAdded: Signal,
    },
}

local ProfileReplication: Class | PrivateClass = {}
ProfileReplication.__index = ProfileReplication

function ProfileReplication.new()
    local self = setmetatable({}, ProfileReplication)

    self.signals = {
        playerDataAdded = Signal.new() :: Signal,
        playerDataRemoved = Signal.new() :: Signal,
        localDataAdded = Signal.new() :: Signal,
    }
    self.profilesFolder = nil
    self.playerToFolder = {}
    return self
end

function ProfileReplication:init()
    
end

function ProfileReplication:start()
    self:getProfilesFolder()

    for _, folder in self.profilesFolder:GetChildren() do
        self:playerFolderAdded(folder)
    end
    self.profilesFolder.ChildAdded:Connect(function(child)
        self:playerFolderAdded(child)
    end)

    self.profilesFolder.ChildRemoved:Connect(function(child)
        self:playerFolderRemoved(child)
    end)
end

function ProfileReplication:playerFolderAdded(folder: Folder)
    local player = Players:GetPlayerByUserId(folder.Name)
    if player == nil then return end

    self.playerToFolder[player] = folder

    if player == Players.LocalPlayer then
        self.signals.localDataAdded:Fire(folder)
    end
    self.signals.playerDataAdded:Fire(player, folder)
end

function ProfileReplication:playerFolderRemoved(folder: Folder)
    local player = Players:GetPlayerByUserId(folder.Name)
    if player == nil then
        warn('data removed but player is nill')
        return
    end
    self.playerToFolder[player] = nil
    self.signals.playerDataRemoved:Fire(folder)
end

function ProfileReplication:getProfilesFolder()
    if self.profilesFolder ~= nil then return end
    self.profilesFolder = ReplicatedStorage:WaitForChild("profiles")
end

--- ### API

function ProfileReplication:dataFolderAdded()
    self:getProfilesFolder()
    if self.playerToFolder[Players.LocalPlayer] ~= nil then
        warn("1")
        return Promise.resolve()
    end

    return Promise.new(function(resolve, reject, onCancel)
        warn('2')
        local connection
        connection = self:onLocalDataAdded(function(folder)
            warn('3')
            connection:Disconnect()
            resolve(folder)
        end)
    end)
end

function ProfileReplication:getDataFolder()
    self:getProfilesFolder()
    if self.playerToFolder[Players.LocalPlayer] ~= nil then return self.playerToFolder[Players.LocalPlayer] end
    return self.profilesFolder:WaitForChild(Players.LocalPlayer.UserId)
end

function ProfileReplication:onPlayerDataFolderAdded(callback: (player: Player, folder: Folder) -> nil): RBXScriptConnection
    return self.signals.playerDataAdded:Connect(function(player, folder)
        callback(player, folder)
    end)
end

function ProfileReplication:onPlayerDataFolderRemoved(callback: (player: Players, folder: Folder) -> nil): RBXScriptConnection
    return self.signals.playerDataRemoved:Connect(function(player, folder)
        callback(player, folder)
    end)
end

function ProfileReplication:onLocalDataAdded(callback: (folder: Folder) -> nil): RBXScriptConnection
    return self.signals.localDataAdded:Connect(function(folder)
        callback(folder)
    end)
end

return ProfileReplication.new() :: Class