--[[
	All 2D interface: lobby buttons, side menu, coin counter, power bar, flight
	HUD, results screen and the Shop / Rebirth / Stats / Settings panels.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UpgradeTree = require(script.Parent.UpgradeTree)
local Widgets = require(script.Parent.Widgets)

local UI = {}

local C = Widgets.Colors
local actions: { [string]: any } = {}
local gui: ScreenGui
local mode = "Lobby"
local data = nil

local refs: { [string]: any } = {} -- named GuiObjects
local panels = {} -- [name] = Frame
local settingButtons = {} -- [key] = { Button, Label }
local shopRows = {} -- [trailId] = { Button, Label, Price }
local statLabels = {} -- [key] = TextLabel
local rebirthRefs: { [string]: any } = {}

local displayedRunCoins = 0
local targetRunCoins = 0
local displayedCoins = 0
local targetCoins = 0

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function pill(props: { [string]: any }): Frame
	local frame = Widgets.new("Frame", {
		Name = props.Name,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = props.Color or C.Dark,
		BackgroundTransparency = props.Transparency or 0.2,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	Widgets.Corner(frame, props.Corner or 14)
	Widgets.Stroke(frame, Color3.fromRGB(0, 0, 0), 2)
	return frame
end

--------------------------------------------------------------------------------
-- Lobby: top buttons, side menu, coins
--------------------------------------------------------------------------------

local function buildLobby()
	local top = Widgets.new("Frame", {
		Name = "TopButtons",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Widgets.AutoScale(top)
	refs.TopButtons = top
	local launch = Widgets.Button({
		Text = "🎯 Launch",
		Color = C.Blue,
		Size = UDim2.fromOffset(212, 68),
		Parent = top,
	})
	launch.Activated:Connect(function()
		actions.Launch()
	end)
	local upgrade = Widgets.Button({
		Text = "⬆️ Upgrade",
		Color = C.Green,
		Position = UDim2.fromOffset(228, 0),
		Size = UDim2.fromOffset(212, 68),
		Parent = top,
	})
	upgrade.Activated:Connect(function()
		UI.OpenPanel("Upgrades")
	end)

	local menu = Widgets.new("Frame", {
		Name = "SideMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(190, 296),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Widgets.AutoScale(menu)
	refs.SideMenu = menu
	Widgets.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(90, 90),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})

	local tiles = {
		{ "Shop", "🛒", "Shop" },
		{ "Upgrades", "⬆️", "Upgrades" },
		{ "Rebirth", "🔄", "Rebirth" },
		{ "Index", "📖", nil },
		{ "Stats", "📊", "Stats" },
		{ "Settings", "⚙️", "Settings" },
	}
	for order, tile in tiles do
		local name, icon, panelName = tile[1], tile[2], tile[3]
		local button = Widgets.new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = order,
			Parent = menu,
		})
		Widgets.Corner(button, 14)
		Widgets.Stroke(button, Color3.fromRGB(20, 24, 36), 3)
		Widgets.Gradient(button, Color3.fromRGB(110, 128, 160), Color3.fromRGB(64, 74, 100))
		Widgets.Label({
			Text = icon,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(50, 50),
			StrokeThickness = 0,
			Parent = button,
		})
		Widgets.Label({
			Text = name,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -8, 0, 22),
			Parent = button,
		})

		local badge = Widgets.new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = C.Red,
			Visible = false,
			ZIndex = 3,
			Parent = button,
		})
		Widgets.Round(badge)
		Widgets.Stroke(badge, Color3.new(1, 1, 1), 2)
		Widgets.Label({ Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 4, Parent = badge })
		refs[name .. "Badge"] = badge

		if not panelName then
			local soon = Widgets.new("Frame", {
				Name = "Soon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 2),
				Size = UDim2.fromOffset(56, 22),
				BackgroundColor3 = C.Yellow,
				ZIndex = 3,
				Parent = button,
			})
			Widgets.Corner(soon, 8)
			Widgets.Stroke(soon, Widgets.Darken(C.Yellow, 0.5), 2)
			Widgets.Label({ Text = "SOON", Size = UDim2.fromScale(1, 1), ZIndex = 4, StrokeThickness = 1.5, Parent = soon })
		end

		button.Activated:Connect(function()
			actions.Click()
			if panelName then
				UI.OpenPanel(panelName)
			else
				UI.Toast("Coming soon!")
			end
		end)
	end

	-- Bottom-left coins + best.
	local wallet = Widgets.new("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(250, 100),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Widgets.AutoScale(wallet)
	refs.Wallet = wallet
	local coins = pill({ Name = "Coins", Size = UDim2.fromOffset(250, 58), Parent = wallet })
	Widgets.Label({ Text = "⭐", Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(48, 48), StrokeThickness = 0, Parent = coins })
	refs.Coins = Widgets.Label({
		Text = "0",
		Position = UDim2.fromOffset(60, 7),
		Size = UDim2.new(1, -70, 1, -14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Coin,
		StrokeThickness = 3,
		Parent = coins,
	})
	refs.Best = Widgets.Label({
		Text = "🏆 BEST 0",
		Position = UDim2.fromOffset(4, 64),
		Size = UDim2.fromOffset(240, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(140, 255, 100),
		StrokeThickness = 3,
		Parent = wallet,
	})
end

--------------------------------------------------------------------------------
-- In-run HUD: run coins, combo, distance, hint, power bar, pop text
--------------------------------------------------------------------------------

local function buildRunHud()
	local runCoins = pill({
		Name = "RunCoins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(230, 58),
		Visible = false,
		Parent = gui,
	})
	Widgets.AutoScale(runCoins)
	Widgets.Label({ Text = "⭐", Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(46, 46), StrokeThickness = 0, Parent = runCoins })
	refs.RunCoinsLabel = Widgets.Label({
		Text = "0",
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.new(1, -72, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = runCoins,
	})
	refs.RunCoins = runCoins

	local combo = Widgets.new("Frame", {
		Name = "Combo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(170, 82),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	})
	Widgets.Corner(combo, 14)
	Widgets.Gradient(combo, Color3.fromRGB(255, 120, 200), Color3.fromRGB(220, 40, 140))
	Widgets.Stroke(combo, Color3.fromRGB(90, 10, 60), 3)
	Widgets.AutoScale(combo)
	Widgets.Label({ Text = "🔥", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(40, 40), StrokeThickness = 0, Parent = combo })
	Widgets.Label({ Text = "COMBO", Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 20), Parent = combo })
	refs.ComboLabel = Widgets.Label({
		Text = "x2",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 40),
		StrokeThickness = 3,
		Parent = combo,
	})
	local barBack = Widgets.new("Frame", {
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.new(1, -28, 0, 7),
		BackgroundColor3 = Color3.fromRGB(110, 20, 70),
		Parent = combo,
	})
	Widgets.Round(barBack)
	refs.ComboBar = Widgets.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = barBack,
	})
	Widgets.Round(refs.ComboBar)
	refs.Combo = combo

	local distance = pill({
		Name = "Distance",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(220, 62),
		Visible = false,
		Parent = gui,
	})
	Widgets.AutoScale(distance)
	Widgets.Label({ Text = "🏁", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(44, 44), StrokeThickness = 0, Parent = distance })
	refs.DistanceLabel = Widgets.Label({
		Text = "0",
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -70, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = distance,
	})
	Widgets.Label({
		Text = "STUDS",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -4),
		Size = UDim2.fromOffset(70, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = distance,
	})
	refs.Distance = distance

	local hint = pill({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(340, 48),
		Visible = false,
		Parent = gui,
	})
	Widgets.AutoScale(hint)
	refs.HintLabel = Widgets.Label({
		Text = "A / D TO STEER",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -14),
		Parent = hint,
	})
	refs.Hint = hint

	-- Power bar. The whole panel is a button so phones can press and hold it.
	local power = Widgets.new("TextButton", {
		Name = "Power",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(470, 128),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = gui,
	})
	Widgets.Corner(power, 16)
	Widgets.Stroke(power, C.PanelStroke, 4)
	Widgets.AutoScale(power)
	refs.Power = power

	local tag = Widgets.new("Frame", {
		Position = UDim2.fromOffset(16, -18),
		Size = UDim2.fromOffset(140, 38),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = power,
	})
	Widgets.Corner(tag, 10)
	Widgets.Gradient(tag, Color3.fromRGB(130, 240, 90), Color3.fromRGB(60, 180, 40))
	Widgets.Stroke(tag, Color3.fromRGB(20, 70, 10), 3)
	Widgets.Label({ Text = "⚡ POWER", Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), ZIndex = 3, Parent = tag })

	refs.PowerPercent = Widgets.Label({
		Text = "0%",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 10),
		Size = UDim2.fromOffset(120, 34),
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 3,
		Parent = power,
	})

	local bar = Widgets.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.new(1, -36, 0, 36),
		BackgroundColor3 = Color3.fromRGB(40, 26, 18),
		ClipsDescendants = true,
		Parent = power,
	})
	Widgets.Corner(bar, 8)
	Widgets.Stroke(bar, C.PanelStroke, 3)
	local fill = Widgets.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	})
	Widgets.Corner(fill, 8)
	refs.PowerGradient = Widgets.Rainbow(fill)
	refs.PowerFill = fill
	for i = 1, 19 do
		Widgets.new("Frame", {
			Position = UDim2.new(i / 20, -1, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.fromRGB(30, 20, 14),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = bar,
		})
	end

	refs.PowerStatus = Widgets.Label({
		Text = "HOLD TO CHARGE",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -40, 0, 28),
		TextColor3 = Color3.fromRGB(255, 226, 120),
		Parent = power,
	})

	local cancel = Widgets.Button({
		Name = "Cancel",
		Text = "X",
		Color = C.Red,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 14, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		Parent = power,
	})
	cancel.Activated:Connect(function()
		actions.Cancel()
	end)

	-- Big centre pop text ("MAX POWER!", "CRITICAL!") and a zone banner.
	local pop = Widgets.Label({
		Name = "Pop",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromOffset(640, 96),
		StrokeThickness = 5,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Widgets.AutoScale(pop)
	refs.PopGradient = Widgets.new("UIGradient", { Rotation = 90, Parent = pop })
	refs.Pop = pop

	local banner = Widgets.Label({
		Name = "Banner",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(560, 64),
		TextColor3 = C.Header,
		StrokeThickness = 4,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Widgets.AutoScale(banner)
	refs.Banner = banner

	local toast = pill({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(440, 46),
		Visible = false,
		Parent = gui,
	})
	toast.ZIndex = 60
	Widgets.AutoScale(toast)
	refs.ToastLabel = Widgets.Label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -12),
		ZIndex = 61,
		Parent = toast,
	})
	refs.Toast = toast
end

--------------------------------------------------------------------------------
-- Results
--------------------------------------------------------------------------------

local function statBox(parent: Instance, x: number, icon: string): TextLabel
	local box = pill({
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(132, 52),
		Color = C.PanelDark,
		Transparency = 0,
		Corner = 10,
		Parent = parent,
	})
	box.ZIndex = 22
	Widgets.Label({ Text = icon, Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(36, 36), StrokeThickness = 0, ZIndex = 23, Parent = box })
	return Widgets.Label({
		Text = "0",
		Position = UDim2.fromOffset(46, 8),
		Size = UDim2.new(1, -54, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = box,
	})
end

local function buildResults()
	local panel, content, close = Widgets.Panel(gui, "🏆 Launch Complete!", Vector2.new(470, 440))
	panels.Results = panel
	close.Activated:Connect(function()
		actions.Return()
	end)

	refs.ResultTitle = Widgets.Label({
		Text = "NICE LAUNCH!",
		Size = UDim2.new(1, 0, 0, 46),
		TextColor3 = C.Header,
		StrokeThickness = 3,
		ZIndex = 22,
		Parent = content,
	})
	refs.ResultGradient = Widgets.Rainbow(refs.ResultTitle)
	Widgets.Label({
		Text = "You earned:",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 22,
		Parent = content,
	})
	refs.ResultEarned = Widgets.Label({
		Text = "⭐ +0",
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 58),
		TextColor3 = Color3.fromRGB(120, 255, 90),
		StrokeThickness = 4,
		ZIndex = 22,
		Parent = content,
	})
	refs.ResultBreakdown = Widgets.Label({
		Text = "",
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Color3.fromRGB(255, 230, 190),
		StrokeThickness = 0,
		ZIndex = 22,
		Parent = content,
	})

	local row = Widgets.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 176),
		Size = UDim2.fromOffset(420, 52),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = content,
	})
	refs.ResultDistance = statBox(row, 0, "🏁")
	refs.ResultSmashes = statBox(row, 144, "🔨")
	refs.ResultCombo = statBox(row, 288, "🔥")

	local retry = Widgets.Button({
		Text = "Retry",
		Color = C.Green,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 6, 1, 0),
		Size = UDim2.fromOffset(200, 66),
		ZIndex = 22,
		Parent = content,
	})
	retry.Activated:Connect(function()
		actions.Retry()
	end)
	local back = Widgets.Button({
		Text = "Return",
		Color = C.Yellow,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, 0),
		Size = UDim2.fromOffset(200, 66),
		ZIndex = 22,
		Parent = content,
	})
	back.Activated:Connect(function()
		actions.Return()
	end)
end

--------------------------------------------------------------------------------
-- Shop (trails)
--------------------------------------------------------------------------------

local function buildShop()
	local panel, content, close = Widgets.Panel(gui, "🛒 Trail Shop", Vector2.new(540, 480))
	panels.Shop = panel
	close.Activated:Connect(UI.ClosePanels)

	local list = Widgets.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 22,
		Parent = content,
	})
	Widgets.new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	for order, trail in Config.Trails do
		local row = Widgets.new("Frame", {
			Name = trail.Id,
			Size = UDim2.new(1, -14, 0, 76),
			BackgroundColor3 = C.PanelDark,
			LayoutOrder = order,
			ZIndex = 22,
			Parent = list,
		})
		Widgets.Corner(row, 12)
		Widgets.Stroke(row, C.PanelStroke, 2)

		local swatch = Widgets.new("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 23,
			Parent = row,
		})
		Widgets.Corner(swatch, 10)
		Widgets.Stroke(swatch, Color3.fromRGB(0, 0, 0), 2)
		if trail.Colors then
			local keypoints = {}
			for i, color in trail.Colors do
				table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #trail.Colors - 1), color))
			end
			if #keypoints == 1 then
				table.insert(keypoints, ColorSequenceKeypoint.new(1, trail.Colors[1]))
			end
			Widgets.new("UIGradient", { Color = ColorSequence.new(keypoints), Rotation = 45, Parent = swatch })
		else
			swatch.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			Widgets.Label({ Text = "✖", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), ZIndex = 24, Parent = swatch })
		end

		Widgets.Label({
			Text = trail.Name,
			Position = UDim2.fromOffset(78, 8),
			Size = UDim2.fromOffset(220, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = row,
		})
		local price = Widgets.Label({
			Text = if trail.Price > 0 then "⭐ " .. Format.Coins(trail.Price) else "Free",
			Position = UDim2.fromOffset(78, 42),
			Size = UDim2.fromOffset(220, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Coin,
			ZIndex = 23,
			Parent = row,
		})
		local button, label = Widgets.Button({
			Text = "Buy",
			Color = C.Green,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 54),
			ZIndex = 23,
			Parent = row,
		})
		button.Activated:Connect(function()
			if not data then
				return
			end
			if data.Trails[trail.Id] then
				actions.EquipTrail(trail.Id)
			else
				actions.BuyTrail(trail.Id)
			end
		end)
		shopRows[trail.Id] = { Button = button, Label = label, Price = price }
	end
end

local function refreshShop()
	if not data then
		return
	end
	for _, trail in Config.Trails do
		local row = shopRows[trail.Id]
		local owned = data.Trails[trail.Id] == true
		if data.EquippedTrail == trail.Id then
			row.Label.Text = "Equipped"
			Widgets.SetButtonColor(row.Button, C.Blue)
		elseif owned then
			row.Label.Text = "Equip"
			Widgets.SetButtonColor(row.Button, C.Yellow)
		elseif data.Coins >= trail.Price then
			row.Label.Text = "Buy"
			Widgets.SetButtonColor(row.Button, C.Green)
		else
			row.Label.Text = "Buy"
			Widgets.SetButtonColor(row.Button, C.Grey)
		end
	end
end

--------------------------------------------------------------------------------
-- Rebirth
--------------------------------------------------------------------------------

local function buildRebirth()
	local panel, content, close = Widgets.Panel(gui, "🔄 Rebirth", Vector2.new(480, 430))
	panels.Rebirth = panel
	close.Activated:Connect(UI.ClosePanels)

	rebirthRefs.Count = Widgets.Label({
		Text = "Rebirths: 0",
		Size = UDim2.new(1, 0, 0, 40),
		StrokeThickness = 3,
		ZIndex = 22,
		Parent = content,
	})
	rebirthRefs.Bonus = Widgets.Label({
		Text = "",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = Color3.fromRGB(140, 255, 100),
		ZIndex = 22,
		Parent = content,
	})
	rebirthRefs.Cost = Widgets.Label({
		Text = "",
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = C.Coin,
		ZIndex = 22,
		Parent = content,
	})
	Widgets.Label({
		Text = "Resets your coins and upgrades.\nKeeps trails, stats and your best distance.",
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 60),
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 220, 190),
		StrokeThickness = 0,
		MaxTextSize = 22,
		ZIndex = 22,
		Parent = content,
	})
	local button, label = Widgets.Button({
		Text = "Rebirth",
		Color = C.Purple,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(260, 70),
		ZIndex = 22,
		Parent = content,
	})
	rebirthRefs.Button = button
	rebirthRefs.ButtonLabel = label
	button.Activated:Connect(function()
		actions.Rebirth()
	end)
end

local function refreshRebirth()
	if not data then
		return
	end
	local cost = Config.RebirthCost(data.Rebirths)
	rebirthRefs.Count.Text = "Rebirths: " .. data.Rebirths
	rebirthRefs.Bonus.Text = string.format(
		"Coin bonus: x%.1f → x%.1f",
		Config.RebirthMultiplier(data.Rebirths),
		Config.RebirthMultiplier(data.Rebirths + 1)
	)
	rebirthRefs.Cost.Text = "Cost: ⭐ " .. Format.Coins(cost)
	local ready = data.Coins >= cost
	rebirthRefs.ButtonLabel.Text = if ready then "Rebirth!" else "Need ⭐ " .. Format.Short(cost - data.Coins)
	Widgets.SetButtonColor(rebirthRefs.Button, if ready then C.Purple else C.Grey)
end

--------------------------------------------------------------------------------
-- Stats + Settings
--------------------------------------------------------------------------------

local STAT_ROWS = {
	{ "Launches", "🚀 Launches" },
	{ "BestDistance", "🏁 Best Distance" },
	{ "TotalDistance", "📏 Total Distance" },
	{ "TotalSmashes", "🔨 Blocks Smashed" },
	{ "BestCombo", "🔥 Best Combo" },
	{ "StarsCollected", "⭐ Stars Collected" },
	{ "TotalCoins", "💰 Coins Earned" },
	{ "Rebirths", "🔄 Rebirths" },
}

local function buildStats()
	local panel, content, close = Widgets.Panel(gui, "📊 Stats", Vector2.new(460, 500))
	panels.Stats = panel
	close.Activated:Connect(UI.ClosePanels)
	Widgets.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	for order, row in STAT_ROWS do
		local frame = Widgets.new("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = C.PanelDark,
			LayoutOrder = order,
			ZIndex = 22,
			Parent = content,
		})
		Widgets.Corner(frame, 10)
		Widgets.Label({
			Text = row[2],
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.62, -12, 1, -12),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = frame,
		})
		statLabels[row[1]] = Widgets.Label({
			Text = "0",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.new(0.38, -12, 1, -12),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.Coin,
			ZIndex = 23,
			Parent = frame,
		})
	end
end

local function refreshStats()
	if not data then
		return
	end
	local values = {
		Launches = Format.Commas(data.Stats.Launches),
		BestDistance = Format.Commas(data.BestDistance) .. " studs",
		TotalDistance = Format.Short(data.Stats.TotalDistance) .. " studs",
		TotalSmashes = Format.Commas(data.Stats.TotalSmashes),
		BestCombo = Format.Commas(data.Stats.BestCombo),
		StarsCollected = Format.Commas(data.Stats.StarsCollected),
		TotalCoins = Format.Coins(data.Stats.TotalCoins),
		Rebirths = tostring(data.Rebirths),
	}
	for key, label in statLabels do
		label.Text = values[key] or "0"
	end
end

local function buildSettings()
	local panel, content, close = Widgets.Panel(gui, "⚙️ Settings", Vector2.new(440, 420))
	panels.Settings = panel
	close.Activated:Connect(UI.ClosePanels)
	Widgets.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	for order, key in Config.SettingsOrder do
		local frame = Widgets.new("Frame", {
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = C.PanelDark,
			LayoutOrder = order,
			ZIndex = 22,
			Parent = content,
		})
		Widgets.Corner(frame, 10)
		Widgets.Label({
			Text = Config.SettingLabels[key],
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -150, 1, -16),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = frame,
		})
		local button, label = Widgets.Button({
			Text = "ON",
			Color = C.Green,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(100, 42),
			ZIndex = 23,
			Parent = frame,
		})
		button.Activated:Connect(function()
			if data then
				actions.Setting(key, not data.Settings[key])
			end
		end)
		settingButtons[key] = { Button = button, Label = label }
	end
end

local function refreshSettings()
	if not data then
		return
	end
	for key, entry in settingButtons do
		local on = data.Settings[key] ~= false
		entry.Label.Text = if on then "ON" else "OFF"
		Widgets.SetButtonColor(entry.Button, if on then C.Green else C.Red)
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function UI.Init(playerGui: PlayerGui, callbacks)
	actions = callbacks

	gui = Widgets.new("ScreenGui", {
		Name = "SlingHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})

	buildLobby()
	buildRunHud()
	buildResults()
	buildShop()
	buildRebirth()
	buildStats()
	buildSettings()
	UpgradeTree.Init(gui, function(nodeId)
		actions.BuyUpgrade(nodeId)
	end)

	-- Smoothly count coin labels up/down.
	RunService.RenderStepped:Connect(function(dt)
		local alpha = math.min(1, dt * 10)
		if math.abs(targetRunCoins - displayedRunCoins) > 0.5 then
			displayedRunCoins += (targetRunCoins - displayedRunCoins) * alpha
			refs.RunCoinsLabel.Text = Format.Coins(math.floor(displayedRunCoins + 0.5))
		end
		if math.abs(targetCoins - displayedCoins) > 0.5 then
			displayedCoins += (targetCoins - displayedCoins) * alpha
			refs.Coins.Text = Format.Coins(math.floor(displayedCoins + 0.5))
		end
		if refs.PowerGradient then
			refs.PowerGradient.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.1, 0)
		end
	end)

	UI.SetMode("Lobby")
end

function UI.PowerButton(): TextButton
	return refs.Power
end

function UI.SetData(newData)
	local first = data == nil
	data = newData
	targetCoins = data.Coins
	if first then
		displayedCoins = data.Coins
		refs.Coins.Text = Format.Coins(data.Coins)
	end
	refs.Best.Text = "🏆 BEST " .. Format.Short(data.BestDistance)

	refs.UpgradesBadge.Visible = UpgradeTree.HasAffordable(data)
	refs.RebirthBadge.Visible = data.Coins >= Config.RebirthCost(data.Rebirths)

	UpgradeTree.SetData(data)
	refreshShop()
	refreshRebirth()
	refreshStats()
	refreshSettings()
	UI.RefreshHint()
end

function UI.ClosePanels()
	for name, panel in panels do
		if name ~= "Results" then
			panel.Visible = false
		end
	end
	UpgradeTree.Close()
end

function UI.OpenPanel(name: string)
	if mode ~= "Lobby" and mode ~= "Results" then
		return
	end
	local wasOpen = (name == "Upgrades" and UpgradeTree.IsOpen()) or (panels[name] and panels[name].Visible)
	UI.ClosePanels()
	if wasOpen then
		return
	end
	if name == "Upgrades" then
		UpgradeTree.Open()
	elseif panels[name] then
		panels[name].Visible = true
		Widgets.PopIn(panels[name])
	end
end

function UI.SetMode(newMode: string)
	mode = newMode
	local lobby = newMode == "Lobby"
	local aiming = newMode == "Aiming"
	local flying = newMode == "Flying"
	local results = newMode == "Results"

	refs.TopButtons.Visible = lobby
	refs.SideMenu.Visible = lobby
	refs.Wallet.Visible = true
	refs.RunCoins.Visible = aiming or flying or results
	refs.Distance.Visible = flying or results
	refs.Power.Visible = aiming
	refs.Combo.Visible = false
	panels.Results.Visible = false
	if not lobby then
		UI.ClosePanels()
	end
	UI.RefreshHint()
end

function UI.RefreshHint()
	local showHints = data == nil or data.Settings.Hints ~= false
	refs.Hint.Visible = mode == "Flying" and showHints
	refs.HintLabel.Text = if isTouchOnly() then "USE THE STICK TO STEER" else "A / D TO STEER"
end

-- stateName: "aim" | "charging"
function UI.SetPower(power: number, stateName: string)
	refs.PowerFill.Size = UDim2.fromScale(power, 1)
	refs.PowerPercent.Text = math.floor(power * 100 + 0.5) .. "%"
	if stateName == "charging" then
		refs.PowerStatus.Text = "RELEASE TO LAUNCH!"
	elseif isTouchOnly() then
		refs.PowerStatus.Text = "PRESS & HOLD HERE TO CHARGE"
	else
		refs.PowerStatus.Text = "HOLD CLICK OR SPACE TO CHARGE"
	end
end

function UI.SetRunCoins(value: number, instant: boolean?)
	targetRunCoins = value
	if instant then
		displayedRunCoins = value
		refs.RunCoinsLabel.Text = Format.Coins(value)
	end
end

function UI.SetDistance(value: number)
	refs.DistanceLabel.Text = Format.Commas(value)
end

function UI.SetCombo(multiplier: number, timeFraction: number, visible: boolean)
	local combo = refs.Combo
	if not visible then
		combo.Visible = false
		return
	end
	local text = "x" .. multiplier
	if not combo.Visible or refs.ComboLabel.Text ~= text then
		refs.ComboLabel.Text = text
		combo.Visible = true
		Widgets.PopIn(combo)
	end
	refs.ComboBar.Size = UDim2.fromScale(math.clamp(timeFraction, 0, 1), 1)
end

local popToken = 0
local POP_STYLES = {
	max = { Color3.fromRGB(120, 255, 120), Color3.fromRGB(60, 160, 255) },
	crit = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 80, 40) },
	boost = { Color3.fromRGB(140, 255, 255), Color3.fromRGB(0, 160, 255) },
	best = { Color3.fromRGB(255, 120, 220), Color3.fromRGB(150, 90, 255) },
	combo = { Color3.fromRGB(255, 160, 220), Color3.fromRGB(255, 60, 150) },
}

function UI.Pop(text: string, style: string?)
	popToken += 1
	local token = popToken
	local pop = refs.Pop
	local colors = POP_STYLES[style or "max"] or POP_STYLES.max
	refs.PopGradient.Color = ColorSequence.new(colors[1], colors[2])
	pop.Text = text
	pop.TextTransparency = 0
	pop.Visible = true
	Widgets.PopIn(pop)
	task.delay(0.9, function()
		if token == popToken then
			TweenService:Create(pop, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			task.wait(0.25)
			if token == popToken then
				pop.Visible = false
			end
		end
	end)
end

local bannerToken = 0
function UI.Banner(text: string)
	bannerToken += 1
	local token = bannerToken
	local banner = refs.Banner
	banner.Text = text
	banner.Visible = true
	Widgets.PopIn(banner)
	task.delay(2, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

local toastToken = 0
function UI.Toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	refs.ToastLabel.Text = text
	refs.ToastLabel.TextColor3 = color or C.Text
	refs.Toast.Visible = true
	Widgets.PopIn(refs.Toast)
	task.delay(2.2, function()
		if token == toastToken then
			refs.Toast.Visible = false
		end
	end)
end

function UI.ShowResults(result, comboMultiplier: number)
	local panel = panels.Results
	refs.ResultTitle.Text = if result.NewBest then "NEW BEST!" else "NICE LAUNCH!"
	refs.ResultGradient.Enabled = result.NewBest == true
	refs.ResultTitle.TextColor3 = if result.NewBest then Color3.new(1, 1, 1) else C.Header
	refs.ResultEarned.Text = "⭐ +" .. Format.Commas(result.Earned or 0)
	if result.Failed then
		refs.ResultBreakdown.Text = "Server didn't respond - nothing was saved"
	else
		refs.ResultBreakdown.Text = string.format(
			"Smashing ⭐ %s  •  Distance ⭐ %s",
			Format.Short(result.RunCoins or 0),
			Format.Short(result.DistanceCoins or 0)
		)
	end
	refs.ResultDistance.Text = Format.Commas(result.Distance or 0)
	refs.ResultSmashes.Text = Format.Commas(result.Smashes or 0)
	refs.ResultCombo.Text = "x" .. comboMultiplier
	panel.Visible = true
	Widgets.PopIn(panel)
end

function UI.HideResults()
	panels.Results.Visible = false
end

return UI
