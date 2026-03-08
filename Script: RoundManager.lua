-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- SETTINGS
local MIN_PLAYERS = 4
local COUNTDOWN_TIME = 12
local NORMAL_SPEED = 16
local GHOST_SPEED = 20
local IMMUNITY_TIME = 5

-- REMOTES
local clockEvent = ReplicatedStorage:WaitForChild("ClockEvent")
local roundStateEvent = ReplicatedStorage:WaitForChild("RoundStateEvent")
local ghostEvent = ReplicatedStorage:WaitForChild("GhostEvent")

-- SPAWNS
local ghostSpawn = Workspace:WaitForChild("ghost_spawn")
local playerSpawn = Workspace:WaitForChild("player_spawn")
local lobbySpawn = Workspace:WaitForChild("lobby_spawn")

-- STATE
local roundActive = false
local aliveSeekers = {}
local immunePlayers = {}
local safeZoneActive = false
local ghostReleased = false

-- HELPERS
local function safeTeleport(player, spawnPart)
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	local rootPart = player.Character:WaitForChild("HumanoidRootPart")
	rootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
end

local function setSpeed(player, speed)
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed
		end
	end
end

local function endRound(winner)
	print("Winners:", winner)
	roundStateEvent:FireAllClients("Lobby")

	-- Reset speed and teleport everyone to lobby
	for _, player in ipairs(Players:GetPlayers()) do
		setSpeed(player, NORMAL_SPEED)
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			player.Character.HumanoidRootPart.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	roundActive = false
end

-- MAIN ROUND FUNCTION
local function startRound()
	if roundActive then return end
	if #Players:GetPlayers() < MIN_PLAYERS then return end

	roundActive = true
	print("Round starting")

	local players = Players:GetPlayers()

	-- Pick ghost
	local ghostPlayer = players[math.random(#players)]
	print("Ghost is:", ghostPlayer.Name)
	ghostEvent:FireAllClients(ghostPlayer.UserId)

	-- Teleport players & setup aliveSeekers
	aliveSeekers = {}
	immunePlayers = {}
	safeZoneActive = false
	ghostReleased = false

	for _, player in ipairs(players) do
		if player == ghostPlayer then
			safeTeleport(player, ghostSpawn)
			setSpeed(player, GHOST_SPEED) -- ghost moves freely during countdown
		else
			safeTeleport(player, playerSpawn)
			setSpeed(player, 0) -- seekers stunned during countdown
			aliveSeekers[player] = true
		end
	end

	-- COUNTDOWN PHASE
	roundStateEvent:FireAllClients("Countdown")
	for i = 1, COUNTDOWN_TIME do
		clockEvent:FireAllClients(i)
		task.wait(1)
	end

	-- AFTER COUNTDOWN
	setSpeed(ghostPlayer, 0) -- ghost freezes
	for player in pairs(aliveSeekers) do
		setSpeed(player, NORMAL_SPEED) -- seekers move
	end
	roundStateEvent:FireAllClients("Search")
	print("Seekers released, ghost frozen until first seeker contact.")

	-- FIRST SEEKER CONTACT → RELEASE GHOST
	local ghostHumanoidRoot = ghostPlayer.Character:WaitForChild("HumanoidRootPart")
	local ghostTouchConnection

	local function onGhostTouched(hit)
		task.wait(2)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and aliveSeekers[player] and not ghostReleased then
			print("Ghost released by:", player.Name)
			ghostReleased = true
			setSpeed(ghostPlayer, GHOST_SPEED) -- ghost moves again

			-- Enable safe zone now
			safeZoneActive = true

			-- Apply immunity
			immunePlayers[player] = true
			task.spawn(function()
				task.wait(IMMUNITY_TIME)
				immunePlayers[player] = nil
				print(player.Name.." immunity ended")
			end)

			-- Disconnect first-contact listener
			if ghostTouchConnection then ghostTouchConnection:Disconnect() end
		end
	end

	ghostTouchConnection = ghostHumanoidRoot.Touched:Connect(onGhostTouched)

	-- GHOST TAG LOGIC
	local function onTag(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if not aliveSeekers[player] then return end
		if not ghostReleased then return end       -- cannot tag before first contact
		if immunePlayers[player] then return end  -- ignore immune player

		print("Ghost tagged:", player.Name)
		aliveSeekers[player] = nil

		if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
			player.Character:FindFirstChildOfClass("Humanoid").Health = 0
		end

		-- Check if round over
		local remaining = 0
		for _ in pairs(aliveSeekers) do remaining += 1 end
		if remaining == 0 then
			endRound("Ghost")
		end
	end

	local tagConnection = ghostHumanoidRoot.Touched:Connect(onTag)

	-- SAFE ZONE LOGIC
	local function onSafeZoneTouched(hit)
		if not safeZoneActive then return end -- inactive until ghost is found

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and aliveSeekers[player] then
			print("Seeker safe:", player.Name)
			aliveSeekers[player] = nil

			-- Check if all seekers safe
			local remaining = 0
			for _ in pairs(aliveSeekers) do remaining += 1 end
			if remaining == 0 then
				endRound("Seekers")
			end
		end
	end

	local safeZoneConnection = playerSpawn.Touched:Connect(onSafeZoneTouched)

	-- WAIT FOR ROUND TO END
	while roundActive do
		task.wait(1)
	end

	-- CLEANUP
	if ghostTouchConnection then ghostTouchConnection:Disconnect() end
	if tagConnection then tagConnection:Disconnect() end
	if safeZoneConnection then safeZoneConnection:Disconnect() end
end

-- AUTO START LOOP WITH 2-SECOND WAIT
task.spawn(function()
	while true do
		task.wait(1)
		if not roundActive and #Players:GetPlayers() >= MIN_PLAYERS then
			-- Enough players detected, wait 2 seconds before starting
			task.wait(10)
			-- Double-check players again in case someone left
			if not roundActive and #Players:GetPlayers() >= MIN_PLAYERS then
				startRound()
			end
		end
	end
end)
