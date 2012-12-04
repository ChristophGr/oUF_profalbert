local oUF = _G.oUF
assert(oUF, "oUF not found")

local ABSORB_SPELLS = {
	[GetSpellInfo(112048)] = true, -- Shield Barrier
	[GetSpellInfo(20925)] = true, -- Sacred Shield
	[GetSpellInfo(66099)] = true, -- Power Word: Shield
	[GetSpellInfo(47515)] = true, -- Divine Aegis
	[GetSpellInfo(11426)] = true, -- Ice Barrier
	[GetSpellInfo(56778)] = true, -- Mana Shield
	[GetSpellInfo(7812)] = true, -- Sacrifice
	-- local AB_MW = 'Mage Ward'
	[GetSpellInfo(116631)] = true -- Colossus (Weapon Enchant)
	[GetSpellInfo(118604)] = true -- Guard (Monk)
	[GetSpellInfo(116849)] = true -- Life Cocoon (Monk)
}

local newdata = {}
local function updateAbsorbInfo(unit, data)
	local totalamount = 0
	local totalmax = 0
	local result = newdata
	for i = 1,40 do
		local name, _, icon, count, _, duration, expirationTime, unitCaster, _, 
_, spellId, _, _, _, amount = UnitBuff(unit, i)
		if ABSORB_SPELLS[name] then
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
	if amount > 0 then
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
