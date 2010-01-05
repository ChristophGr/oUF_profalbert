local oUF = _G.oUF
assert(oUF, "oUF not found")

-- how long the OnUpdate should run on the frame after vehicle-state changed
local UPDATE_TIME = 3

local vehicleDelayFrame = CreateFrame('Frame')
local affectedFrames = {}


-- local function print() end

local function updateAllElements(frame)
	for _, v in ipairs(frame.__elements) do
		v(frame, 'UpdateElement', frame.unit)
	end
end

local function forceUpdate(self, elapsed)
	for k,v in pairs(affectedFrames) do
		--print("updating frame ", k:GetName())
		if k.unit and UnitExists(k.unit) then
			updateAllElements(k)
			affectedFrames[k] = nil
			--print(k.unit, " existed after ", elapsed)
			return
		end

		local afterUpdate = v - elapsed
		if afterUpdate < 0 then
			--print("updating finished for ", k:GetName(), " (", afterUpdate, ")")
			afterUpdate = nil
		end
		affectedFrames[k] = afterUpdate
	end
	if not next(affectedFrames) then
		self:Hide()
	end
end
vehicleDelayFrame:SetScript("OnUpdate", forceUpdate)
vehicleDelayFrame:Hide()

local Update = function(self)
	if not self.unit then return end
	local unit = self.unit
	local normalUnit = self:GetAttribute("unit")
	local modunit = SecureButton_GetModifiedUnit(self)
	--print("unit: ", unit, "; modunit: ", modunit)
	if modunit ~= unit then
		self.unit = modunit
		if unit == normalUnit then
			-- not in vehicle
			self.vehicleUnit = nil
		else
			self.vehicleUnit = modunit
		end
		affectedFrames[self] = UPDATE_TIME
		vehicleDelayFrame:Show()
	--[[elseif modunit == unit and self.vehicleUnit then
		self.vehicleUnit = nil
		self.unit = unit
		affectedFrames[self] = UPDATE_TIME
		vehicleDelayFrame:Show()--]]
		print("updating ", self:GetName())
	--[[else
		print("skipping updating ", self:GetName())
		print("unit: ", unit)
		print("modunit: ", modunit)
		print("vehicleUnit: ", self.vehicleUnit)--]]
	end
	
	if unit == "player" then
		PlayerFrame.unit = self.unit
		BuffFrame_Update()
	end
end

local function attrChanged(self, name, value)
	local modunit = SecureButton_GetModifiedUnit(self)
	if self.unit and modunit ~= self.unit then
		self.vehicleUnit = modunit
		self.unit = modunit
		--print(self:GetName(), " HAHAHA, gotcha OnAttributeChanged....")
	end
end

local Enable = function(self, unit)
	-- do not interfere with the default vehicleswitch
	if (unit == "player" or unit == "pet") and not self.disallowVehicleSwap then
		return
	end
	if not self.VehicleSwap2 or not self:GetAttribute("toggleForVehicle") then
		return
	end

	self:RegisterEvent("UNIT_ENTERED_VEHICLE", Update)
	self:RegisterEvent("UNIT_EXITED_VEHICLE", Update)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
	self:HookScript("OnAttributeChanged", attrChanged)
	self:HookScript("OnShow", Update)

	Update(self)
end

local Disable = function(self)
	self.unit = self:GetAttribute("unit")
end

oUF:AddElement("VehicleSwitch2", Update, Enable, Disable)