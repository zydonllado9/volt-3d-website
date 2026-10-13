--[[
	Sling Smash - server entry point.

	Builds the world, owns player data (coins, upgrades, trails, settings),
	and validates launch results reported by clients.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CourseLayout = require(Shared:WaitForChild("CourseLayout"))

local DataService = require(script.DataService)
local WorldBuilder = require(script.WorldBuilder)

Players.CharacterAutoLoads = false

--------------------------------------------------------------------------------
-- Collision groups
--   Players: walking characters (don't push each other around the slingshot)
--   Flyer:   a character mid-launch (set by its own client; passes through all)
--   Debris:  smashed blocks flying around (never hit characters)
--------------------------------------------------------------------------------

for _, name in { "Players", "Flyer", "Debris" } do
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Flyer", "Default", false)
PhysicsService:CollisionGroupSetCollidable("Flyer", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Flyer", "Flyer", false)
PhysicsService:CollisionGroupSetCollidable("Flyer", "Debris", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Players", false)

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function remote(className: string, name: string): any
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = remotes
	return instance
end

local GetData = remote("RemoteFunction", "GetData") :: RemoteFunction
local DataChanged = remote("RemoteEvent", "DataChanged") :: RemoteEvent
local StartLaunch = remote("RemoteFunction", "StartLaunch") :: RemoteFunction
local FinishLaunch = remote("RemoteFunction", "FinishLaunch") :: RemoteFunction
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade") :: RemoteFunction
local Rebirth = remote("RemoteFunction", "Rebirth") :: RemoteFunction
local BuyTrail = remote("RemoteFunction", "BuyTrail") :: RemoteFunction
local EquipTrail = remote("RemoteFunction", "EquipTrail") :: RemoteFunction
local UpdateSetting = remote("RemoteEvent", "UpdateSetting") :: RemoteEvent

remotes.Parent = ReplicatedStorage

--------------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------------

WorldBuilder.Build()

local layout = CourseLayout.Get()

--------------------------------------------------------------------------------
-- Characters + trails
--------------------------------------------------------------------------------

local function applyTrail(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, child in root:GetChildren() do
		if child.Name == "SlingTrail" or child.Name == "SlingTrailA0" or child.Name == "SlingTrailA1" then
			child:Destroy()
		end
	end

	local data = DataService.Get(player)
	local trailInfo = data and Config.TrailsById[data.EquippedTrail]
	if not trailInfo or not trailInfo.Colors then
		return
	end

	-- Attachments sit shoulder-to-shoulder so the ribbon is wide whether the
	-- character is standing or flying superman-style.
	local a0 = Instance.new("Attachment")
	a0.Name = "SlingTrailA0"
	a0.Position = Vector3.new(-1.2, 0, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "SlingTrailA1"
	a1.Position = Vector3.new(1.2, 0, 0)
	a1.Parent = root

	local keypoints = {}
	local colors = trailInfo.Colors
	for i, color in colors do
		local time = if #colors == 1 then 0 else (i - 1) / (#colors - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end

	local trail = Instance.new("Trail")
	trail.Name = "SlingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.6
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = root
end

local function setCollisionGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = "Players"
	end
end

local function spawnCharacter(player: Player)
	if player.Parent ~= Players then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn("[SlingSmash] Could not spawn", player.Name, err)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	for _, descendant in character:GetDescendants() do
		setCollisionGroup(descendant)
	end
	character.DescendantAdded:Connect(setCollisionGroup)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			task.wait(2.5)
			spawnCharacter(player)
		end)
	end

	character:WaitForChild("HumanoidRootPart", 10)
	applyTrail(player)
end

DataService.OnChanged(function(player, data)
	DataChanged:FireClient(player, data)
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	DataService.Load(player)
	spawnCharacter(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Release(player)
end)

game:BindToClose(function()
	DataService.SaveAll()
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.Save, player)
		end
	end
end)

--------------------------------------------------------------------------------
-- Launch validation
--------------------------------------------------------------------------------

local sessions = {} -- [Player] = { Id, StartedAt, Active }

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

-- tonumber that also rejects NaN and infinities from untrusted input.
local function safeNumber(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return n
end

GetData.OnServerInvoke = function(player)
	return DataService.WaitFor(player, 20)
end

StartLaunch.OnServerInvoke = function(player)
	if not DataService.Get(player) then
		return nil
	end
	local session = sessions[player] or { Id = 0 }
	session.Id += 1
	session.StartedAt = os.clock()
	session.Active = true
	sessions[player] = session
	return session.Id
end

FinishLaunch.OnServerInvoke = function(player, launchId, report)
	local data = DataService.Get(player)
	local session = sessions[player]
	if not data or not session or not session.Active or session.Id ~= launchId or type(report) ~= "table" then
		return nil
	end
	session.Active = false

	local elapsed = os.clock() - session.StartedAt
	local stats = Config.ComputeStats(data.Upgrades, data.Rebirths)

	-- Clamp every reported number to what is physically possible.
	local maxDistance = math.min(Config.LaneLength + 20, elapsed * stats.LaunchSpeed * 2.5 + 40)
	local distance = math.clamp(safeNumber(report.Distance), 0, maxDistance)
	-- TNT chains can smash dozens at once, but never hundreds per second.
	local maxSmashes = math.min(layout.TotalBlocks, math.floor(60 + elapsed * 30))
	local smashes = math.clamp(math.floor(safeNumber(report.Smashes)), 0, maxSmashes)
	local stars = math.clamp(math.floor(safeNumber(report.Stars)), 0, #layout.Stars)
	local maxCombo = math.clamp(math.floor(safeNumber(report.MaxCombo)), 0, smashes)

	local maxZoneMult = Config.Zones[#Config.Zones].ValueMult
	local ceiling = (
		smashes * Config.MaxBlockValue() * stats.SmashCoinMult * stats.MaxComboMult * Config.CritMultiplier
		+ stars * Config.StarValue * maxZoneMult
	) * stats.CoinMult
	local runCoins = math.clamp(math.floor(safeNumber(report.RunCoins)), 0, math.floor(ceiling))
	local distanceCoins = math.floor(distance * Config.CoinsPerStud * stats.CoinMult)
	local earned = runCoins + distanceCoins

	local newBest = distance > data.BestDistance
	data.Coins += earned
	if newBest then
		data.BestDistance = math.floor(distance)
	end
	data.Stats.Launches += 1
	data.Stats.TotalSmashes += smashes
	data.Stats.TotalCoins += earned
	data.Stats.TotalDistance += math.floor(distance)
	data.Stats.StarsCollected += stars
	data.Stats.BestCombo = math.max(data.Stats.BestCombo, maxCombo)
	DataService.Changed(player)

	return {
		Earned = earned,
		RunCoins = runCoins,
		DistanceCoins = distanceCoins,
		Distance = math.floor(distance),
		Smashes = smashes,
		MaxCombo = maxCombo,
		Stars = stars,
		NewBest = newBest,
		Best = data.BestDistance,
	}
end

--------------------------------------------------------------------------------
-- Upgrades, rebirth, trails, settings
--------------------------------------------------------------------------------

BuyUpgrade.OnServerInvoke = function(player, nodeId)
	local data = DataService.Get(player)
	local node = type(nodeId) == "string" and Config.NodesById[nodeId]
	if not data or not node then
		return false, "Unknown upgrade"
	end
	if data.Upgrades[node.Id] then
		return false, "Already owned"
	end
	if node.Requires ~= "Start" and not data.Upgrades[node.Requires] then
		return false, "Unlock the previous upgrade first"
	end
	if data.Coins < node.Cost then
		return false, "Not enough coins"
	end
	data.Coins -= node.Cost
	data.Upgrades[node.Id] = true
	DataService.Changed(player)
	return true
end

Rebirth.OnServerInvoke = function(player)
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Coins < cost then
		return false, "Not enough coins"
	end
	data.Coins = 0
	data.Upgrades = {}
	data.Rebirths += 1
	DataService.Changed(player)
	return true
end

BuyTrail.OnServerInvoke = function(player, trailId)
	local data = DataService.Get(player)
	local trail = type(trailId) == "string" and Config.TrailsById[trailId]
	if not data or not trail then
		return false, "Unknown trail"
	end
	if data.Trails[trail.Id] then
		return false, "Already owned"
	end
	if data.Coins < trail.Price then
		return false, "Not enough coins"
	end
	data.Coins -= trail.Price
	data.Trails[trail.Id] = true
	data.EquippedTrail = trail.Id
	DataService.Changed(player)
	applyTrail(player)
	return true
end

EquipTrail.OnServerInvoke = function(player, trailId)
	local data = DataService.Get(player)
	if not data or type(trailId) ~= "string" or not data.Trails[trailId] then
		return false, "Trail not owned"
	end
	data.EquippedTrail = trailId
	DataService.Changed(player)
	applyTrail(player)
	return true
end

UpdateSetting.OnServerEvent:Connect(function(player, key, value)
	local data = DataService.Get(player)
	if not data or type(key) ~= "string" or type(value) ~= "boolean" then
		return
	end
	if Config.DefaultSettings[key] == nil then
		return
	end
	data.Settings[key] = value
end)

print("[SlingSmash] Server ready -", layout.TotalBlocks, "blocks,", #layout.Stars, "stars,", #layout.Rings, "boost rings")
