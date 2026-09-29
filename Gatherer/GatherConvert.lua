--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherConvert.lua 776 2008-11-13 03:02:26Z Esamynn $

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

	Database conversion/merging code and conversion data tables
--]]

local metatable = { __index = getfenv(0) }
setmetatable( Gatherer.Convert, metatable )
setfenv(1, Gatherer.Convert)

local type = type
local ipairs = ipairs
local pairs = pairs

local nodeLevel, mappingData, typeConverstionData
local traversalData = {}
local MergeNode

local nodeData = {}
local function extractNodeInformation()
	for index, mapping in ipairs(mappingData) do
		if ( mapping.type == "key" ) then
			nodeData[index] = traversalData[mapping.level].key
		elseif ( mapping.type == "value" ) then
			nodeData[index] = traversalData[mapping.level].data[mapping.key]
		else
			return
		end
	end
	for index, data in ipairs(nodeData) do
		local typeInfo = typeConverstionData[index]
		local dataType = type(data)
		if ( typeInfo ) then
			if ( type(typeInfo) == "string" ) then
				if ( dataType ~= typeInfo ) then
					data = nil;
				end
			elseif ( type(typeInfo) == "table" ) then
				local conversionInfo = typeInfo[dataType]
				if ( (dataType == "string") and not (typeInfo.caseSensitive) ) then
					data = string.lower(data)
				end
				if ( conversionInfo ) then
					if ( type(conversionInfo) == "table" ) then
						data = conversionInfo[data]
					elseif ( type(conversionInfo) == "function" ) then
						data = conversionInfo(data, nodeData)
					end
				else
					data = nil;
				end
			end
		else
			data = nil;
		end
		nodeData[index] = data
	end
	pcall(MergeNode, unpack(nodeData, 1, 10))
end

local function iterateOnLevel( level )
	if ( level < 1 or level > nodeLevel ) then return level end
	
	if ( level == nodeLevel ) then
		extractNodeInformation()
	else
		for key, data in pairs(traversalData[level].data) do
			if ( type(data) == "table" ) then
				local newLevel = level + 1
				traversalData[newLevel].key = key
				traversalData[newLevel].data = data
				iterateOnLevel(newLevel)
			end
		end
	end
end


function ImportDatabase( dataToImport, nodeMergeFunction )
	local dbVer = dataToImport.dbVersion
	local converInfo = ConversionInformation[dbVer]
	if ( converInfo ) then
		nodeLevel = converInfo.nodeLevel
		mappingData = converInfo.mappingData
		typeConverstionData = converInfo.typeConverstionData
		MergeNode = nodeMergeFunction
		for i = 1, nodeLevel do
			if not ( traversalData[i] ) then
				traversalData[i] = {}
			end
		end
		for key, data in pairs(dataToImport) do
			if ( type(data) == "table" ) then
				traversalData[1].data = data
				traversalData[1].key = key
				iterateOnLevel(1)
			end
		end
	end
end

ConversionInformation = {
	[3] = {
		nodeLevel = 4,
		mappingData = {
			[1] = { type="key", level=3, },
			[2] = { type="value", level=3, key="gtype" },
			[3] = { type="key", level=1, },
			[4] = { type="key", level=2, },
			[5] = { type="value", level=4, key=1, },
			[6] = { type="value", level=4, key=2, },
			[7] = { type="value", level=4, key=3, },
			[8] = { type="value", level=4, key=4, },
			[9] = { type="value", level=4, key=5, },
			[10] = { type="value", level=4, key=6, },
		},
		typeConverstionData = {
			[1] = {
				string = (
					function( data )
						for k, v in pairs(Gatherer.Nodes.Names) do
							if ( strlower(k) == strlower(data) ) then
								return v
							end
						end
						return Gatherer.Nodes.ReMappings[data] or data
					end
				),
				number = (
					function( data )
						return Gatherer.Nodes.ReMappings[data] or data
					end
				),
			},
			[2] = "string",
			[3] = "number",
			[4] = "string",
			[5] = "number",
			[6] = "number",
			[7] = "number",
			[8] = "number",
			[9] = "number",
			[10] = "string",
		},
	},
}

