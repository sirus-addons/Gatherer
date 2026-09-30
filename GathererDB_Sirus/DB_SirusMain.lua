--[[
	Portions of data included here may belong to Blizzard.
	Code in this file is hereby released into the Public Domain.
	No warranty of merchantability or fitness of purpose is provided or
	implied. Use this code at your own risk.
]]

if not GathererDB then GathererDB = {} end

local ADDON = "GathererDB_Sirus"
local SOURCE = "DB Sirus"
local VERSION_KEY = "db.sirus.version"

local lib = {}
GathererDB.Sirus = lib

lib.isLoading = true
if not Gatherer then lib.isLoading = false
elseif not Gatherer.Api then lib.isLoading = false
elseif not Gatherer.Api.AddGather then lib.isLoading = false
elseif not Gatherer.ZoneTokens then lib.isLoading = false
elseif not Gatherer.Config.AddCallback then
	DEFAULT_CHAT_FRAME:AddMessage(ADDON..": Please upgrade to the latest version of Gatherer.")
	lib.isLoading = false
end

if not lib.isLoading then
	DEFAULT_CHAT_FRAME:AddMessage(ADDON..": Not loading due to missing or old Gatherer.")
	return
end

local L = setmetatable({}, { __index = function(t, key) return key end })
if GetLocale() == "ruRU" then
	L["Database"] = "База данных"
	L["GathererDB Imports"] = "Импорт баз данных GathererDB"
	L["Perform import of node DB v%s:"] = "Импорт базы точек сбора, версия %s:"
	L["Import"] = "Импортировать"
	L["Importing node database:"] = "Идёт импорт базы точек:"
	L["%s: import finished, %d new nodes, %d already known."] = "%s: импорт завершён, новых точек: %d, уже известных: %d."
	L["%s: import stopped by an error: %s"] = "%s: импорт остановлен из-за ошибки: %s"
end

local Objects = Gatherer.Nodes.Objects
local Names = Gatherer.Nodes.Names
local CategoryNames = Gatherer.Categories.CategoryNames

local known = {}
for id, gtype in pairs(Objects) do
	known[id] = gtype
end
local knownNames = {}
for name, id in pairs(Names) do
	knownNames[name] = id
end

lib.alias = {}
local alias = lib.alias

local zonelut
local updateFrame
local co

local displaySettings = { "minimap.enable", "mainmap.enable", "plugin.gatherer_hud.enable" }
local paused

local function pauseDisplays()
	if paused then return end
	paused = {}
	for _, key in ipairs(displaySettings) do
		paused[key] = Gatherer.Config.GetSetting(key)
		Gatherer.Config.SetSetting(key, false)
	end
end

local function resumeDisplays()
	local saved = paused
	paused = nil
	if saved then
		for _, key in ipairs(displaySettings) do
			Gatherer.Config.SetSetting(key, saved[key])
		end
	end
end

local FRAME_BUDGET = 10
local function beginImport()
	pauseDisplays()

	local position, total, stored = 0,0,0
	local deadline = debugprofilestop() + FRAME_BUDGET
	for zone, zdata in pairs(lib.data) do
		if zonelut[zone] then
			for node, ndata in pairs(zdata) do
				total = total + #ndata
			end
		end
	end

	for zone, zonedef in pairs(zonelut) do
		local c,z = unpack(zonedef)
		for node, ntype in pairs(Gatherer.Nodes.Objects) do
			Gatherer.Storage.RemoveGather(c, z, node, SOURCE)
			Gatherer.Storage.RemoveGather(c, z, node, "DB:Sirus")
		end
		if debugprofilestop() > deadline then
			coroutine.yield()
			deadline = debugprofilestop() + FRAME_BUDGET
		end
	end

	for zone, zdata in pairs(lib.data) do
		local zonedef = zonelut[zone]
		if zonedef then
			local c,z = unpack(zonedef)
			for node, ndata in pairs(zdata) do
				local id = alias[node] or node
				for pos, coord in ipairs(ndata) do
					local x = math.floor(coord/1000)/1000
					local y = (coord%1000)/1000
					local success = Gatherer.Api.AddGather(id, nil, nil, SOURCE, nil, nil, false, c, z, x, y)
					if success then
						stored = stored + 1
					end
					position = position + 1
					if debugprofilestop() > deadline then
						updateFrame:SetPct(position/total)
						coroutine.yield()
						deadline = debugprofilestop() + FRAME_BUDGET
					end
				end
			end
		end
	end

	resumeDisplays()
	Gatherer.Settings[VERSION_KEY] = GetAddOnMetadata(ADDON, "Version")
	Gatherer.Util.ChatPrint(L["%s: import finished, %d new nodes, %d already known."]:format(ADDON, stored, position - stored))
end

function lib:PerformImport()
	if not updateFrame then
		zonelut = {}
		for c, zones in pairs(Gatherer.ZoneTokens.Tokens) do
			for zone, z in pairs(zones) do
				if type(zone)=='string' and type(z)=='number' then
					zonelut[zone] = {c, z}
				end
			end
		end

		updateFrame = CreateFrame("Frame", nil, UIParent)
		updateFrame:SetPoint("CENTER", UIParent, "CENTER")
		updateFrame:SetFrameStrata("TOOLTIP")
		updateFrame:SetWidth("320")
		updateFrame:SetHeight("50")
		updateFrame:SetScript("OnUpdate", function(self)
			local ok, err = coroutine.resume(co)
			if not ok then
				resumeDisplays()
				Gatherer.Util.ChatPrint(L["%s: import stopped by an error: %s"]:format(ADDON, tostring(err)))
			end
			if not ok or coroutine.status(co) == "dead" then
				self:Hide()
			end
		end)

		updateFrame.text = updateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		updateFrame.text:SetPoint("TOPLEFT", updateFrame, "TOPLEFT", 10,-5)
		updateFrame.text:SetHeight(16)
		updateFrame.text:SetJustifyH("LEFT")
		updateFrame.text:SetJustifyV("TOP")
		updateFrame.text:SetText(L["Importing node database:"])

		updateFrame.back = updateFrame:CreateTexture(nil, "BACKGROUND")
		updateFrame.back:SetPoint("TOPLEFT")
		updateFrame.back:SetPoint("BOTTOMRIGHT")
		updateFrame.back:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

		updateFrame.bar = updateFrame:CreateTexture(nil, "BORDER")
		updateFrame.bar:SetTexture(1,1,1)
		updateFrame.bar:SetPoint("BOTTOMLEFT", updateFrame, "BOTTOMLEFT", 10, 5)
		updateFrame.bar:SetPoint("BOTTOMRIGHT", updateFrame, "BOTTOMRIGHT", -10, 5)
		updateFrame.bar:SetHeight(18)
		updateFrame.bar:SetAlpha(0.2)

		updateFrame.bar.pct = updateFrame:CreateTexture(nil, "ARTWORK")
		updateFrame.bar.pct:SetTexture(1,1,1)
		updateFrame.bar.pct:SetGradientAlpha("Vertical", 0,0,0.4, 1, 0,0,0.7, 1)
		updateFrame.bar.pct:SetPoint("BOTTOMLEFT", updateFrame.bar, "BOTTOMLEFT")
		updateFrame.bar.pct:SetPoint("TOPLEFT", updateFrame.bar, "TOPLEFT")

		updateFrame.bar.text = updateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		updateFrame.bar.text:SetPoint("TOPLEFT", updateFrame.bar, "TOPLEFT", 0,0)
		updateFrame.bar.text:SetPoint("BOTTOMRIGHT", updateFrame.bar, "BOTTOMRIGHT", 0,0)
		updateFrame.bar.text:SetJustifyH("CENTER")
		updateFrame.bar.text:SetJustifyV("CENTER")

		updateFrame.bar.text:SetText("0%")

		function updateFrame:SetPct(pct)
			pct = math.max(0, math.min((tonumber(pct) or 0), 1))

			local width = updateFrame:GetWidth() - 20
			updateFrame.bar.pct:SetWidth(width * pct)
			updateFrame.bar.text:SetText(("%0.1f%%"):format(pct*100))
		end
	end
	updateFrame:Show()

	co = coroutine.create(beginImport)
end

local function setupGui(gui)
	local id
	if (GathererDB.guiId) then
		id = GathererDB.guiId
	else
		id = gui:AddTab(L["Database"])
		gui:AddControl(id, "Header",     0,    L["GathererDB Imports"])
		gui:MakeScrollable(id)
		GathererDB.guiId = id
	end

	local version = GetAddOnMetadata(ADDON, "Version")
	gui:AddControl(id, "Subhead",    0,    L["Perform import of node DB v%s:"]:format(version))

	local buttonFrame = CreateFrame("Frame", nil, gui.tabs[id][3])
	buttonFrame:SetHeight(24)
	gui:AddControl(id, "Custom", 0, 1, buttonFrame)

	local button = CreateFrame("Button", nil, buttonFrame, "OptionsButtonTemplate")
	button:SetPoint("TOPLEFT", buttonFrame, "TOPLEFT", 0,0)
	button:SetScript("OnClick", lib.PerformImport)
	button:SetText(L["Import"])
end
Gatherer.Config.AddCallback(ADDON, setupGui)

local defaultIcon = {
	HERB = "Herb\\Silverleaf",
	MINE = "Mine\\Copper",
	OPEN = "Open\\Chest",
}

local nameIcons = {
	{ "Herb\\GhostMushroom", "гриб", "Гриб" },
	{ "Herb\\FrostLotus", "лотос", "Лотос" },
	{ "Mine\\Saronite", "саронит", "Саронит" },
	{ "UngoroCrystal", "кристалл", "Кристалл" },
	{ "Open\\Egg", "Гнездо", "Яйца" },
	{ "Open\\Barrel", "Бидон" },
}

local function iconFor(gtype, name)
	if ( name ) then
		for _, rule in ipairs(nameIcons) do
			for i = 2, #rule do
				if ( name:find(rule[i], 1, true) ) then
					return rule[1]
				end
			end
		end
	end
	return defaultIcon[gtype]
end

local function fixNodes()
	local ids = {}
	for id in pairs(Objects) do
		if ( type(id) == "number" ) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)

	local owner = {}
	for name, id in pairs(knownNames) do
		if ( known[id] ) then
			owner[known[id]..name] = id
		end
	end
	for _, id in ipairs(ids) do
		local gtype, name = known[id], CategoryNames[id]
		if ( gtype and name and not owner[gtype..name] ) then
			owner[gtype..name] = id
		end
	end
	for _, id in ipairs(ids) do
		local name = CategoryNames[id]
		if ( not known[id] and name ) then
			local key = Objects[id]..name
			if ( owner[key] ) then
				alias[id] = owner[key]
			else
				owner[key] = id
			end
		end
	end

	for name, id in pairs(Names) do
		if ( alias[id] ) then
			Names[name] = alias[id]
		end
	end
	for id in pairs(alias) do
		Objects[id] = nil
		CategoryNames[id] = nil
	end

	if ( GetLocale() ~= "ruRU" ) then
		local ownName = {}
		for name, id in pairs(knownNames) do
			ownName[id] = true
		end
		for name, id in pairs(Names) do
			if ( ownName[id] and not knownNames[name] ) then
				Names[name] = nil
			end
		end
		for id in pairs(ownName) do
			if ( type(id) == "number" ) then
				CategoryNames[id] = nil
			end
		end
	end

	for _, id in ipairs(ids) do
		if ( not known[id] and not alias[id] and not Gatherer.Icons[id] ) then
			Gatherer.Icons[id] = iconFor(Objects[id], CategoryNames[id])
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name:lower() == ADDON:lower() then
			self:UnregisterEvent("ADDON_LOADED")
			fixNodes()
		end
	elseif event == "PLAYER_LOGIN" then
		if Gatherer.Settings[VERSION_KEY] ~= GetAddOnMetadata(ADDON, "Version") then
			lib:PerformImport()
		end
	else
		resumeDisplays()
	end
end)
