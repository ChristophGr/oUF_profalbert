local oUF = select( 2, ... ).oUF or _G[ assert( GetAddOnMetadata( ..., "X-oUF" ), "X-oUF metadata missing in parent addon." ) ]
assert( oUF, "Unable to locate oUF." );

local UPDATE_TIME = 3

local function updateAllElements(frame)
	for _, v in ipairs(frame.__elements) do
		v(frame, 'UpdateElement', frame.unit)
	end
end

local eventFrame = CreateFrame('Frame')
local timerFrame = CreateFrame('Frame')

eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")

local vehicleWatch = {}

local function updateVehicleFix(self, elapsed)
	for frame,value in pairs(vehicleWatch) do
		local newValue = value + elapsed
		if newValue > UPDATE_TIME then
			vehicleWatch[frame] = nil
		else
			vehicleWatch[frame] = value + elapsed
		end
		-- only update every second
		if math.floor(newValue) ~= math.floor(value) then
			print("updating ", frame:GetName(), " ", value)
			updateAllElements(frame)
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