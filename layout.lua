--[[-------------------------------------------------------------------------
  Trond A Ekseth grants anyone the right to use this work for any purpose,
  without any conditions, unless such conditions are required by law.
---------------------------------------------------------------------------]]

local LSM = LibStub("LibSharedMedia-3.0")

local _TEXTURE = LSM:Fetch("statusbar", "Perl v2")
local defaultfont = LSM:Fetch("font", "Arial Narrow")
local cbfont = LSM:Fetch("font", "Tw_Cen_MT_Bold")
local bigfont = LSM:Fetch("font", "Diablo")

local colors = setmetatable({
	health = {.45, .73, .27},
	power = setmetatable({
		['MANA'] = {.27, .53, .73},
		['RAGE'] = {.73, .27, .27},
	}, {__index = oUF.colors.power}),
}, {__index = oUF.colors})

local menu = function(self)
	local unit = self.unit:sub(1, -2)
	local cunit = self.unit:gsub("^%l", string.upper)

	if(cunit == 'Vehicle') then
		cunit = 'Pet'
	end

	if(unit == "party" or unit == "partypet") then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	elseif(_G[cunit.."FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
	end
end

function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

local siValueShort = function(val)
	if(val >= 1e7) then
		return ("%dm"):format(round(val / 1e6))
	elseif(val >= 1e6) then
		return ("%.1fm"):format(round(val / 1e6), 1)
	elseif(val >= 1e4) then
		return ("%dk"):format(round(val / 1e3))
	elseif(val >= 1e3) then
		return ("%.1fk"):format(round(val / 1e3, 1))
	else
		return val
	end
end

local siValue = function(val)
	if(val >= 1e7) then
		return ("%dm"):format(round(val / 1e6))
	elseif(val >= 1e6) then
		return ("%.1fm"):format(round(val / 1e6), 1)
	elseif(val >= 1e5) then
		return ("%dk"):format(round(val / 1e3))
	else
		return val
	end
end

oUF.Tags['classic:health'] = function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return siValue(UnitHealth(unit)) .. '/' .. siValue(UnitHealthMax(unit))
end
oUF.TagEvents['classic:health'] = oUF.TagEvents.missinghp

oUF.Tags['profalbert:curhp'] = function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return siValue(UnitHealth(unit))
end
oUF.TagEvents['profalbert:curhp'] = oUF.TagEvents.missinghp

oUF.Tags['profalbert:maxhp'] = function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return siValue(UnitHealthMax(unit))
end
oUF.TagEvents['profalbert:maxhp'] = oUF.TagEvents.missinghp

oUF.Tags['profalbert:perhp'] = function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	local val = UnitHealth(unit) / UnitHealthMax(unit) * 100
	return round(val, 1)
end
oUF.TagEvents['profalbert:perhp'] = oUF.TagEvents.missinghp


oUF.Tags['profalbert:power'] = function(unit)
	local min, max = UnitPower(unit), UnitPowerMax(unit)
	--if(min == 0 or max == 0 or not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return ("%d/%d"):format(min, max)
	--return siValue(min) .. '/' .. siValue(max)
end
oUF.TagEvents['classic:power'] = oUF.TagEvents.missingpp

oUF.Tags['profalbert:difficulty'] = function(u)
		local l = UnitLevel(u)
		return Hex(GetQuestDifficultyColor((l > 0) and l or 99))
	end

local PostUpdateHealth = function(health, unit, min, max)
	--[[local self = health:GetParent()
	if(UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) or not UnitIsConnected(unit)) then
		self:SetBackdropBorderColor(.3, .3, .3)
	else
		local r, g, b = UnitSelectionColor(unit)
		self:SetBackdropBorderColor(r, g, b)
	end

	if(UnitIsDead(unit)) then
		health:SetValue(0)
	elseif(UnitIsGhost(unit)) then
		health:SetValue(0)
	end--]]
end

local PostUpdatePower = function(power, unit,min, max)
	if(UnitIsDead(unit) or UnitIsGhost(unit)) then
		power:SetValue(0)
	end
end

local backdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true,
	tileSize = 16,
	insets = {
		left = -1.5,
		right = -1.5,
		top = -1.5,
		bottom = -1.5
	},
}

local function getBoundedHeight(height)
	if height < 11 then
		return 11
	elseif height > 13 then
		return 13
	else
		return height
	end
end

local function getFontStringHeight(parent)
	if parent.GetHeight then
		local height = parent:GetHeight()
		return getBoundedHeight(height)
	else
		return 10
	end
end

local function getFontString(parent, font)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	local height = getFontStringHeight(parent)
	
	fs:SetFont(font or defaultfont, height)
	fs:SetShadowColor(0,0,0)
	fs:SetShadowOffset(0.8, -0.8)
	fs:SetTextColor(1,1,1)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function applyPoints(self, points)
	if not points then return end
	for _, v in ipairs(points) do
		self:SetPoint(unpack(v))
	end
end

local function makeCommon(self, settings)
	self.menu = menu

	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

	self:RegisterForClicks"anyup"
	self:SetAttribute("*type2", "menu")

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(.3, .3, .3, 1)

	self:SetAttribute("initial-width", settings["initial-width"] or 240)
	self:SetAttribute("initial-height", settings["initial-height"] or 60)
end

local function makeBlankBar(self, height)
	local bb = CreateFrame("StatusBar", nil, self)
	bb:SetHeight(height)
	bb:SetPoint("TOPLEFT")
	bb:SetPoint("TOPRIGHT")
	self.Info = bb
	return bb
end

local function makeHealthBar(self, height, anchors) -- above, portrait, right)
	local Health = CreateFrame("StatusBar", nil, self)
	Health:SetHeight(height or 20)
	Health:SetStatusBarTexture(_TEXTURE)
	
	Health:SetPoint("TOP")
	--Health:SetPoint("BOTTOM")
	Health:SetPoint("LEFT")
	Health:SetPoint("RIGHT")

	applyPoints(Health, anchors)

	Health.frequentUpdates = true
	Health.colorDisconnected = true
	Health.colorTapping = true
	Health.colorHappiness = true
	Health.colorSmooth = true

	Health.PostUpdate = PostUpdateHealth
	Health.colorTapping = true
	Health.colorDisconnected = true

	self.Health = Health

	-- Health bar background
	local HealthBackground = Health:CreateTexture(nil, "BORDER")
	HealthBackground:SetAllPoints(Health)
	HealthBackground:SetAlpha(.5)
	HealthBackground:SetTexture(_TEXTURE)
	Health.bg = HealthBackground
	return Health
end

local function makeHealthValue(self, tag, point)
	local HealthPoints = getFontString(self.Health)
	if point then
		HealthPoints:SetPoint(unpack(point))
	else
		HealthPoints:SetPoint("CENTER")
	end

	self:Tag(HealthPoints, tag)

	self.Health.value = HealthPoints
end

local function makeHealthValue2(self, tag)
	local HealthPoints = getFontString(self.Health)
	HealthPoints:SetPoint("CENTER")
	
	self:Tag(HealthPoints, tag)

	self.Health.value = HealthPoints
end

local function makeLeader(self)
	local Leader = self:CreateTexture(nil, "OVERLAY")
	Leader:SetSize(16, 16)
	Leader:SetPoint("BOTTOM", self, "TOP", 0, -7)
	self.Leader = Leader
	return Leader
end

local function makeResting(self)
	local resting = self.Health:CreateTexture(nil, "OVERLAY") -- use self.Health so that it comes before the portrait
	resting:SetHeight(16)
	resting:SetWidth(16)
	resting:SetPoint("BOTTOMLEFT", self, -8, -8)
	resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
	self.Resting = resting
end

local function Portrait(self)
	local portrait = CreateFrame("PlayerModel", nil, self)
	portrait:SetBackdropColor(0, 0, 0, .7)
	portrait:SetWidth(34)
	portrait:SetHeight(34)
	if self.unit == "target" then
		portrait:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
	else
		portrait:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
	end
	
	local fallback = portrait:CreateTexture()
	fallback:SetAllPoints(portrait)
	portrait.fallback = fallback
	self.Portrait2 = portrait
	return portrait
end

local DoPower = function(self, anchors)
	-- Power bar
	local Power = CreateFrame("StatusBar", nil, self)
	Power:SetHeight(12)
	Power:SetStatusBarTexture(_TEXTURE)

	Power:SetPoint("LEFT")
	Power:SetPoint("RIGHT")
	Power:SetPoint("BOTTOM")

	applyPoints(Power, anchors)

	Power.colorPower = true
	Power.frequentUpdates = true

	self.Power = Power

	-- Power bar background
	local PowerBackground = Power:CreateTexture(nil, "BORDER")
	PowerBackground:SetAllPoints(Power)
	PowerBackground:SetAlpha(.5)
	PowerBackground:SetTexture(_TEXTURE)
	Power.bg = PowerBackground

	return Power
end

local function makePowerValue(self, tag)
	local PowerPoints = getFontString(self.Power)
	PowerPoints:SetPoint("CENTER")
	PowerPoints:SetJustifyH("CENTER")

	self:Tag(PowerPoints, tag or '[profalbert:power]')

	self.Power.value = PowerPoints
	self.Power.PostUpdate = PostUpdatePower
end

local function makePortrait(self)
	local portrait = Portrait(self)
	if self.unit == "target" then -- do it on the right for the target
		self.Health:SetPoint("RIGHT", portrait, "LEFT")
		self.Power:SetPoint("RIGHT", portrait, "LEFT")
	else
		self.Health:SetPoint("LEFT", portrait, "RIGHT")
		self.Power:SetPoint("LEFT", portrait, "RIGHT")
	end
end

local function makeInfoText(self, tag)
	local Name = getFontString(self.Info)
	Name:SetPoint("LEFT", self.Info, "LEFT")

	self:Tag(Name, tag ) -- '[profalbert:difficulty][level][shortclassification] [raidcolor][name]'
	self.Name = Name
end

local function Shared(self, settings)
	makeCommon(self, settings)
	local bbheight = settings["bb-height"] or settings["initial-height"] - settings["hp-height"] - settings["pp-height"]
	
	local bb = makeBlankBar(self, bbheight)
	if settings["info-tag"] then
		makeInfoText(self, settings["info-tag"])
	end
	local anchors = {
		{ "TOP", bb, "BOTTOM", },
	}
	local Health = makeHealthBar(self, settings["hp-height"] or 25, anchors)
	if settings["hp-tag"] then
		makeHealthValue(self, settings["hp-tag"], settings["hp-point"])
	end
	anchors[1] = { "TOP", Health, "BOTTOM", }
	local Power = DoPower(self, anchors)
	if settings["pp-tag"] then
		makePowerValue(self, settings["pp-tag"])
	end
end

--[[local Shared = function(self, settings)
	makeCommon(self, settings)
	local bb = makeBlankBar(self)
	local Health = makeHealthBar(self)
	makeLeader(self)
end--]]

--[[local function makeHealthOnly(self)
	makeCommon(self)
	local bb = makeBlankBar(self)
	local points = {
		{ "TOP", bb, "BOTTOM", },
		{ "BOTTOM", },
	}
	local Health = makeHealthBar(self, points)
end--]]

local DoAuras = function(self)
	if true then return end
	-- Buffs
	local Buffs = CreateFrame("Frame", nil, self)
	Buffs:SetPoint("BOTTOM", self, "TOP")
	Buffs:SetPoint'LEFT'
	Buffs:SetPoint'RIGHT'
	Buffs:SetHeight(17)

	Buffs.size = 17
	Buffs.num = math.floor(self:GetAttribute'initial-width' / Buffs.size + .5)

	self.Buffs = Buffs

	-- Debuffs
	local Debuffs = CreateFrame("Frame", nil, self)
	Debuffs:SetPoint("TOP", self, "BOTTOM")
	Debuffs:SetPoint'LEFT'
	Debuffs:SetPoint'RIGHT'
	Debuffs:SetHeight(20)

	Debuffs.initialAnchor = "TOPLEFT"
	Debuffs.size = 20
	Debuffs.showDebuffType = true
	Debuffs.num = math.floor(self:GetAttribute'initial-width' / Debuffs.size + .5)

	self.Debuffs = Debuffs
end

local big = {
	["initial-width"] = 140,
	["initial-height"] = 48,
	["hp-height"] = 22,
	["hp-point"] = { "RIGHT" },
	["pp-height"] = 12,
	["hp-tag"] = '[dead][offline][profalbert:curhp]/[profalbert:maxhp] |cffcc3333[profalbert:perhp]%|r',
	["pp-tag"] = '[profalbert:power]',
	["info-tag"] = '[profalbert:difficulty][level][shortclassification] [raidcolor][name]',
}

local small = {
	["initial-width"] = 80,
	["initial-height"] = 30,
	["hp-height"] = 16,
	["pp-height"] = 4,
	["hp-point"] = { "CENTER" },
	["info-tag"] = '[raidcolor][name]',
}

local focus = {
	["initial-width"] = 90,
	["initial-height"] = 35,
	["hp-height"] = 18,
	["pp-height"] = 4,
	["hp-point"] = { "CENTER" },
	["hp-tag"] = '[dead][profalbert:curhp]/[profalbert:maxhp]',
	["info-tag"] = '[profalbert:difficulty][level][shortclassification] [raidcolor][name]',
}

local UnitSpecific = {
	target = function(self)
		Shared(self, big)
		makePortrait(self)
		DoAuras(self)
	end,

	targettarget = function(self)
		local settings = CopyTable(small)
		settings["hp-point"] = { "RIGHT", }
		settings["hp-tag"] = "[profalbert:curhp] |cffcc3333[profalbert:perhp]%|r"
		Shared(self, settings)
		DoAuras(self)
	end,
	player = function(self)
		local settings = CopyTable(big)
		settings["hp-point"] = nil
		settings["hp-tag"] = '[dead][profalbert:curhp]/[profalbert:maxhp]'
		Shared(self, settings)
		--[[self.Health.value:ClearAllPoints()
		self.Health.value:SetPoint("RIGHT")--]]
		
		makePortrait(self)
		makeResting(self)
		makeLeader(self)
		--DoPower(self)
--		self:RegisterEvent("PLAYER_UPDATE_RESTING", PLAYER_UPDATE_RESTING)
	end,
	focus = function(self)
		Shared(self, focus)
	end,
	focustarget = function(self)
		local settings = CopyTable(small)
		settings["hp-tag"] = "[profalbert:curhp] |cffcc3333[profalbert:perhp]%|r"
		settings["hp-point"] = { "RIGHT", }
		Shared(self, settings)
	end,
	party = function(self)
		Shared(self, big)
		makePortrait(self)
		makeLeader(self)
	end,
}

oUF:RegisterStyle("Classic", function(self, unit)
	Shared(self, small)
end)
for unit,layout in next, UnitSpecific do
	-- Capitalize the unit name, so it looks better.
	oUF:RegisterStyle('Classic - ' .. unit:gsub("^%l", string.upper), layout)
end

-- A small helper to change the style into a unit specific, if it exists.
local spawnHelper = function(self, unit, ...)
	if(UnitSpecific[unit]) then
		self:SetActiveStyle('Classic - ' .. unit:gsub("^%l", string.upper))
		local object = self:Spawn(unit)
		object:SetPoint(...)
		return object
	else
		self:SetActiveStyle'Classic'
		local object = self:Spawn(unit)
		object:SetPoint(...)
		return object
	end
end

oUF:Factory(function(self)
	local player = spawnHelper(self, 'player', "RIGHT", UIParent, "CENTER", -80, -230)
	spawnHelper(self, 'pet', "BOTTOMRIGHT", player, "TOPLEFT", -25, -10)
	local target = spawnHelper(self, 'target',"LEFT", UIParent, "CENTER", 80, -230)
	spawnHelper(self, 'targettarget', "BOTTOMLEFT", target, "TOPRIGHT", 25, 10)

	local focus = spawnHelper(self, 'focus', "TOPLEFT", UIParent, "TOPLEFT", 320, -240)
	spawnHelper(self, 'focustarget', "LEFT", focus, "RIGHT", 25, 0)

	self:SetActiveStyle'Classic - Party'
	local party = self:SpawnHeader(nil, nil, 'party',
		'showParty', true,
		'yOffset', -40,
		'xOffset', -40,
		'maxColumns', 2,
		'unitsPerColumn', 2,
		'columnAnchorPoint', 'LEFT',
		'columnSpacing', 15
	)
	party:SetPoint("TOPLEFT", 30, -30)
end)
