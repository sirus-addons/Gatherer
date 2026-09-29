--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherMapNotes.lua 754 2008-10-14 04:43:39Z Esamynn $

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

	World Map Drawing Functions
]]

local _tr = Gatherer.Locale.Tr

local mapTooltip = CreateFrame("GameTooltip", "GathererWorldMapTooltip", WorldMapFrame, "GameTooltipTemplate")

function Gatherer.MapNotes.Enable()
	Gatherer.Config.SetSetting("mainmap.enable", true)
	Gatherer.MapNotes.Update()
end

function Gatherer.MapNotes.Disable()
	Gatherer.Config.SetSetting("mainmap.enable", false)
	Gatherer.MapNotes.Update()
end

function Gatherer.MapNotes.ToggleDisplay()
	if ( Gatherer.Config.GetSetting("mainmap.enable") ) then
		Gatherer.MapNotes.Disable()
	else
		Gatherer.MapNotes.Enable()
	end
end

function Gatherer.MapNotes.Update()
	if ( Gatherer.Config.GetSetting("mainmap.enable") ) then
		Gatherer_WorldMapDisplay:SetText(_tr("Hide Items"))
		GathererMapOverlayParent:Show()
	else
		Gatherer_WorldMapDisplay:SetText(_tr("Show Items"))
		GathererMapOverlayParent:Hide()
	end
end

function Gatherer.MapNotes.GetNoteObject( noteNumber )
	local button = getglobal("GatherMain"..noteNumber)
	if not ( button ) then
		local overlayFrameNumber = math.ceil(noteNumber / 100)
		local overlayFrame = GathererMapOverlayParent[overlayFrameNumber]
		if not ( overlayFrame ) then
			overlayFrame = CreateFrame("Frame", "GathererMapOverlayFrame"..overlayFrameNumber, GathererMapOverlayParent, "GathererMapOverlayTemplate")
			GathererMapOverlayParent[overlayFrameNumber] = overlayFrame
		end
		button = CreateFrame("Button" ,"GatherMain"..noteNumber, overlayFrame, "GatherMainTemplate")
		button:SetID(noteNumber)
		overlayFrame[(noteNumber-1) % 100 + 1] = button
	end
	return button
end

local drawnContinent, drawnZone, drawnChanges

function Gatherer.MapNotes.Invalidate()
	drawnChanges = nil
end

function Gatherer.MapNotes.MapDraw()
	local GathererMapOverlayParent = GathererMapOverlayParent
	if not ( GathererMapOverlayParent:IsVisible() ) then
		return
	end
	local setting = Gatherer.Config.GetSetting
	local maxNotes = setting("mainmap.count")
	local noteCount = 0

	local mapContinent, mapZone = Gatherer.Util.GetWorldMapZone()
	local changes = Gatherer.Storage.ChangeCount
	if ( mapContinent == drawnContinent and mapZone == drawnZone and changes == drawnChanges ) then
		return
	end
	drawnContinent, drawnZone, drawnChanges = mapContinent, mapZone, changes
	
	local opacity = setting("mainmap.opacity") / 100
	local iconsize = setting("mainmap.iconsize")
	local tooltip = setting("mainmap.tooltip.enable")
	local mapWidth, mapHeight = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
	if ( Gatherer.Storage.HasDataOnZone(mapContinent, mapZone) ) then
		for nodeId, gatherType, num in Gatherer.Storage.ZoneGatherNames(mapContinent, mapZone) do
			if ( Gatherer.Config.DisplayFilter_MainMap(nodeId) ) then
				for index, xPos, yPos, count in Gatherer.Storage.ZoneGatherNodes(mapContinent, mapZone, nodeId) do
					if ( noteCount < maxNotes ) then
						noteCount = noteCount + 1
						local mainNote = Gatherer.MapNotes.GetNoteObject(noteCount)
						
						mainNote:SetAlpha(opacity)
						
						local texture = Gatherer.Util.GetNodeTexture(nodeId)
						getglobal(mainNote:GetName().."Texture"):SetTexture(texture)
						
						mainNote:SetWidth(iconsize)
						mainNote:SetHeight(iconsize)
						
						mainNote.continent = mapContinent
						mainNote.zone = mapZone
						mainNote.id = nodeId
						mainNote.index = index

						if (tooltip and not mainNote:IsMouseEnabled()) then
							mainNote:EnableMouse(true)
						elseif (not tooltip and mainNote:IsMouseEnabled()) then
							mainNote:EnableMouse(false)
						end
						
						mainNote:ClearAllPoints()
						mainNote:SetPoint("CENTER", WorldMapButton, "TOPLEFT", xPos * mapWidth, -yPos * mapHeight)
						mainNote:Show()
					else
						break
					end
				end
			end
		end
	end
	
	local numUsedOverlays = math.ceil(noteCount / 100)
	local partialOverlay = GathererMapOverlayParent[numUsedOverlays]
	for i = (noteCount - ((numUsedOverlays - 1) * 100) + 1), 100 do
		local note = partialOverlay[i]
		if not ( note ) then
			break
		end
		note:Hide()
	end
	for i, overlay in ipairs(GathererMapOverlayParent) do
		if ( i <= numUsedOverlays ) then
			overlay:Show()
		else
			overlay:Hide()
		end
	end
end

function Gatherer.MapNotes.MapOverlayFrame_OnHide( frame )
	for _, childFrame in ipairs(frame) do
		childFrame:Hide()
	end
	drawnChanges = nil
end

function Gatherer.MapNotes.MapNoteOnEnter(frame)
	local setting = Gatherer.Config.GetSetting
	local tooltip = mapTooltip

	local enabled = setting("mainmap.tooltip.enable")
	if (not enabled) then 
		return
	end
	
	local showcount = setting("mainmap.tooltip.count")
	local showsource = setting("mainmap.tooltip.source")
	local showseen = setting("mainmap.tooltip.seen")
	local showrate = setting("mainmap.tooltip.rate")

	tooltip:SetOwner(frame, "ANCHOR_BOTTOMLEFT")
	
	local id = frame.id
	local name = Gatherer.Util.GetNodeName(id)
	local _, _, 
		count, 
		gType, 
		harvested, 
		inspected, 
		who = Gatherer.Storage.GetNodeInfo(frame.continent, frame.zone, id, frame.index)
	if not ( count ) then
		drawnChanges = nil
		return
	end
	local last = inspected or harvested

	tooltip:ClearLines()
	tooltip:AddLine(name)
	if (count > 0 and showcount) then
		tooltip:AddLine(_tr("NOTE_COUNT", count))
	end
	if (who and showsource) then
		if (who == "REQUIRE") then
			tooltip:AddLine(_tr("NOTE_UNSKILLED"))
		elseif (who == "IMPORTED") then
			tooltip:AddLine(_tr("NOTE_IMPORTED"))
		else
			tooltip:AddLine(_tr("NOTE_SOURCE", who:gsub(",", ", ")))
		end
	end
	if (last and last > 0 and showseen) then
		tooltip:AddLine(_tr("NOTE_LASTVISITED", Gatherer.Util.SecondsToTime(time()-last)))
	end
	
	if ( showrate ) then
		local num = Gatherer.Config.GetSetting("mainmap.tooltip.rate.num")
		Gatherer.Tooltip.AddDropRates(tooltip, id, num)
	end
	tooltip:Show()
end
