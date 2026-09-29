--[[
	Gatherer Addon for World of Warcraft(tm).
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GathererNodeSearch.lua 854 2009-04-16 06:13:47Z Esamynn $

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

	Node density and zone availability search UI
--]]

local _tr = Gatherer.Locale.Tr

Gatherer.NodeSearch = {}
local lib = Gatherer.NodeSearch
local private = {}

lib.private = private

private.frame = CreateFrame("Frame", nil, UIParent)
local frame = private.frame

frame:SetBackdrop({
        bgFile = "Interface/Tooltips/ChatBubble-Background",
        edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 32, right = 32, top = 32, bottom = 32 }
})
frame:SetBackdropColor(0,0,0, 1)

frame:SetPoint("CENTER", UIParent, "CENTER")
frame:SetWidth(450)
frame:SetHeight(450)

frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()

frame.Drag = CreateFrame("Button", nil, frame)
frame.Drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 10,-5)
frame.Drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10,-5)
frame.Drag:SetHeight(6)
frame.Drag:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")

frame.Drag:SetScript("OnMouseDown", function() frame:StartMoving() end)
frame.Drag:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

frame.DragBottom = CreateFrame("Button",nil, frame)
frame.DragBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10,5)
frame.DragBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10,5)
frame.DragBottom:SetHeight(6)
frame.DragBottom:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")

frame.DragBottom:SetScript("OnMouseDown", function() frame:StartMoving() end)
frame.DragBottom:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

frame.Done = CreateFrame("Button", nil, frame, "OptionsButtonTemplate")
frame.Done:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
frame.Done:SetScript("OnClick", function() frame:Hide() end)
frame.Done:SetText(_tr("Done"))

frame.GatherablesReport = CreateFrame("Button", nil, frame, "OptionsButtonTemplate")
frame.GatherablesReport:SetWidth(150)
frame.GatherablesReport:SetPoint("BOTTOM", frame, "BOTTOM", -142, 10)
frame.GatherablesReport:SetScript("OnClick", function() frame:Hide() GathererReportFrame:Show() end)
frame.GatherablesReport:SetText(_tr("Gatherables Report"))

frame.Config = CreateFrame("Button", "", frame, "OptionsButtonTemplate")
frame.Config:SetPoint("BOTTOM", frame, "BOTTOM", -20, 10)
frame.Config:SetScript("OnClick", function() frame:Hide() Gatherer.Config.ShowOptions() end)
frame.Config:SetText(_tr("Config"))

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("CENTER", frame, "TOP", 0, -20)
frame.title:SetText(_tr("Node Density Report"))

local SelectBox = LibStub:GetLibrary("SelectBox")
local ScrollSheet = LibStub:GetLibrary("ScrollSheet")

frame.searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
frame.searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
frame.searchBox:SetAutoFocus(false)
frame.searchBox:SetHeight(15)
frame.searchBox:SetWidth(150)
frame.searchBox:SetScript("OnEnterPressed", function() private.startSearch(nil, nil, frame.searchBox:GetText() ) end)

frame.searchButton = CreateFrame("Button", nil, frame, "OptionsButtonTemplate")
frame.searchButton:SetPoint("TOPLEFT", frame.searchBox, "BOTTOMLEFT", -6, -1)
frame.searchButton:SetText(_tr("Search"))
frame.searchButton:SetScript("OnClick", function() private.startSearch(nil, nil, frame.searchBox:GetText() ) end)

frame.SelectBoxSetting = {"all", "all"}
function private.ChangeControls(obj, arg1,arg2,...)
	frame.SelectBoxSetting = {arg1, arg2}
end

local continents
local maxCont
local function vals()
	if not continents then
		continents = {
			{"all", _tr("All")},
		}
		maxCont = table.maxn(Gatherer.Util.ZoneNames)
		for n = 1, maxCont do
			local cdata = Gatherer.Util.ZoneNames[n]
			if (cdata and cdata[0]) then
				table.insert(continents, {n, cdata[0]})
			end
		end
	end
	return continents
end

frame.selectbox = CreateFrame("Frame", "GathererNodeSearchBox", frame)
frame.selectbox.box = SelectBox:Create("GathererNodeSearchBox", frame.selectbox, 120, private.ChangeControls, vals, "default")
frame.selectbox.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 180,-56)
frame.selectbox.box:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0,-90)
frame.selectbox.box:SetText(_tr("All"))

frame.resultlist = CreateFrame("Frame", nil, frame)
frame.resultlist:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
})

frame.resultlist:SetBackdropColor(1, 0, 0, 0.5)
frame.resultlist:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 5, 350)
frame.resultlist:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -5, 0)
frame.resultlist:SetPoint("BOTTOM", frame, "BOTTOM",0, 38)

frame.resultlist.sheet = ScrollSheet:Create(frame.resultlist, {
		{ _tr("Location"), "TEXT",  123},
		{ _tr("Type"), "TEXT",  137},
		{ _tr("# Nodes"), "NUMBER",  67},
		{ _tr("Percent"), "NUMBER",  67},


	})

local Data = {}
function private.getZonesWithNodes(start, finish, gatherName)
	for continent = start, finish do
		for _, zone in Gatherer.Storage.GetAreaIndices(continent) do
			if Gatherer.Storage.IsGatherInZone( continent, zone, gatherName ) then
				local nodes = Gatherer.Storage.GetGatherCountsForZone( continent, zone, gatherName )
				local treasures, herbs, ores = Gatherer.Storage.GetNodeCountsByGatherType( continent, zone )
				local type = Gatherer.Nodes.Objects[gatherName]
				table.insert(Data, {["continent"] = continent, ["zone"] = zone, ["gatherName"] = gatherName, ["nodes"] = nodes, ["HERB"] = herbs, ["MINE"] = ores, ["OPEN"] = treasures, ["type"] = type})
			end
		end
	end
end

function private.startSearch(start, finish, name)
	if frame.SelectBoxSetting[2] == "all" then
		if not maxCont then vals() end
		start, finish = 1, maxCont
	else
		start, finish = frame.SelectBoxSetting[2], frame.SelectBoxSetting[2]
	end
	for text, gatherName in pairs(Gatherer.Nodes.Names) do
		if text:lower():find(name:lower(), 1, true) then
			private.getZonesWithNodes(start, finish, gatherName)
		end
	end
	private.nodesByPercent()
end
function private.nodesByPercent()
	local data = {}
	for i,v in pairs( Data ) do
		local nodes = v.nodes
		local total = v[v.type]
		local pct = 0
		if (total and total > 0) then
			pct = floor(nodes*100/total + 0.5)
		end
		local cdata = Gatherer.Util.ZoneNames[v.continent]
		local location = cdata and cdata[v.zone] or ""

		table.insert(data, {location, Gatherer.Util.GetNodeName(v.gatherName), nodes, pct,} )
	end
	Data = {}
	frame.resultlist.sheet:SetData(data)
end