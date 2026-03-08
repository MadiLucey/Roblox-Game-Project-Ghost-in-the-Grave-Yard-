local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerCount = ReplicatedStorage:WaitForChild("PlayerCount")
local roundStateEvent = ReplicatedStorage:WaitForChild("RoundStateEvent")

local label = script.Parent:WaitForChild("StatusText")
local MIN_PLAYERS = 4

local function updateText()
	label.Text = "Waiting for players (" .. playerCount.Value .. "/" .. MIN_PLAYERS .. ")"
end

playerCount.Changed:Connect(updateText)
updateText()

roundStateEvent.OnClientEvent:Connect(function(state)
	label.Visible = (state == "Lobby")
end)
