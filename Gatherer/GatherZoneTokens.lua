--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherZoneTokens.lua 869 2009-08-05 19:54:12Z Esamynn $

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

	Functions for converting to and from the locale independent zone tokens
--]]

local Astrolabe = DongleStub(Gatherer.AstrolabeVersion)

local metatable = { __index = getfenv(0) }
setmetatable( Gatherer.ZoneTokens, metatable )
setfenv(1, Gatherer.ZoneTokens)

local FileNameToTokenMap = {
	[1] = {
		["Ashenvale"] = "ASHENVALE",
		["Aszhara"] = "AZSHARA",
		["AzuremystIsle"] = "AZUREMYST_ISLE",
		["Barrens"] = "BARRENS",
		["BloodmystIsle"] = "BLOODMYST_ISLE",
		["Darkshore"] = "DARKSHORE",
		["Darnassis"] = "DARNASSUS",
		["Desolace"] = "DESOLACE",
		["Durotar"] = "DUROTAR",
		["Dustwallow"] = "DUSTWALLOW_MARSH",
		["Felwood"] = "FELWOOD",
		["Feralas"] = "FERALAS",
		["Moonglade"] = "MOONGLADE",
		["Mulgore"] = "MULGORE",
		["Ogrimmar"] = "ORGRIMMAR",
		["Silithus"] = "SILITHUS",
		["StonetalonMountains"] = "STONETALON_MOUNTAINS",
		["Tanaris"] = "TANARIS",
		["Teldrassil"] = "TELDRASSIL",
		["TheExodar"] = "EXODAR",
		["ThousandNeedles"] = "THOUSAND_NEEDLES",
		["ThunderBluff"] = "THUNDER_BLUFF",
		["UngoroCrater"] = "UNGORO_CRATER",
		["Winterspring"] = "WINTERSPRING",
	},
	[2] = {
		["Alterac"] = "ALTERAC_MOUNTAINS",
		["Arathi"] = "ARATHI_HIGHLANDS",
		["Badlands"] = "BADLANDS",
		["BlastedLands"] = "BLASTED_LANDS",
		["BurningSteppes"] = "BURNING_STEPPES",
		["DeadwindPass"] = "DEADWIND_PASS",
		["DunMorogh"] = "DUN_MOROGH",
		["Duskwood"] = "DUSKWOOD",
		["EasternPlaguelands"] = "EASTERN_PLAGUELANDS",
		["Elwynn"] = "ELWYNN_FOREST",
		["EversongWoods"] = "EVERSONG_WOODS",
		["Ghostlands"] = "GHOSTLANDS",
		["Hilsbrad"] = "HILLSBRAD_FOOTHILLS",
		["Hinterlands"] = "HINTERLANDS",
		["Ironforge"] = "IRONFORGE",
		["LochModan"] = "LOCH_MODAN",
		["Redridge"] = "REDRIDGE_MOUNTAINS",
		["SearingGorge"] = "SEARING_GORGE",
		["SilvermoonCity"] = "SILVERMOON",
		["Silverpine"] = "SILVERPINE_FOREST",
		["Stormwind"] = "STORMWIND",
		["Stranglethorn"] = "STRANGLETHORN_VALE",
		["Sunwell"] = "QUEL_DANAS",
		["SwampOfSorrows"] = "SWAMP_OF_SORROWS",
		["Tirisfal"] = "TIRISFAL_GLADES",
		["Undercity"] = "UNDERCITY",
		["WesternPlaguelands"] = "WESTERN_PLAGUELANDS",
		["Westfall"] = "WESTFALL",
		["Wetlands"] = "WETLANDS",
	},
	[3] = {
		["BladesEdgeMountains"] = "BLADES_EDGE_MOUNTAINS",
		["Hellfire"] = "HELLFIRE_PENINSULA",
		["Nagrand"] = "NAGRAND",
		["Netherstorm"] = "NETHERSTORM",
		["ShadowmoonValley"] = "SHADOWMOON_VALLEY",
		["ShattrathCity"] = "SHATTRATH",
		["TerokkarForest"] = "TEROKKAR_FOREST",
		["Zangarmarsh"] = "ZANGARMARSH",
	},
	[4] = {
		["BoreanTundra"] = "BOREAN_TUNDRA",
		["CrystalsongForest"] = "CRYSTALSONG_FOREST",
		["Dalaran"] = "DALARAN", 
		["Dragonblight"] = "DRAGONBLIGHT",
		["GrizzlyHills"] = "GRIZZLY_HILLS",
		["HrothgarsLanding"] = "HROTHGARS_LANDING",
		["HowlingFjord"] = "HOWLING_FJORD",
		["IcecrownGlacier"] = "ICECROWN_GLACIER",
		["SholazarBasin"] = "SHOLAZAR_BASIN",
		["TheStormPeaks"] = "STORM_PEAKS",
		["LakeWintergrasp"] = "LAKE_WINTERGRASP",
		["ZulDrak"] = "ZULDRAK",
	},
	[12] = {
		["PRIME"] = "PRIME",
		["VIP"] = "VIP",
	},
	[13] = {
		["GilneasSilverpineForest"] = "GilneasSilverpineForest",
	},
}

Tokens = {}

local unrecognizedZones = {}

for continent, zones in pairs(Astrolabe.ContinentList) do
	local fileTokenMap = FileNameToTokenMap[continent];
	local tokenMap = {}
	for index, mapName in pairs(zones) do
		if not ( fileTokenMap and fileTokenMap[mapName] ) then
			tokenMap[index] = mapName;
			tokenMap[mapName] = index
			table.insert(unrecognizedZones, (select(index, GetMapZones(continent))))
		else
			tokenMap[index] = fileTokenMap[mapName];
			tokenMap[fileTokenMap[mapName]] = index;
		end
	end
	Tokens[continent] = tokenMap
end

if ( next(unrecognizedZones) ) then
	local zoneList = string.join(", ", unpack(unrecognizedZones))
	Gatherer.Var.UnknownZones = zoneList
end
unrecognizedZones = nil


function GetZoneToken( continent, zone )
	if not ( Tokens[continent] ) then
		return nil
	end
	local val = Tokens[continent][zone]
	if ( val ) then
		if ( type(zone) == "number" ) then
			return val
		else
			return zone
		end
	end
end

function GetZoneIndex( continent, token )
	if not ( Tokens[continent] ) then
		return nil
	end
	local val = Tokens[continent][token]
	if ( val ) then
		if ( type(token) == "string" ) then
			return val
		else
			return token
		end
	end
end

function GetTokenFromFileName( continent, fileName )
	if ( FileNameToTokenMap[continent] ) then
		return FileNameToTokenMap[continent][fileName]
	else
		for i, contData in pairs(FileNameToTokenMap) do
			if ( contData[fileName] ) then
				return contData[fileName]
			end
		end
	end
end
