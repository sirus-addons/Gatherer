--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherEvent.lua 869 2009-08-05 19:54:12Z Esamynn $

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

	Event handling routines
]]

local _tr = Gatherer.Locale.Tr

function Gatherer.Event.RegisterEvents( frame )
	frame:RegisterEvent("WORLD_MAP_UPDATE")
	frame:RegisterEvent("LEARNED_SPELL_IN_TAB");
	frame:RegisterEvent("SPELLS_CHANGED");
	frame:RegisterEvent("SKILL_LINES_CHANGED");
	frame:RegisterEvent("UI_ERROR_MESSAGE");
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	frame:RegisterEvent("MINIMAP_UPDATE_TRACKING")

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LEAVING_WORLD")

	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_LOGOUT")

	frame:RegisterEvent("CHAT_MSG_ADDON")
end

function Gatherer.Event.OnLoad()
	local hookFunc = function( ... ) Gatherer.Event.OnSwag(...) end
	LibSwag.RegisterHook("Gatherer", hookFunc, hookFunc)
	
	Gatherer.Config.Load()
	Gatherer.DropRates.Load()
	
	Gatherer.MapNotes.Update()
	Gatherer.MiniNotes.Show()
	
	Gatherer.MiniIcon.Reposition()
	Gatherer.MiniIcon.Update()
	
	if ( Gatherer.Config.GetSetting("about.loaded") ) then
		Gatherer.Util.ChatPrint("Gatherer v"..Gatherer.Var.Version.." -- Loaded!")
		local zones = Gatherer.Var.UnknownZones
		if ( zones ) then
			Gatherer.Util.ChatPrint(_tr("Unrecognized zones (nodes are saved under the map name): %1", zones))
		end
	end
end

function Gatherer.Event.OnEvent( event, ... )
	if (event == "PLAYER_ENTERING_WORLD" ) then
		Gatherer.MiniNotes.Show()

	elseif (event == "PLAYER_LEAVING_WORLD" ) then
		Gatherer.MiniNotes.Hide()

	elseif (event == "WORLD_MAP_UPDATE") then
		Gatherer.MapNotes.MapDraw()
	
	elseif( event == "ADDON_LOADED" ) then
		local addon = select(1, ...)
		if (addon and string.lower(addon) == "gatherer") then
			Gatherer.Event.OnLoad()
		end
	
	elseif ( event == "PLAYER_LOGIN" ) then
		Gatherer.Util.GetSkills()
		Gatherer.Plugins.LoadPluginData()
	
	elseif ( event == "PLAYER_LOGOUT" ) then
		Gatherer.Config.Save()
		Gatherer.DropRates.Save()
	
	elseif ( event == "LEARNED_SPELL_IN_TAB" ) then
		Gatherer.Util.QueueSkillCheck()
	
	elseif ( event == "SPELLS_CHANGED" ) then
		Gatherer.Util.QueueSkillCheck()
	
	elseif ( event == "SKILL_LINES_CHANGED" ) then
		Gatherer.Util.QueueSkillCheck()
	
	elseif ( event == "MINIMAP_UPDATE_TRACKING" ) then
		Gatherer.MiniNotes.ForceUpdate()
		Gatherer.MapNotes.Invalidate()
		Gatherer.MapNotes.MapDraw()
	
	elseif ( event == "CHAT_MSG_ADDON" ) then
		local prefix, msg, how, who = select(1, ...)
		if ( prefix == "GathX" ) then
			Gatherer.Comm.Receive( msg, how, who )
		elseif ( prefix == "Gatherer" ) then
			Gatherer.Comm.General(msg, how, who)
		end
		
	elseif ( event == "ZONE_CHANGED_NEW_AREA" ) then
		Gatherer.MiniNotes.Show()
	
	elseif ( event == "UI_ERROR_MESSAGE" ) then
		local msg =  select(1, ...)
		local skill = Gatherer.Util.ParseFormattedMessage(ERR_USE_LOCKED_WITH_ITEM_S, msg)
		if not ( skill ) then
			skill = Gatherer.Util.ParseFormattedMessage(ERR_USE_LOCKED_WITH_SPELL_KNOWN_SI, msg)
		end

		if ( skill ) then
			LibSwag.SetTooltip()
			local tooltip = LibSwag.GetLastTip()
			if not ( tooltip and GameTooltip:IsShown() and (GetTime() - tooltip.time) < 1 ) then return end
			local tip = tooltip.tip

			local objId = Gatherer.Nodes.Names[tip]
			if ( objId ) then
				local gType = Gatherer.Nodes.Objects[objId]
				Gatherer.Api.AddGather(objId, gType, tip, "REQUIRE", 0, {}, false)
			end
		end
	end
end

function Gatherer.Event.OnSwag(lootType, lootTable, coinAmount, extraData)
	local node = "Unknown"
	if (extraData and extraData.tip) then node = extraData.tip end
	
	local object = Gatherer.Nodes.Names[node]
	if (not object) then return end
	
	local objectType = Gatherer.Nodes.Objects[object]
	if (objectType ~= lootType) then return end
	
	Gatherer.Api.AddGather(object, lootType, node, nil, coinAmount, lootTable, (lootTable and coinAmount))
end
