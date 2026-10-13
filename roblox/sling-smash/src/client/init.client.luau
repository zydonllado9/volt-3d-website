--[[
	Sling Smash - client entry point.

	Game loop:  Lobby -> Aiming (in the slingshot) -> Charging (hold) -> Flying
	            -> Results -> Retry / Return

	Flight is simulated here with simple custom physics: the character is put in
	PlatformStand and its root part is moved every frame, which replicates to
	other players because the client owns its own character's physics.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CourseLayout = require(Shared:WaitForChild("CourseLayout"))
local Format = require(Shared:WaitForChild("Format"))

local Course = require(script.Course)
local Effects = require(script.Effects)
local UI = require(script.UI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetDataRemote = remotes:WaitForChild("GetData") :: RemoteFunction
local DataChangedRemote = remotes:WaitForChild("DataChanged") :: RemoteEvent
local StartLaunchRemote = remotes:WaitForChild("StartLaunch") :: RemoteFunction
local FinishLaunchRemote = remotes:WaitForChild("FinishLaunch") :: RemoteFunction
local UpdateSettingRemote = remotes:WaitForChild("UpdateSetting") :: RemoteEvent

local HOLD_STEP = "SlingSmashHold"
local FLIGHT_STEP = "SlingSmashFlight"
local CHARGE_ACTION = "SlingSmashCharge"
local SUBSTEP = 1 / 120

local rng = Random.new()

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = "Lobby" -- Lobby | Aiming | Charging | Flying | Results
local data = nil
local stats = Config.ComputeStats({}, 0)
local power = 0
local chargeStart = 0
local chargeInput: InputObject? = nil
local maxAnnounced = false
local flight = nil

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local savedGroups = {} -- [BasePart] = original CollisionGroup

local course = Course.new()
task.spawn(function()
	course:Build()
end)

local controls = nil
task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local module = playerScripts:WaitForChild("PlayerModule", 10)
	if module then
		local ok, playerModule = pcall(require, module)
		if ok and playerModule then
			controls = (playerModule :: any):GetControls()
		end
	end
end)

-- Render-step bindings, tracked so cleanup never unbinds something unbound.
local boundSteps = {}
local function bindStep(name: string, callback: (number) -> ())
	if boundSteps[name] then
		RunService:UnbindFromRenderStep(name)
	end
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, callback)
	boundSteps[name] = true
end
local function unbindStep(name: string)
	if boundSteps[name] then
		boundSteps[name] = nil
		RunService:UnbindFromRenderStep(name)
	end
end

local function camera(): Camera
	return Workspace.CurrentCamera :: Camera
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- -1 (left) .. 1 (right). Works with keyboard, thumbstick and gamepad.
local function steerInput(): number
	local x = 0
	if controls then
		local ok, move = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(move) == "Vector3" then
			x = move.X
		end
	end
	if math.abs(x) < 0.05 then
		x = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			x -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			x += 1
		end
	end
	return math.clamp(x, -1, 1)
end

local function setFlyerMode(enabled: boolean)
	if enabled then
		if humanoid then
			humanoid.PlatformStand = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		if character then
			for _, descendant in character:GetDescendants() do
				if descendant:IsA("BasePart") then
					if savedGroups[descendant] == nil then
						savedGroups[descendant] = descendant.CollisionGroup
					end
					descendant.CollisionGroup = "Flyer"
				end
			end
		end
	else
		for part, group in savedGroups do
			if part.Parent then
				part.CollisionGroup = group
			end
		end
		table.clear(savedGroups)
		if humanoid then
			humanoid.PlatformStand = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
	end
end

local function restoreCamera()
	local cam = camera()
	cam.CameraType = Enum.CameraType.Custom
	if humanoid then
		cam.CameraSubject = humanoid
	end
	cam.FieldOfView = 70
end

local function pouchCFrame(amount: number): CFrame
	local back = Config.PouchRestOffset + Config.PouchPullDistance * amount
	local position = Config.SlingshotPosition + Vector3.new(0, Config.PouchHeight - amount * 1.2, back)
	return CFrame.lookAt(position, position + Config.Forward)
end

--------------------------------------------------------------------------------
-- Slingshot bands (local visuals while aiming)
--------------------------------------------------------------------------------

local bands: { BasePart } = {}
local hiddenSlingParts: { BasePart } = {}

local function makeBand(): Part
	local band = Instance.new("Part")
	band.Name = "SlingBand"
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.CanTouch = false
	band.CastShadow = false
	band.Material = Enum.Material.SmoothPlastic
	band.Color = Color3.fromRGB(255, 120, 60)
	band.Size = Vector3.new(0.45, 0.45, 1)
	band.Transparency = 1
	band.Parent = course.Folder
	return band
end

local function setBandsVisible(visible: boolean)
	if #bands == 0 then
		bands = { makeBand(), makeBand() }
	end
	for _, band in bands do
		band.Transparency = if visible then 0 else 1
	end

	-- Hide the server's resting band locally while our stretched bands show.
	local map = Workspace:FindFirstChild("Map")
	local slingshot = map and map:FindFirstChild("Slingshot")
	if slingshot and #hiddenSlingParts == 0 then
		for _, name in { "RestBand", "Pouch" } do
			local partInstance = slingshot:FindFirstChild(name)
			if partInstance and partInstance:IsA("BasePart") then
				table.insert(hiddenSlingParts, partInstance)
			end
		end
	end
	for _, slingPart in hiddenSlingParts do
		slingPart.Transparency = if visible then 1 else 0
	end
end

local function updateBands(pouch: Vector3)
	local base = Config.SlingshotPosition
	local tipY = Config.SlingshotArmTip - 0.6
	for i, side in { -1, 1 } do
		local band = bands[i]
		if band then
			local tip = base + Vector3.new(side * Config.SlingshotArmSpread, tipY, 0)
			local length = (pouch - tip).Magnitude
			band.Size = Vector3.new(0.45, 0.45, length)
			band.CFrame = CFrame.lookAt((tip + pouch) / 2, pouch)
		end
	end
end

--------------------------------------------------------------------------------
-- Aiming + charging
--------------------------------------------------------------------------------

local enterAiming, startFlight, returnToLobby

local function aimCamera(amount: number, dt: number)
	local pouch = pouchCFrame(amount).Position
	local position = pouch + Vector3.new(0, 5 + amount, 14 + amount * 3)
	local target = pouch + Config.Forward * 40 + Vector3.new(0, 2, 0)
	local cam = camera()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(position, target) * Effects.ShakeOffset(dt)
	cam.FieldOfView = 70 + amount * 6
end

local function holdStep(dt: number)
	if state == "Charging" then
		power = math.min(1, (os.clock() - chargeStart) / Config.Flight.ChargeTime)
		if power >= 1 and not maxAnnounced then
			maxAnnounced = true
			UI.Pop("MAX POWER!", "max")
			Effects.Play("Coin", 1.6)
		end
		if power > 0.6 then
			Effects.Shake(0.08 * power)
		end
	end
	local cf = pouchCFrame(power)
	if root then
		root.CFrame = cf
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	updateBands(cf.Position + Vector3.new(0, 0, 1.2))
	aimCamera(power, dt)
	UI.SetPower(power, if state == "Charging" then "charging" else "aim")
end

local function unbindAiming()
	unbindStep(HOLD_STEP)
	ContextActionService:UnbindAction(CHARGE_ACTION)
	setBandsVisible(false)
end

local function startCharging(input: InputObject?)
	if state ~= "Aiming" then
		return
	end
	state = "Charging"
	chargeStart = os.clock()
	chargeInput = input
	maxAnnounced = false
	Effects.Play("Click", 0.8)
end

local function releaseCharge()
	if state ~= "Charging" then
		return
	end
	local launchPower = power
	unbindAiming()
	startFlight(launchPower)
end

local function isPointerInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function chargeAction(_actionName: string, inputState: Enum.UserInputState, input: InputObject)
	if inputState == Enum.UserInputState.Begin then
		startCharging(input)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if chargeInput and chargeInput.KeyCode == input.KeyCode then
			releaseCharge()
		end
	end
	return Enum.ContextActionResult.Sink
end

enterAiming = function()
	if state == "Aiming" or state == "Charging" or state == "Flying" then
		return
	end
	if not (root and humanoid and humanoid.Health > 0) then
		return
	end
	if not course.Ready then
		UI.Toast("The course is still loading...")
		return
	end

	UI.ClosePanels()
	UI.HideResults()
	course:Reset()
	setFlyerMode(true)

	state = "Aiming"
	power = 0
	chargeInput = nil
	setBandsVisible(true)
	bindStep(HOLD_STEP, holdStep)
	ContextActionService:BindActionAtPriority(
		CHARGE_ACTION,
		chargeAction,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonR2
	)

	UI.SetMode("Aiming")
	UI.SetPower(0, "aim")
	UI.SetRunCoins(0, true)
	Effects.Play("Click", 1)
end

local function cancelAim()
	if state ~= "Aiming" and state ~= "Charging" then
		return
	end
	unbindAiming()
	returnToLobby()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or state ~= "Aiming" then
		return
	end
	if isPointerInput(input) then
		startCharging(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if state ~= "Charging" or not chargeInput or not isPointerInput(input) then
		return
	end
	-- Touches must match the finger that started the charge; mouse just needs the button.
	if input == chargeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if chargeInput.UserInputType == input.UserInputType then
			releaseCharge()
		end
	end
end)

--------------------------------------------------------------------------------
-- Flight
--------------------------------------------------------------------------------

local finishFlight

local function registerSmash(f, entry)
	local info = Config.Blocks[entry.Data.Kind] or Config.Blocks.Block
	f.Smashes += 1
	if f.ComboTimer > 0 then
		f.Combo += 1
	else
		f.Combo = 1
	end
	f.ComboTimer = stats.ComboWindow
	f.MaxCombo = math.max(f.MaxCombo, f.Combo)

	local multiplier = Config.ComboMultiplier(f.Combo, stats.MaxComboMult)
	local crit = rng:NextNumber() < Config.CritChance
	local zone = Config.Zones[entry.Data.Zone]
	local coins = math.floor(
		info.Value
			* zone.ValueMult
			* stats.SmashCoinMult
			* multiplier
			* (if crit then Config.CritMultiplier else 1)
			* stats.CoinMult
	)
	f.RunCoins += coins

	Effects.Play("Smash", rng:NextNumber(0.85, 1.35), 0.05)
	if crit then
		UI.Pop("CRITICAL!", "crit")
		Effects.Shake(1.2)
		Effects.FloatText(entry.Position + Vector3.new(0, 3, 0), "+" .. Format.Short(coins), Color3.fromRGB(255, 170, 40), 1.4)
	else
		Effects.Shake(0.35)
		Effects.FloatText(entry.Position + Vector3.new(0, 2, 0), "+" .. Format.Short(coins), Color3.fromRGB(220, 150, 255), 1)
	end
end

local function explode(f, first)
	local queue = { first }
	local explosions = 0
	while #queue > 0 do
		local entry = table.remove(queue, 1)
		local info = Config.Blocks.TNT
		explosions += 1
		if explosions <= 4 then
			Effects.Explosion(entry.Position, info.BlastRadius)
		end
		for _, other in course:BlocksNear(entry.Position, info.BlastRadius) do
			local away = other.Position - entry.Position
			local push = if away.Magnitude > 0.01 then away.Unit * 45 else Vector3.zero
			course:Smash(other, f.Velocity * 0.4 + push)
			registerSmash(f, other)
			if other.Data.Kind == "TNT" then
				table.insert(queue, other)
			end
		end
	end
	f.Velocity += Config.Forward * Config.Blocks.TNT.Boost
	f.Velocity = Vector3.new(f.Velocity.X, math.max(f.Velocity.Y, Config.Blocks.TNT.Lift), f.Velocity.Z)
	f.Grounded = false
	f.FovKick = 10
	Effects.Shake(2.2)
	Effects.Flash(Color3.fromRGB(255, 170, 60), 0.35)
	UI.Pop("BOOM!", "crit")
end

local function onBlock(entry)
	local f = flight
	if not f or entry.Broken then
		return
	end
	local info = Config.Blocks[entry.Data.Kind] or Config.Blocks.Block
	course:Smash(entry, f.Velocity)
	registerSmash(f, entry)
	f.Velocity *= 1 - info.Slowdown * stats.SmashSlow
	if entry.Data.Kind == "TNT" then
		explode(f, entry)
	end
end

local function onStar(star)
	local f = flight
	if not f then
		return
	end
	course:CollectStar(star)
	f.Stars += 1
	local zone = Config.Zones[star.Data.Zone]
	local coins = math.floor(Config.StarValue * zone.ValueMult * stats.CoinMult)
	f.RunCoins += coins
	Effects.Play("Coin", 1.25)
	Effects.Flash(Color3.fromRGB(255, 225, 90), 0.25)
	Effects.FloatText(star.Position, "⭐ +" .. Format.Short(coins), Color3.fromRGB(255, 220, 60), 1.6)
end

local function onRing(ring)
	local f = flight
	if not f then
		return
	end
	course:UseRing(ring)
	f.Velocity += Config.Forward * Config.RingBoost
	f.Velocity = Vector3.new(f.Velocity.X, math.max(f.Velocity.Y, Config.RingLift), f.Velocity.Z)
	f.Grounded = false
	f.FovKick = 14
	UI.Pop("BOOST!", "boost")
	Effects.Flash(Color3.fromRGB(80, 230, 255), 0.3)
	Effects.Play("Launch", 1.4)
	Effects.Shake(0.8)
end

-- One fixed physics substep of length h.
local function simulate(f, h: number, steer: number)
	local F = Config.Flight
	local previous = f.Position
	local velocity = f.Velocity
	f.Time += h

	-- Steering (sideways only).
	local vx = velocity.X + steer * stats.Steer * h
	if steer == 0 then
		vx -= vx * math.min(1, F.SideDamping * h)
	end
	vx = math.clamp(vx, -F.MaxSideSpeed, F.MaxSideSpeed)
	velocity = Vector3.new(vx, velocity.Y, velocity.Z)

	if f.Grounded then
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = horizontal.Magnitude
		if speed > 1e-3 then
			local newSpeed = math.max(0, speed - F.GroundDecel * h) * (1 - math.min(1, F.GroundDrag * h))
			horizontal *= newSpeed / speed
		end
		velocity = Vector3.new(horizontal.X, math.max(0, velocity.Y), horizontal.Z)
		if velocity.Y > 0 then
			f.Grounded = false
		end
	else
		velocity *= 1 - math.min(1, F.AirDrag * h)
		velocity -= Vector3.new(0, stats.Gravity * h, 0)
	end

	local position = previous + velocity * h

	-- Bounce off the lane rails.
	local limit = Config.LaneWidth / 2 - 1.5
	if math.abs(position.X) > limit then
		position = Vector3.new(math.sign(position.X) * limit, position.Y, position.Z)
		velocity = Vector3.new(-velocity.X * 0.4, velocity.Y, velocity.Z)
	end

	-- Ground: bounce when falling fast, otherwise start sliding.
	local floor = Config.GroundY + F.BodyHeight
	if position.Y <= floor then
		position = Vector3.new(position.X, floor, position.Z)
		if velocity.Y < -F.MinBounceSpeed then
			velocity = Vector3.new(velocity.X * F.BounceKeep, -velocity.Y * F.Bounce, velocity.Z * F.BounceKeep)
			Effects.Shake(0.7)
			Effects.Play("Smash", 0.7, 0.1)
		elseif velocity.Y <= 0 then
			velocity = Vector3.new(velocity.X, 0, velocity.Z)
			f.Grounded = true
		end
	end

	-- End of the lane.
	if -position.Z >= Config.LaneLength then
		f.Position = Vector3.new(position.X, position.Y, -Config.LaneLength)
		f.Velocity = Vector3.zero
		f.Done = "finish"
		return
	end

	f.Position = position
	f.Velocity = velocity

	course:Sweep(previous, position, stats.HitRadius, onBlock, onStar, onRing)

	if f.ComboTimer > 0 then
		f.ComboTimer -= h
		if f.ComboTimer <= 0 then
			f.Combo = 0
		end
	end

	local horizontalSpeed = Vector3.new(f.Velocity.X, 0, f.Velocity.Z).Magnitude
	if f.Grounded and horizontalSpeed < F.StopSpeed then
		f.Done = "stopped"
	elseif f.Time > F.MaxFlightTime then
		f.Done = "timeout"
	end
end

local function flightStep(dt: number)
	local f = flight
	if not f then
		return
	end
	dt = math.min(dt, 0.1)
	local steps = math.max(1, math.ceil(dt / SUBSTEP))
	local h = dt / steps
	local steer = steerInput()
	for _ = 1, steps do
		simulate(f, h, steer)
		if f.Done then
			break
		end
	end

	local velocity = f.Velocity
	local speed = velocity.Magnitude

	-- Pose: superman-style, head first, rolling into turns.
	local direction = velocity + Config.Forward * 2
	if direction.Magnitude < 1e-3 then
		direction = Config.Forward
	end
	direction = direction.Unit
	local wobble = if f.Grounded then 0 else math.sin(f.Time * 7) * 0.12
	local pose = CFrame.lookAt(f.Position, f.Position + direction)
		* CFrame.Angles(-math.pi / 2, 0, 0)
		* CFrame.Angles(0, -steer * 0.5 + wobble, 0)
	if root then
		root.CFrame = pose
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- Chase camera.
	local cam = camera()
	local desired = f.Position + Vector3.new(0, 7 + math.min(speed, 200) * 0.02, 20)
	f.CameraPosition = f.CameraPosition:Lerp(desired, 1 - math.exp(-12 * dt))
	local look = f.Position + Config.Forward * 14 + Vector3.new(0, 1.5, 0)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(f.CameraPosition, look) * Effects.ShakeOffset(dt)
	f.FovKick = math.max(0, f.FovKick - dt * 25)
	cam.FieldOfView = 70 + math.clamp(speed * 0.1, 0, 22) + f.FovKick

	-- HUD + effects.
	local distance = math.max(0, -f.Position.Z)
	UI.SetDistance(math.floor(distance))
	UI.SetRunCoins(f.RunCoins)
	local multiplier = Config.ComboMultiplier(f.Combo, stats.MaxComboMult)
	UI.SetCombo(multiplier, f.ComboTimer / stats.ComboWindow, multiplier >= 2 and f.ComboTimer > 0)
	Effects.UpdateSpeedLines(dt, math.clamp((speed - 50) / 120, 0, 1))
	Effects.SetWind(speed / 150)
	course:Update(f.Position)

	local zoneIndex = CourseLayout.ZoneIndexAt(distance)
	if zoneIndex > f.Zone then
		f.Zone = zoneIndex
		UI.Banner("🌍 " .. string.upper(Config.Zones[zoneIndex].Name))
	end

	if f.Done then
		finishFlight(f.Done)
	end
end

startFlight = function(launchPower: number)
	local F = Config.Flight
	local speed = stats.LaunchSpeed * (F.MinPower + (1 - F.MinPower) * launchPower)
	local angle = math.rad(F.LaunchAngle)
	local start = pouchCFrame(launchPower).Position

	local f = {
		Position = start,
		Velocity = (Config.Forward * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * speed,
		Time = 0,
		Grounded = false,
		Combo = 0,
		ComboTimer = 0,
		MaxCombo = 0,
		RunCoins = 0,
		Smashes = 0,
		Stars = 0,
		Zone = 1,
		FovKick = 8,
		CameraPosition = camera().CFrame.Position,
		LaunchId = nil,
		Done = nil,
	}
	flight = f
	state = "Flying"

	task.spawn(function()
		local ok, launchId = pcall(function()
			return StartLaunchRemote:InvokeServer()
		end)
		if ok then
			f.LaunchId = launchId
		end
		f.IdReady = true
	end)

	UI.SetMode("Flying")
	UI.Pop(if launchPower >= 0.99 then "PERFECT!" else "LAUNCH!", "max")
	Effects.Play("Launch", 0.9)
	Effects.Shake(1)
	bindStep(FLIGHT_STEP, flightStep)
end

finishFlight = function(reason: string)
	local f = flight
	if not f then
		return
	end
	flight = nil
	unbindStep(FLIGHT_STEP)
	Effects.SetWind(0)
	Effects.HideSpeedLines()
	state = "Results"

	-- Stand back up where we landed.
	if root and humanoid then
		local p = Vector3.new(f.Position.X, Config.GroundY + 3.2, f.Position.Z)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(p, p + Config.Forward)
		setFlyerMode(false)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	restoreCamera()
	UI.SetMode("Results")
	UI.SetCombo(1, 0, false)
	if reason == "finish" then
		UI.Pop("🏆 FINISH!", "best")
	end

	local distance = math.max(0, -f.Position.Z)
	local comboMultiplier = Config.ComboMultiplier(f.MaxCombo, stats.MaxComboMult)
	task.spawn(function()
		local waited = 0
		while not f.IdReady and waited < 5 do
			waited += task.wait(0.1)
		end
		local report = {
			Distance = distance,
			Smashes = f.Smashes,
			Stars = f.Stars,
			MaxCombo = f.MaxCombo,
			RunCoins = f.RunCoins,
		}
		local ok, result = pcall(function()
			return FinishLaunchRemote:InvokeServer(f.LaunchId, report)
		end)
		if not ok or type(result) ~= "table" then
			result = {
				Earned = 0,
				Distance = math.floor(distance),
				Smashes = f.Smashes,
				MaxCombo = f.MaxCombo,
				NewBest = false,
				Failed = true,
			}
		end
		if state ~= "Results" then
			return
		end
		if result.NewBest then
			UI.Pop("NEW BEST!", "best")
			Effects.Flash(Color3.fromRGB(255, 200, 255), 0.3)
		end
		Effects.Play("Coin", 1)
		UI.ShowResults(result, comboMultiplier)
	end)
end

returnToLobby = function()
	state = "Lobby"
	flight = nil
	unbindStep(FLIGHT_STEP)
	unbindAiming()
	Effects.SetWind(0)
	Effects.HideSpeedLines()
	setFlyerMode(false)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(Config.ReturnPoint, Config.ReturnPoint + Config.Forward)
	end
	restoreCamera()
	UI.SetMode("Lobby")
end

--------------------------------------------------------------------------------
-- Character lifecycle
--------------------------------------------------------------------------------

local function resetToLobbyState()
	flight = nil
	unbindStep(FLIGHT_STEP)
	unbindAiming()
	Effects.SetWind(0)
	Effects.HideSpeedLines()
	table.clear(savedGroups)
	state = "Lobby"
	UI.SetMode("Lobby")
end

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	root = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	resetToLobbyState()
	restoreCamera()
	if humanoid then
		humanoid.Died:Connect(function()
			if character == newCharacter then
				resetToLobbyState()
			end
		end)
	end
end


--------------------------------------------------------------------------------
-- Data + UI wiring
--------------------------------------------------------------------------------

local function applyData(newData)
	if type(newData) ~= "table" then
		return
	end
	data = newData
	stats = Config.ComputeStats(newData.Upgrades, newData.Rebirths)
	UI.SetData(newData)
	Effects.ApplySettings(newData.Settings)
end

local function invoke(remoteName: string, ...): (boolean, string?)
	local args = table.pack(...)
	local remote = remotes:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then
		return false, "Missing remote " .. remoteName
	end
	local ok, success, message = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "Server didn't respond"
	end
	return success == true, message
end

Effects.Init(playerGui)
UI.Init(playerGui, {
	Launch = function()
		enterAiming()
	end,
	Cancel = function()
		cancelAim()
	end,
	Retry = function()
		enterAiming()
	end,
	Return = function()
		returnToLobby()
	end,
	Click = function()
		Effects.Play("Click", 1.2)
	end,
	BuyUpgrade = function(nodeId: string)
		local node = Config.NodesById[nodeId]
		if not node or not data then
			return
		end
		if data.Upgrades[nodeId] then
			return
		end
		if node.Requires ~= "Start" and not data.Upgrades[node.Requires] then
			UI.Toast("🔒 Unlock " .. Config.NodesById[node.Requires].Name .. " first")
			return
		end
		if data.Coins < node.Cost then
			UI.Toast("Not enough ⭐! Launch to earn more.", Color3.fromRGB(255, 120, 120))
			return
		end
		local ok, message = invoke("BuyUpgrade", nodeId)
		if ok then
			Effects.Play("Coin", 1.4)
			UI.Toast("✅ " .. node.Name .. " unlocked!", Color3.fromRGB(140, 255, 100))
		else
			UI.Toast(message or "Couldn't buy that", Color3.fromRGB(255, 120, 120))
		end
	end,
	Rebirth = function()
		local ok, message = invoke("Rebirth")
		if ok then
			UI.ClosePanels()
			UI.Pop("REBIRTH!", "best")
			Effects.Flash(Color3.fromRGB(200, 140, 255), 0.5)
		else
			UI.Toast(message or "Can't rebirth yet", Color3.fromRGB(255, 120, 120))
		end
	end,
	BuyTrail = function(trailId: string)
		local ok, message = invoke("BuyTrail", trailId)
		if ok then
			Effects.Play("Coin", 1.4)
			UI.Toast("✨ New trail equipped!", Color3.fromRGB(140, 255, 100))
		else
			UI.Toast(message or "Couldn't buy that", Color3.fromRGB(255, 120, 120))
		end
	end,
	EquipTrail = function(trailId: string)
		local ok, message = invoke("EquipTrail", trailId)
		if not ok then
			UI.Toast(message or "Couldn't equip that", Color3.fromRGB(255, 120, 120))
		end
	end,
	Setting = function(key: string, value: boolean)
		if not data then
			return
		end
		data.Settings[key] = value
		Effects.ApplySettings(data.Settings)
		UI.SetData(data)
		UpdateSettingRemote:FireServer(key, value)
	end,
})

-- Holding the power panel itself also charges (handy on phones).
UI.PowerButton().InputBegan:Connect(function(input)
	if state == "Aiming" and isPointerInput(input) then
		startCharging(input)
	end
end)

DataChangedRemote.OnClientEvent:Connect(applyData)
task.spawn(function()
	for _ = 1, 5 do
		local ok, result = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			applyData(result)
			return
		end
		task.wait(2)
	end
end)

-- Keep tidying smashed blocks while not flying (the flight loop does it otherwise).
RunService.Heartbeat:Connect(function()
	if not flight then
		course:Update(nil)
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
