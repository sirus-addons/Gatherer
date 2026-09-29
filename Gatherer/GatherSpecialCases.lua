--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherSpecialCases.lua 754 2008-10-14 04:43:39Z Esamynn $

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
	
	Special Case Handling
	
	This file handles modifications that need to be made to various data tables
	throughout Gatherer that need to be "hacked up" in some fashion to handle
	Special Case nodes.
	
	THIS FILE SHOULD ALWAYS BE HEAVILY COMMENTED SO THAT IT IS EASY TO UNDERSTAND
	EXACTLY WHAT IS BEING DONE AND WHY!!!
]]

local AllNodesInCategoryAreSame = { 
	"TREASURE_POWERCRYST",
}

do
	for _, category in ipairs(AllNodesInCategoryAreSame) do
		local origIds = {}
		for id, cat in pairs(Gatherer.Categories.ObjectCategories) do
			if ( cat == category ) then
				origIds[id] = cat
				table.insert(origIds, id)
			end
		end
		
		if ( #origIds > 0 ) then
			Gatherer.Categories.ObjectCategories[category] = category
			
			local Names = Gatherer.Nodes.Names
			for name, id in pairs(Names) do
				if ( origIds[id] ) then
					Names[name] = category
				end
			end
			
			Gatherer.Nodes.Objects[category] = Gatherer.Nodes.Objects[origIds[1]]
			
			local ReMappings = Gatherer.Nodes.ReMappings
			for _, nodeId in ipairs(origIds) do
				ReMappings[nodeId] = category
			end
			
			Gatherer.Icons[category] = Gatherer.Icons[origIds[1]]
		end
	end
end
