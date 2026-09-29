--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherDropRates.lua 798 2009-02-03 23:48:25Z Esamynn $

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
]]

local dbVersion = 2

function Gatherer.DropRates.Load()
	local data = Gatherer_DropRates
	
	if ( type(data) ~= "table" or dbVersion ~= data.dbVersion ) then
		data = { dbVersion = dbVersion }
	end
	
	Gatherer.DropRates.Data = data
end

function Gatherer.DropRates.Save()
	Gatherer_DropRates = Gatherer.DropRates.Data
end

function Gatherer.DropRates.ProcessDrops( objectId, continent, zone, source, coins, loot )
	if not ( loot ) then return end
	local zoneToken = Gatherer.ZoneTokens.GetZoneToken(continent, zone)
	local data = Gatherer.DropRates.Data
	
	if not (data[continent]) then data[continent] = { } end
	if not (data[continent][zoneToken]) then data[continent][zoneToken] = { } end
	if not (data[continent][zoneToken][objectId]) then data[continent][zoneToken][objectId] = { total = 0 } end
	data = data[continent][zoneToken][objectId]
	
	local foundItem = false
	for pos, loot in ipairs(loot) do
		local id = loot.id
		if (not id and loot.link) then
			id = Gatherer.Util.BreakLink(loot.link)
		end
		if ( id ) then
			local count = loot.count
			if ( count ) then
				data[id] = (data[id] or 0) + count
				foundItem = true
			end
		end
	end
	if ( foundItem ) then
		data.total = data.total + 1
	end
end

local tempData = {}
local function GetDropsTable( objectId )
	local data = Gatherer.DropRates.Data
	for k in pairs(tempData) do
		tempData[k] = nil
	end
	tempData.total = 0
	for _, zones in pairs(data) do
		if ( type(zones) == "table" ) then
			for _, nodes in pairs(zones) do
				for id, node in pairs(nodes) do
					if ( objectId == id ) then
						for item, count in pairs(node) do
							tempData[item] = (tempData[item] or 0) + count
						end
					end
				end
			end
		end
	end
	return tempData
end

function Gatherer.DropRates.GetDropsTotal( objectId )
	local data = GetDropsTable(objectId)
	if ( data ) then
		return data.total
	end
end

function Gatherer.DropRates.GetPrimaryItem( objectId )
	local data = GetDropsTable(objectId)
	if ( data and (data.total > 0) ) then
		local prime = 0
		local pcount = 0
		for item, count in pairs(data) do
			if (item ~= "total" and pcount < count) then
				prime = item
				pcount = count
			end
		end
		return prime, pcount
	end
end

local EmptyIterator = function() end

local iteratorStateTables = {}
setmetatable(iteratorStateTables, { __mode = "k" });

local workTableCache = { {}, {}, {}, {}, };

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
		local nodeIndex = lastIndex * 2
		if ( iteratorData[nodeIndex] ) then
			return lastIndex,
			       iteratorData[nodeIndex - 1],
			       iteratorData[nodeIndex]
		else
			releaseWorkTable(iteratorData)
			return
		end
	end
	
	local data
	local function dropRateCompare_DESC( i, j )
		if ( data[i] > data[j] ) then
			return true
		else
			return false
		end
	end
	
	local dropsCache = {}
	
	function Gatherer.DropRates.ObjectDrops( objectId )
		data = GetDropsTable(objectId)
		if not ( data and (data.total > 0) ) then
			return EmptyIterator
		end
		
		local iteratorData = getWorkTable()
		for k in pairs(dropsCache) do
			dropsCache[k] = nil
		end
		for item, count in pairs(data) do
			if (item ~= "total") then
				table.insert(dropsCache, item)
			end
		end
		table.sort(dropsCache, dropRateCompare_DESC)
		for i, item in ipairs(dropsCache) do
			tinsert(iteratorData, item)
			tinsert(iteratorData, data[item])
		end
		
		return iterator, iteratorData, 0
	end

end