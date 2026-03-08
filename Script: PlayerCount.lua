local Players = game:GetService("Players")

local playerCountValue = Instance.new("IntValue")
playerCountValue.Name = "PlayerCount"
playerCountValue.Parent = game.ReplicatedStorage

local function updateCount()
	playerCountValue.Value = #Players:GetPlayers()
end

Players.PlayerAdded:Connect(updateCount)
Players.PlayerRemoving:Connect(updateCount)

updateCount()
