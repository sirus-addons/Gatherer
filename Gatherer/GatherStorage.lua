--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherStorage.lua 786 2008-12-08 20:50:59Z Esamynn $

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

	Library for accessing and updating the database
--]]

local POS_X = 1
local POS_Y = 2
local COUNT = 3
local HARVESTED = 4
local INSPECTED = 5
local SOURCE = 6

local dbVersion = 3

local globalName = "GatherItems"
local data

local corruptData = false

local lib = Gatherer.Storage
lib.ChangeCount = 0

local validGatherTypes = {
	MINE = "MINE",
	HERB = "HERB",
	OPEN = "OPEN",
}
function lib.AddNode(nodeName, gatherType, continent, zone, gatherX, gatherY, source, incrementCount)
	if not (continent and zone and gatherX and gatherY) then return end
	local zoneToken = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	zone = Gatherer.ZoneTokens.GetZoneIndex(continent, zone)
	
	if not ( (continent > 0) and zoneToken and (gatherX > 0) and (gatherY > 0) ) then return end
	
	local gatherType = validGatherTypes[gatherType]

	if not (data[continent]) then data[continent] = { }; end
	if not (data[continent][zoneToken]) then data[continent][zoneToken] = { }; end
	if not (data[continent][zoneToken][nodeName]) then data[continent][zoneToken][nodeName] = { gtype = gatherType }; end
	local gatherTable = data[continent][zoneToken][nodeName]

	if not ( gatherType ) then
		gatherType = Gatherer.Nodes.Objects[nodeName]
	end
	if not ( gatherTable.gtype ) then
		gatherTable.gtype = gatherType
	end

	local matchDist = 10
	local isImport = false
	if source and source:sub(1,3) == "DB:" then
		matchDist = 25
		isImport = true
	elseif source == "REQUIRE" then
		matchDist = 15
	end
	
	local index, node

	for i, gatherData in ipairs(gatherTable) do
		local dist = Gatherer.Util.ZoneDistance(continent, zone, gatherX, gatherY, gatherData[POS_X], gatherData[POS_Y])
		if ( dist < matchDist ) then
			node = gatherData
			index = i
			break
		end
	end

	if node then

		if isImport then return end

		local count = node[COUNT]

		gatherX = (gatherX + (node[POS_X] * count)) / (count + 1)
		gatherY = (gatherY + (node[POS_Y] * count)) / (count + 1)
		
		local nodeSource = node[SOURCE]
		if ( nodeSource ) then
			if ( source ) then
				if ( (source == "IMPORTED" or nodeSource == "IMPORTED") and nodeSource ~= source ) then
					node[SOURCE] = nil
				elseif ( (source == "REQUIRE" or nodeSource == "REQUIRE") and nodeSource ~= source ) then
					node[SOURCE] = nil
				elseif not ( (","..nodeSource..","):find(","..source..",", 1, true) ) then
					node[SOURCE] = nodeSource..","..source
				end
			else
				node[SOURCE] = nil
			end
		end

	else
		node = { 0, 0, 0, 0, 0, source }
		table.insert(gatherTable, node)
		index = table.getn(gatherTable)
	end
	
	node[POS_X] = gatherX
	node[POS_Y] = gatherY
	if ( incrementCount ) then
		node[COUNT] = node[COUNT] + 1
	end

	local now = time()

	node[HARVESTED] = now
	if (not node[SOURCE]) then
		node[INSPECTED] = now
	end

	lib.ChangeCount = lib.ChangeCount + 1
	Gatherer.Report.NeedsUpdate()

	return index
end

function lib.ClearDatabase()
	data = { dbVersion = dbVersion }
	collectgarbage("collect");
	lib.ChangeCount = lib.ChangeCount + 1
	Gatherer.Report.NeedsUpdate()
end

local function removeNode( gatherData, index, playerName )
	local remove = true
	if ( playerName ) then
		local nodeData = gatherData[index]
		local source = nodeData[SOURCE]
		if ( source and source:find(",", 1, true) ) then
			local kept = {}
			for _, name in ipairs({ strsplit(",", source) }) do
				if ( name ~= playerName ) then
					kept[#kept + 1] = name
				end
			end
			if ( kept[1] ) then
				remove = false
				nodeData[SOURCE] = table.concat(kept, ",")
			end
		elseif ( source ~= playerName ) then
			remove = false
		
		end
	end
	if ( remove ) then
		table.remove(gatherData, index)
	end

	lib.ChangeCount = lib.ChangeCount + 1
	Gatherer.Report.NeedsUpdate()

	return remove
end

function lib.RemoveNode( continent, zone, gatherId, index, playerName )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.IsGatherInZone(continent, zone, gatherId) ) then
		local gatherData = data[continent][zone][gatherId]
		if ( gatherData[index] ) then
			local result = removeNode(gatherData, index, playerName)
			if not ( gatherData[1] ) then
				lib.RemoveGather(continent, zone, gatherId)
			end
			return result
		end
	end
end

function lib.RemoveGather( continent, zone, gatherId, playerName )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.IsGatherInZone(continent, zone, gatherId) ) then
		if ( playerName ) then
			local gatherData = data[continent][zone][gatherId]
			local numNodes = #gatherData
			for i = numNodes, 1, -1 do
				removeNode(gatherData, i, playerName)
			end
			if ( gatherData[1] ) then
				if ( numNodes > #gatherData ) then
					return 1, (numNodes - #gatherData)
				else
					return -1, 0
				end
			else
				lib.RemoveGather(continent, zone, gatherId)
				return 0, numNodes
			end
		
		else
			local numGathers = #(data[continent][zone][gatherId])
			data[continent][zone][gatherId] = nil
			if not ( next(data[continent][zone]) ) then
				data[continent][zone] = nil
			end
			if not ( next(data[continent]) ) then
				data[continent] = nil
			end
			return 0, numGathers
		
		end
	end
	return -2, 0
end

function lib.HasDataOnZone( continent, zone )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.HasDataOnContinent(continent) and data[continent][zone] ) then
		return true
	else
		return false
	end
end

function lib.HasDataOnContinent( continent )
	if ( data[continent] ) then
		return true
	else
		return false
	end
end

function lib.IsGatherInZone( continent, zone, gatherName )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.HasDataOnZone(continent, zone) and data[continent][zone][gatherName] ) then
		return true
	else
		return false
	end
end

function lib.GetGatherCountsForZone( continent, zone, gatherName )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( data[continent] and data[continent][zone] and data[continent][zone][gatherName] ) then
		return table.getn(data[continent][zone][gatherName])
	else
		return 0
	end
end

local nodeCountsByType = { OPEN=0, HERB=0, MINE=0, unknown=0, }

function lib.GetNodeCountsByGatherType( continent, zone )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	for k, v in pairs(nodeCountsByType) do
		nodeCountsByType[k] = 0
	end

	if ( lib.HasDataOnZone(continent, zone) ) then
		for gather, nodes in pairs(data[continent][zone]) do
			local gtype = nodes.gtype
			if ( nodeCountsByType[gtype] ) then
				nodeCountsByType[gtype] = nodeCountsByType[gtype] + table.getn(nodes)
			else
				nodeCountsByType.unknown = nodeCountsByType.unknown + table.getn(nodes)
			end
		end
	end
	return nodeCountsByType.OPEN,
	       nodeCountsByType.HERB,
	       nodeCountsByType.MINE,
	       nodeCountsByType.unknown
end

function lib.GetNodeInfo( continent, zone, gatherName, index )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.IsGatherInZone(continent, zone, gatherName) ) then
		local info = data[continent][zone][gatherName][index]
		if ( info ) then
			return info[POS_X],
			       info[POS_Y],
			       info[COUNT],
			       data[continent][zone][gatherName].gtype,
			       info[HARVESTED] or 0,
			       info[INSPECTED] or 0,
			       info[SOURCE]
		end
	end
end

function lib.SetNodeInspected( continent, zone, nodeid, index )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.IsGatherInZone(continent, zone, nodeid) ) then
		local node = data[continent][zone][nodeid][index]
		if ( node ) then
			node[INSPECTED] = time()
		end
	end
end

function lib.GetNodeInspected( continent, zone, nodeid, index )
	zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	if ( lib.IsGatherInZone(continent, zone, nodeid) ) then
		local node = data[continent][zone][nodeid][index]
		if ( node ) then
			return node[INSPECTED]
		end
	end
end

local EmptyIterator = function() end

local iteratorStateTables = {}
setmetatable(iteratorStateTables, { __mode = "k" });

local workTableCache = { {}, {}, {}, {}, };

local function getWorkTablePair()
	if ( table.getn(workTableCache) < 2 ) then
		table.insert(workTableCache, {})
		table.insert(workTableCache, {})
	end
	local index = table.remove(workTableCache)
	local state = table.remove(workTableCache)
	iteratorStateTables[index] = state
	return index, state
end

local function releaseWorkTablePair( index )
	local data = iteratorStateTables[index]
	if ( data ) then
		iteratorStateTables[index] = nil
		for k, v in pairs(index) do
			index[k] = nil
		end
		for k, v in pairs(data) do
			data[k] = nil
		end
		table.insert(workTableCache, index)
		table.insert(workTableCache, data)
	end
end

local function getWorkTable()
	if ( table.getn(workTableCache) < 1 ) then
		table.insert(workTableCache, {})
	end
	local workTable = table.remove(workTableCache)
	iteratorStateTables[workTable] = false
	return workTable
end

local function releaseWorkTable( workTable )
	if ( iteratorStateTables[workTable] == false ) then
		iteratorStateTables[workTable] = nil
		for k, v in pairs(workTable) do
			workTable[k] = nil
		end
		table.insert(workTableCache, workTable)
	end
end

do

	local function iterator( iteratorData, lastIndex )
		if not ( iteratorData and lastIndex ) then return end

		lastIndex = lastIndex + 1
		if ( iteratorData[lastIndex] ) then
			return lastIndex, iteratorData[lastIndex]
		else
			releaseWorkTable(iteratorData)
			return;
		end
	end


	function lib.GetAreaIndices( continent )
		local dataTable

		if ( continent and lib.HasDataOnContinent(continent) ) then
			dataTable = data[continent]
		else
			dataTable = data
		end
		if not ( dataTable ) then return EmptyIterator; end
		
		local iteratorData = getWorkTable()
		if ( continent ) then
			local GetZoneIndex = Gatherer.ZoneTokens.GetZoneIndex
			for i in pairs(dataTable) do
				if ( lib.HasDataOnZone(continent,i) ) then
					tinsert(iteratorData, GetZoneIndex(continent, i))
				end
			end
		else
			for i in pairs(dataTable) do
				if (type(i) == "number") and (lib.HasDataOnContinent(i)) then
					tinsert(iteratorData, i)
				end
			end
		end
		table.sort(iteratorData)
		return iterator, iteratorData, 0
	end

end

do

	local function iterator( stateIndex, lastGatherName )
		local state = iteratorStateTables[stateIndex]
		if not ( state ) then return end;

		local gatherName, gatherNodesTable = next(state.table, lastGatherName)
		if not ( gatherName ) then
			releaseWorkTablePair(stateIndex)
			return;
		end
		local gtype = gatherNodesTable.gtype
		return gatherName, gtype, table.getn(gatherNodesTable)
	end


	function lib.ZoneGatherNames( continent, zone )
		zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
		if ( lib.HasDataOnZone(continent, zone) ) then
			local stateIndex, state = getWorkTablePair()
			state.table = data[continent][zone]

			return iterator, stateIndex, nil
		end
		return EmptyIterator
	end

end

do

	local function iterator( stateIndex, lastNodeIndex )
		local state = iteratorStateTables[stateIndex]
		if not ( state ) then return end;

		local nodeIndex, info = state.iterator(state.stateInfo, lastNodeIndex)
		if not ( info ) then
			releaseWorkTablePair(stateIndex)
			return;
		end
		return nodeIndex, info[POS_X], info[POS_Y], info[COUNT], info[HARVESTED], info[INSPECTED], info[SOURCE]
	end


	function lib.ZoneGatherNodes( continent, zone, gatherName )
		zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
		if ( lib.IsGatherInZone(continent, zone, gatherName) ) then
			local stateIndex, state = getWorkTablePair()
			state.iterator, state.stateInfo = ipairs(data[continent][zone][gatherName])

			return iterator, stateIndex, 0
		end
		return EmptyIterator
	end

end

do

	local function iterator( iteratorData, lastIndex )
		if not ( iteratorData and lastIndex ) then return end

		lastIndex = lastIndex + 1
		local nodeIndex = lastIndex * 3
		if ( iteratorData[nodeIndex] ) then
			return lastIndex,
			       iteratorData.continent,
			       iteratorData.zone,
			       iteratorData[nodeIndex - 2],
			       iteratorData[nodeIndex - 1],
			       iteratorData[nodeIndex]
		else
			releaseWorkTable(iteratorData)
			return;
		end
	end

	local nodeNames = {}
	local nodeIndex = {}
	local distances = {}
	local order = {}

	local function byDistance( a, b )
		return distances[a] < distances[b]
	end

	function lib.ClosestNodes( continent, zone, xPos, yPos, num, maxDist, filter )
		local zoneToken = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
		if not ( lib.HasDataOnZone(continent, zone) and xPos > 0 and yPos > 0 ) then
			return EmptyIterator
		end

		local iteratorData = getWorkTable()
		iteratorData.continent = continent
		iteratorData.zone = zone

		if ( type(filter) == "function" ) then

		elseif ( type(filter) == "table" ) then
			local filterTable = filter
			filter = (
				function( nodeId, gatherType )
					if not ( filterTable[gatherType] ) then
						return false

					elseif ( filterTable[gatherType] == true ) then
						return true

					else
						return filterTable[gatherType][nodeId]

					end
				end
			)

		elseif ( filter == nil or filter ) then
			filter = true

		else
			return EmptyIterator

		end

		local count = 0
		local zoneData = data[continent][zoneToken]
		for gatherName, nodesList in pairs(zoneData) do
			if ( (filter == true) or filter(gatherName, nodesList.gtype) ) then
				for index, nodeData in ipairs(nodesList) do
					local nodeX, nodeY = nodeData[POS_X], nodeData[POS_Y]
					if ( (nodeX ~= 0) and (nodeY ~= 0) ) then
						local dist = Gatherer.Util.ZoneDistance(continent, zone, xPos, yPos, nodeX, nodeY)
						if ( (maxDist == 0) or (dist < maxDist) ) then
							count = count + 1
							nodeNames[count] = gatherName
							nodeIndex[count] = index
							distances[count] = dist
							order[count] = count
						end
					end
				end
			end
		end

		for i = count + 1, #order do
			order[i] = nil
			nodeNames[i] = nil
			nodeIndex[i] = nil
			distances[i] = nil
		end
		table.sort(order, byDistance)

		for i = 1, math.min(num, count) do
			local k = order[i]
			tinsert(iteratorData, nodeNames[k])
			tinsert(iteratorData, nodeIndex[k])
			tinsert(iteratorData, math.floor(distances[k]*100)/100)
		end

		return iterator, iteratorData, 0
	end

end

do

	local function iterator( iteratorData, lastIndex )
		if not ( iteratorData and lastIndex ) then return end

		lastIndex = lastIndex + 1
		local nodeIndex = lastIndex * 3
		if ( iteratorData[nodeIndex] ) then
			local continent, zone, nodeName, index, dist = iteratorData.continent, iteratorData.zone, iteratorData[nodeIndex - 2], iteratorData[nodeIndex - 1], iteratorData[nodeIndex]

			return lastIndex, continent, zone, nodeName, index, dist, lib.GetNodeInfo(continent, zone, nodeName, index)
		else
			releaseWorkTable(iteratorData)
			return;
		end
	end


	function lib.ClosestNodesInfo( continent, zone, xPos, yPos, num, maxDist, filter )
		local f, iteratorData, var = lib.ClosestNodes(continent, zone, xPos, yPos, num, maxDist, filter)

		if ( f == EmptyIterator ) then
			return f
		else
			return iterator, iteratorData, var
		end
	end

end

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame.UnregisterEvent = function() end

eventFrame:SetScript("OnEvent", function( frame, event, arg1 )
	if ( event == "ADDON_LOADED" and strlower(arg1) == "gatherer" ) then
		local savedData = getglobal(globalName)
		if ( savedData ) then
			getfenv(0)[globalName] = nil
			if ( savedData.dbVersion == nil ) then
				savedData.dbVersion = 0
			end
			if ( type(savedData.dbVersion) == "number" ) then
				if ( dbVersion == savedData.dbVersion ) then
					data = savedData
					
					local needImport = false
					local dataToImport = { dbVersion = dbVersion }
					
					local checkToken = Gatherer.ZoneTokens.GetTokenFromFileName
					for continent, contData in pairs(data) do
						if ( type(contData) == "table" ) then
							for zoneToken, zoneData in pairs(contData) do
								local token = checkToken(continent, zoneToken)
								if ( token and token ~= zoneToken ) then
									needImport = true
									if not (dataToImport[continent]) then dataToImport[continent] = { }; end
									dataToImport[continent][token] = data[continent][zoneToken]
									data[continent][zoneToken] = nil
								end
							end
						end
					end
					
					if ( Gatherer.Nodes.ReMappings ) then
						local remap = Gatherer.Nodes.ReMappings
						for continent, contData in pairs(data) do
							if ( type(contData)=="table" and type(continent)=="number" ) then
								for zoneToken, zoneData in pairs(contData) do
									for nodeId, nodes in pairs(zoneData) do
										if ( remap[nodeId] ) then
											needImport = true
											if not (dataToImport[continent]) then dataToImport[continent] = { }; end
											if not (dataToImport[continent][zoneToken]) then dataToImport[continent][zoneToken] = { }; end
											dataToImport[continent][zoneToken][nodeId] = nodes
											data[continent][zoneToken][nodeId] = nil
										end
									end
								end
							end
						end
					end
					
					if ( needImport ) then
						lib.ImportDatabase(dataToImport)
					end
					
				else
					lib.ClearDatabase()
					data.setAsideDatabases = savedData.setAsideDatabases or {}
					savedData.setAsideDatabases = nil
					table.insert(data.setAsideDatabases, savedData)
					StaticPopup_Show("GATHERER_DATABASE_TOO_NEW")
				
				end
			else
				StaticPopup_Show("GATHERER_INVALID_DATABASE_VERSION")
				getfenv(0)[globalName] = savedData
				corruptData = true
				lib.ClearDatabase()
			end
		else
			lib.ClearDatabase();
		end

	elseif ( event == "PLAYER_LOGIN" ) then
		local validObjects = Gatherer.Nodes.Objects
		for continent, contData in pairs(data) do
			if ( type(contData)=="table" and type(continent)=="number" ) then
				for zoneToken, zoneData in pairs(contData) do
					for nodeId in pairs(zoneData) do
						if not ( validObjects[nodeId] ) then
							zoneData[nodeId] = nil
						end
					end
					if not ( next(zoneData) ) then
						contData[zoneToken] = nil
					end
				end
				if not ( next(contData) ) then
					data[continent] = nil
				end
			end
		end

	elseif ( event == "PLAYER_LOGOUT" ) then
		if not ( corruptData ) then
			getfenv(0)[globalName] = data
		end

	end
end)
eventFrame.SetScript = function() end

local workingTable = {}
local function processImportedSourceField( ... )
	for k in pairs(workingTable) do
		workingTable[k] = nil
	end
	local hasName, imported, require
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if ( name == "REQUIRE" ) then
			require = true
		elseif ( name == "IMPORTED" ) then
			imported = true
		else
			hasName = true
			workingTable[name] = true
		end
	end
	if ( (hasName and imported) or (hasName and require) or (require and imported) ) then
		return nil
	else
		local nameList = ""
		for name in pairs(workingTable) do
			nameList = nameList..","..name
		end
		return nameList:sub(2)
	end
end

local function MergeNode(gather, gatherType, continent, zone, gatherX, gatherY, count, harvested, inspected, source)
	if not ( gather and gatherType and continent and zone and gatherX and gatherY ) then
		return
	end
	local index = lib.AddNode(gather, gatherType, continent, zone, gatherX, gatherY, (source or "IMPORTED"), false)
	if not ( index ) then return end
	local zone = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	local node = data[continent][zone][gather][index]
	if ( count ) then
		node[COUNT] = node[COUNT] + count
	end
	if ( harvested ) then
		node[HARVESTED] = harvested
	else
		node[HARVESTED] = 0
	end
	if ( inspected ) then
		node[INSPECTED] = inspected
	else
		node[INSPECTED] = 0
	end
	if ( node[SOURCE] and node[SOURCE] ~= "IMPORTED" and node[SOURCE] ~= "REQUIRE" ) then
		node[SOURCE] = processImportedSourceField(string.split(",", node[SOURCE]))
	end
end

function lib.ImportDatabase( database )
	if not ( data ) then
		lib.ClearDatabase();
	end
	Gatherer.Convert.ImportDatabase(database, MergeNode)
end

local _trL = Gatherer.Locale.TrLocale

StaticPopupDialogs["GATHERER_INVALID_DATABASE_VERSION"] = {
	text = _trL("WARNING!!!\nGatherer has detected that your database version is invalid.  Please press accept to clear your database, or select ignore if you want to try to repair your database manually."),
	button1 = _trL("ACCEPT"),
	button2 = _trL("IGNORE"),
	OnAccept = function()
		corruptData = false
	end,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["GATHERER_DATABASE_TOO_NEW"] = {
	text = _trL("Your saved Gatherer database is too new.  Your current database has been set aside until you upgrade Gatherer.  "),
	button1 = _trL("OK"),
	timeout = 0,
	whileDead = 1,
}
