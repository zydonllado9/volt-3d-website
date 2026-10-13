--[[
	Builds the static world on the server: lobby, slingshot, the long launch
	lane with its zones, decorations and lighting.

	The smashable obstacles are NOT built here; each client builds its own copy
	(see Client/Course) so smashing is instant and resets for every launch.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)

local WorldBuilder = {}

local TILE = 40
local GROUND_HALF_WIDTH = 120 -- checker tiles cover x = -120..120

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function sign(parent: Instance, size: Vector3, cframe: CFrame, text: string, color: Color3, textColor: Color3?)
	local board = part({
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = color,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the +Z face, which faces the lobby
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(40, 24, 12)
	stroke.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.Parent = label
	return board
end

--------------------------------------------------------------------------------
-- Ground
--------------------------------------------------------------------------------

local function buildGround(map: Folder)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map

	local startZ = 160
	local endZ = -(Config.LaneLength + 120)

	local row = 0
	local z = startZ
	while z > endZ do
		local centerZ = z - TILE / 2
		local zone = Config.Zones[CourseLayout.ZoneIndexAt(math.max(0, -centerZ))]
		local col = 0
		for x = -GROUND_HALF_WIDTH, GROUND_HALF_WIDTH - TILE, TILE do
			part({
				Name = "Tile",
				Size = Vector3.new(TILE, 2, TILE),
				CFrame = CFrame.new(x + TILE / 2, Config.GroundY - 1, centerZ),
				Color = if (row + col) % 2 == 0 then zone.GroundA else zone.GroundB,
				Material = Enum.Material.Plastic,
				Parent = ground,
			})
			col += 1
		end
		row += 1
		z -= TILE
	end

	-- Wide side ground out to the horizon, split per zone (parts max out at 2048 studs).
	local sideWidth = 900
	local zoneStart = -startZ
	for index, zone in Config.Zones do
		local zoneEnd = math.min(zone.EndsAt, Config.LaneLength + 120)
		if index == #Config.Zones then
			zoneEnd = Config.LaneLength + 120
		end
		local length = zoneEnd - zoneStart
		while length > 0 do
			local segment = math.min(length, 2000)
			local centerZ = -(zoneStart + segment / 2)
			for _, side in { -1, 1 } do
				part({
					Name = "SideGround",
					Size = Vector3.new(sideWidth, 2, segment),
					CFrame = CFrame.new(side * (GROUND_HALF_WIDTH + sideWidth / 2), Config.GroundY - 1.05, centerZ),
					Color = zone.Outer,
					Material = Enum.Material.Plastic,
					Parent = ground,
				})
			end
			zoneStart += segment
			length -= segment
		end
	end

	-- Ground behind the lobby.
	part({
		Name = "LobbyBack",
		Size = Vector3.new(GROUND_HALF_WIDTH * 2 + sideWidth * 2, 2, 600),
		CFrame = CFrame.new(0, Config.GroundY - 1.05, startZ + 300),
		Color = Config.Zones[1].Outer,
		Material = Enum.Material.Plastic,
		Parent = ground,
	})

	-- Neon grid lines in the Neon zone.
	local neonZone = Config.Zones[3]
	local neonStart = Config.Zones[2].EndsAt
	for d = neonStart, neonZone.EndsAt, TILE do
		part({
			Name = "NeonLine",
			Size = Vector3.new(GROUND_HALF_WIDTH * 2, 0.2, 0.6),
			CFrame = CFrame.new(0, Config.GroundY + 0.05, -d),
			Color = Color3.fromRGB(60, 255, 140),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = ground,
		})
	end
	for x = -GROUND_HALF_WIDTH, GROUND_HALF_WIDTH, TILE do
		part({
			Name = "NeonLine",
			Size = Vector3.new(0.6, 0.2, neonZone.EndsAt - neonStart),
			CFrame = CFrame.new(x, Config.GroundY + 0.05, -(neonStart + neonZone.EndsAt) / 2),
			Color = Color3.fromRGB(0, 200, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = ground,
		})
	end
end

--------------------------------------------------------------------------------
-- Lane rails, markers and gates
--------------------------------------------------------------------------------

local function buildLane(map: Folder)
	local lane = Instance.new("Folder")
	lane.Name = "Lane"
	lane.Parent = map

	local railX = Config.LaneWidth / 2 + 0.6
	local segment = 16
	local index = 0
	for d = 8, Config.LaneLength, segment do
		for _, side in { -1, 1 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.9, 0.9, segment),
				CFrame = CFrame.new(side * railX, Config.GroundY + 0.45, -(d + segment / 2)),
				Color = if index % 2 == 0 then Color3.fromRGB(230, 40, 60) else Color3.fromRGB(245, 245, 245),
				CanCollide = false,
				Parent = lane,
			})
		end
		index += 1
	end

	-- Distance markers every 100 studs on both sides.
	for d = 100, Config.LaneLength, 100 do
		for _, side in { -1, 1 } do
			local x = side * (railX + 5)
			part({
				Name = "MarkerPost",
				Size = Vector3.new(0.8, 6, 0.8),
				CFrame = CFrame.new(x, Config.GroundY + 3, -d),
				Color = Color3.fromRGB(90, 60, 40),
				Parent = lane,
			})
			sign(
				lane,
				Vector3.new(8, 4, 0.6),
				CFrame.new(x, Config.GroundY + 7.5, -d),
				tostring(d),
				Color3.fromRGB(255, 196, 40)
			)
		end
	end

	-- Zone gates.
	local gateStart = 0
	for index2, zone in Config.Zones do
		local d = if index2 == 1 then 14 else gateStart
		local pillarX = Config.LaneWidth / 2 + 4
		for _, side in { -1, 1 } do
			part({
				Name = "GatePillar",
				Size = Vector3.new(4, 30, 4),
				CFrame = CFrame.new(side * pillarX, Config.GroundY + 15, -d),
				Color = Color3.fromRGB(255, 196, 40),
				Parent = lane,
			})
		end
		local title = if index2 == 1 then Config.GameName else string.upper(zone.Name)
		sign(
			lane,
			Vector3.new(pillarX * 2 + 4, 7, 2),
			CFrame.new(0, Config.GroundY + 33, -d),
			title,
			Color3.fromRGB(120, 70, 220),
			Color3.fromRGB(255, 230, 90)
		)
		gateStart = zone.EndsAt
	end

	-- Finish wall at the very end of the lane.
	local finishD = Config.LaneLength + 6
	part({
		Name = "FinishWall",
		Size = Vector3.new(Config.LaneWidth + 12, 40, 4),
		CFrame = CFrame.new(0, Config.GroundY + 20, -finishD),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		Parent = lane,
	})
	sign(
		lane,
		Vector3.new(60, 12, 1),
		CFrame.new(0, Config.GroundY + 20, -(finishD - 2.6)),
		"🏆 FINISH 🏆",
		Color3.fromRGB(120, 70, 220)
	)
end

--------------------------------------------------------------------------------
-- Slingshot + lobby
--------------------------------------------------------------------------------

local function buildSlingshot(map: Folder)
	local model = Instance.new("Model")
	model.Name = "Slingshot"
	model.Parent = map

	local base = Config.SlingshotPosition
	local wood = Color3.fromRGB(150, 96, 60)
	local cap = Color3.fromRGB(226, 52, 70)

	-- Launch pad (blue with a yellow border) behind the slingshot.
	part({
		Name = "Pad",
		Size = Vector3.new(26, 0.6, 26),
		CFrame = CFrame.new(base + Vector3.new(0, 0.3, 9)),
		Color = Color3.fromRGB(90, 110, 230),
		Material = Enum.Material.Plastic,
		Parent = model,
	})
	for _, info in {
		{ Vector3.new(28, 0.8, 1.5), Vector3.new(0, 0.4, 9 - 13.75) },
		{ Vector3.new(28, 0.8, 1.5), Vector3.new(0, 0.4, 9 + 13.75) },
		{ Vector3.new(1.5, 0.8, 26), Vector3.new(-13.75, 0.4, 9) },
		{ Vector3.new(1.5, 0.8, 26), Vector3.new(13.75, 0.4, 9) },
	} do
		part({
			Name = "PadBorder",
			Size = info[1],
			CFrame = CFrame.new(base + info[2]),
			Color = Color3.fromRGB(255, 206, 40),
			Parent = model,
		})
	end

	-- Trunk.
	part({
		Name = "Trunk",
		Size = Vector3.new(2.2, 6, 2.2),
		CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0)),
		Color = wood,
		Parent = model,
	})

	-- Two arms angled 25 degrees outwards, with red caps.
	local angle = math.rad(25)
	local armLength = 7
	for _, side in { -1, 1 } do
		local dir = Vector3.new(side * math.sin(angle), math.cos(angle), 0)
		local root = base + Vector3.new(0, 6.5, 0)
		local rotation = CFrame.Angles(0, 0, -side * angle)
		part({
			Name = "Arm",
			Size = Vector3.new(1.8, armLength, 1.8),
			CFrame = CFrame.new(root + dir * (armLength / 2)) * rotation,
			Color = wood,
			Parent = model,
		})
		part({
			Name = "Cap",
			Size = Vector3.new(2.4, 1.6, 2.4),
			CFrame = CFrame.new(root + dir * (armLength + 0.4)) * rotation,
			Color = cap,
			Parent = model,
		})
	end

	-- Resting band between the arm tips (the client hides it while aiming).
	local spread = Config.SlingshotArmSpread
	local tipY = Config.SlingshotArmTip
	part({
		Name = "RestBand",
		Size = Vector3.new(spread * 2, 0.5, 0.5),
		CFrame = CFrame.new(base + Vector3.new(0, tipY - 0.6, 0)),
		Color = Color3.fromRGB(255, 120, 60),
		CanCollide = false,
		Parent = model,
	})
	part({
		Name = "Pouch",
		Size = Vector3.new(2.4, 1, 1),
		CFrame = CFrame.new(base + Vector3.new(0, tipY - 0.6, 0.3)),
		Color = Color3.fromRGB(110, 70, 40),
		CanCollide = false,
		Parent = model,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(Config.LobbySpawn)
	spawn.Color = Color3.fromRGB(255, 206, 40)
	spawn.Material = Enum.Material.Plastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = map
end

--------------------------------------------------------------------------------
-- Decorations
--------------------------------------------------------------------------------

local function palmTree(parent: Instance, position: Vector3, rng: Random)
	local tree = Instance.new("Model")
	tree.Name = "PalmTree"
	tree.Parent = parent

	local height = rng:NextNumber(10, 16)
	local lean = math.rad(rng:NextNumber(-12, 12))
	local trunkColor = Color3.fromRGB(120, 70, 140)
	local top = position + Vector3.new(math.sin(lean), math.cos(lean), 0) * height
	part({
		Name = "Trunk",
		Size = Vector3.new(1.6, height, 1.6),
		CFrame = CFrame.new((position + top) / 2) * CFrame.Angles(0, 0, -lean),
		Color = trunkColor,
		CanCollide = false,
		Parent = tree,
	})
	local leafColor = Color3.fromRGB(80, 200, 70)
	for i = 1, 6 do
		local yaw = math.rad(i * 60 + rng:NextNumber(-10, 10))
		part({
			Name = "Leaf",
			Size = Vector3.new(2.6, 0.5, 9),
			CFrame = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(
				0,
				0,
				-4
			),
			Color = if i % 2 == 0 then leafColor else Color3.fromRGB(110, 220, 80),
			CanCollide = false,
			Parent = tree,
		})
	end
end

local function cloud(parent: Instance, position: Vector3, rng: Random)
	for i = 1, rng:NextInteger(2, 4) do
		part({
			Name = "Cloud",
			Size = Vector3.new(rng:NextNumber(14, 34), rng:NextNumber(5, 9), rng:NextNumber(12, 26)),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-2, 3), rng:NextNumber(-8, 8))),
			Color = Color3.fromRGB(248, 250, 255),
			CanCollide = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function buildDecorations(map: Folder)
	local deco = Instance.new("Folder")
	deco.Name = "Decorations"
	deco.Parent = map
	local rng = Random.new(42)
	local outside = Config.LaneWidth / 2 + 12

	-- Lobby palms.
	for _, offset in {
		Vector3.new(-30, 0, 30),
		Vector3.new(30, 0, 34),
		Vector3.new(-40, 0, 80),
		Vector3.new(38, 0, 90),
		Vector3.new(-22, 0, 120),
		Vector3.new(26, 0, 128),
	} do
		palmTree(deco, offset, rng)
	end

	local function sideX(): number
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		return side * rng:NextNumber(outside, outside + 70)
	end

	for d = 40, Config.LaneLength, 34 do
		local zone = CourseLayout.ZoneIndexAt(d)
		local x = sideX()
		local pos = Vector3.new(x, Config.GroundY, -d)
		if zone == 1 then
			palmTree(deco, pos, rng)
		elseif zone == 2 then
			local height = rng:NextNumber(30, 110)
			local width = rng:NextNumber(14, 26)
			part({
				Name = "Building",
				Size = Vector3.new(width, height, width),
				CFrame = CFrame.new(x + math.sign(x) * width / 2, Config.GroundY + height / 2, -d),
				Color = if rng:NextNumber() < 0.5 then Color3.fromRGB(120, 160, 240) else Color3.fromRGB(210, 222, 250),
				Material = Enum.Material.SmoothPlastic,
				Parent = deco,
			})
		elseif zone == 3 then
			local height = rng:NextNumber(20, 70)
			part({
				Name = "NeonPillar",
				Size = Vector3.new(2, height, 2),
				CFrame = CFrame.new(x, Config.GroundY + height / 2, -d),
				Color = if rng:NextNumber() < 0.5 then Color3.fromRGB(60, 255, 140) else Color3.fromRGB(190, 90, 255),
				Material = Enum.Material.Neon,
				Parent = deco,
			})
		else
			local height = rng:NextNumber(10, 20)
			part({
				Name = "LollipopStick",
				Size = Vector3.new(1, height, 1),
				CFrame = CFrame.new(x, Config.GroundY + height / 2, -d),
				Color = Color3.fromRGB(250, 250, 250),
				Parent = deco,
			})
			part({
				Name = "Lollipop",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(8, 8, 8),
				CFrame = CFrame.new(x, Config.GroundY + height + 3, -d),
				Color = Config.Zones[4].BlockColors[rng:NextInteger(1, 4)],
				Parent = deco,
			})
		end
	end

	-- Clouds and floating islands across the whole map.
	for _ = 1, 70 do
		cloud(
			deco,
			Vector3.new(rng:NextNumber(-500, 500), rng:NextNumber(70, 160), -rng:NextNumber(-200, Config.LaneLength)),
			rng
		)
	end
	for _ = 1, 18 do
		local pos = Vector3.new(sideX() * 1.6, rng:NextNumber(35, 90), -rng:NextNumber(0, Config.LaneLength))
		local size = rng:NextNumber(14, 26)
		part({
			Name = "IslandTop",
			Size = Vector3.new(size, 3, size),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(110, 206, 72),
			Material = Enum.Material.Plastic,
			Parent = deco,
		})
		part({
			Name = "IslandDirt",
			Size = Vector3.new(size * 0.7, 6, size * 0.7),
			CFrame = CFrame.new(pos - Vector3.new(0, 4.5, 0)),
			Color = Color3.fromRGB(150, 100, 64),
			Parent = deco,
		})
	end
end

--------------------------------------------------------------------------------
-- Lighting
--------------------------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 228, 255)
	atmosphere.Decay = Color3.fromRGB(120, 170, 230)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

function WorldBuilder.Build()
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildGround(map)
	buildLane(map)
	buildSlingshot(map)
	buildDecorations(map)

	map.Parent = Workspace
	setupLighting()
	return map
end

return WorldBuilder
