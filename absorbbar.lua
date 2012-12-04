local oUF = _G.oUF
assert(oUF, "oUF not found")

local newdata = {}
local function updateAbsorbInfo(unit, data)
	local totalamount = 0
	local totalmax = 0
	local result = newdata
	for i = 1,40 do
		local _, _, icon, count, _, duration, expirationTime, unitCaster, _, 
_, spellId, _, _, _, amount = UnitBuff(unit, i)
		if amount then
			if data[spellId] then
				newdata[spellId] = data[spellId]
				data[spellId] = nil
			else
				newdata[spellId] = amount
			end
			totalamount = totalamount + amount
			totalmax = totalmax + newdata[spellId]
		end
	end
	newdata = wipe(data)
	return totalamount, totalmax, result
end

local Update = function(self, event, unit)
	if(not unit or not UnitIsUnit(self.unit, unit)) then return end
	print("updating AbsorbBar")
	local absorb = self.Absorb
	local amount, max, data = updateAbsorbInfo(unit, absorb.data)
	absorb.data = data
	if amount then
		absorb:SetMinMaxValues(0, max)
		absorb:SetValue(amount)
	else
		absorb:SetValue(0)
	end
end

local Enable = function(self)
	if not self.Absorb then return end
	self.Absorb:SetValue(0)
	self.Absorb:SetMinMaxValues(0,1)
	self.Absorb.data = {}
	self:RegisterEvent("UNIT_AURA", Update)
end

local Disable = function(self)
	if not self.Absorb then return end
	self:UnregisterEvent("Update")
end

oUF:AddElement('Absorb', Update, Enable, Disable)
