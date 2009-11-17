local oUF = _G.oUF
assert(oUF, "oUF not found")

local Update = function(self, event, unit)
	if(not UnitIsUnit(self.unit, unit)) then return end

	local portrait = self.Portrait2
	if(portrait:IsObjectType'Model') then
		local name = UnitName(unit)
		if(not UnitExists(unit) or not UnitIsConnected(unit) or not UnitIsVisible(unit)) then
			
			if unit then
				if portrait.fallback then
					SetPortraitTexture(portrait.fallback, unit)
				else
					portrait.fallback:SetTexture("")
				end
			end
			
			portrait:SetModelScale(4.25)
			portrait:SetPosition(0, 0, -1.5)
			
		elseif(portrait.name ~= name or event == 'UNIT_MODEL_CHANGED') then
			if unit then
				portrait.fallback:SetTexture("")
			end
			portrait:SetUnit(unit)
			portrait:SetCamera(0)

			portrait.name = name
		else
			if unit then
				portrait.fallback:SetTexture("")
			end
			portrait:SetCamera(0)
		end
	else
		SetPortraitTexture(portrait, unit)
	end
end

local Enable = function(self)
	if(self.Portrait2) then
		self:RegisterEvent("UNIT_PORTRAIT_UPDATE", Update)
		self:RegisterEvent("UNIT_MODEL_CHANGED", Update)

		return true
	end
end

local Disable = function(self)
	if(self.Portrait2) then
		self:UnregisterEvent("UNIT_PORTRAIT_UPDATE", Update)
		self:UnregisterEvent("UNIT_MODEL_CHANGED", Update)
	end
end

oUF:AddElement('Portrait2', Update, Enable, Disable)
