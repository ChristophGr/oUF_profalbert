--[[
* review health-tags (death)
* pet-update-fix?
* mana-color (tiny-bars)
* bigger in 10-man
* indicate hostile raidmembers
* combo-points
* fix warlock pet vehicle
* boss-hp-tags
--]]

local name, ns = ...
local oUF = ns.oUF or _G[ assert( GetAddOnMetadata(name, "X-oUF"), "X-oUF metadata missing in parent addon.")]
assert( oUF, "Unable to locate oUF." )

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

-- AbbreviateLargeNumbers
local siValueShort = function(val)
	if(val >= 1e7) then
		return ("%dm"):format(round(val / 1e6))
	elseif(val >= 1e6) then
		return ("%sm"):format(round(val / 1e6, 1))
	elseif(val >= 1e4) then
		return ("%dk"):format(round(val / 1e3))
	elseif(val >= 1e3) then
		return ("%sk"):format(round(val / 1e3, 1))
	else
		return val
	end
end

local siValue = function(val)
	if(val >= 1e7) then
		return ("%dm"):format(round(val / 1e6))
	elseif(val >= 1e6) then
		return ("%sm"):format(round(val / 1e6, 1))
	elseif(val >= 1e5) then
		return ("%dk"):format(round(val / 1e3))
	else
		return val
	end
end

local function makeHealthTag(name, func)
	oUF.Tags.Methods[name] = func
	oUF.Tags.Events[name] = oUF.Tags.Events.missinghp
end

oUF.Tags.Methods["profalbert:dead"] = function(u)
	if UnitHasIncomingResurrection(u) then
		if unit == "player" then
			 return string.format('Rez %s', ResurrectGetOfferer())
		end
		return 'Rezzing'
	elseif(UnitIsDead(u)) then
		return 'Dead'
	elseif(UnitIsGhost(u)) then
		return 'Ghost'
	end
end
oUF.Tags.Events["profalbert:dead"] = "UNIT_HEALTH INCOMING_RESURRECT_CHANGED"

local function healthOrAFK(unit, orig)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	local min, max = UnitHealth(unit), UnitHealthMax(unit)
	if UnitIsAFK(unit) then
		if min == max then
			return AFK
		else
			return ("|cff000000%s/%s|r"):format(siValue(min), siValue(max))
		end
	else
		return ("%s/%s"):format(siValue(min), siValue(max))
	end
end

makeHealthTag("profalbert:Health", healthOrAFK)

local function missinghp(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	local current = UnitHealthMax(unit) - UnitHealth(unit)
	if(current > 0) then
		return ("|cffff8080-%s|r"):format(siValue(current))
	end
end
makeHealthTag("profalbert:missinghp", missinghp)

local function perhp(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	local val = UnitHealth(unit) / UnitHealthMax(unit) * 100
	return ("|cffcc3333%s%%|r"):format(round(val, 1))
end

makeHealthTag("profalbert:HealthWithPer", function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	local min, max = UnitHealth(unit), UnitHealthMax(unit)
	if UnitIsAFK(unit) and min == max then
		return AFK
	else
		return ("%s %s"):format(healthOrAFK(unit),perhp(unit))
	end
end)

makeHealthTag("profalbert:curhp", function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return siValue(UnitHealth(unit))
end)

makeHealthTag("profalbert:maxhp", function(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return siValue(UnitHealthMax(unit))
end)

makeHealthTag("profalbert:perhp", perhp)

local function hpshort(unit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return ("%s/%s"):format(siValueShort(UnitHealth(unit)), siValueShort(UnitHealthMax(unit)))
end
makeHealthTag("profalbert:hpshort", hpshort)

makeHealthTag("profalbert:raidhp", function(unit, origUnit)
	if(not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	if origUnit then
		return hpshort(unit)
	else
		local min, max = UnitHealth(unit), UnitHealthMax(unit)
		if UnitIsAFK(unit) then
			if min == max then
				return AFK
			else
				return ("|cff000000%s|r"):format(siValue(min - max))
			end
		else
			return missinghp(unit)
		end
	end
end)

oUF.Tags.Methods['profalbert:power'] = function(unit)
	local min, max = UnitPower(unit), UnitPowerMax(unit)
	--if(min == 0 or max == 0 or not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then return end
	return ("%s/%s"):format(min, max)
	--return siValue(min) .. '/' .. siValue(max)
end
oUF.Tags.Events['profalbert:power'] = oUF.Tags.Events.missingpp

oUF.Tags.Methods['profalbert:difficulty'] = function(u)
	local l = UnitLevel(u)
	return Hex(GetQuestDifficultyColor((l > 0) and l or 99))
end

local function hex(color)
	if not color then return "|cffffffff" end
	local r = math.floor(color.r * 255)
	local g = math.floor(color.g * 255)
	local b = math.floor(color.b * 255)
	return("|cff%02x%02x%02x"):format(r,g,b)
end

local function raidcolor(unit)
	local color = { r = 1, g = 1, b = 1, }
	if UnitIsPlayer(unit) then
		color = RAID_CLASS_COLORS[select(2, UnitClass(unit))] or white
	else
		color = FACTION_BAR_COLORS[UnitReaction("player", unit)]
	end
	return hex(color)
end

oUF.Tags.Methods["profalbert:raidcolor"] = raidcolor

oUF.Tags.Methods["profalbert:name"] = function(unit, originalUnit)
	if not originalUnit then
		return UnitName(unit)
	end
	if unit == "vehicle" or unit:match("pet") then
		return ("%s%s|r's %s%s"):format(raidcolor(originalUnit) or "", UnitName(originalUnit) or "", raidcolor(unit) or "", UnitName(unit) or "")
	else
		return UnitName(unit)
	end
end
oUF.Tags.Events["profalbert:name"] = "UNIT_NAME_UPDATE UNIT_ENTERING_VEHICLE UNIT_ENTERED_VEHICLE UNIT_EXITING_VEHICLE UNIT_EXITED_VEHICLE PARTY_MEMBERS_CHANGED"

local PreUpdateHealth = function(health, unit)
	health.colorReaction = not UnitIsPlayer(unit) and not UnitIsUnit(unit, "pet") and not UnitIsUnit(unit, "vehicle")
end

local PostUpdateHealth = function(health, unit, min, max)
	local self = health:GetParent()
	if(UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) or not UnitIsConnected(unit)) then
		health:SetStatusBarColor(.3, .3, .3)
	end

	if(UnitIsDead(unit)) then
		health:SetValue(0)
	elseif(UnitIsGhost(unit)) then
		health:SetValue(0)
	end
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
	self:SetSize(settings["initial-width"] or 240, settings["initial-height"] or 60)
end

local function makeRaidIcons(self)
	local icon = self:CreateTexture(nil, "OVERLAY")
	icon:SetHeight(16)
	icon:SetWidth(16)
	icon:SetPoint("CENTER", self, "TOP")
	self.RaidIcon = icon
end

local function makeBlankBar(self, height)
	local bb = CreateFrame("StatusBar", nil, self)
	bb:SetHeight(height)
	bb:SetPoint("TOPLEFT")
	bb:SetPoint("TOPRIGHT")
	self.Info = bb
	return bb
end

local function makeHealComm(self)
	self.HealCommBar = CreateFrame('StatusBar', nil, self.Health)
	self.HealCommBar:SetHeight(0)
	self.HealCommBar:SetWidth(0)
	self.HealCommBar:SetStatusBarTexture(self.Health:GetStatusBarTexture():GetTexture())
	self.HealCommBar:SetStatusBarColor(0, 1, 0, 0.5)
	self.HealCommBar:SetPoint('LEFT', self.Health, 'LEFT')

	-- optional flag to show overhealing
	self.allowHealCommOverflow = true
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
	-- Health.colorReaction = true -- does not behave as desired

	Health.PostUpdate = PostUpdateHealth
	Health.PreUpdate = PreUpdateHealth
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
	HealthPoints.frequentUpdates = true
	self:Tag(HealthPoints, tag)

	self.Health.value = HealthPoints
end

local function doBanzai(self, unit, aggro)
	if aggro == 1 then
		self.BanzaiFrame:Show()
	else
		self.BanzaiFrame:Hide()
	end
end

local function makeBanzai(self)
	local frame = CreateFrame('Frame', nil, self)
	local border = LSM:Fetch("border", "Tooltip enlarged")
	local backdrop = {
		edgeFile = border,
		edgeSize = 10
	}
	local height = math.ceil(self:GetHeight() / 10)
	local diff = height or 5
	frame:SetPoint("TOPLEFT", self, "TOPLEFT", -diff, diff)
	frame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", diff, -diff)
	frame:SetBackdrop(backdrop)
	frame:SetBackdropBorderColor(1, 0, 0)
	frame:SetFrameLevel(self:GetFrameLevel() - 1)
    frame.SetVertexColor = frame.SetBackdropBorderColor
	--frame:Hide()
    self.Threat = frame
	--self.BanzaiFrame = frame
	--self.ignoreBanzai = false
	--self.Banzai = doBanzai
end

local function makeLeader(self)
	local Leader = self:CreateTexture(nil, "OVERLAY")
	Leader:SetSize(16, 16)
	Leader:SetPoint("TOPLEFT", self, "TOPLEFT", -8, 8)
	self.Leader = Leader
	return Leader
end

local function makeRange(self)
	self.SpellRange = {
		insideAlpha = 1,
		outsideAlpha = 0.6,
	}
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
	Name:SetPoint("RIGHT", self.Info, "RIGHT")

	self:Tag(Name, tag ) -- '[profalbert:difficulty][level][shortclassification] [raidcolor][name]'
	self.Name = Name
end

local hptags = {
	player = '[profalbert:dead][profalbert:Health]',
	pet = "[profalbert:dead][profalbert:hpshort]",
	target = '[profalbert:dead][offline][profalbert:HealthWithPer]',
	targettarget = "[profalbert:dead][profalbert:curhp] [profalbert:perhp]",
	focus = '[profalbert:dead][offline][profalbert:hpshort]',
	focustarget = "[profalbert:dead][profalbert:curhp] [profalbert:perhp]",
	party = '[profalbert:dead][offline][profalbert:Health] [profalbert:missinghp]',
	partytarget = "[dead][profalbert:curhp] [profalbert:perhp]",
	partypet = '[profalbert:dead][profalbert:Health]',
	raid = "[profalbert:dead][offline][profalbert:raidhp]",
	boss = "[profalbert:dead][profalbert:HealthWithPer]",
	maintank = "[profalbert:dead][offline][profalbert:curhp] [profalbert:missinghp]",
}
hptags.vehicle = hptags.pet

do
	local function getTag(self, key)
		local key2 = key:gsub("%d+","")
		return rawget(self, key2) or "[profalbert:Health]"
	end
	setmetatable(hptags, { __index = getTag, } )
end

local function Shared(self, settings, unit, isSingle)
	local unit = unit or self.unit
	makeCommon(self, settings)
	makeRaidIcons(self)
	self.ignoreBanzai = true
	local bbheight = settings["bb-height"] or settings["initial-height"] - settings["hp-height"] - settings["pp-height"]

	local bb = makeBlankBar(self, bbheight)
	if settings["info-tag"] then
		makeInfoText(self, settings["info-tag"])
	end
	local anchors = {
		{ "TOP", bb, "BOTTOM", },
	}
	local Health = makeHealthBar(self, settings["hp-height"] or 25, anchors)
	if unit then
		makeHealthValue(self, hptags[unit], settings["hp-point"])
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

local makeBuffs = function(self, settings)
	-- Buffs
	local Buffs = CreateFrame("Frame", nil, self)

	Buffs:SetPoint'LEFT'
	Buffs:SetPoint'RIGHT'
	Buffs:SetHeight(16)

	Buffs.size = 16
	for k,v in pairs(settings) do
		Buffs[k] = v
	end

	self.Buffs = Buffs
	return Buffs

end

local function makeDebuffs(self, settings)
	-- Debuffs
	local Debuffs = CreateFrame("Frame", nil, self)
	--Debuffs:SetPoint'LEFT'
	--Debuffs:SetPoint'RIGHT'

	Debuffs:SetPoint("TOPLEFT", self, "TOPRIGHT",1.5,0)
	Debuffs.initialAnchor = "TOPLEFT"
	Debuffs["growth-x"] = "RIGHT"
	Debuffs["growth-y"] = "DOWN"

	Debuffs:SetHeight(settings.size * settings.y)
	Debuffs:SetWidth(settings.size * settings.x)

	Debuffs.size = settings.size
	Debuffs.showDebuffType = true
	Debuffs.num = settings.x * settings.y

	self.Debuffs = Debuffs
end

local big = {
	["initial-width"] = 140,
	["initial-height"] = 48,
	["hp-height"] = 22,
	["pp-height"] = 12,
	["pp-tag"] = '[profalbert:power]',
	["info-tag"] = '[profalbert:difficulty][level][shortclassification] [profalbert:raidcolor][profalbert:name]',
	["buffs"] = {
		num = 6,
		initialAnchor = "TOPLEFT",
		["growth-y"] = "DOWN",
		["growth-x"] = "RIGHT",
		size = 16,
	},
	["debuffs"] = {
		x = 2,
		y = 3,
		size = 20,
	},
}

local small = {
	["initial-width"] = 80,
	["initial-height"] = 30,
	["hp-height"] = 16,
	["pp-height"] = 4,
	["hp-point"] = { "CENTER" },
	["info-tag"] = '[profalbert:raidcolor][profalbert:name]',
}

local focus = {
	["initial-width"] = 90,
	["initial-height"] = 35,
	["hp-height"] = 18,
	["pp-height"] = 4,
	["hp-point"] = { "CENTER" },
	["info-tag"] = '[profalbert:difficulty][level][shortclassification] [profalbert:raidcolor][profalbert:name]',
	["buffs"] = {
		num = 4,
		initialAnchor = "TOPLEFT",
		["growth-y"] = "DOWN",
		["growth-x"] = "RIGHT",
		size = 12,
	},
	["debuffs"] = {
		x = 1,
		y = 3,
		size = 12,
	},
}

local raid = {
	["initial-width"] = 60,
	["initial-height"] = 30,
	["hp-height"] = 18,
	["pp-height"] = 3,
	["info-tag"] = small["info-tag"],
	["debuffs"] = {
		x = 1,
		y = 3,
		size = 10,
	},
}

local function makeEarthShieldIcon(self)
	local spellName, _, texture = GetSpellInfo(974)
	local shieldFrame = CreateFrame('Frame', nil, self)
	shieldFrame:SetHeight(10)
	shieldFrame:SetWidth(10)
	shieldFrame:SetPoint("LEFT", self, "LEFT", -5, 0)

	local shieldIcon = shieldFrame:CreateTexture(nil, "OVERLAY")
	shieldIcon:SetTexture(texture)
	shieldIcon:SetAllPoints(shieldFrame)
	shieldIcon:Hide()
	shieldFrame:RegisterEvent("UNIT_AURA")
	shieldFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	shieldFrame:SetScript("OnEvent", function(self)
		local unit = self:GetParent().unit
		if unit and UnitAura(self:GetParent().unit, spellName) then
			shieldIcon:Show()
		else
			shieldIcon:Hide()
		end
	end)
end

local makePetTTL

do
	local function updatePetFrame(self)
		local time = GetPetTimeRemaining()
		local ttl = self.ttl
		if not time then
			ttl:SetText("")
			self:Hide()
		else
			if time > 1000000 then
				ttl:SetText("")
				return
			elseif time > 20000 then
				ttl:SetTextColor(0, 1, 0) -- green
			elseif time > 10000 then
				ttl:SetTextColor(1, 1, 0) -- yellow
			else
				ttl:SetTextColor(1, 0, 0) -- red
			end
			ttl:SetText(("%.1f"):format(time/1000))
		end
	end

	local function onPetEvent(self)
		if GetPetTimeRemaining() then
			self:Show()
		else
			self:Hide()
		end
	end

	function makePetTTL(self)
		local ttl = getFontString(self)
		ttl:SetPoint("BOTTOM", self, "TOP")
		local petupdateFrame = CreateFrame("Frame")
		petupdateFrame:Hide()
		petupdateFrame:SetScript("OnUpdate", updatePetFrame)
		petupdateFrame:RegisterEvent("UNIT_PET")
		petupdateFrame:SetScript("OnEvent", onPetEvent)
		petupdateFrame.ttl = ttl
	end
end

local function makeMasterlooter(self)
	local masterlooter = self:CreateTexture(nil, "OVERLAY")
	masterlooter:SetHeight(16)
	masterlooter:SetWidth(16)
	masterlooter:SetPoint("TOPRIGHT", self, "TOPRIGHT", 8, 8)
	self.MasterLooter = masterlooter
end

-- lfd-role, raid-targets, readycheck
local function makeLFDRole(self)
	local lfdrole = self.Health:CreateTexture(nil, "OVERLAY")
	lfdrole:SetHeight(16)
	lfdrole:SetWidth(16)
	lfdrole:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -8, -8)
	self.LFDRole = lfdrole
end

local function makeReadyCheck(self)
	local readycheck = self.Health:CreateTexture(nil, "OVERLAY")
	readycheck:SetHeight(16)
	readycheck:SetWidth(16)
	readycheck:SetPoint("TOPLEFT", self, "RIGHT", -8, 8)
	self.ReadyCheck = readycheck
end

local _, playerClass = UnitClass("player")
local function makeDebuffHighlighting(self)
	self.DebuffHighlightBackdrop = true -- oUF_DebuffHighlight Support, using the backdrop
	local unfiltered = (playerClass == "ROGUE" or playerClass == "WARRIOR")
	self.DebuffHighlightFilter = not unfiltered -- only show debuffs I can cure, if I can cure any
end

local function makeQuestIcon(self)
	local frame = CreateFrame('Frame', nil, self)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetTexture[[Interface\TargetingFrame\PortraitQuestBadge]]
	icon:SetAllPoints(frame)
	local size = 16 -- min(self:GetHeight(), self:GetWidth()) / 2
	frame:SetWidth(size)
	frame:SetHeight(size)
	frame:SetPoint("RIGHT", self, "TOPRIGHT")
	frame:SetFrameLevel(self:GetFrameLevel() + 1)
	frame:Hide()
	self.QuestIcon = frame
end
local function makeResComm(self)
	local frame = CreateFrame('Frame', nil, self)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetTexture[[Interface\RaidFrame\Raid-Icon-Rez]]
	icon:SetAllPoints(frame)
	local size = min(self:GetHeight(), self:GetWidth()) / 2
	frame:SetWidth(size)
	frame:SetHeight(size)
	frame:SetPoint("CENTER", self.Health, "CENTER")
	frame:SetFrameLevel(self:GetFrameLevel() + 1)
	frame:Hide()
	self.ResurrectIcon = frame
end
local function makePhaseIcon(self)
	local frame = CreateFrame('Frame', nil, self)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetTexture[[Interface\TargetingFrame\UI-PhasingIcon]]
	icon:SetAllPoints(frame)
	local size = min(self:GetHeight(), self:GetWidth()) / 2
	frame:SetWidth(size)
	frame:SetHeight(size)
	frame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 5, -5)
	frame:SetFrameLevel(self:GetFrameLevel() + 1)
	frame:Hide()
	self.PhaseIcon = frame
	-- forcing updates as UNIT_PHASE is not always fired correctly
	local helperFrame = CreateFrame('Frame')
	helperFrame:SetScript("OnUpdate", function()
		if not UnitExists(self.unit) or not self:IsShown() then
			frame:Hide()
			return
		end
		frame:ForceUpdate()
	end)
end
local function makeBackground(self)
	local wbBackground = self:CreateTexture(nil, "BORDER")
	wbBackground:SetAllPoints(self)
	wbBackground:SetAlpha(.5)
	wbBackground:SetTexture(_TEXTURE)
	self.bg = wbBackground
end
local class = select(2, UnitClass('player'))
local function makeClassSpecific(self)
	if class == "WARLOCK" then
		-- Warlock Spec Bars
		if select(2, UnitClass("player")) == "WARLOCK" then
			local wb = CreateFrame("Frame", "TukuiWarlockSpecBars", self)
			wb:SetHeight(8)
			wb:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
			wb:SetWidth(self:GetWidth())
			wb:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
			wb[1] = CreateFrame("StatusBar", "TukuiWarlockSpecBars1", wb)
			wb[1]:SetStatusBarTexture(_TEXTURE)
			makeBackground(wb[1])
			wb[1]:SetPoint("LEFT", wb, "LEFT", 0, 0)
			wb[1]:SetPoint("BOTTOMLEFT", wb, "BOTTOMLEFT")
			wb[1]:SetPoint("TOPLEFT", wb, "TOPLEFT")
			wb[1]:SetWidth(self:GetWidth() / 4)
			for i = 2, 4 do
				wb[i] = CreateFrame("StatusBar", "TukuiWarlockSpecBars"..i, wb)
				wb[i]:SetStatusBarTexture(_TEXTURE)
				wb[i]:SetPoint("TOPLEFT", wb[i-1], "TOPRIGHT", 1, 0)
				wb[i]:SetPoint("BOTTOMLEFT", wb[i-1], "BOTTOMRIGHT", 1, 0)
				makeBackground(wb[i])
			end
			self.WarlockSpecBars = wb
		end
	end
end

local function makeComboPoints(self)
	if class=="DRUID" or class=="ROGUE" then
		-- Druid/rogue combo points
		local cpoints = {}
		for i = 1, MAX_COMBO_POINTS do
			cpoints[i] = self.Power:CreateTexture(nil, 'OVERLAY')
			cpoints[i]:SetSize(15,19)
		end
		cpoints[3]:SetPoint("TOP", self, "BOTTOM", 0, -1)
		cpoints[2]:SetPoint("RIGHT", cpoints[3], 'LEFT', -10)
		cpoints[1]:SetPoint("RIGHT", cpoints[2], 'LEFT', -10)
		cpoints[4]:SetPoint("LEFT", cpoints[3], 'RIGHT', 10)
		cpoints[5]:SetPoint("LEFT", cpoints[4], 'RIGHT', 10)
		self.CPoints = cpoints
	end
end

local UnitSpecific = {
	target = function(self, ...)
		local settings = CopyTable(big)
		settings["hp-point"] = { "RIGHT" },
		Shared(self, settings, ...)
		makePortrait(self)
		local buffs = makeBuffs(self, settings.buffs)
		buffs:SetPoint("TOP", self, "BOTTOM")
		makeDebuffs(self, settings.debuffs)
		makeComboPoints(self)
		makePhaseIcon(self)
		makeQuestIcon(self)
	end,
	targettarget = function(self, ...)
		local settings = CopyTable(small)
		settings["hp-point"] = { "RIGHT", }
		Shared(self, settings, ...)
		--DoAuras(self)
		makePhaseIcon(self)
	end,
	player = function(self, ...)
		local settings = CopyTable(big)
		settings["hp-point"] = nil
		Shared(self, settings, ...)
		--[[self.Health.value:ClearAllPoints()
		self.Health.value:SetPoint("RIGHT")--]]

		makePortrait(self)
		makeResting(self)
		makeLeader(self)
		makeMasterlooter(self)
		makeLFDRole(self)
		makeReadyCheck(self)
		makeDebuffHighlighting(self)
		makeBanzai(self)
		makeHealComm(self)
		makeResComm(self)
		makeClassSpecific(self)
		makeComboPoints(self)

		RuneFrame:ClearAllPoints()
		RuneFrame:SetPoint("BOTTOM", self, "TOP", 0, 5)
		--DoPower(self)
--		self:RegisterEvent("PLAYER_UPDATE_RESTING", PLAYER_UPDATE_RESTING)
	end,
	focus = function(self, ...)
		Shared(self, focus, ...)
		makeRange(self)
		local buffs = makeBuffs(self, focus.buffs)
		buffs:SetPoint("TOP", self, "BOTTOM")
		makeDebuffs(self, focus.debuffs)
		makeDebuffHighlighting(self)
	end,
	focustarget = function(self, ...)
		local settings = CopyTable(small)
		settings["hp-point"] = { "RIGHT", }
		Shared(self, settings, ...)
	end,
	party = function(self, ...)
		Shared(self, big, ...)
		makePortrait(self)
		makeLeader(self)
		makeRange(self)
		makeMasterlooter(self)
		makeLFDRole(self)
		makeDebuffs(self, big.debuffs)
		makeDebuffHighlighting(self)
		makeBanzai(self)
		makeHealComm(self)
		makeResComm(self)
		makePhaseIcon(self)
		makeQuestIcon(self)
	end,
	pet = function(self, ...)
		local settings = CopyTable(small)
		Shared(self, settings, ...)
		makeDebuffHighlighting(self)
		makeBanzai(self)
		makePetTTL(self)
		makeHealComm(self)
		makePhaseIcon(self)
	end,
	raid = function(self, ...)
		Shared(self, raid, ...)
		self.Health.colorReaction = true
		makeLeader(self)
		makeRange(self)
		makeEarthShieldIcon(self)
		makeMasterlooter(self)
		makeReadyCheck(self)
		makeDebuffs(self, raid.debuffs)
		makeDebuffHighlighting(self)
		makeBanzai(self)
		makeHealComm(self)
		makeResComm(self)
        makeLFDRole(self)
		makePhaseIcon(self)
	end,
	maintank = function(self, ...)
		local settings = CopyTable(small)
		settings["hp-point"] = { "RIGHT", }
		Shared(self, settings, ...)
		makeRange(self)
		--self:Tag(self.Health.value, hptags.maintank)
		makeEarthShieldIcon(self)
		makeReadyCheck(self)
		makeDebuffHighlighting(self)
		makeBanzai(self)
		makeHealComm(self)
		makeResComm(self)
		makePhaseIcon(self)
		makeQuestIcon(self)
	end,
}

--[[
registering style:  Classic - Player
registering style:  Classic - Pet
registering style:  Classic - Target
registering style:  Classic - Targettarget
registering style:  Classic - Focus
registering style:  Classic - Focustarget

registering style:  Classic - Raid
registering style:  Classic - Party

registering style:  Classic - Maintank
--]]

oUF:RegisterStyle("Classic", function(self, ...)
	Shared(self, small, ...)
end)
for unit,layout in next, UnitSpecific do
	-- Capitalize the unit name, so it looks better.
	print("registering style: ", 'Classic - ' .. unit:gsub("^%l", string.upper))
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
	local player = spawnHelper(self, 'player', "BOTTOMRIGHT", WorldFrame, "BOTTOM", -80, 25)
	spawnHelper(self, 'pet', "BOTTOMRIGHT", player, "TOPLEFT", -25, -10)
	local target = spawnHelper(self, 'target',"BOTTOMLEFT", WorldFrame, "BOTTOM", 80, 25)
	spawnHelper(self, 'targettarget', "BOTTOMLEFT", target, "TOPRIGHT", 25, 10)

	local focus = spawnHelper(self, 'focus', "TOPLEFT", UIParent, "TOPLEFT", 320, -240)
	spawnHelper(self, 'focustarget', "LEFT", focus, "RIGHT", 25, 0)

	self:SetActiveStyle'Classic - Party'
	local party = self:SpawnHeader(nil, nil, 'party',
		'showParty', true,
		'yOffset', -31,
		'oUF-initialConfigFunction', ([[
				self:SetWidth(%d);
				self:SetHeight(%d)
			]]):format(big["initial-width"], big["initial-height"])
	)
	party:SetPoint("TOPLEFT", 30, -30)

	local ptcontainer = CreateFrame('Frame', nil, party, "SecureHandlerStateTemplate")
	-- RegisterStateDriver(ptcontainer, "visibility", "[group:raid]hide;show")
	ptcontainer:SetPoint("TOPLEFT", party, "TOPRIGHT", 35, 0)

	self:SetActiveStyle("Classic - Targettarget")
	local pts = {}
	pts[1] = self:Spawn("party1target")
	pts[1]:SetParent(ptcontainer)
	pts[1]:SetPoint("TOPLEFT", ptcontainer, "TOPLEFT")
	for i =2, 4 do
		pts[i] = self:Spawn("party"..i.."target")
		pts[i]:SetPoint("TOP", pts[i-1], "BOTTOM", 0, -50)
		pts[i]:SetParent(ptcontainer)
	end

	local petcontainer = CreateFrame('Frame', nil, party, "SecureHandlerStateTemplate")
	local pets = {}
	pets[1] = self:Spawn("partypet1", "oUF_PartyPet1")
	pets[1]:SetPoint("TOP", pts[1], "BOTTOM", 0, -5)
	pets[1]:SetParent(petcontainer)
	pets[1]:SetAttribute("toggleForVehicle", true)
	for i =2, 4 do
		pets[i] = self:Spawn("partypet"..i, "oUF_PartyPet"..i)
		pets[i]:SetPoint("TOP", pts[i], "BOTTOM", 0, -5)
		pets[i]:SetParent(petcontainer)
	end

	-- raid frames
	self:SetActiveStyle("Classic - Raid")
	local raidsettings = raid
	local raid = {}
	for i = 1, 8 do
		raid[i] = self:SpawnHeader("oUF_Raid"..i, nil, 'raid',
			-- "template", "oUF_profalbert_raid",
			"yOffset", -5,
			"groupFilter", tostring(i),
			"showRaid", true,
			"point", "TOP",
			'oUF-initialConfigFunction', ([[
				self:SetWidth(%d);
				self:SetHeight(%d)
			]]):format(raidsettings["initial-width"], raidsettings["initial-height"])
		)
		if i == 1 then
			raid[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -75)
		elseif i == 6 then
			raid[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, (-80 - 33*5))
		else
			raid[i]:SetPoint("TOPLEFT", raid[i-1], "TOPRIGHT", 20, 0)
		end
	end

	self:SetActiveStyle("Classic - Maintank")
	local mts = self:SpawnHeader(nil, nil, 'raid',
		"template", "oUF_profalbert_mtt",
		"showRaid", true,
		"yOffset", 1,
		"groupBy", "ROLE",
		"groupFilter", "MAINTANK",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		'oUF-initialConfigFunction', ([[
				self:SetWidth(%d);
				self:SetHeight(%d)
			]]):format(small["initial-width"], small["initial-height"])
	)
	mts:SetPoint("TOPLEFT", raid[6], "BOTTOMLEFT", 0, -30)

	local bossContainer = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
	bossContainer:SetPoint("TOPLEFT", mts, "BOTTOMLEFT", 0, -30)
	local boss = {}
	boss[1] = self:Spawn("boss1")
	boss[1]:SetParent(bossContainer)
	boss[1]:SetPoint("TOPLEFT", bossContainer, "TOPLEFT")
	for i = 2,4 do
		boss[i] = self:Spawn("boss" .. i)
		boss[i]:SetPoint("TOP", boss[i-1], "BOTTOM", 0, -5)
		boss[i]:SetParent(bossContainer)
	end

	-- TODO castbar and targetframe sometimes
	local arenaContainer = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
	arenaContainer:SetPoint("TOPLEFT", UIParent, "LEFT", 10, 0)
	local arena = {}
	arena[1] = self:Spawn("arena1")
	arena[1]:SetParent(arenaContainer)
	arena[1]:SetPoint("TOPLEFT", arenaContainer, "TOPLEFT")
	for i = 2,5 do
		arena[i] = self:Spawn("arena" .. i)
		arena[i]:SetPoint("TOP", arena[i-1], "BOTTOM", 0, -5)
		arena[i]:SetParent(arenaContainer)
	end
	-- pets should work
	local arenapets = {}
	arenapets[1] = self:Spawn("arenapet1")
	arenapets[1]:SetParent(arenaContainer)
	arenapets[1]:SetPoint("TOPLEFT", arena[1], "TOPRIGHT", 5, 0)
	for i = 2,5 do
		arenapets[i] = self:Spawn("arenapet" .. i)
		arenapets[i]:SetPoint("TOP", arenapets[i-1], "BOTTOM", 0, -5)
		arenapets[i]:SetParent(arenaContainer)
	end

	-- handle the original araneframes
	-- arenaframes are created when first entering an arena
	local dummy = function() end
	arenaContainer:RegisterEvent("PLAYER_ENTERING_WORLD")
	arenaContainer:SetScript("OnEvent", function(self)
		for i = 1,5 do
			local frame = _G["ArenaEnemyFrame" .. i]
			if not frame then return end
			self:UnregisterEvent("PLAYER_ENTERING_WORLD")
			frame:UnregisterAllEvents()
			frame.Show = dummy
			frame:Hide()
		end
	end)

	local healspec = {
		["Cedwani"] = 2,
		["Farolgin"] = 1,
	}

	local playerHealSpec = healspec[UnitName("player")]
	if playerHealSpec then
		local SpecFrame = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
		SpecFrame:SetFrameRef("party", party)
		SpecFrame:Execute([[
			party = self:GetFrameRef("party")
		]])
		SpecFrame:SetAttribute("_onstate-healer", [[
			if newstate == "healer" then
				party:SetAttribute("showPlayer", true)
			else
				party:SetAttribute("showPlayer", false)
			end
		]])
		RegisterStateDriver(SpecFrame, "healer", ("[spec:%d]healer;nohealer"):format(playerHealSpec))

		ptcontainer:SetFrameRef("party2", party)
		ptcontainer:Execute([[
			party2 = self:GetFrameRef("party2")
		]])
		ptcontainer:SetAttribute("_onstate-healer", [[
			if newstate == "healer" then
				self:SetPoint("TOPLEFT", party2, "TOPRIGHT", 35, -81)
			else
				self:SetPoint("TOPLEFT", party2, "TOPRIGHT", 35, 0)
			end
		]])
		RegisterStateDriver(ptcontainer, "healer", ("[spec:%d]healer;nohealer"):format(playerHealSpec))
	else
		party:SetAttribute("showPlayer", false)
	end
end)
