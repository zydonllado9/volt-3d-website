--[[
	Client-only juice: sounds, camera shake, speed lines, screen flashes and
	floating "+coins" numbers. Everything respects the player's settings.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Widgets = require(script.Parent.Widgets)

local Effects = {}

Effects.Settings = table.clone(Config.DefaultSettings)

local sounds = {} -- [name] = Sound template
local wind: Sound? = nil
local music: Sound? = nil
local lastPlayed = {} -- [name] = os.clock()

local shakeAmount = 0
local speedGui: ScreenGui? = nil
local speedLines = {}
local flashFrame: Frame? = nil
local floatingCount = 0
local rng = Random.new()

local function makeSound(name: string, id: string, volume: number, looped: boolean?): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sling_" .. name
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped == true
	sound.Parent = SoundService
	return sound
end

function Effects.Init(playerGui: PlayerGui)
	sounds.Launch = makeSound("Launch", Config.Sounds.Launch, 0.8)
	sounds.Smash = makeSound("Smash", Config.Sounds.Smash, 0.45)
	sounds.Coin = makeSound("Coin", Config.Sounds.Coin, 0.35)
	sounds.Click = makeSound("Click", Config.Sounds.Click, 0.25)
	wind = makeSound("Wind", Config.Sounds.Wind, 0, true)
	music = makeSound("Music", Config.Sounds.Music, 0.35, true)

	local gui = Widgets.new("ScreenGui", {
		Name = "SlingEffects",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = -1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = playerGui,
	})
	speedGui = gui

	for i = 1, 26 do
		local line = Widgets.new("Frame", {
			Name = "Line" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(3, rng:NextInteger(70, 180)),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		table.insert(speedLines, {
			Frame = line,
			Angle = rng:NextNumber(0, math.pi * 2),
			Radius = rng:NextNumber(0.2, 0.8),
			Speed = rng:NextNumber(0.9, 1.6),
		})
	end

	local flashGui = Widgets.new("ScreenGui", {
		Name = "SlingFlash",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		Parent = playerGui,
	})
	flashFrame = Widgets.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = flashGui,
	})

	Effects.ApplySettings(Effects.Settings)
end

function Effects.ApplySettings(settings)
	for key, value in settings do
		Effects.Settings[key] = value
	end
	if music then
		if Effects.Settings.Music then
			if not music.IsPlaying then
				music:Play()
			end
		else
			music:Stop()
		end
	end
	if not Effects.Settings.SpeedLines and speedGui then
		speedGui.Enabled = false
	end
end

-- Plays a one-shot sound; minGap throttles rapid repeats (e.g. smashes).
function Effects.Play(name: string, pitch: number?, minGap: number?)
	if not Effects.Settings.SFX then
		return
	end
	local template = sounds[name]
	if not template then
		return
	end
	local now = os.clock()
	if minGap and lastPlayed[name] and now - lastPlayed[name] < minGap then
		return
	end
	lastPlayed[name] = now
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- Looping wind while flying; louder and higher pitched when fast.
function Effects.SetWind(speedFraction: number)
	if not wind then
		return
	end
	if speedFraction <= 0 or not Effects.Settings.SFX then
		if wind.IsPlaying then
			wind:Stop()
		end
		return
	end
	if not wind.IsPlaying then
		wind:Play()
	end
	wind.Volume = math.clamp(speedFraction, 0, 1) * 0.5
	wind.PlaybackSpeed = 0.8 + math.clamp(speedFraction, 0, 1.5) * 0.5
end

function Effects.Shake(amount: number)
	if Effects.Settings.CameraShake then
		shakeAmount = math.max(shakeAmount, amount)
	end
end

-- Returns a CFrame offset to multiply onto the camera this frame.
function Effects.ShakeOffset(dt: number): CFrame
	if shakeAmount < 0.01 then
		shakeAmount = 0
		return CFrame.identity
	end
	local a = shakeAmount
	shakeAmount *= math.exp(-9 * dt)
	return CFrame.new(rng:NextNumber(-a, a), rng:NextNumber(-a, a), 0)
		* CFrame.Angles(0, 0, rng:NextNumber(-a, a) * 0.02)
end

-- intensity 0..1 controls how visible the speed lines are.
function Effects.UpdateSpeedLines(dt: number, intensity: number)
	local gui = speedGui
	if not gui then
		return
	end
	if not Effects.Settings.SpeedLines or intensity <= 0.05 then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	for _, line in speedLines do
		line.Radius += dt * line.Speed * (0.6 + intensity * 1.4)
		if line.Radius > 0.9 then
			line.Radius = rng:NextNumber(0.25, 0.45)
			line.Angle = rng:NextNumber(0, math.pi * 2)
		end
		local x = 0.5 + math.cos(line.Angle) * line.Radius * 0.62
		local y = 0.5 + math.sin(line.Angle) * line.Radius * 0.62
		line.Frame.Position = UDim2.fromScale(x, y)
		line.Frame.Rotation = math.deg(line.Angle) + 90
		line.Frame.BackgroundTransparency = 1 - math.clamp(intensity, 0, 1) * 0.55 * math.clamp((line.Radius - 0.2) * 2, 0, 1)
	end
end

function Effects.HideSpeedLines()
	if speedGui then
		speedGui.Enabled = false
	end
end

function Effects.Flash(color: Color3, strength: number?)
	local frame = flashFrame
	if not frame then
		return
	end
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - (strength or 0.4)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- Invisible part at the origin that floating-text attachments hang off.
local anchorPart: Part? = nil
local function floatAnchor(): Part
	if anchorPart and anchorPart.Parent then
		return anchorPart
	end
	local created = Instance.new("Part")
	created.Name = "SlingFloatAnchor"
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.Transparency = 1
	created.Size = Vector3.new(0.2, 0.2, 0.2)
	created.CFrame = CFrame.new()
	created.Parent = Workspace
	anchorPart = created
	return created
end

-- Floating text in the world (e.g. "+1.4K") that rises and fades.
function Effects.FloatText(position: Vector3, text: string, color: Color3, size: number?)
	if floatingCount > 30 then
		return
	end
	floatingCount += 1

	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = floatAnchor()

	local scale = size or 1
	local billboard = Widgets.new("BillboardGui", {
		Size = UDim2.fromOffset(170 * scale, 54 * scale),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		Adornee = attachment,
		Parent = attachment,
	})
	local label = Widgets.Label({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = color,
		StrokeThickness = 3,
		Parent = billboard,
	})

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
	end

	task.delay(0.95, function()
		floatingCount -= 1
		attachment:Destroy()
	end)
end

-- Client-side explosion: purely visual, never hurts anyone.
function Effects.Explosion(position: Vector3, radius: number)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = Workspace
end

return Effects
