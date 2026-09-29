--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherUtil.lua 783 2008-12-05 08:13:41Z Esamynn $

	License:
	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version 2
	of the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program(see GPL.txt); if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

	Note:
		This AddOn's source code is specifically designed to work with
		World of Warcraft's interpreted AddOn system.
		You have an implicit licence to use this AddOn with these facilities
		since that is it's designated purpose as per:
		http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat

	Utility functions
]]

local Astrolabe = DongleStub(Gatherer.AstrolabeVersion)

function Gatherer.Util.BreakLink(link)

	if (type(link) ~= 'string') then return end
	local i,j, item, name = string.find(link, "|H(.-)|h[[](.-)[]]|h")
	local itype, id, enchant, slot1,slot2,slot3,slot4, random, uniq = strsplit(":", item)
	
	if (random == nil) then
		random, uniq = slot1, slot2
		slot1, slot2, slot3, slot4 = 0, 0, 0, 0
	end
	return
		tonumber(id) or 0,
		tonumber(enchant) or 0,
		tonumber(random) or 0,
		tonumber(slot1) or 0,
		tonumber(slot2) or 0,
		tonumber(slot3) or 0,
		tonumber(slot4) or 0,
		tonumber(uniq) or 0,
		name, itype
end

function Gatherer.Util.ChatPrint(str)
	if ( DEFAULT_CHAT_FRAME ) then
		DEFAULT_CHAT_FRAME:AddMessage(str, 1.0, 0.5, 0.25)
	end
end

local skillTypes = {}
for gatherType, key in pairs({ HERB = "TRADE_HERBALISM", MINE = "TRADE_MINING" }) do
	local skillName = Gatherer.Locale.TrClient(key)
	if ( skillName ) then
		skillTypes[skillName] = gatherType
	end
end

local function ReadSkillRanks()
	local ranks = {}
	for i = 1, GetNumSkillLines() do
		local skillName, header, _, skillRank = GetSkillLineInfo(i)
		local gatherType = not header and skillTypes[skillName]
		if ( gatherType and not ranks[gatherType] ) then
			ranks[gatherType] = skillRank
		end
	end
	for _, gatherType in pairs(skillTypes) do
		if not ( ranks[gatherType] ) then
			return ranks, false
		end
	end
	return ranks, true
end

local checkingSkills = false
local expandedLineCount
local nextExpandTime = 0

function Gatherer.Util.GetSkills()
	if ( checkingSkills ) then return end
	checkingSkills = true

	local ranks, complete = ReadSkillRanks()
	local numLines = GetNumSkillLines()
	if not ( complete or numLines == expandedLineCount ) then
		local collapsed = {}
		for i = 1, numLines do
			local skillName, header, isExpanded = GetSkillLineInfo(i)
			if ( header and not isExpanded ) then
				collapsed[skillName] = true
			end
		end
		if not ( next(collapsed) ) then
			complete = true
		elseif ( GetTime() >= nextExpandTime ) then
			nextExpandTime = GetTime() + 5
			expandedLineCount = numLines
			ExpandSkillHeader(0)
			ranks = ReadSkillRanks()
			for i = GetNumSkillLines(), 1, -1 do
				local skillName, header = GetSkillLineInfo(i)
				if ( header and collapsed[skillName] ) then
					CollapseSkillHeader(i)
				end
			end
			complete = true
		end
	end

	for _, gatherType in pairs(skillTypes) do
		if ( complete or ranks[gatherType] ) then
			Gatherer.Var.Skills[gatherType] = ranks[gatherType]
		end
	end
	checkingSkills = false
	Gatherer.MapNotes.Invalidate()
	Gatherer.MapNotes.MapDraw()
end

local pendingSkillCheck

function Gatherer.Util.QueueSkillCheck()
	if ( pendingSkillCheck ) then
		pendingSkillCheck:Cancel()
	end
	pendingSkillCheck = C_Timer.NewTimer(1, Gatherer.Util.GetSkills)
end

local function GetTrackingMode()
	return Gatherer.Constants.TrackingTextures[GetTrackingTexture()]
end

function Gatherer.Util.IsNodeTracked( nodeId )
	local trackingMode = GetTrackingMode()
	if not ( trackingMode ) then
		return false
	end
	
	local trackType = Gatherer.Nodes.Objects[nodeId]
	
	local category = Gatherer.Categories.ObjectCategories[nodeId]
	trackType = Gatherer.Constants.TrackingOverrides[category] or trackType
	
	return (trackingMode == trackType)
end


local nodeNames = {}
for name, objid in pairs(Gatherer.Nodes.Names) do
	nodeNames[objid] = name
end
function Gatherer.Util.GetNodeName(objectID)
	return Gatherer.Categories.CategoryNames[objectID] or nodeNames[objectID] or ("Unknown: "..objectID)
end

local parseStrings = {}
local parseStringInfo = {}
local returnCache = {}

local function processMatches( format, ... )
	local parseInfo = parseStringInfo[format]
	for i = 1, select("#", ...) do
		if ( parseInfo[i] ) then
			returnCache[i] = select(parseInfo[i], ...)
		else
			returnCache[i] = ""
		end
	end
	return unpack(returnCache, 1, select("#", ...))
end

local function replaceAllBut( char )
	if ( char ~= "$" and char ~= "%" ) then
		return "%"..char
	end
end

function Gatherer.Util.ParseFormattedMessage(format, message)
	local parser = parseStrings[format]
	if not ( parser ) then
		parser = string.gsub(format, "([%p])", replaceAllBut)
		local parseInfo = {}
		local curPos = 0
		local count = 0
		local function analyzeMatch( index, check, type )
			if ( #index > 1 ) then return end
			index = tonumber(index)
			if ( index ) then
				curPos = index
				if ( check ~= "$" ) then
					return
				end
			else
				curPos = curPos + 1
			end
			local replacement
			if ( type == "s" ) then
				replacement = "(.-)"
			elseif ( type == "d" ) then
				replacement = "(-?%d+)"
			else
				return
			end
			count = count + 1
			parseInfo[curPos] = count
			return replacement
		end
		parser = string.gsub(parser, "%%(%d?)(%$?)([sd])", analyzeMatch)
		parseStringInfo[format] = parseInfo
		parser = string.gsub(parser, "%$", "%%$")
		parser = "^"..parser.."$"
		parseStrings[format] = parser
	end
	return processMatches(format, string.match(message, parser))
end

local nodeTextures = {}
local trimmedTextures = {}

function Gatherer.Util.GetNodeTexture( nodeID )
	local texture = nodeTextures[nodeID]
	if not ( texture ) then
		if ( Gatherer.Icons[nodeID] ) then
			texture = "Interface\\AddOns\\Gatherer\\Icons\\"..Gatherer.Icons[nodeID]
		else
			local prime = Gatherer.DropRates.GetPrimaryItem(nodeID)
			texture = prime and select(10, GetItemInfo(prime))
			if not ( texture ) then
				return "Interface\\AddOns\\Gatherer\\Shaded\\Red", false
			end
			trimmedTextures[nodeID] = true
		end
		nodeTextures[nodeID] = texture
	end
	return texture, trimmedTextures[nodeID] or false
end

Gatherer.Util.ZoneNames = {GetMapContinents()}
for index, cname in pairs(Gatherer.Util.ZoneNames) do
	local zones = {GetMapZones(index)}
	Gatherer.Util.ZoneNames[index] = zones
	for index, name in ipairs(zones) do
		zones[name] = index
	end
	zones[0] = cname
end

local function FindZoneByName( zoneName )
	for continent, zones in pairs(Gatherer.Util.ZoneNames) do
		local zone = zones[zoneName]
		if ( zone ) then
			return continent, zone
		end
	end
end

local GetAreaNameByID = C_Map and C_Map.GetAreaNameByID
for continent, info in pairs({
	[12] = { name = "Sirus", { 919, "Остров Погоды" }, { 907, "Остров Форбс" } },
	[13] = { name = "Sirus (Гилнеас)", { 909, "Серебряный бор (Гилнеас)" } },
}) do
	if not ( Gatherer.Util.ZoneNames[continent] ) then
		local zones = { [0] = info.name }
		Gatherer.Util.ZoneNames[continent] = zones
		for index, area in ipairs(info) do
			local zoneName = GetAreaNameByID and GetAreaNameByID(area[1])
			if ( not zoneName or zoneName == "" or FindZoneByName(zoneName) ) then
				zoneName = area[2]
			end
			zones[index] = zoneName
			zones[zoneName] = index
		end
	end
end

function Gatherer.Util.GetPositionInCurrentZone()
	local continent, zone = FindZoneByName(GetRealZoneText())
	local c, z, px, py
	if not ( zone ) then
		return Astrolabe:GetCurrentPlayerPosition()
	else
		c, z, px, py = Astrolabe:GetCurrentPlayerPosition()
	end
	if not ( c and z ) then
		return
	end
	local tx, ty = Astrolabe:TranslateWorldMapPosition(c, z, px, py, continent, zone)
	if not ( tx and ty ) then
		return c, z, px, py
	end
	return continent, zone, tx, ty
end

function Gatherer.Util.GetWorldMapZone()
	local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
	if ( (continent or 0) <= 0 or (zone or 0) <= 0 ) then
		local mapFile = GetMapInfo()
		for c, zoneFiles in pairs(Astrolabe.ContinentList) do
			for z, fileName in pairs(zoneFiles) do
				if ( fileName == mapFile ) then
					return c, z
				end
			end
		end
	end
	return continent, zone
end

function Gatherer.Util.ZoneDistance( continent, zone, x1, y1, x2, y2 )
	local dist = Astrolabe:ComputeDistance(continent, zone, x1, y1, continent, zone, x2, y2)
	if not ( dist and dist > 0 ) then
		local dx, dy = x2 - x1, y2 - y1
		dist = math.sqrt(dx*dx + dy*dy) * 3500
	end
	return dist
end


function Gatherer.Util.SecondsToTime(seconds, noSeconds)
	local time = ""
	local count = 0
	local GetText = Gatherer.Locale.GetText
	seconds = floor(seconds)
	if ( seconds >= 604800 ) then
		local tempTime = floor(seconds / 604800)
		time = tempTime.." "..GetText("WEEKS_ABBR", tempTime).." "
		seconds = (seconds % 604800)
		count = count + 1
	end
	if ( seconds >= 86400  ) then
		local tempTime = floor(seconds / 86400)
		time = time..tempTime.." "..GetText("DAYS_ABBR", tempTime).." "
		seconds = (seconds % 86400)
		count = count + 1
	end
	if ( count < 2 and seconds >= 3600  ) then
		local tempTime = floor(seconds / 3600)
		time = time..tempTime.." "..GetText("HOURS_ABBR", tempTime).." "
		seconds = (seconds % 3600)
		count = count + 1
	end
	if ( count < 2 and seconds >= 60  ) then
		local tempTime = floor(seconds / 60)
		time = time..tempTime.." "..GetText("MINUTES_ABBR",tempTime).." "
		seconds = (seconds % 60)
		count = count + 1
	end
	if ( count < 2 and seconds > 0 and not noSeconds ) then
		time = time..seconds.." "..GetText("SECONDS_ABBR", seconds).." "
	end
	return time
end
