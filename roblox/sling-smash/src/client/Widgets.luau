--[[
	Tiny UI kit: chunky cartoon panels, buttons and labels built from code.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Widgets = {}

Widgets.Font = Enum.Font.FredokaOne

Widgets.Colors = {
	Panel = Color3.fromRGB(96, 62, 42),
	PanelDark = Color3.fromRGB(62, 40, 28),
	PanelStroke = Color3.fromRGB(36, 22, 14),
	Header = Color3.fromRGB(255, 206, 46),
	Green = Color3.fromRGB(92, 214, 64),
	Yellow = Color3.fromRGB(255, 196, 36),
	Blue = Color3.fromRGB(64, 146, 255),
	Red = Color3.fromRGB(236, 64, 64),
	Purple = Color3.fromRGB(150, 80, 230),
	Pink = Color3.fromRGB(255, 76, 170),
	Grey = Color3.fromRGB(120, 120, 130),
	Slate = Color3.fromRGB(70, 82, 104),
	Text = Color3.fromRGB(255, 255, 255),
	TextStroke = Color3.fromRGB(30, 18, 10),
	Coin = Color3.fromRGB(255, 214, 60),
	Dark = Color3.fromRGB(24, 24, 32),
}

local buttonColorSetters = setmetatable({}, { __mode = "k" }) -- [GuiButton] = function(Color3)
local autoScales = {} -- list of { Scale: UIScale, Multiplier: number }
local autoMultipliers = setmetatable({}, { __mode = "k" }) -- [UIScale] = multiplier

function Widgets.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Widgets.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Widgets.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Widgets.Corner(parent: Instance, radius: number?): UICorner
	return Widgets.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Widgets.Round(parent: Instance): UICorner
	return Widgets.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Widgets.Stroke(parent: Instance, color: Color3?, thickness: number?, border: boolean?): UIStroke
	return Widgets.new("UIStroke", {
		Color = color or Widgets.Colors.PanelStroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = if border == false then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Widgets.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Widgets.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function Widgets.Rainbow(parent: Instance, rotation: number?): UIGradient
	return Widgets.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 220, 255)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(150, 110, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 200)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 90)),
		}),
		Rotation = rotation or 0,
		Parent = parent,
	})
end

-- A text label with the chunky outlined look used everywhere.
-- Extra props: StrokeThickness (0 = no outline), MaxTextSize.
function Widgets.Label(props: { [string]: any }): TextLabel
	local label = Widgets.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Widgets.Font,
		TextColor3 = Widgets.Colors.Text,
		TextScaled = true,
		Text = "",
	})
	for key, value in props do
		if key ~= "StrokeThickness" and key ~= "MaxTextSize" and key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	if props.StrokeThickness ~= 0 then
		Widgets.Stroke(label, Widgets.Colors.TextStroke, props.StrokeThickness or 2, false)
	end
	if props.MaxTextSize then
		Widgets.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, Parent = label })
	end
	label.Parent = props.Parent
	return label
end

-- Button with a gradient, outline, centred label and a squish animation.
function Widgets.Button(props: { [string]: any }): (TextButton, TextLabel)
	local color = props.Color or Widgets.Colors.Green
	local button = Widgets.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size or UDim2.fromOffset(180, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
	})
	Widgets.Corner(button, props.Corner or 12)
	local stroke = Widgets.Stroke(button, Widgets.Darken(color, 0.55), props.StrokeThickness or 3)
	local gradient = Widgets.Gradient(button, Widgets.Lighten(color, 0.15), Widgets.Darken(color, 0.12))

	local label = Widgets.Label({
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = props.TextSize,
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = button,
	})

	local scale = Widgets.new("UIScale", { Parent = button })
	local function tweenScale(target: number)
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenScale(1.05)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenScale(0.92)
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(1)
	end)

	buttonColorSetters[button] = function(newColor: Color3)
		gradient.Color = ColorSequence.new(Widgets.Lighten(newColor, 0.15), Widgets.Darken(newColor, 0.12))
		stroke.Color = Widgets.Darken(newColor, 0.55)
	end

	button.Parent = props.Parent
	return button, label
end

-- Recolours a button made with Widgets.Button (e.g. Buy -> Owned).
function Widgets.SetButtonColor(button: GuiButton, color: Color3)
	local setter = buttonColorSetters[button]
	if setter then
		setter(color)
	end
end

-- Keeps UIScales proportional to the screen height so the UI fits phones.
local function viewportScale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 800
	return math.clamp(height / 820, 0.48, 1.3)
end

function Widgets.ViewportScale(): number
	return viewportScale()
end

function Widgets.AutoScale(parent: Instance, multiplier: number?): UIScale
	local scale = Widgets.new("UIScale", { Scale = viewportScale() * (multiplier or 1), Parent = parent })
	table.insert(autoScales, { Scale = scale, Multiplier = multiplier or 1 })
	autoMultipliers[scale] = multiplier or 1
	return scale
end

local function refreshScales()
	local value = viewportScale()
	for _, entry in autoScales do
		entry.Scale.Scale = value * entry.Multiplier
	end
end

local function watchCamera(camera: Camera?)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
		refreshScales()
	end
end
watchCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(Workspace.CurrentCamera)
end)

-- Modal panel: brown body, yellow header with a title and a red close button.
function Widgets.Panel(parent: Instance, title: string, size: Vector2): (Frame, Frame, TextButton)
	local panel = Widgets.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Widgets.Colors.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	Widgets.Corner(panel, 16)
	Widgets.Stroke(panel, Widgets.Colors.PanelStroke, 4)
	Widgets.AutoScale(panel)

	local header = Widgets.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 21,
		Parent = panel,
	})
	Widgets.Corner(header, 16)
	Widgets.Gradient(header, Color3.fromRGB(255, 222, 90), Color3.fromRGB(240, 170, 20))
	Widgets.Stroke(header, Widgets.Colors.PanelStroke, 4)

	Widgets.Label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.new(0, 20, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 22,
		Parent = header,
	})

	local close = Widgets.Button({
		Name = "Close",
		Text = "X",
		Color = Widgets.Colors.Red,
		Size = UDim2.fromOffset(50, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		ZIndex = 24,
		Parent = panel,
	})

	local content = Widgets.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 76),
		Size = UDim2.new(1, -36, 1, -92),
		ZIndex = 21,
		Parent = panel,
	})

	return panel, content, close
end

-- Pops a GuiObject in with a quick bounce (reuses its UIScale if it has one).
function Widgets.PopIn(gui: GuiObject)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Widgets.new("UIScale", { Parent = gui })
	end
	local target = 1
	local multiplier = autoMultipliers[scale]
	if multiplier then
		target = viewportScale() * multiplier
	end
	scale.Scale = target * 0.6
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target })
		:Play()
end

return Widgets
