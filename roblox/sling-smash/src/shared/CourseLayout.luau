--[[
	Deterministic obstacle course layout.

	The client builds its own copy of the course from this data (so every player
	gets a fresh, smashable course for each launch) and the server uses the same
	data to sanity-check launch reports.
]]

local Config = require(script.Parent.Config)

local CourseLayout = {}

local cached = nil

function CourseLayout.ZoneIndexAt(distance: number): number
	for index, zone in Config.Zones do
		if distance < zone.EndsAt then
			return index
		end
	end
	return #Config.Zones
end

local function pickKind(rng: Random): string
	local roll = rng:NextNumber()
	if roll < 0.045 then
		return "TNT"
	elseif roll < 0.075 then
		return "Gold"
	end
	return "Block"
end

function CourseLayout.Get()
	if cached then
		return cached
	end

	local rng = Random.new(Config.CourseSeed)
	local size = Config.BlockSize
	local halfLane = Config.LaneWidth / 2 - 2
	local blocks = {}
	local stars = {}
	local rings = {}

	-- x is the block centre, level counts blocks up from the ground.
	local function addBlock(x: number, level: number, distance: number, kind: string, zone: number, colorIndex: number)
		table.insert(blocks, {
			Id = #blocks + 1,
			Position = Vector3.new(x, Config.GroundY + size / 2 + level * size, -distance),
			Kind = kind,
			Zone = zone,
			ColorIndex = colorIndex,
		})
	end

	local function wall(cx: number, distance: number, width: number, height: number, baseLevel: number, zone: number)
		local colorIndex = rng:NextInteger(1, 4)
		for i = 0, width - 1 do
			for j = 0, height - 1 do
				addBlock(cx + (i - (width - 1) / 2) * size, baseLevel + j, distance, pickKind(rng), zone, colorIndex)
			end
		end
	end

	local function tower(cx: number, distance: number, height: number, zone: number)
		local colorIndex = rng:NextInteger(1, 4)
		for i = 0, 1 do
			for k = 0, 1 do
				for j = 0, height - 1 do
					addBlock(cx + (i - 0.5) * size, j, distance + k * size, pickKind(rng), zone, colorIndex)
				end
			end
		end
	end

	local function pyramid(cx: number, distance: number, base: number, zone: number)
		local colorIndex = rng:NextInteger(1, 4)
		for level = 0, base - 1 do
			local count = base - level
			for i = 0, count - 1 do
				addBlock(cx + (i - (count - 1) / 2) * size, level, distance, pickKind(rng), zone, colorIndex)
			end
		end
	end

	-- Picks a centre so a structure of halfWidth fits between minX and maxX.
	local function centerIn(minX: number, maxX: number, halfWidth: number): number
		local low, high = minX + halfWidth, maxX - halfWidth
		if low >= high then
			return (minX + maxX) / 2
		end
		return rng:NextNumber(low, high)
	end

	-- The first wall sits right in front of the slingshot so even a weak
	-- first launch smashes something.
	wall(0, Config.CourseStart, 5, 5, 0, 1)

	local distance = Config.CourseStart + 45
	local row = 0
	while distance < Config.LaneLength - 60 do
		row += 1
		local zone = CourseLayout.ZoneIndexAt(distance)

		if row % 9 == 0 then
			-- Full-width wall: you can't steer around this one.
			local width = math.floor((Config.LaneWidth - 4) / size)
			wall(0, distance, width, rng:NextInteger(2, 3), 0, zone)
		else
			local count = if rng:NextNumber() < 0.55 then 2 else 1
			for n = 1, count do
				local minX, maxX = -halfLane, halfLane
				if count == 2 then
					if n == 1 then
						maxX = -3
					else
						minX = 3
					end
				end

				local roll = rng:NextNumber()
				if roll < 0.5 then
					local width = rng:NextInteger(3, 7)
					local height = rng:NextInteger(3, 6)
					wall(centerIn(minX, maxX, width * size / 2), distance, width, height, 0, zone)
				elseif roll < 0.78 then
					tower(centerIn(minX, maxX, size), distance, rng:NextInteger(6, 12), zone)
				else
					local base = rng:NextInteger(3, 5)
					pyramid(centerIn(minX, maxX, base * size / 2), distance, base, zone)
				end
			end
		end

		-- Floating walls reward high launches later in the course.
		if zone >= 2 and rng:NextNumber() < 0.25 then
			local width = rng:NextInteger(3, 6)
			wall(
				centerIn(-halfLane, halfLane, width * size / 2),
				distance + 20,
				width,
				2,
				rng:NextInteger(6, 13),
				zone
			)
		end

		if rng:NextNumber() < 0.6 then
			table.insert(stars, {
				Id = #stars + 1,
				Position = Vector3.new(
					rng:NextNumber(-halfLane + 10, halfLane - 10),
					Config.GroundY + rng:NextNumber(6, 34),
					-(distance + rng:NextNumber(10, 25))
				),
				Zone = zone,
			})
		end

		if rng:NextNumber() < 0.3 then
			table.insert(rings, {
				Id = #rings + 1,
				Position = Vector3.new(rng:NextNumber(-18, 18), Config.GroundY + rng:NextNumber(6, 22), -(distance + 28)),
				Zone = zone,
			})
		end

		distance += rng:NextNumber(40, 60)
	end

	cached = {
		Blocks = blocks,
		Stars = stars,
		Rings = rings,
		TotalBlocks = #blocks,
	}
	return cached
end

return CourseLayout
