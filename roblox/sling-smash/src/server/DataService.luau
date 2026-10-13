--[[
	Loads, caches and saves player data with DataStoreService.

	In an unpublished place (or with Studio API access turned off) DataStores are
	unavailable; the game still works, progress just isn't saved between sessions.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local profiles = {} -- [Player] = data table
local canSave = {} -- [Player] = boolean
local changedCallbacks = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[SlingSmash] DataStores unavailable, progress will not save:", result)
	end
end

local function defaultData()
	local settings = {}
	for key, value in Config.DefaultSettings do
		settings[key] = value
	end
	return {
		Coins = 0,
		BestDistance = 0,
		Rebirths = 0,
		Upgrades = {},
		Trails = { None = true },
		EquippedTrail = "None",
		Settings = settings,
		Stats = {
			Launches = 0,
			TotalSmashes = 0,
			TotalCoins = 0,
			TotalDistance = 0,
			BestCombo = 0,
			StarsCollected = 0,
		},
	}
end

-- Fills in any keys missing from saved data (e.g. after adding new features).
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			if type(value) == "table" then
				local copy = {}
				reconcile(copy, value)
				target[key] = copy
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
	if not coins then
		local value = Instance.new("IntValue")
		value.Name = "Coins"
		value.Parent = leaderstats
		coins = value
	end
	local best = leaderstats:FindFirstChild("Best") :: IntValue?
	if not best then
		local value = Instance.new("IntValue")
		value.Name = "Best"
		value.Parent = leaderstats
		best = value
	end
	if coins then
		coins.Value = math.floor(data.Coins)
	end
	if best then
		best.Value = math.floor(data.BestDistance)
	end
end

function DataService.Load(player: Player)
	local data = nil
	local loaded = false

	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			local message = tostring(result)
			if message:find("StudioAccessToApisNotAllowed") or message:find("publish") or message:find("403") then
				-- Unpublished place / API access disabled: stop trying for everyone.
				warn("[SlingSmash] DataStores are disabled here, progress will not save. " .. message)
				store = nil
				break
			end
			warn(string.format("[SlingSmash] Load attempt %d failed for %s: %s", attempt, player.Name, message))
			task.wait(1.5)
		end
	end

	if type(data) ~= "table" then
		data = defaultData()
	else
		reconcile(data, defaultData())
	end

	-- Only save if we actually read the store; never overwrite real data with defaults.
	canSave[player] = store ~= nil and loaded

	if player.Parent ~= Players then
		return nil
	end

	profiles[player] = data
	updateLeaderstats(player, data)
	DataService.Changed(player)
	return data
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 20)
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.OnChanged(callback)
	table.insert(changedCallbacks, callback)
end

-- Call after mutating a player's data so the client and leaderstats update.
function DataService.Changed(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	updateLeaderstats(player, data)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, data)
	end
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not store or not canSave[player] then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[SlingSmash] Save failed for", player.Name, err)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	canSave[player] = nil
end

-- Saves every loaded profile in parallel and yields until all are done.
function DataService.SaveAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.Save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

return DataService
