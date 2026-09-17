-- v44.11: auto-execute can run before the game has loaded; wait for the
-- player, PlayerGui and Backpack first.
do
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    local players = game:GetService("Players")
    while not players.LocalPlayer do
        task.wait(0.1)
    end
    local player = players.LocalPlayer
    player:WaitForChild("PlayerGui", 60)
    player:WaitForChild("Backpack", 60)
    local waited = 0
    while not player.Character and waited < 30 do
        task.wait(0.25)
        waited += 0.25
    end
    task.wait(0.5)
end

if getgenv().UIW then
    pcall(function()
        getgenv().UIW:Destroy()
    end)
elseif getgenv().UNDERWORLD_AI then
    pcall(function()
        getgenv().UNDERWORLD_AI:Destroy()
    end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
