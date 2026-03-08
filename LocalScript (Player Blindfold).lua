local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local clockEvent = ReplicatedStorage:WaitForChild("ClockEvent")
local roundStateEvent = ReplicatedStorage:WaitForChild("RoundStateEvent")
local ghostEvent = ReplicatedStorage:WaitForChild("GhostEvent")

local player = Players.LocalPlayer

local label = script.Parent:WaitForChild("ClockText")
local blindfold = script.Parent:WaitForChild("Blindfold")

label.Visible = false
blindfold.Visible = false

local ghostUserId = nil

-- Receive who the ghost is
ghostEvent.OnClientEvent:Connect(function(userId)
	ghostUserId = userId
end)

roundStateEvent.OnClientEvent:Connect(function(state)
	if state == "Countdown" then
		label.Visible = true

		-- Only blindfold SEEKERS
		if ghostUserId ~= player.UserId then
			blindfold.Visible = true
		else
			blindfold.Visible = false
		end
	else
		label.Visible = false
		blindfold.Visible = false
	end
end)

clockEvent.OnClientEvent:Connect(function(number)
	label.Text = number .. " O'Clock"
end)
