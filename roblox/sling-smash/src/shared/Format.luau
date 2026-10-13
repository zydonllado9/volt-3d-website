--[[
	Number formatting helpers shared by the server and the UI.
]]

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- 7880 -> "7,880"
function Format.Commas(value: number): string
	local whole = math.floor(math.abs(value))
	local digits = tostring(whole)
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return (if value < 0 then "-" else "") .. grouped
end

-- 1400 -> "1.4K", 25000 -> "25K", 999 -> "999"
function Format.Short(value: number): string
	local abs = math.abs(value)
	if abs < 1000 then
		return (if value < 0 then "-" else "") .. tostring(math.floor(abs))
	end
	local index = 0
	while abs >= 1000 and index < #SUFFIXES do
		abs /= 1000
		index += 1
	end
	local text
	if abs >= 100 then
		text = tostring(math.floor(abs))
	else
		text = string.format("%.1f", math.floor(abs * 10) / 10)
		text = text:gsub("%.0$", "")
	end
	return (if value < 0 then "-" else "") .. text .. SUFFIXES[index]
end

-- Uses commas below 100K and the short form above it.
function Format.Coins(value: number): string
	if math.abs(value) < 100000 then
		return Format.Commas(value)
	end
	return Format.Short(value)
end

return Format
