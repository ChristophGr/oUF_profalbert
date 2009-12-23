local _G = _G
local oUF_profalbert = {}
_G.oUF_profalbert = oUF_profalbert

-- the local upvalues bandwagon
local select = select
local UnitClass = UnitClass
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsPlayer = UnitIsPlayer
local UnitIsConnected = UnitIsConnected
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UnitLevel = UnitLevel
local UnitPowerType = UnitPowerType
local UnitClassification = UnitClassification
local UnitCreatureFamily = UnitCreatureFamily
local UnitCreatureType = UnitCreatureType
local UnitCanAttack = UnitCanAttack
local GetQuestGreenRange = GetQuestGreenRange

local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax

local playerClass = select(2, UnitClass("player")) -- combopoints for druid/rogue

local unfiltered = (playerClass == "ROGUE" or playerClass == "WARRIOR")

local LSM = LibStub("LibSharedMedia-3.0")
local AceTimer = LibStub("AceTimer-3.0")
local QuickHealth = LibStub("LibQuickHealth-2.0")

local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		insets = {left = -1.5, right = -1.5, top = -1.5, bottom = -1.5},
	}
local statusbartexture = LSM:Fetch("statusbar", "Perl v2")
local bordertexture = "Interface\\AddOns\\oUF_profalbert\\media\\border"
local defaultfont = LSM:Fetch("font", "Arial Narrow")
local bigfont = LSM:Fetch("font", "Diablo")
local white = { r = 1, g = 1, b = 1}

local barFormatMinMax = "%s/%s"
local barFormatPerc = "%d%%"
local barFormatPercMinMax = "%s/%s %d%%"
local barFormatDeficit = "|cffff8080%s|r"
local barFormatDeficitNoMax = "%s"
local barFormatMinMaxDef = "%s/%s |cffff8080%d|r"

local function shortnumber(number)
	local neg, result
	if number < 0 then
		neg = true
		number = 0 - number
	end
	if number < 100000 then
		result = number
	elseif number < 1000000 then
		result = ("%dk"):format(floor(number/1000))
	elseif number < 10000000 then
		result = ("%.1fm"):format(number/1000000)
	else
		result = ("%dm"):format(number/1000000)
	end
	if neg then
		return "-" .. result
	end
	return result
end

local function fmt_standard(txt, min, max)
	txt:SetFormattedText(barFormatMinMax, shortnumber(min), shortnumber(max))
end

local function fmt_perc(txt, min, max)
	txt:SetFormattedText(barFormatPerc,floor(min/max*100))
end

local function fmt_full(txt, min, max)
	local deficit = min - max
	if deficit == 0 then
		txt:SetFormattedText(barFormatMinMax, shortnumber(min), shortnumber(max))
	else
		txt:SetFormattedText(barFormatMinMaxDef, shortnumber(min), shortnumber(max), deficit)
	end
end

local function fmt_deficit(txt, min, max)
	local deficit = min - max
	if deficit < 0 then
		txt:SetFormattedText(barFormatDeficit, deficit)
	else
		txt:SetText(max)
	end
end

local function fmt_deficitnomax(txt, min, max)
	local deficit = min - max
	if deficit < 0 then
		txt:SetFormattedText(barFormatDeficitNoMax, deficit)
	else
		txt:SetText("")
	end
end

local function fmt_percminmax(txt, min, max)
	txt:SetFormattedText(barFormatPercMinMax, shortnumber(min), shortnumber(max), floor(min/max*100))
end

local function fmt_minonly(txt, min)
  txt:SetFormattedText(barFormatDeficitNoMax, shortnumber(min))
end

local fmtmeta = { __index = function(self, key)
	if type(key) == "nil" then return nil end
	if not rawget(self, key) then
		rawset(self, key, fmt_standard)
		return self[key]
	end
end}

local formats = setmetatable({}, {
	__index = function(self, key)
		if type(key) == "nil" then return nil end
		if not rawget(self, key) then
			if key:find("raid%d+pet") then self[key] = self.raidpet
			elseif key:find("raid%d+target") then self[key] = self.raidtarget
			elseif key:find("raid%d") then self[key] = self.raid
			elseif key:find("partypet%d") then self[key] = self.partypet
			elseif key:find("party%dtarget") then self[key] = self.partytarget
			elseif key:find("party%d") then self[key] = self.party
			else
				self[key] = {}
			end
		end
		return self[key]
	end,
	__newindex = function(self, key, value)
		rawset(self, key, setmetatable(value, fmtmeta))
	end,
})

formats.player.health = fmt_minmax
formats.pet.health = fmt_minmax
formats.party.health = fmt_full

formats.target.health = fmt_minmax
formats.target.health2 = fmt_perc
formats.target.power = fmt_minmax

formats.focus.health = fmt_minmax
formats.focus.power = fmt_minmax

formats.partypet.health = fmt_deficit
formats.partytarget.health = fmt_perc

formats.targettarget.health = fmt_minonly
formats.targettarget.health2 = fmt_perc
formats.targettarget.power = fmt_perc

formats.focustarget.health = fmt_deficit
formats.focustarget.power = fmt_perc

formats.raid.health = fmt_deficitnomax
formats.raidtarget.health = fmt_minonly
formats.raidtarget.health2 = fmt_perc

local classificationFormats = {
	worldboss = "%sb",
	rareelite = "%s+r",
	elite = "%s+",
	rare = "%sr",
	normal = "%s",
	trivial = "%s~",
}

local function getDifficultyColor(level)
	if type(level) ~= 'number' then
		return "|cFFFF1A1A%s|r"
	end
	local levelDiff = level - UnitLevel("player")
	if levelDiff >= 5 then
		return "|cFFFF1A1A%s|r"
	elseif levelDiff >= 3 then
		return "|cFFFF7F3F%s|r"
	elseif levelDiff >= -2 then
		return "|cFFFFFF1A%s|r"
	elseif -levelDiff <= GetQuestGreenRange() then
		return "|cFF3FBF3F%s|r"
	end
	return "|cFF7F7F7F%s|r"
end

-- This is the core of RightClick menus on diffrent frames
local function menu(self)
	local unit = self.unit:sub(1, -2)
	local cunit = self.unit:gsub("(.)", string.upper, 1)

	if(unit == "party" or unit == "partypet") then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	elseif(_G[cunit.."FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
	end
end

local function updateLevel(self, event, unit)
	if self.unit ~= unit then return end

	local lvl = self.Lvl
	local level = UnitLevel(unit)
	if level < 0 then
		level = "??"
	end

	level = getDifficultyColor(level):format(level)
	lvl:SetFormattedText(classificationFormats[UnitClassification(unit)] or classificationFormats["normal"], level)
--	lvl:SetTextColor(getDifficultyColor(level))

end

local function smartRace(u)
	return UnitIsPlayer(u) and UnitRace(u) or UnitCreatureType(u)
end

local function updateName(self, event, unit)
	if self.unit ~= unit then return end

	local name = UnitName(unit) or ""
	if self.namelength then
		name = name:sub(0, self.namelength)
	end
	if not self.grid and name ~= UnitName(unit) then
		name = name .. ".."
	end
	self.Name:SetText(name)
	local color = white
	if UnitIsPlayer(unit) then
		color = RAID_CLASS_COLORS[select(2, UnitClass(unit))] or white
	else
		color = FACTION_BAR_COLORS[UnitReaction("player", unit)]
	end
	if color then
		self.Name:SetTextColor(color.r, color.g, color.b)
	end

	if self.Lvl then
		updateLevel(self, event, unit)
	end

	if self.Class then
		local color = white
		if UnitIsPlayer(unit)	then
			self.Class:SetText(UnitClass(unit))
			color = RAID_CLASS_COLORS[select(2, UnitClass(unit))] or white
		else
			self.Class:SetText(UnitCreatureFamily(unit) or UnitCreatureType(unit))
		end
		self.Class:SetTextColor(color.r, color.g, color.b)
	end
	if self.Race then
		self.Race:SetText(smartRace(unit))
	end
end

local unit_status = setmetatable({}, { __index = function(self, key)
		if not key then return nil end
		local val = rawget(self, key)
		if not val then
			val = {}
			self[key] = val
		end
		return val
	end})

_G.unit_status = unit_status

local updateHealth

local function updateStatusText(self, unit, status)
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	local value = self.Health.value
	if cur == max then
		value:SetTextColor(1,1,1)
		if status and next(status) then
			if status.aggro then
				value:SetTextColor(1,0,0)
				formats[unit].health(value, cur, max)
			elseif status.offline then
				self.Health:SetValue(0)
				value:SetText("Offline")
			elseif status.afk then
				value:SetText("AFK")
			elseif status.dnd then
				value:SetText("DND")
			end
		else
--			formats[unit].health(value, cur, max)
			updateHealth(self, nil, unit, self.Health, cur, max)
		end
	else
		if status and next(status) then
			if status.aggro then
				value:SetTextColor(1,0,0)
			elseif status.afk then
				value:SetTextColor(0,0,0)
			else
				value:SetTextColor(1,1,1)
			end
		else
			value:SetTextColor(1,1,1)
		end
--		formats[unit].health(value, cur, max)
		--updateHealth(self, nil, unit, self.Health, UnitHealth(unit), UnitHealthMax(unit))
	end
end

local function Banzai(self, unit, aggro)
	if not UnitIsPlayer(unit) then return end
	local status = unit_status[UnitGUID(unit)]
	status.aggro = aggro == 1 or nil
	updateStatusText(self, unit, status)
end

local function updateStatus(self)
	local unit = self.unit
	if not unit then return end
	local status = unit_status[UnitGUID(unit)]
	if not status then return end
	status.offline = (not UnitIsConnected(unit)) or nil
	status.afk = UnitIsAFK(unit)
	updateStatusText(self, unit, status)
end

function updateHealth(self, event, unit, bar, min, max)
	local cur, maxhp
	cur, maxhp = min, max

	local status = unit_status[UnitGUID(unit)] --getStatusByGUID(UnitGUID(unit))
	local value = bar.value
	if cur == max then
		if not status or not next(status) and not UnitIsDeadOrGhost(unit) then
			formats[unit].health(value, cur, max)
		else
			updateStatus(self)
		end
	elseif UnitIsDead(unit) then
		value:SetText("Dead")
		bar:SetValue(0)
	elseif UnitIsGhost(unit) then
		value:SetText("Ghost")
		bar:SetValue(0)
	else
		formats[unit].health(value, cur, max)
	end
	self:UNIT_NAME_UPDATE(event, unit)
end

oUF_profalbert.updateStatus = updateStatus

local function updateHealth2(self, event, unit, bar, min, max)
	if min and max and not UnitIsDead(unit) and not UnitIsGhost(unit) and UnitIsConnected(unit) then
		formats[unit].health2(bar.value2, min, max)
	else
		bar.value2:SetText("")
	end
	updateHealth(self, event, unit, bar, min, max)
end

local units = oUF.units

local function quickHealthUpdate(event, unitID, health, healthMax)
	local uf = units[unitID]
	local bar = uf.Health
	bar:SetMinMaxValues(0, healthMax)
	bar:SetValue(health)
	updateHealth(uf, event, unitID, bar, health, healthMax)
end

local function enableQuickHealth()
	QuickHealth.RegisterCallback(oUF_profalbert, "UnitHealthUpdated", quickHealthUpdate)
end

local function disableQuickHealth()
	QuickHealth.UnregisterCallback(oUF_profalbert, "UnitHealthUpdated")
end

local function updatePower(self, event, unit, bar, min, max)
	if max == 0 or UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
		bar:SetValue(0)
		if bar.value then
			bar.value:SetText()
		end
	elseif bar.value then
		formats[unit].power(bar.value, min, max)
	end
end

local function noHide(self)
	self:SetVertexColor(.25,.25, .25)
end

local function auraIcon(self, button, icons, index, debuff)
	button.cd:SetReverse()
	button.icon:SetTexCoord(.07, .93, .07, .93) --zoom icon
	button.overlay:SetTexture(bordertexture)
	button.overlay:SetTexCoord(0,1,0,1)
	button.overlay.Hide = noHide
end

local oldr, oldg, oldb
local function OnEnter(self)
	-- self.Name:SetTextColor(1, 0, 1)
	UnitFrame_OnEnter(self)
end

local function OnLeave(self)
	-- updateName(self, nil, self.unit)
--	if InCombatLockdown() or self.grid then return end
	UnitFrame_OnLeave()
end

local function getFontString(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	if parent.GetHeight then
		local height = parent:GetHeight()
		if height < 11 then
			height = 11
		elseif height > 13 then
			height = 13
		end
		fs:SetFont(defaultfont, height)
	else
		fs:SetFont(defaultfont, 10)
	end
--	fs:SetFontObject(GameFontNormalSmall)
	fs:SetShadowColor(0,0,0)
	fs:SetShadowOffset(0.8, -0.8)
	fs:SetTextColor(1,1,1)
	fs:SetJustifyH("LEFT")
	return fs
end

local function CustomTimeText(self, duration)
	local tformat = "%.1f"
	if self.delay ~= 0 then
		tformat = "%.1f|cffff0000-%.1f|r"
	end
	if self.casting then
		self.Time:SetFormattedText(tformat, self.max - duration, self.delay)
	elseif self.channeling then
		self.Time:SetFormattedText(tformat, duration, self.delay)
	end
end

local function updateBarColor(self, event, unit)
	self.Health.colorReaction = not UnitIsPlayer(unit)
end

--[[local function updateFlags(self)
	if self.aggro then return end
	local unit = self.unit
	if not unit then return end
--	print("updating ", unit, " flags")
	local status = getStatusText(unit)
	if not status then
		self.Health.value:SetTextColor(1,1,1)
		updateHealth(self, nil, unit, self.Health, UnitHealth(unit), UnitHealthMax(unit))
	else
		if UnitHealth(unit) == UnitHealthMax(unit) then
			-- replace text
			self.Health.value:SetTextColor(1,1,1)
			self.Health.value:SetText(status)
		elseif status == "AFK" then
			self.Health.value:SetTextColor(statusColor[status])
			-- color text
		end
	end
end--]]

local function setStyle(settings, self, unit)
	self.menu = menu -- Enable the menus
	self:RegisterForClicks("anyup")
	self:SetAttribute("*type2", "menu")
	self:SetScript("OnEnter", OnEnter)
	self:SetScript("OnLeave", OnLeave)
	local width = settings["initial-width"] or 100
	local height = settings["initial-height"] or 20

	local grid = settings["ammo-grid"]

	if grid then
		self.grid = true
	end
	self.namelength = settings["namelength"]

	local hpheight = settings["hpheight"] or 22
	local ppheight = settings["ppheight"] or 16
	local bbheight = settings["initial-height"] - (hpheight + ppheight + 2)

	-- Background
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0,0,0,1)

	-- pet TTL
	if unit == "pet" then
		local ttl = getFontString(self)
		ttl:SetPoint("BOTTOM", self, "TOP")
		local petupdateFrame = CreateFrame("Frame")
		petupdateFrame:Hide()
		petupdateFrame:SetScript("OnUpdate", function()
				local time = GetPetTimeRemaining()
				if not time then
					ttl:SetText("")
					petupdateFrame:Hide()
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
			end)
		petupdateFrame:RegisterEvent("UNIT_PET")
		petupdateFrame:SetScript("OnEvent", function()
				if GetPetTimeRemaining() then
					petupdateFrame:Show()
				else
					petupdateFrame:Hide()
				end
			end)
	end

	local bb = CreateFrame("StatusBar", nil, self)
	bb:SetHeight(bbheight)
--	bb.value = getFontString(bb)
--	bb.value:SetPoint("LEFT")
	bb:SetPoint("TOPLEFT")
	bb:SetPoint("TOPRIGHT")
--	bb:SetStatusBarColor(255, 100, 100, 255)
--	bb:SetStatusBarTexture(statusbartexture)

	if settings["level"] then
		self.Lvl = getFontString(bb)
		self.Lvl:SetPoint("LEFT", bb, "LEFT", 2, 0)
	end
	self.Name = getFontString(bb)
	if self.Lvl then
		self.Name:SetPoint("LEFT", self.Lvl, "RIGHT", 2, 0)
		self:RegisterEvent("UNIT_LEVEL", updateName)
	else
		self.Name:SetPoint("LEFT", bb, "LEFT", 2, 0)
	end
	self:RegisterEvent("UNIT_NAME_UPDATE", updateName)
	-- Portrait
	local portrait
	if settings["portrait"] then
			portrait = CreateFrame("PlayerModel", nil, self)
			portrait:SetBackdropColor(0, 0, 0, .7)
			portrait:SetWidth(hpheight + ppheight)
			portrait:SetHeight(hpheight + ppheight)
			if unit == "target" then
				portrait:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
			else
				portrait:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
			end
			local fallback = portrait:CreateTexture()
			fallback:SetAllPoints(portrait)
			portrait.fallback = fallback
			self.Portrait2 = portrait

	end

	-- Healthbar
	local hp
	hp = CreateFrame("StatusBar", nil, self)
	hp:SetHeight(hpheight)
	hp:SetStatusBarTexture(statusbartexture)

	if bb then
		hp:SetPoint("TOPLEFT", bb, "BOTTOMLEFT", 0, -1.5)
		hp:SetPoint("TOPRIGHT", bb, "BOTTOMRIGHT", 0, -1.5)
	else
		hp:SetPoint("TOPLEFT")
		hp:SetPoint("TOPRIGHT")
	end

	if portrait then
		if unit == "target" then
			hp:SetPoint("TOPRIGHT", portrait, "TOPLEFT")
		else
			hp:SetPoint("TOPLEFT", portrait, "TOPRIGHT")
		end
	end

	-- Healthbar background
	hp.bg = hp:CreateTexture(nil, "BORDER")
	hp.bg:SetAllPoints(hp)
	hp.bg:SetTexture(statusbartexture)
	hp.bg:SetAlpha(.5)

	-- healthbar coloring, happy true fest
	hp.colorHappiness = true
	hp.colorTapping = true
	hp.colorHealth = true
	hp.colorSmooth = true
	hp.colorDisconnected = true
	-- Healthbar text
	hp.value = getFontString(hp)
	if grid then
		hp.value:SetPoint("TOP", 0, -2)
	else
		hp.value:SetPoint("RIGHT", -2, 0)
	end
	if unit and (unit == "player" or unit:match("party%d$") or unit:match("raid%d+$")) then
		AceTimer:ScheduleRepeatingTimer(updateStatus, 1, self)
	end

--	self:RegisterEvent("PLAYER_FLAGS_CHANGED", function() updateFlags(self) end)
--	local updateFrame = CreateFrame("frame")
--	updateFrame:SetScript("OnUpdate", function() updateFlags(self) end)

	self.PreUpdateHealth = updateBarColor
	self.Health = hp

	if unit == "target" or unit == "targettarget" or unit and unit:match("raid%d+target") then
		hp.value2 = getFontString(hp)
		hp.value2:SetFont(bigfont, 9, "THICK")
		hp.value2:SetTextColor(1,0.3,0.3,1)
		hp.value:SetPoint("RIGHT", hp.value2, "LEFT", 1)
		hp.value2:SetPoint("RIGHT", hp, "RIGHT", 1)
--		hp.value:SetPoint("RIGHT
		self.PostUpdateHealth = updateHealth2
	else
		self.PostUpdateHealth = updateHealth
	end

	local icon = hp:CreateTexture(nil, "OVERLAY")
	icon:SetHeight(16)
	icon:SetWidth(16)
	icon:SetPoint("CENTER", self, "TOP")
	icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	self.RaidIcon = icon
	local pp
	if ppheight then
		-- Power Bar
		pp = CreateFrame("StatusBar", nil, self)
		pp:SetHeight(ppheight)
		pp:SetStatusBarTexture(statusbartexture)

		pp:SetPoint("LEFT")
		pp:SetPoint("RIGHT")
		pp:SetPoint("TOP", hp, "BOTTOM")

		if portrait then
			if unit == "target" then
				pp:SetPoint("RIGHT", portrait, "LEFT")
			else
				pp:SetPoint("LEFT", portrait, "RIGHT")
			end
		end

		pp.colorPower = true
		if unit == "player" then
			pp.frequentUpdates = true
		end
		pp.bg = pp:CreateTexture(nil, "BORDER")
		pp.bg:SetAllPoints(pp)
		pp.bg:SetTexture(statusbartexture)
		pp.bg:SetAlpha(.5)

		self.Power = pp
		self.PostUpdatePower = updatePower

		if ppheight > 5 then -- anything larger than tiny has text on the powerbar
			pp.value = getFontString(pp)
			pp.value:SetPoint("CENTER")
		end
	end

	if (not unit or unit == "player") and settings["leader"] then --raid,	party or player gets a leader icon
		local leader = hp:CreateTexture(nil, "OVERLAY")
		leader:SetHeight(16)
		leader:SetWidth(16)
		leader:SetPoint("TOPLEFT", self, "TOPLEFT", -8, 8)
		leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
		self.Leader = leader

		local masterlooter = hp:CreateTexture(nil, "OVERLAY")
		masterlooter:SetHeight(16)
		masterlooter:SetWidth(16)
		masterlooter:SetPoint("TOPRIGHT", self, "TOPRIGHT", 8, 8)
		masterlooter:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
		self.MasterLooter = masterlooter

	end

	if unit == "player" then -- player gets resting and combat
		local resting = pp:CreateTexture(nil, "OVERLAY")
		resting:SetHeight(16)
		resting:SetWidth(16)
		resting:SetPoint("BOTTOMLEFT", self, -8, -8)
		resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
		resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
		self.Resting = resting
		local combat = pp:CreateTexture(nil, "OVERLAY")
		combat:SetHeight(16)
		combat:SetWidth(16)
		combat:SetPoint("BOTTOMRIGHT", self, 8, -8)
		combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
		combat:SetTexCoord(0.57, 0.90, 0.08, 0.41)
		self.Combat = combat
	end

	-- player, pet party and partypets get debuff highlighting
	if not unit or unit == "player" or unit == "pet" or unit:find("partypet%d") then
		if micro then
			local dbh = hp:CreateTexture(nil, "OVERLAY")
			dbh:SetWidth(16)

			dbh:SetPoint("TOPLEFT", self, "TOPRIGHT")
			dbh:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT")

			dbh:SetTexture(statusbartexture)
--			dbh:SetVertexColor(0,0,0,0) -- set alpha to 0 to hide the texture
			self.DebuffHighlight = dbh
			self.DebuffHighlightAlpha = 1
		else
			self.DebuffHighlightBackdrop = true -- oUF_DebuffHighlight Support, using the backdrop
		end
		self.DebuffHighlightFilter = not unfiltered -- only show debuffs I can cure, if I can cure any
	end

	self.Banzai = Banzai
--[[
	if micro then -- micro units (raid) don't color healthbar but the health text
		self.Banzai = Banzai
	end
	if unit == "focustarget" then
		self.ignoreBanzai = true
	end
--]]

	if unit and unit:match("target") then
		self.ignoreBanzai = true
	end
	local buffx = settings["buffs-x"]
	local buffy = settings["buffs-y"]
	local buffs = buffx and buffy and (buffx * buffy)

	local debuffx = settings["debuffs-x"]
	local debuffy = settings["debuffs-y"]
	local debuffs = debuffx and debuffy and (debuffx * debuffy)


	local buffheight = settings["buff-height"] or 16
--	local buffwidth = settings["initial-width"]
--	buffwidth = buffwidth - (buffwidth%buffheight) -- make sure we have exactly enough room for the buffs
	if not unit or unit == "target" or unit == "focus" then
		if debuffx and debuffy then
			local debuffs = CreateFrame("Frame", nil, self)
			debuffs.size = buffheight
			debuffs:SetHeight(buffheight * debuffy)
			debuffs:SetWidth(buffheight * debuffx)
			debuffs:SetPoint("TOPLEFT", self, "TOPRIGHT",1.5,0)
			debuffs.initialAnchor = "TOPLEFT"
			debuffs["growth-x"] = "RIGHT"
			debuffs["growth-y"] = "DOWN"
			debuffs.num = debuffx * debuffy
			self.Debuffs = debuffs
		end -- settings["debuffs"]
		if buffx and buffy then
			if not unit or unit == "target" or unit == "focus" then
				local buffs = CreateFrame("Frame", nil, self)
				buffs.size = buffheight
				buffs:SetHeight(buffheight * buffy)
				buffs:SetWidth(buffheight * buffx)
				buffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT",-1.5, -3)
				buffs.initialAnchor = "TOPLEFT"
				buffs["growth-y"] = "DOWN"
				buffs.num = buffx * buffy
				if unit and unit:find("focus") then
					buffs.onlyShowPlayer = true
				end
				self.Buffs = buffs
			end -- if unit
		end -- settings["buffs"]
	end -- if unit-find

	if not unit or unit:find("partypet%d") then -- range on party, raid and party pets
		self.Range = true
		self.inRangeAlpha = 1.0
		if grid then
			self.outsideRangeAlpha = 0.4
		else
			self.outsideRangeAlpha = micro and 0.4 or 0.6
		end
	end

	if unit=="target" then
		self.CPoints = getFontString(self)
		local font = self.CPoints:GetFont()
		self.CPoints:SetPoint("RIGHT", self, "LEFT", -9, 3)
		self.CPoints:SetFont(font, 38, "OUTLINE")
		self.CPoints:SetJustifyH("RIGHT")
	end
	self.PostCreateAuraIcon = auraIcon

	return self
end

local default = {
	["initial-width"] = 140,
	["initial-height"] = 48,
	["namelength"] = 20,
	["hpheight"] = 22,
	["ppheight"] = 12,
	["buffs-x"] = 6,
	["buffs-y"] = 1,
	["debuffs-x"] = 2,
	["debuffs-y"] = 3,
	["portrait"] = true,
	["level"] = true,
	["leader"] = true,
	["buff-height"] = 16,
}

local focus = CopyTable(default)
focus["initial-width"] = 106
focus["portrait"] = false

oUF:RegisterStyle("Ammo", setmetatable(default, {__call = setStyle}))

oUF:RegisterStyle("pa_focus", setmetatable(focus, {__call = setStyle}))

local small = setmetatable({
	["initial-width"] = 80,
	["initial-height"] = 35,
	["namelength"] = 15,
	["hpheight"] = 20,
	["ppheight"] = 3,
	["debuffs-x"] = 1,
	["debuffs-y"] = 3,
}, {__call = setStyle})
oUF_profalbert.small = small
oUF:RegisterStyle("Ammo_Small", small)

oUF:RegisterStyle("Ammo_Grid", setmetatable({
	["initial-width"] = 60,
	["initial-height"] = 30,
	["namelength"] = 10,
	["hpheight"] = 18,
	["ppheight"] = 3,
	["ammo-grid"] = true,
	["debuffs-x"] = 1,
	["debuffs-y"] = 3,
	["buff-height"]=10,
	["leader"] = true,
}, {__call = setStyle}))

-- big UFs
oUF:SetActiveStyle("Ammo")

-- player
local player = oUF:Spawn("player", "oUF_Player")
player:SetPoint("RIGHT", UIParent, "CENTER", -80, -230)

-- target
local target = oUF:Spawn("target", "oUF_Target")
target:SetPoint("LEFT", UIParent, "CENTER", 80, -230)

oUF:SetActiveStyle("pa_focus")
-- focus
local focus = oUF:Spawn("focus", "oUF_Focus")
focus:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 320, -240)

oUF:SetActiveStyle("Ammo")
-- group
local party	= oUF:Spawn("header", "oUF_Party")
party:SetAttribute("template", "oUF_profalbert_party")
party:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -50)
party:SetAttribute("yOffset", -31)
party:SetAttribute("showParty", true)
-- do not show in raid
RegisterStateDriver(party, "visibility", "[group:raid]hide;show")
party:Show()

--oUF:RegisterEvent("RAID_ROSTER_UPDATE", updateParty)
--oUF:RegisterEvent("PARTY_MEMBERS_CHANGED", updateParty)

-- small UFs
oUF:SetActiveStyle("Ammo_Small")

-- pet
local pet = oUF:Spawn("pet", "oUF_Pet")
pet:SetPoint("BOTTOMRIGHT", player, "TOPLEFT", -25, -10)

-- targetstarget
local tot = oUF:Spawn("targettarget", "oUF_TargetTarget")
tot:SetPoint("BOTTOMLEFT", target, "TOPRIGHT", 25, 10)

-- focustarget
local tof = oUF:Spawn("focustarget", "oUF_Focustarget")
tof:SetPoint("LEFT", focus, "RIGHT", 25, 0)

-- The pet header is being a cunt, this is a better solution
--[[ no pets for now
local pets = {}
pets[1] = oUF:Spawn("partypet1", "oUF_PartyPet1")
pets[1]:SetPoint("TOPRIGHT", party, "TOPRIGHT", 0, -44)
pets[1]:SetParent(party)
for i =2, 4 do
	pets[i] = oUF:Spawn("partypet"..i, "oUF_PartyPet"..i)
	pets[i]:SetPoint("TOP", pets[i-1], "BOTTOM", 0, -50)
	pets[i]:SetParent(party)
end
--]]

local pts = {}
pts[1] = oUF:Spawn("party1target", "oUF_Party1Target")
pts[1]:SetPoint("TOPLEFT", party, "TOPRIGHT", 35, 0)
pts[1]:SetParent(party)
--pts[1]:Disable()
for i =2, 4 do
	pts[i] = oUF:Spawn("party"..i.."target", "oUF_Party"..i.."Target")
	pts[i]:SetPoint("TOP", pts[i-1], "BOTTOM", 0, -50)
	pts[i]:SetParent(party)
--	pts[i]:Disable()
end

-- raid frames
oUF:SetActiveStyle("Ammo_Grid")
local grid = {}
for i = 1, 8 do
	grid[i] = oUF:Spawn("header", "oUF_Grid"..i)
	if i == 1 then
		grid[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -75)
	elseif i == 6 then
		grid[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, (-80 - 33*5))
	else
		grid[i]:SetPoint("TOPLEFT", grid[i-1], "TOPRIGHT", 20, 0)
	end
	grid[i]:SetManyAttributes(
		"template", "oUF_profalbert_raid",
		"yOffset", -3,
		"groupFilter", tostring(i),
		"showRaid", true,
		"point", "TOP",
		"sortDir", "DESC"
	)
	RegisterStateDriver(grid[i], "visibility", "[group:raid]show;hide")
--	grid[i]:Show()
end

-- MTs and mt-targets
oUF:SetActiveStyle("Ammo_Small")
local mts = oUF:Spawn("header", "oUF_MTs")
--mts:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -275)
mts:SetPoint("TOPLEFT", grid[6], "BOTTOMLEFT", 0, -30)
mts:SetManyAttributes(
"template", "oUF_profalbert_mtt",
"showRaid", true,
"yOffset", 1,
"groupBy", "ROLE",
"groupFilter", "MAINTANK",
"groupingOrder", "1,2,3,4,5,6,7,8"
)
mts:Show()

-- move the RuneFrame somewhere sane
RuneFrame:ClearAllPoints()
RuneFrame:SetPoint("BOTTOM", player, "TOP", 0, 5)

local partyToggleEvent
local function partyToggleEvent(self, event)
	if(InCombatLockdown()) and event ~= "PLAYER_LOGIN" then
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
--		self:SetScript("OnUpdate", partyToggleEvent)
	else
		self:UnregisterEvent('PLAYER_REGEN_ENABLED')
		if GetNumRaidMembers() > (GetNumPartyMembers() + 1) then
			 -- if there is a unit in another party, switch to raid mode
			--party:Hide()
			--for i,v in ipairs(grid) do v:Show() end
			for i,v in ipairs(pts) do v:Disable()	end
		else
			--party:Show()
			--for i,v in ipairs(grid) do v:Hide() end
			for i,v in ipairs(pts) do v:Enable() end
		end
	end
end

local partyToggle = CreateFrame('Frame')
partyToggle:RegisterEvent('PLAYER_LOGIN')
partyToggle:RegisterEvent('RAID_ROSTER_UPDATE')
partyToggle:RegisterEvent('PARTY_LEADER_CHANGED')
partyToggle:RegisterEvent('PARTY_MEMBERS_CHANGED')
partyToggle:SetScript('OnEvent', partyToggleEvent)

local healtree = {
	["SHAMAN"] = 3,
	["PRIEST"] = 2,
	--["PALADIN"] = 0, -- TODO
	["DRUID"] = 3,
}

local function playerIsHealer()
	if healtree[playerClass] then
		local _, _, points = GetTalentTabInfo(healtree[playerClass])
		return points > (UnitLevel("player")/2)
	end
	return false
end

local talentUpdateFrame = CreateFrame("Frame")
talentUpdateFrame:RegisterEvent("PLAYER_ALIVE")
talentUpdateFrame:RegisterEvent('PLAYER_LOGIN')
talentUpdateFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
talentUpdateFrame:SetScript("OnEvent", function(self)
		if not InCombatLockdown() then
			if playerIsHealer() then
				party:SetAttribute("showPlayer", true)
				for i,v in ipairs(pts) do v:Disable()	end
				enableQuickHealth()
			else
				party:SetAttribute("showPlayer", false)
				for i,v in ipairs(pts) do v:Enable() end
				disableQuickHealth()
			end
		end
	end)

