local oUF = select( 2, ... ).oUF or _G[ assert( GetAddOnMetadata( ..., "X-oUF" ), "X-oUF metadata missing in parent addon." ) ]
assert( oUF, "Unable to locate oUF." );

local MAX_DELAY = 10

local eventFrame = CreateFrame('Frame')
local timerFrame = CreateFrame('Frame')

eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")

local vehicleWatch = {}

local function updateVehicleFix(self, elapsed)
	for frame,value in pairs(vehicleWatch) do
		local newValue = value + elapsed
		if UnitExists(frame.unit) or newValue > MAX_DELAY then
			vehicleWatch[frame] = nil
			frame:UpdateAllElements()
		else
			vehicleWatch[frame] = value + elapsed
		end
	end
	if not next(vehicleWatch) then
		self:Hide()
	end
end
timerFrame:SetScript("OnUpdate", updateVehicleFix)

local function handleVehicleEvent(self, event, unit)
	local frame = oUF.units[unit]
	if not frame then
		return
	end
	vehicleWatch[frame] = 0
	timerFrame:Show()
end
eventFrame:SetScript("OnEvent", handleVehicleEvent)

timerFrame:Hide()
eventFrame:Show()