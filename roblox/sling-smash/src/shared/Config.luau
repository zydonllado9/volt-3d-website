--[[
	Sling Smash - shared configuration.

	Every tunable number in the game lives here so it can be balanced without
	touching gameplay code. Both the server and the client require this module.
]]

local Config = {}

Config.GameName = "SLING SMASH"
Config.DataStoreName = "SlingSmash_PlayerData_v1"
Config.AutosaveInterval = 120

--------------------------------------------------------------------------------
-- World layout
--------------------------------------------------------------------------------

Config.GroundY = 0
Config.Forward = Vector3.new(0, 0, -1) -- launch direction (down the lane)
Config.Right = Vector3.new(1, 0, 0)
Config.LaneWidth = 80
Config.LaneLength = 3000
Config.LobbySpawn = Vector3.new(0, 0.5, 70)
Config.ReturnPoint = Vector3.new(0, 4, 32)

-- The slingshot stands at the origin and fires towards Config.Forward.
Config.SlingshotPosition = Vector3.new(0, 0, 0)
Config.SlingshotArmTip = 12.8 -- height of the band anchor points
Config.SlingshotArmSpread = 2.96 -- half distance between the two arm tips
Config.PouchHeight = 11 -- character height while sitting in the pouch
Config.PouchRestOffset = 3 -- studs behind the slingshot at 0% power
Config.PouchPullDistance = 8 -- extra studs pulled back at 100% power

Config.BlockSize = 4
Config.CourseSeed = 1337
Config.CourseStart = 50

Config.Zones = {
	{
		Name = "Green Meadows",
		EndsAt = 550,
		ValueMult = 1,
		GroundA = Color3.fromRGB(112, 208, 72),
		GroundB = Color3.fromRGB(90, 184, 58),
		Outer = Color3.fromRGB(78, 162, 54),
		BlockMaterial = Enum.Material.SmoothPlastic,
		BlockColors = {
			Color3.fromRGB(198, 98, 66),
			Color3.fromRGB(172, 80, 56),
			Color3.fromRGB(216, 132, 88),
			Color3.fromRGB(150, 104, 72),
		},
	},
	{
		Name = "Sky City",
		EndsAt = 1250,
		ValueMult = 2.5,
		GroundA = Color3.fromRGB(150, 196, 236),
		GroundB = Color3.fromRGB(126, 176, 224),
		Outer = Color3.fromRGB(104, 150, 204),
		BlockMaterial = Enum.Material.SmoothPlastic,
		BlockColors = {
			Color3.fromRGB(96, 146, 236),
			Color3.fromRGB(142, 184, 250),
			Color3.fromRGB(226, 234, 255),
			Color3.fromRGB(70, 112, 210),
		},
	},
	{
		Name = "Neon Grid",
		EndsAt = 2050,
		ValueMult = 6,
		GroundA = Color3.fromRGB(26, 30, 42),
		GroundB = Color3.fromRGB(34, 40, 56),
		Outer = Color3.fromRGB(18, 20, 30),
		BlockMaterial = Enum.Material.Neon,
		BlockColors = {
			Color3.fromRGB(60, 255, 130),
			Color3.fromRGB(0, 210, 255),
			Color3.fromRGB(190, 90, 255),
			Color3.fromRGB(255, 70, 190),
		},
	},
	{
		Name = "Candy Peaks",
		EndsAt = math.huge,
		ValueMult = 15,
		GroundA = Color3.fromRGB(255, 186, 222),
		GroundB = Color3.fromRGB(255, 160, 206),
		Outer = Color3.fromRGB(236, 136, 188),
		BlockMaterial = Enum.Material.SmoothPlastic,
		BlockColors = {
			Color3.fromRGB(255, 120, 190),
			Color3.fromRGB(186, 140, 255),
			Color3.fromRGB(130, 236, 206),
			Color3.fromRGB(255, 236, 140),
		},
	},
}

--------------------------------------------------------------------------------
-- Smashing, combos and coins
--------------------------------------------------------------------------------

Config.Blocks = {
	Block = { Value = 10, Slowdown = 0.035 },
	Gold = { Value = 150, Slowdown = 0.02 },
	TNT = { Value = 25, Slowdown = 0, BlastRadius = 13, Boost = 22, Lift = 32 },
}

Config.CritChance = 0.08
Config.CritMultiplier = 3
Config.ComboStep = 6 -- smashes in a chain needed for each +1 multiplier
Config.BaseComboWindow = 1.0
Config.BaseMaxComboMult = 5
Config.StarValue = 300
Config.StarRadius = 3.5
Config.RingRadius = 7
Config.RingBoost = 35
Config.RingLift = 28
Config.CoinsPerStud = 2

--------------------------------------------------------------------------------
-- Flight physics (custom, simulated on the client)
--------------------------------------------------------------------------------

Config.Flight = {
	BaseSpeed = 95, -- launch speed at 100% power with no upgrades
	MinPower = 0.3, -- a quick tap still launches at 30%
	LaunchAngle = 24, -- degrees above the horizon
	ChargeTime = 1.3, -- seconds to charge from 0% to 100%
	Gravity = 70,
	AirDrag = 0.05, -- fraction of speed lost per second in the air
	GroundDecel = 40, -- studs/s^2 lost while sliding
	GroundDrag = 0.5, -- extra fraction of speed lost per second while sliding
	Bounce = 0.45, -- vertical speed kept on a bounce
	BounceKeep = 0.88, -- horizontal speed kept on a bounce
	MinBounceSpeed = 14,
	StopSpeed = 5,
	BodyHeight = 1.3, -- root part height above ground while sliding
	SteerAccel = 60,
	MaxSideSpeed = 40,
	SideDamping = 2,
	MaxFlightTime = 90,
}

--------------------------------------------------------------------------------
-- Upgrade tree (hex grid, axial coordinates, "Start" sits at 0,0)
--------------------------------------------------------------------------------

Config.Roman = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

Config.StartNode = {
	Id = "Start",
	Name = "Start",
	Icon = "🎯",
	Q = 0,
	R = 0,
}

Config.Branches = {
	{
		Key = "LaunchPower",
		Name = "Launch Power",
		Icon = "🚀",
		Description = "+20% launch speed per level.",
		Tiers = 5,
		Origin = { 0, 0 },
		Dir = { 1, -1 },
		Requires = "Start",
		Costs = { 100, 500, 1800, 6000, 20000 },
	},
	{
		Key = "HangTime",
		Name = "Hang Time",
		Icon = "🎈",
		Description = "-12% gravity per level. Stay in the air longer!",
		Tiers = 3,
		Origin = { 0, 0 },
		Dir = { 0, -1 },
		Requires = "Start",
		Costs = { 250, 1500, 8000 },
	},
	{
		Key = "AirControl",
		Name = "Air Control",
		Icon = "💨",
		Description = "+35% steering strength per level.",
		Tiers = 3,
		Origin = { 0, 0 },
		Dir = { -1, 0 },
		Requires = "Start",
		Costs = { 150, 900, 4000 },
	},
	{
		Key = "ComboTime",
		Name = "Combo Time",
		Icon = "🔥",
		Description = "+0.3s to keep your combo alive per level.",
		Tiers = 5,
		Origin = { 0, 0 },
		Dir = { -1, 1 },
		Requires = "Start",
		Costs = { 200, 800, 2500, 7500, 22000 },
	},
	{
		Key = "CoinBonus",
		Name = "Coin Bonus",
		Icon = "💰",
		Description = "+25% coins from everything per level.",
		Tiers = 6,
		Origin = { 0, 0 },
		Dir = { 0, 1 },
		Requires = "Start",
		Costs = { 150, 600, 2000, 6500, 18000, 50000 },
	},
	{
		Key = "SmashPower",
		Name = "Smash Power",
		Icon = "💥",
		Description = "+20% smash coins and -12% slowdown per level.",
		Tiers = 6,
		Origin = { 0, 0 },
		Dir = { 1, 0 },
		Requires = "Start",
		Costs = { 120, 500, 1600, 5000, 15000, 45000 },
	},
	{
		Key = "WreckingBall",
		Name = "Wrecking Ball",
		Icon = "💣",
		Description = "+1.5 studs smash radius per level.",
		Tiers = 3,
		Origin = { 2, 0 },
		Dir = { 1, -1 },
		Requires = "SmashPower2",
		Costs = { 3000, 12000, 40000 },
	},
	{
		Key = "ComboKing",
		Name = "Combo King",
		Icon = "👑",
		Description = "+3 max combo multiplier per level.",
		Tiers = 2,
		Origin = { -3, 3 },
		Dir = { -1, 0 },
		Requires = "ComboTime3",
		Costs = { 10000, 60000 },
	},
}

Config.Nodes = {}
Config.NodesById = {}

for _, branch in Config.Branches do
	for tier = 1, branch.Tiers do
		local node = {
			Id = branch.Key .. tier,
			Branch = branch.Key,
			Tier = tier,
			Name = branch.Name .. " " .. Config.Roman[tier],
			Icon = branch.Icon,
			Description = branch.Description,
			Cost = branch.Costs[tier],
			Requires = if tier == 1 then branch.Requires else branch.Key .. (tier - 1),
			Q = branch.Origin[1] + branch.Dir[1] * tier,
			R = branch.Origin[2] + branch.Dir[2] * tier,
		}
		table.insert(Config.Nodes, node)
		Config.NodesById[node.Id] = node
	end
end

-- Returns { [branchKey] = level } for a set of owned node ids.
function Config.GetLevels(upgrades)
	local levels = {}
	for _, branch in Config.Branches do
		local level = 0
		for tier = 1, branch.Tiers do
			if upgrades and upgrades[branch.Key .. tier] then
				level = tier
			else
				break
			end
		end
		levels[branch.Key] = level
	end
	return levels
end

function Config.RebirthMultiplier(rebirths)
	return 1 + Config.Rebirth.BonusPerRebirth * (rebirths or 0)
end

function Config.RebirthCost(rebirths)
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ (rebirths or 0))
end

-- Every gameplay stat derived from upgrades + rebirths.
function Config.ComputeStats(upgrades, rebirths)
	local levels = Config.GetLevels(upgrades)
	local flight = Config.Flight
	return {
		Levels = levels,
		LaunchSpeed = flight.BaseSpeed * (1 + 0.2 * levels.LaunchPower),
		Gravity = flight.Gravity * (1 - 0.12 * levels.HangTime),
		Steer = flight.SteerAccel * (1 + 0.35 * levels.AirControl),
		ComboWindow = Config.BaseComboWindow + 0.3 * levels.ComboTime,
		MaxComboMult = Config.BaseMaxComboMult + 3 * levels.ComboKing,
		SmashCoinMult = 1 + 0.2 * levels.SmashPower,
		SmashSlow = math.max(0.25, 1 - 0.12 * levels.SmashPower),
		HitRadius = 4 + 1.5 * levels.WreckingBall,
		CoinMult = (1 + 0.25 * levels.CoinBonus) * Config.RebirthMultiplier(rebirths),
	}
end

function Config.ComboMultiplier(combo, maxMult)
	if combo <= 0 then
		return 1
	end
	return math.min(maxMult, 1 + math.floor(combo / Config.ComboStep))
end

-- Highest coin value a single smashed block can have before multipliers.
function Config.MaxBlockValue()
	local best = 0
	for _, block in Config.Blocks do
		best = math.max(best, block.Value)
	end
	local zoneMult = 0
	for _, zone in Config.Zones do
		zoneMult = math.max(zoneMult, zone.ValueMult)
	end
	return best * zoneMult
end

--------------------------------------------------------------------------------
-- Rebirth, trails, settings, sounds
--------------------------------------------------------------------------------

Config.Rebirth = {
	BaseCost = 100000,
	CostGrowth = 2,
	BonusPerRebirth = 0.5, -- +50% coins per rebirth
}

Config.Trails = {
	{ Id = "None", Name = "No Trail", Price = 0 },
	{
		Id = "Ocean",
		Name = "Ocean",
		Price = 2500,
		Colors = { Color3.fromRGB(0, 170, 255), Color3.fromRGB(0, 255, 210) },
	},
	{
		Id = "Fire",
		Name = "Fire",
		Price = 8000,
		Colors = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 70, 30) },
	},
	{
		Id = "Toxic",
		Name = "Toxic",
		Price = 20000,
		Colors = { Color3.fromRGB(190, 255, 60), Color3.fromRGB(40, 200, 80) },
	},
	{
		Id = "Galaxy",
		Name = "Galaxy",
		Price = 60000,
		Colors = { Color3.fromRGB(120, 60, 255), Color3.fromRGB(255, 80, 200) },
	},
	{
		Id = "Rainbow",
		Name = "Rainbow",
		Price = 150000,
		Colors = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 200, 40),
			Color3.fromRGB(60, 230, 90),
			Color3.fromRGB(40, 200, 255),
			Color3.fromRGB(170, 80, 255),
		},
	},
}

Config.TrailsById = {}
for _, trail in Config.Trails do
	Config.TrailsById[trail.Id] = trail
end

Config.DefaultSettings = {
	Music = true,
	SFX = true,
	CameraShake = true,
	SpeedLines = true,
	Hints = true,
}

Config.SettingsOrder = { "Music", "SFX", "CameraShake", "SpeedLines", "Hints" }

Config.SettingLabels = {
	Music = "Music",
	SFX = "SFX",
	CameraShake = "Camera Shake",
	SpeedLines = "Speed Lines",
	Hints = "Hints",
}

-- Built-in engine sounds work in every place without uploading anything.
-- Paste an "rbxassetid://<id>" into Music to add background music.
Config.Sounds = {
	Music = "",
	Launch = "rbxasset://sounds/action_jump.mp3",
	Wind = "rbxasset://sounds/action_falling.mp3",
	Smash = "rbxasset://sounds/action_jump_land.mp3",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/electronicpingshort.wav",
}

return Config
