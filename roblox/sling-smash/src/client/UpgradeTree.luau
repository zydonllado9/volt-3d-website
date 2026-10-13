--[[
	Full-screen hex upgrade tree. Drag to pan, scroll or 🔍 to zoom, tap a node
	to see it in the info card and buy it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Widgets = require(script.Parent.Widgets)

local UpgradeTree = {}

local HEX = 47 -- hex "radius" in pixels; neighbours are HEX * sqrt(3) apart
local NODE_SIZE = 66
local ZOOM_LEVELS = { 1, 0.75, 0.55 }

local COLORS = {
	Owned = { Color3.fromRGB(90, 190, 255), Color3.fromRGB(40, 110, 225) },
	Available = { Color3.fromRGB(190, 110, 255), Color3.fromRGB(122, 52, 214) },
	Locked = { Color3.fromRGB(84, 62, 120), Color3.fromRGB(52, 36, 80) },
	Start = { Color3.fromRGB(90, 240, 220), Color3.fromRGB(30, 170, 180) },
}

local overlay: Frame
local canvas: Frame
local canvasScale: UIScale
local coinsLabel: TextLabel
local info = {}
local nodeViews = {} -- [nodeId] = { Button, Gradient, Stroke, Icon, Line }
local selectedId: string? = nil
local currentData = nil
local onBuy = nil
local pan = Vector2.zero
local zoomIndex = 1
local pulseConnection: RBXScriptConnection? = nil

local function hexToPixel(q: number, r: number): Vector2
	return Vector2.new(HEX * math.sqrt(3) * (q + r / 2), HEX * 1.5 * r)
end

local function nodeState(node, data): string
	if not data then
		return "Locked"
	end
	if data.Upgrades[node.Id] then
		return "Owned"
	end
	if node.Requires == "Start" or data.Upgrades[node.Requires] then
		return "Available"
	end
	return "Locked"
end

local function applyCanvasTransform()
	canvas.Position = UDim2.new(0.5, pan.X, 0.5, pan.Y)
	canvasScale.Scale = Widgets.ViewportScale() * ZOOM_LEVELS[zoomIndex]
end

local function makeLine(fromPos: Vector2, toPos: Vector2): Frame
	local delta = toPos - fromPos
	local mid = (fromPos + toPos) / 2
	return Widgets.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, mid.X, 0.5, mid.Y),
		Size = UDim2.fromOffset(delta.Magnitude, 9),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = Color3.fromRGB(50, 36, 70),
		BorderSizePixel = 0,
		ZIndex = 32,
		Parent = canvas,
	})
end

local function makeNode(node, isStart: boolean)
	local pos = hexToPixel(node.Q, node.R)
	local button = Widgets.new("TextButton", {
		Name = node.Id,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, pos.X, 0.5, pos.Y),
		Size = UDim2.fromOffset(NODE_SIZE, NODE_SIZE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 34,
		Parent = canvas,
	})
	Widgets.Round(button)
	local colors = if isStart then COLORS.Start else COLORS.Locked
	local gradient = Widgets.Gradient(button, colors[1], colors[2])
	local stroke = Widgets.Stroke(button, Color3.fromRGB(30, 20, 46), 4)

	local icon = Widgets.Label({
		Name = "Icon",
		Text = node.Icon,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.62, 0.62),
		StrokeThickness = 0,
		ZIndex = 35,
		Parent = button,
	})

	if not isStart then
		local badge = Widgets.new("Frame", {
			Name = "Tier",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Color3.fromRGB(30, 22, 44),
			ZIndex = 36,
			Parent = button,
		})
		Widgets.Round(badge)
		Widgets.Stroke(badge, Color3.fromRGB(255, 255, 255), 1.5)
		Widgets.Label({
			Text = tostring(node.Tier),
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			StrokeThickness = 0,
			ZIndex = 37,
			Parent = badge,
		})
	end

	button.Activated:Connect(function()
		UpgradeTree.Select(node.Id)
	end)

	return {
		Button = button,
		Gradient = gradient,
		Stroke = stroke,
		Icon = icon,
		Position = pos,
	}
end

local function buildInfoCard(parent: Instance)
	local card = Widgets.new("Frame", {
		Name = "InfoCard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(270, 340),
		BackgroundColor3 = Widgets.Colors.Panel,
		Active = true, -- clicks on the card shouldn't start a pan
		ZIndex = 40,
		Parent = parent,
	})
	Widgets.Corner(card, 16)
	Widgets.Stroke(card, Widgets.Colors.PanelStroke, 4)
	Widgets.AutoScale(card)

	info.Icon = Widgets.Label({
		Text = "🎯",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(70, 70),
		StrokeThickness = 0,
		ZIndex = 41,
		Parent = card,
	})
	info.Name = Widgets.Label({
		Text = "Start",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(1, -24, 0, 34),
		StrokeThickness = 3,
		ZIndex = 41,
		Parent = card,
	})
	info.Description = Widgets.Label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(1, -28, 0, 66),
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 236, 200),
		MaxTextSize = 20,
		StrokeThickness = 0,
		ZIndex = 41,
		Parent = card,
	})
	info.Status = Widgets.Label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 202),
		Size = UDim2.new(1, -28, 0, 30),
		TextColor3 = Widgets.Colors.Coin,
		MaxTextSize = 24,
		ZIndex = 41,
		Parent = card,
	})
	local buy, buyLabel = Widgets.Button({
		Name = "Buy",
		Text = "Buy",
		Color = Widgets.Colors.Green,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(220, 62),
		ZIndex = 41,
		Parent = card,
	})
	info.Buy = buy
	info.BuyLabel = buyLabel
	buy.Activated:Connect(function()
		if selectedId and selectedId ~= "Start" and onBuy then
			onBuy(selectedId)
		end
	end)
end

function UpgradeTree.Init(gui: ScreenGui, buyCallback)
	onBuy = buyCallback

	overlay = Widgets.new("Frame", {
		Name = "UpgradeTree",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(16, 12, 28),
		BackgroundTransparency = 0.25,
		Active = true,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})

	local viewport = Widgets.new("Frame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = overlay,
	})

	canvas = Widgets.new("Frame", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1400, 1100),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = viewport,
	})
	canvasScale = Widgets.new("UIScale", { Parent = canvas })

	-- Lines first so they render under the nodes.
	local startView = makeNode(Config.StartNode, true)
	nodeViews.Start = startView
	local lines = {}
	for _, node in Config.Nodes do
		local parentNode = Config.NodesById[node.Requires] or Config.StartNode
		lines[node.Id] = makeLine(hexToPixel(parentNode.Q, parentNode.R), hexToPixel(node.Q, node.R))
	end
	for _, node in Config.Nodes do
		local view = makeNode(node, false)
		view.Line = lines[node.Id]
		nodeViews[node.Id] = view
	end

	-- Drag to pan.
	local dragging = false
	local dragStart = Vector2.zero
	local panStart = Vector2.zero
	viewport.InputBegan:Connect(function(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			panStart = pan
		end
	end)
	viewport.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if input.Position.Z > 0 then
				zoomIndex = math.max(1, zoomIndex - 1)
			else
				zoomIndex = math.min(#ZOOM_LEVELS, zoomIndex + 1)
			end
			applyCanvasTransform()
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			pan = Vector2.new(math.clamp(panStart.X + delta.X, -700, 700), math.clamp(panStart.Y + delta.Y, -600, 600))
			applyCanvasTransform()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- Header: coins + title.
	local top = Widgets.new("Frame", {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = overlay,
	})
	local coinsPill = Widgets.new("Frame", {
		Name = "Coins",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(210, 52),
		BackgroundColor3 = Widgets.Colors.Dark,
		BackgroundTransparency = 0.2,
		ZIndex = 40,
		Parent = top,
	})
	Widgets.Corner(coinsPill, 14)
	Widgets.Stroke(coinsPill, Color3.fromRGB(0, 0, 0), 2)
	Widgets.AutoScale(coinsPill)
	Widgets.Label({
		Text = "⭐",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(44, 44),
		StrokeThickness = 0,
		ZIndex = 41,
		Parent = coinsPill,
	})
	coinsLabel = Widgets.Label({
		Text = "0",
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.new(1, -66, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Widgets.Colors.Coin,
		ZIndex = 41,
		Parent = coinsPill,
	})

	local title = Widgets.new("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(420, 70),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = top,
	})
	Widgets.AutoScale(title)
	Widgets.Label({
		Text = "UPGRADES",
		Size = UDim2.new(1, 0, 0, 42),
		TextColor3 = Widgets.Colors.Header,
		StrokeThickness = 3,
		ZIndex = 41,
		Parent = title,
	})
	Widgets.Label({
		Text = "Drag to explore • tap a node to buy",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Color3.fromRGB(220, 210, 255),
		ZIndex = 41,
		Parent = title,
	})

	buildInfoCard(overlay)

	-- Bottom: Close + zoom.
	local bottom = Widgets.new("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(280, 64),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = overlay,
	})
	Widgets.AutoScale(bottom)
	local close = Widgets.Button({
		Text = "Close",
		Color = Widgets.Colors.Red,
		Size = UDim2.fromOffset(200, 62),
		ZIndex = 41,
		Parent = bottom,
	})
	close.Activated:Connect(function()
		UpgradeTree.Close()
	end)
	local zoom = Widgets.Button({
		Text = "🔍",
		Color = Widgets.Colors.Blue,
		Position = UDim2.fromOffset(216, 0),
		Size = UDim2.fromOffset(62, 62),
		ZIndex = 41,
		Parent = bottom,
	})
	zoom.Activated:Connect(function()
		zoomIndex = zoomIndex % #ZOOM_LEVELS + 1
		applyCanvasTransform()
	end)

	applyCanvasTransform()
	UpgradeTree.Select("Start")
end

function UpgradeTree.Select(nodeId: string)
	selectedId = nodeId
	for id, view in nodeViews do
		view.Button.Size = if id == nodeId
			then UDim2.fromOffset(NODE_SIZE + 10, NODE_SIZE + 10)
			else UDim2.fromOffset(NODE_SIZE, NODE_SIZE)
	end

	if nodeId == "Start" then
		info.Icon.Text = Config.StartNode.Icon
		info.Name.Text = "Slingshot"
		info.Description.Text = "Your trusty slingshot. Every branch grows from here!"
		info.Status.Text = ""
		info.Buy.Visible = false
		return
	end

	local node = Config.NodesById[nodeId]
	if not node then
		return
	end
	local data = currentData
	local state = nodeState(node, data)
	info.Icon.Text = node.Icon
	info.Name.Text = node.Name
	info.Description.Text = node.Description
	info.Buy.Visible = true

	if state == "Owned" then
		info.Status.Text = "✅ Owned"
		info.BuyLabel.Text = "Owned"
		Widgets.SetButtonColor(info.Buy, Widgets.Colors.Blue)
	elseif state == "Available" then
		info.Status.Text = "⭐ " .. Format.Coins(node.Cost)
		local affordable = data ~= nil and data.Coins >= node.Cost
		info.BuyLabel.Text = if affordable then "Buy" else "Need more ⭐"
		Widgets.SetButtonColor(info.Buy, if affordable then Widgets.Colors.Green else Widgets.Colors.Grey)
	else
		local required = Config.NodesById[node.Requires]
		info.Status.Text = "🔒 Needs " .. (if required then required.Name else "previous")
		info.BuyLabel.Text = "Locked"
		Widgets.SetButtonColor(info.Buy, Widgets.Colors.Grey)
	end
end

function UpgradeTree.SetData(data)
	currentData = data
	if not overlay then
		return
	end
	coinsLabel.Text = Format.Coins(data.Coins)

	for _, node in Config.Nodes do
		local view = nodeViews[node.Id]
		local state = nodeState(node, data)
		local colors = COLORS[state]
		view.Gradient.Color = ColorSequence.new(colors[1], colors[2])
		view.Icon.TextTransparency = if state == "Locked" then 0.5 else 0
		if state == "Owned" then
			view.Stroke.Color = Color3.fromRGB(255, 255, 255)
			view.Stroke.Thickness = 3
			view.Line.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
		elseif state == "Available" then
			view.Stroke.Color = Color3.fromRGB(255, 210, 60)
			view.Stroke.Thickness = 4
			view.Line.BackgroundColor3 = Color3.fromRGB(190, 150, 255)
		else
			view.Stroke.Color = Color3.fromRGB(30, 20, 46)
			view.Stroke.Thickness = 4
			view.Line.BackgroundColor3 = Color3.fromRGB(50, 36, 70)
		end
	end

	if selectedId then
		UpgradeTree.Select(selectedId)
	end
end

-- True when at least one unlocked upgrade can be bought right now.
function UpgradeTree.HasAffordable(data): boolean
	if not data then
		return false
	end
	for _, node in Config.Nodes do
		if nodeState(node, data) == "Available" and data.Coins >= node.Cost then
			return true
		end
	end
	return false
end

function UpgradeTree.IsOpen(): boolean
	return overlay ~= nil and overlay.Visible
end

function UpgradeTree.Open()
	if not overlay then
		return
	end
	overlay.Visible = true
	applyCanvasTransform()
	if currentData then
		UpgradeTree.SetData(currentData)
	end
	-- Pick the cheapest thing you can buy so the card is useful immediately.
	if currentData then
		local best = nil
		for _, node in Config.Nodes do
			if nodeState(node, currentData) == "Available" and (best == nil or node.Cost < best.Cost) then
				best = node
			end
		end
		if best then
			UpgradeTree.Select(best.Id)
		end
	end

	if pulseConnection then
		pulseConnection:Disconnect()
	end
	pulseConnection = RunService.Heartbeat:Connect(function()
		local data = currentData
		if not data then
			return
		end
		local pulse = 4 + math.sin(os.clock() * 6) * 2
		for _, node in Config.Nodes do
			if nodeState(node, data) == "Available" and data.Coins >= node.Cost then
				nodeViews[node.Id].Stroke.Thickness = pulse
			end
		end
	end)
end

function UpgradeTree.Close()
	if overlay then
		overlay.Visible = false
	end
	if pulseConnection then
		pulseConnection:Disconnect()
		pulseConnection = nil
	end
end

return UpgradeTree
