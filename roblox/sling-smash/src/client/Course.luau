--[[
	The smashable course, built locally on each client from CourseLayout.

	Blocks are bucketed by distance so the flight code can sweep the flyer's
	path every frame without physics queries. Smashed blocks are unanchored and
	flung, then hidden; Reset() puts everything back for the next launch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local Widgets = require(script.Parent.Widgets)

local Course = {}
Course.__index = Course

local BUCKET = 16
local FLING_TIME = 2.5
local BLOCK_HIT_RADIUS = Config.BlockSize * 0.55

local rng = Random.new()

local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	if lengthSquared < 1e-6 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / lengthSquared, 0, 1)
	return (a + ab * t - point).Magnitude
end

local function bucketOf(distance: number): number
	return math.floor(distance / BUCKET)
end

local function tntLabel(part: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = part
	Widgets.Label({
		Text = "TNT",
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.25),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		TextColor3 = Color3.fromRGB(30, 30, 30),
		StrokeThickness = 0,
		Parent = gui,
	})
end

function Course.new()
	local self = setmetatable({}, Course)
	self.Layout = CourseLayout.Get()
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "LocalCourse"
	self.Folder.Parent = Workspace
	self.Blocks = {}
	self.Buckets = {}
	self.Stars = {}
	self.Rings = {}
	self.Flung = {}
	self.Ready = false
	return self
end

function Course:_buildBlock(data)
	local zone = Config.Zones[data.Zone]
	local size = Config.BlockSize - 0.08
	local part = Instance.new("Part")
	part.Name = data.Kind
	part.Anchored = true
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(data.Position)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanQuery = false
	part.CanTouch = false

	if data.Kind == "Gold" then
		part.Color = Color3.fromRGB(255, 196, 40)
		part.Material = Enum.Material.Neon
	elseif data.Kind == "TNT" then
		part.Color = Color3.fromRGB(220, 40, 40)
		part.Material = Enum.Material.SmoothPlastic
		tntLabel(part, Enum.NormalId.Back)
		tntLabel(part, Enum.NormalId.Left)
		tntLabel(part, Enum.NormalId.Right)
	else
		local base = zone.BlockColors[data.ColorIndex] or zone.BlockColors[1]
		-- Deterministic per-block shade so walls look hand-built.
		local shade = ((data.Id * 37) % 11 - 5) / 60
		part.Color = if shade >= 0 then Widgets.Lighten(base, shade) else Widgets.Darken(base, -shade)
		part.Material = zone.BlockMaterial
	end
	part.Parent = self.Folder

	local entry = {
		Data = data,
		Part = part,
		Position = data.Position,
		CFrame = part.CFrame,
		Radius = BLOCK_HIT_RADIUS,
		Broken = false,
	}
	table.insert(self.Blocks, entry)
	local bucket = bucketOf(-data.Position.Z)
	local list = self.Buckets[bucket]
	if not list then
		list = {}
		self.Buckets[bucket] = list
	end
	table.insert(list, entry)
end

function Course:_buildStar(data)
	local ball = Instance.new("Part")
	ball.Name = "Star"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3, 3)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 214, 40)
	ball.CFrame = CFrame.new(data.Position)
	ball.Parent = self.Folder

	local billboard = Widgets.new("BillboardGui", {
		Size = UDim2.new(8, 0, 8, 0),
		LightInfluence = 0,
		MaxDistance = 600,
		Parent = ball,
	})
	Widgets.Label({ Text = "⭐", Size = UDim2.fromScale(1, 1), StrokeThickness = 0, Parent = billboard })

	table.insert(self.Stars, {
		Data = data,
		Part = ball,
		Billboard = billboard,
		Position = data.Position,
		Radius = Config.StarRadius,
		Collected = false,
	})
end

function Course:_buildRing(data)
	local segments = {}
	local radius = Config.RingRadius
	local count = 14
	local chord = 2 * radius * math.sin(math.pi / count) + 0.4
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		local segment = Instance.new("Part")
		segment.Name = "RingSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(0, 230, 255)
		segment.Size = Vector3.new(1.2, chord, 1.2)
		segment.CFrame = CFrame.new(data.Position + offset) * CFrame.Angles(0, 0, angle)
		segment.Parent = self.Folder
		table.insert(segments, segment)
	end
	table.insert(self.Rings, {
		Data = data,
		Segments = segments,
		Position = data.Position,
		Radius = radius,
		Used = false,
	})
end

-- Builds everything, yielding now and then so joining doesn't hitch.
function Course:Build()
	for index, data in self.Layout.Blocks do
		self:_buildBlock(data)
		if index % 400 == 0 then
			task.wait()
		end
	end
	for _, data in self.Layout.Stars do
		self:_buildStar(data)
	end
	for _, data in self.Layout.Rings do
		self:_buildRing(data)
	end
	self.Ready = true
end

-- Calls onBlock/onStar/onRing for everything touched by a sphere of `radius`
-- moving from fromPos to toPos this step.
function Course:Sweep(fromPos: Vector3, toPos: Vector3, radius: number, onBlock, onStar, onRing)
	local d1, d2 = -fromPos.Z, -toPos.Z
	local low = math.min(d1, d2) - radius - BUCKET
	local high = math.max(d1, d2) + radius + BUCKET
	for b = bucketOf(low), bucketOf(high) do
		local list = self.Buckets[b]
		if list then
			for _, entry in list do
				if not entry.Broken and distanceToSegment(entry.Position, fromPos, toPos) <= radius + entry.Radius then
					onBlock(entry)
				end
			end
		end
	end

	for _, star in self.Stars do
		if not star.Collected then
			local d = -star.Position.Z
			if d >= low and d <= high and distanceToSegment(star.Position, fromPos, toPos) <= radius + star.Radius then
				onStar(star)
			end
		end
	end

	for _, ring in self.Rings do
		if not ring.Used then
			local d = -ring.Position.Z
			if d >= low and d <= high and distanceToSegment(ring.Position, fromPos, toPos) <= ring.Radius then
				onRing(ring)
			end
		end
	end
end

-- Every unbroken block within radius of a point (used by TNT).
function Course:BlocksNear(center: Vector3, radius: number)
	local found = {}
	local d = -center.Z
	for b = bucketOf(d - radius - BUCKET), bucketOf(d + radius + BUCKET) do
		local list = self.Buckets[b]
		if list then
			for _, entry in list do
				if not entry.Broken and (entry.Position - center).Magnitude <= radius then
					table.insert(found, entry)
				end
			end
		end
	end
	return found
end

-- Flings a block away along the flyer's velocity.
function Course:Smash(entry, velocity: Vector3)
	entry.Broken = true
	local part: BasePart = entry.Part
	part.CollisionGroup = "Debris"
	part.Anchored = false
	part.AssemblyLinearVelocity = velocity * 0.55
		+ Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(14, 36), rng:NextNumber(-12, 12))
	part.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
	table.insert(self.Flung, { Entry = entry, Time = os.clock() })
end

function Course:CollectStar(star)
	star.Collected = true
	star.Part.Transparency = 1
	star.Billboard.Enabled = false
end

function Course:UseRing(ring)
	ring.Used = true
	for _, segment in ring.Segments do
		segment.Color = Color3.fromRGB(255, 220, 60)
		segment.Transparency = 0.6
	end
end

-- Hides flung blocks after a while and bobs nearby stars.
function Course:Update(focus: Vector3?)
	local now = os.clock()
	for i = #self.Flung, 1, -1 do
		local item = self.Flung[i]
		if now - item.Time > FLING_TIME then
			local part = item.Entry.Part
			part.Anchored = true
			part.Transparency = 1
			part.CanCollide = false
			table.remove(self.Flung, i)
		end
	end

	if focus then
		local bob = math.sin(now * 3) * 0.8
		for _, star in self.Stars do
			if not star.Collected and math.abs(star.Position.Z - focus.Z) < 250 then
				star.Part.CFrame = CFrame.new(star.Position + Vector3.new(0, bob, 0))
			end
		end
	end
end

function Course:Reset()
	for _, entry in self.Blocks do
		if entry.Broken or entry.Part.Transparency > 0 then
			local part = entry.Part
			part.Anchored = true
			part.CFrame = entry.CFrame
			part.Transparency = 0
			part.CanCollide = true
			part.CollisionGroup = "Default"
			entry.Broken = false
		end
	end
	table.clear(self.Flung)

	for _, star in self.Stars do
		star.Collected = false
		star.Part.Transparency = 0
		star.Part.CFrame = CFrame.new(star.Position)
		star.Billboard.Enabled = true
	end

	for _, ring in self.Rings do
		ring.Used = false
		for _, segment in ring.Segments do
			segment.Color = Color3.fromRGB(0, 230, 255)
			segment.Transparency = 0
		end
	end
end

return Course
