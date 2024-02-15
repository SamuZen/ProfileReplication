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

export type Class = {
    Start: () -> any,
}

export type PrivateClass = {
    PlayerFolderAdded: (Folder) -> nil,
    PlayerFolderRemoved: (Folder) -> nil,
}

local ProfileReplication: Class | PrivateClass = {}

ProfileReplication.ProfilesFolder = nil
ProfileReplication.PlayerToFolder = {}
ProfileReplication.MyDataFolder = nil

ProfileReplication.Signals = {
    PlayerDataAdded = Signal.new() :: Signal,
    PlayerDataRemoved = Signal.new() :: Signal,
    LocalDataAdded = Signal.new() :: Signal,
}

function ProfileReplication.Start()
    ProfileReplication.ProfilesFolder = ReplicatedStorage:WaitForChild("profiles")

    for _, folder in ProfileReplication.ProfilesFolder:GetChildren() do
        ProfileReplication.PlayerFolderAdded(folder)
    end
    ProfileReplication.ProfilesFolder.ChildAdded:Connect(function(child)
        ProfileReplication.PlayerFolderAdded(child)
    end)
    ProfileReplication.ProfilesFolder.ChildRemoved:Connect(function(child)
        ProfileReplication.PlayerFolderRemoved(child)
    end)

    ProfileReplication.MyDataFolder = ProfileReplication.ProfilesFolder:WaitForChild(Players.LocalPlayer.UserId)
end

function ProfileReplication.PlayerFolderAdded(folder: Folder)
    local player = Players:GetPlayerByUserId(folder.Name)
    if player == nil then return end

    ProfileReplication.PlayerToFolder[player] = folder
    ProfileReplication.Signals.PlayerDataAdded:Fire(player, folder)
end

function ProfileReplication.PlayerFolderRemoved(folder: Folder)
    local player = Players:GetPlayerByUserId(folder.Name)
    if player == nil then
        warn('data removed but player is nill')
        return
    end
    ProfileReplication.PlayerToFolder[player] = nil
    ProfileReplication.Signals.PlayerDataRemoved:Fire(folder)
end

return ProfileReplication :: Class