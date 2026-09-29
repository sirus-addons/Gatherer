--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherApi.lua 754 2008-10-14 04:43:39Z Esamynn $

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

	These functions can be used by external addons for interfacing with
	Gatherer. We will try and keep these functions as unchanged as possible.
]]

function Gatherer.Api.AddGather(objectId, gatherType, tooltipText, gatherSource, gatherCoins, gatherLoot, wasGathered, gatherC, gatherZ, gatherX, gatherY)
	local success
	
	if not (gatherC and gatherZ and gatherX and gatherY) then
		gatherC, gatherZ, gatherX, gatherY = Gatherer.Util.GetPositionInCurrentZone()
		if not (gatherC and gatherZ and gatherX and gatherY) then
			return
		end
	end
	if ( gatherC <= 0 or gatherZ <= 0 ) then
		return
	end
	
	if (not gatherSource) then
		Gatherer.DropRates.ProcessDrops(objectId, gatherC, gatherZ, gatherSource, gatherCoins, gatherLoot)
	end
	
	if ( type(objectId) == "number" or Gatherer.Categories.CategoryNames[objectId] ) then 
		local index = Gatherer.Storage.AddNode(objectId, gatherType, gatherC, gatherZ, gatherX, gatherY, gatherSource, wasGathered)
		if  index and index > 0 then
			success = true
		end

		if ( (not gatherSource) or (gatherSource == "REQUIRE") ) then
			Gatherer.Comm.Send(objectId, gatherC, gatherZ, index, gatherCoins, gatherLoot)
		end
	end
	
	if ( (not gatherSource) or (gatherSource == "REQUIRE") ) then
		Gatherer.MiniNotes.ForceUpdate()
		Gatherer.MapNotes.MapDraw()
	end

	return success
end
