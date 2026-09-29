--[[
	Gatherer Addon for World of Warcraft(tm).
	HUD Plugin Module
	Version: 3.1.14 (<%codename%>)
	Revision: $Id: GatherHUD.lua 854 2009-04-16 06:13:47Z Esamynn $

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
		This AddOn\'s source code is specifically designed to work with
		World of Warcraft\'s interpreted AddOn system.
		You have an implicit licence to use this AddOn with these facilities
		since that is it\'s designated purpose as per:
		http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
]]

local Astrolabe = DongleStub(Gatherer.AstrolabeVersion)

local lib = {}
Gatherer_HUD = lib

local private = {
	curNode = 0,
	maxNode = 0,
	nodes = {},
	heat = {},
	gridres = 250,
	elapsed = 0,
	dirty = true,
}

local get = Gatherer.Config.GetSetting

local frame

function lib.Load( self )
	frame = self
	frame.me = Gatherer_Hud_Center
	frame.base = Gatherer_Hud_Base
	frame.heat = Gatherer_Hud_Heat

	this:RegisterEvent("PLAYER_ENTER_COMBAT")
	this:RegisterEvent("PLAYER_LEAVE_COMBAT")
end

function lib.ProcessGameEvent( event )
	if event == "PLAYER_ENTER_COMBAT" then
		private.inCombat = 1;
	elseif event == "PLAYER_LEAVE_COMBAT" then
		private.inCombat = nil;
	end
end

function lib.UpdateStruture()
	local tpy = get("plugin.gatherer_hud.radius")/get("plugin.gatherer_hud.yards")

	if not (get("plugin.gatherer_hud.enable") and get("minimap.enable")) or private.hidden then
		frame:Hide()
	else
		frame:Show()
	end

	frame:SetPoint("CENTER", UIParent, "CENTER", get("plugin.gatherer_hud.offset.horizontal"), get("plugin.gatherer_hud.offset.vertical"))
	frame:SetWidth(get("plugin.gatherer_hud.radius")*2)
	frame:SetHeight(get("plugin.gatherer_hud.radius")*2)
	frame:SetAlpha(get("plugin.gatherer_hud.alpha")/100)
	local strata = get("plugin.gatherer_hud.strata")
	if (strata == 1) then
	frame:SetFrameStrata("BACKGROUND")
	elseif (strata == 2) then
	frame:SetFrameStrata("LOW")
	elseif (strata == 3) then
	frame:SetFrameStrata("MEDIUM")
	else
	frame:SetFrameStrata("HIGH")
	end

	frame.me:SetWidth(tpy*132)
	frame.me:SetHeight(tpy*132*(get("plugin.gatherer_hud.aspect")/100))
	if (get("plugin.gatherer_hud.center.enable")) then
		local color = get("plugin.gatherer_hud.center.color")
		local r, g, b, a = strsplit(",", tostring(color) or "0,0,0,1")
		r = tonumber(r) or 0
		g = tonumber(g) or 0
		b = tonumber(b) or 0
		a = tonumber(a) or 0
		frame.me:SetVertexColor(r,g,b,a)
		frame.me:Show()
	else
		frame.me:Hide()
	end

	frame.base:SetWidth(get("plugin.gatherer_hud.radius")*2.2)
	frame.base:SetHeight(get("plugin.gatherer_hud.radius")*2.2*(get("plugin.gatherer_hud.aspect")/100))
	if (get("plugin.gatherer_hud.base.enable")) then
		local color = get("plugin.gatherer_hud.base.color")
		local r, g, b, a = strsplit(",", tostring(color) or "0,0,0,1")
		r = tonumber(r) or 0
		g = tonumber(g) or 0
		b = tonumber(b) or 0
		a = tonumber(a) or 0
		frame.base:SetVertexColor(r,g,b,a)
		frame.base:Show()
	else
		frame.base:Hide()
	end

	if not get("plugin.gatherer_hud.heat.enable") then frame.heat:Hide()
	else frame.heat:Show() end

	local color = get("plugin.gatherer_hud.heat.color")
	local r, g, b, a = strsplit(",", tostring(color) or "0,0,0,1")
	a = tonumber(a) or 0.7 
	frame.heat:SetAlpha(a)

	private.dirty = true
	if (private.started) then
		lib.Render()
	end
end

function lib.BeginUpdate()
	private.curNode = 0
	private.dirty = true
end

function lib.PlaceIcon(n, c, z, x, y)
	local tex, trim = Gatherer.Util.GetNodeTexture(n)

	local nodeId = private.curNode+1
	private.curNode = nodeId

	local node = private.nodes[nodeId]
	if (not node) then
		node = {}
		node.tex = frame:CreateTexture()
		node.tex:SetWidth(get("plugin.gatherer_hud.iconsize"))
		node.tex:SetHeight(get("plugin.gatherer_hud.iconsize"))
		node.tex:Show();
		private.nodes[nodeId] = node
		if nodeId > private.maxNode then
			private.maxNode = nodeId
		end
	end

	node.tex:SetTexture(tex)
	node.c = c
	node.z = z
	node.x = x
	node.y = y
end

private.zoneGrid = {}

local function hideFrame()
	private.hidden = true
	private.dirty = true
	frame:Hide()
end

function lib.Render()
	local hide = false
	if not (get("plugin.gatherer_hud.enable") and get("minimap.enable")) then hide=true
	elseif get("plugin.gatherer_hud.hide.flying") and IsFlying() then hide=true
	elseif get("plugin.gatherer_hud.hide.inside") and IsIndoors() then hide=true
	elseif get("plugin.gatherer_hud.hide.mounted") and IsMounted() then hide=true
	elseif get("plugin.gatherer_hud.hide.walking") and not IsMounted() then hide=true
	elseif get("plugin.gatherer_hud.hide.resting") and IsResting() then hide=true
	elseif get("plugin.gatherer_hud.hide.stealth") and IsStealthed() then hide=true
	elseif get("plugin.gatherer_hud.hide.swimming") and IsSwimming() then hide=true
	elseif get("plugin.gatherer_hud.hide.combat") and ( private.inCombat or
	                                    UnitAffectingCombat("target") or
	                                    UnitAffectingCombat("player") or
	                                    UnitAffectingCombat("pet")
	                                  ) then hide=true
	elseif get("plugin.gatherer_hud.hide.target") and ( (UnitCanAttack("target", "player") or
	                                    UnitIsEnemy("target", "player")) and
									not UnitIsDead("target")
	                                  ) then hide=true
	end

	if hide then
		hideFrame()
		return
	end
	private.hidden = nil
	frame:Show()

	local d, dx, dy, node, pct, angle, newangle, newsize, newalpha
	local pc, pz, px, py = unpack(Astrolabe.LastPlayerPosition)
	if not ( Astrolabe.processingFrame:IsShown() ) then
		local mx, my = GetPlayerMapPosition("player")
		if ( mx > 0 or my > 0 ) then
			local c, z, x, y = Astrolabe:GetCurrentPlayerPosition()
			if ( c and c >= 0 ) then
				pc, pz, px, py = c, z, x, y
			end
		end
	end

	local _, xScale, yScale = Astrolabe:ComputeDistance(pc, pz, 0,0, pc, pz, 1,1)
	if not (xScale and xScale > 0 and yScale > 0) then
		hideFrame()
		return
	end

	local gridres = private.gridres
	local now = time()
	local heatTime = get("plugin.gatherer_hud.heat.cooldown")
	if (get("plugin.gatherer_hud.heat.nevercooldown")) then
		heatTime = 1000000000
	end

	local zone = pc * 1000 + pz
	if (zone ~= private.gridZone) then
		private.gridZone = zone
		for key, cells in pairs(private.zoneGrid) do
			for index, gridTime in pairs(cells) do
				if (now - gridTime >= heatTime) then
					cells[index] = nil
				end
			end
			if not next(cells) then
				private.zoneGrid[key] = nil
			end
		end
	end
	local grid = private.zoneGrid[zone]
	if not grid then
		grid = {}
		private.zoneGrid[zone] = grid
	end
	if not (UnitIsDeadOrGhost("player") or UnitOnTaxi("player")) then
		grid[math.floor(px*gridres) + math.floor(py*gridres)*gridres] = now
	end

	if (private.curNode == 0) then
		hideFrame()
		return
	end

	local facing = GetPlayerFacing()
	if ( not private.dirty and pc == private.lastC and pz == private.lastZ and px == private.lastX and py == private.lastY and facing == private.lastFacing ) then
		return
	end
	private.dirty = nil
	private.lastC, private.lastZ, private.lastX, private.lastY, private.lastFacing = pc, pz, px, py, facing

	local radius = get("plugin.gatherer_hud.radius")
	local maxYards = get("plugin.gatherer_hud.yards")
	local aspect = get("plugin.gatherer_hud.aspect") / 100
	local reduce = get("plugin.gatherer_hud.reduce") / 100
	local size = get("plugin.gatherer_hud.iconsize")
	local fadeAt = get("plugin.gatherer_hud.fade") / 100
	local ratio = radius / maxYards

	for i = 1, private.curNode do
		node = private.nodes[i]
		d, dx, dy = Astrolabe:ComputeDistance(pc, pz, px, py, node.c, node.z, node.x, node.y);

		if d and dx and dy then
			angle = math.atan2(dx, -dy)
			newangle = angle + facing

			dx = d * math.sin(newangle);
			dy = d * math.cos(newangle);

			if (d < maxYards) then
				pct = d/maxYards
				if (pct > fadeAt) then
					pct = (1-pct)/(1-fadeAt)
				else
					pct = 1
				end

				local fb = dy/maxYards/2 + 0.5
				newsize = size - size*fb*reduce
				newalpha = pct - pct*(1-fb)*reduce

				dx = dx * ratio
				dy = dy * ratio * aspect

				node.tex:SetAlpha(newalpha)
				node.tex:ClearAllPoints()
				node.tex:SetPoint("CENTER", frame, "CENTER", dx, dy)
				node.tex:SetWidth(newsize)
				node.tex:SetHeight(newsize)
				if not node.tex:IsVisible() then
					node.tex:Show()
				end
			elseif node.tex:IsVisible() then
				node.tex:Hide()
			end
		end
	end
	for i = private.curNode+1, private.maxNode do
		node = private.nodes[i]
		if node.tex:IsVisible() then
			node.tex:Hide()
		end
	end

	local pos = 1
	if (get("plugin.gatherer_hud.heat.enable")) then
		local color = get("plugin.gatherer_hud.heat.color")
		local r, g, b, a = strsplit(",", tostring(color) or "0,0,0,1")
		r = tonumber(r) or 0
		g = tonumber(g) or 0
		b = tonumber(b) or 0

		local maxExtentX = maxYards/xScale
		local maxExtentY = maxYards/yScale

		local delta, gx, gy
		local heatTrailSize = get("plugin.gatherer_hud.heat.size") + 20
		local size = heatTrailSize * ratio
		for index, gridTime in pairs(grid) do
			delta = now - gridTime
			if (delta >= heatTime) then
				grid[index] = nil
			else
				gx = ((index % gridres) + 0.5) / gridres
				gy = (math.floor(index / gridres) + 0.5) / gridres
				if (
					gx > px - maxExtentX and gx < px + maxExtentX and
					gy > py - maxExtentY and gy < py + maxExtentY
				) then
					dx = (gx - px) * xScale
					dy = (gy - py) * yScale
					d = math.sqrt(dx*dx + dy*dy)

					if (d < maxYards) then
						angle = math.atan2(dx, -dy)
						newangle = angle + facing

						dx = d * math.sin(newangle);
						dy = d * math.cos(newangle);

						node = private.heat[pos]
						if not node then
							node = frame.heat:CreateTexture()
							node:SetTexture("Interface\\AddOns\\Gatherer_HUD\\HudShape")
							private.heat[pos] = node
						end
						node:SetVertexColor(r, g, b)
						pos = pos + 1

						pct = d/maxYards
						if (pct > fadeAt) then
							pct = (1-pct)/(1-fadeAt)
						else
							pct = 1
						end

						pct = pct * (1 - (delta / heatTime))

						local fb = dy/maxYards/2 + 0.5
						newsize = size - size*fb*reduce
						newalpha = pct - pct*(1-fb)*reduce

						dx = dx * ratio
						dy = dy * ratio * aspect

						node:SetAlpha(newalpha)
						node:ClearAllPoints()
						node:SetPoint("CENTER", frame, "CENTER", dx, dy)
						node:SetWidth(newsize)
						node:SetHeight(newsize * aspect)
						if not node:IsVisible() then
							node:Show()
						end
					end
				end
			end
		end
	end

	while private.heat[pos] do
		if private.heat[pos]:IsVisible() then
			private.heat[pos]:Hide()
		end
		pos = pos + 1
	end
end


function Gatherer_HUD.RunUpdate(delay)
	private.elapsed = private.elapsed + delay
	local rate = GetFramerate()
	
	if not private.started then
		if private.elapsed < 30 and rate < 5 then return end
		private.started = true
	end
	
	if not private.interval then
		private.interval = 1
	end

	local min_fullframerate = get("plugin.gatherer_hud.min_fullframerate")

	local interval = 0
	if rate > min_fullframerate or min_fullframerate == 0 then 
		private.interval = 0
	else
		if     (rate > (min_fullframerate/4)) then interval = rate/2
		elseif (rate > (min_fullframerate/8)) then interval = rate/4
		elseif (rate > (min_fullframerate/12)) then interval = 1
		elseif (rate > (min_fullframerate/16)) then interval = 0.5
		else interval = 0.01 end
		
		private.interval = ((private.interval * 100) + interval) / 101
	end
	
	if private.interval == 0 or private.elapsed > 1/private.interval then
		private.elapsed = 0
		lib.Render()
	end
end
