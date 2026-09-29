--[[

	Report for Gatherer

]]

local filterName = "By Type"

local function filterFunction(parameter, continent, zone, nodeid, index, x,y, count, harvest, inspect, source, gtype)
	local nodeName = Gatherer.Util.GetNodeName(nodeid)
	if (nodeName:lower():find(parameter:lower(), 1, true)) then return true end
	return false
end

Gatherer.Report.AddButton(filterName, filterFunction)
