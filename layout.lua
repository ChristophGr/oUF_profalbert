local _G = _G
local oUF_profalbert = {}
_G.oUF_profalbert = oUF_profalbert

-- the local upvalues bandwagon
local select = select

-- unit-stuff
local UnitClass = UnitClass
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsPlayer = UnitIsPlayer
local UnitIsConnected = UnitIsConnected
local UnitLevel = UnitLevel
local UnitPowerType = UnitPowerType
local UnitClassification = UnitClassification
local UnitCreatureFamily = UnitCreatureFamily
local UnitCreatureType = UnitCreatureType
local UnitRace = _G.UnitRace
local UnitCanAttack = UnitCanAttack
local UnitReaction = _G.UnitReaction
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local GetQuestGreenRange = GetQuestGreenRange
local UnitFrame_OnEnter = _G.UnitFrame_OnEnter
local UnitFrame_OnLeave = _G.UnitFrame_OnLeave
local ToggleDropDownMenu = _G.ToggleDropDownMenu

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local FACTION_BAR_COLORS = _G.FACTION_BAR_COLORS

local playerClass = select(2, UnitClass("player")) -- combopoints for druid/rogue

local LibStub = _G.LibStub
local LSM = LibStub("LibSharedMedia-3.0")
local AceTimer = LibStub("AceTimer-3.0")
local QuickHealth = LibStub("LibQuickHealth-2.0")

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
	if unit:match("pet") then
		local owner = unit:gsub("pet", "")
		if owner then
			if owner == "" then
				owner = "player"
			end

			local ownerName = UnitName(owner)
			if not ownerName then
				-- yprint(owner)
				-- print(self:GetName())
			end
			local test, class = UnitClass(owner)
			local colors = RAID_CLASS_COLORS[class]
			if colors then
				local r = math.floor(colors.r * 255)
				local g = math.floor(colors.g * 255)
				local b = math.floor(colors.b * 255)
				name = ("|cff%02x%02x%02x%s|r's %s"):format(r, g, b, UnitName(owner), name)
			else
				name = ("%s's %s"):format(UnitName(owner) or "", name)
			end
		end
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
		if UnitIsPlayer(unit) then
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

	if self.isHighlighted then
		self.Name:SetTextColor(1,0,1)
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
	updateName(self, nil, unit)
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	local value = self.Health.value
	if not next(status) then
		if UnitIsGhost(unit) then
			value:SetText("Ghost")
		elseif UnitIsDead(unit) then
			value:SetText("Dead")
		else
			self.healthfunc(value, cur, max)
		end
		value:SetTextColor(1,1,1)
		return
	end
	if cur == max then
		value:SetTextColor(1,1,1)
		if status.aggro and self.Banzai and not unit:match("target") then
			value:SetTextColor(1,0,0)
			self.healthfunc(value, cur, max)
		elseif status.offline then
			self.Health:SetStatusBarColor(0.3, 0.3, 0.3)
			value:SetText("Offline")
		elseif UnitIsDead(unit) then
			value:SetText("Dead")
		elseif UnitIsGhost(unit) then
			value:SetText("Ghost")
		elseif status.afk then
			value:SetText("AFK")
		elseif status.dnd then
			value:SetText("DND")
		end
	else
		if UnitIsGhost(unit) then
			value:SetText("Ghost")
			return
		elseif UnitIsDead(unit) then
			value:SetText("Dead")
			return
		elseif status.aggro and self.Banzai and not unit:match("target") then
			value:SetTextColor(1,0,0)
		elseif status.afk then
			value:SetTextColor(0,0,0)
		else
			value:SetTextColor(1,1,1)
		end
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

oUF_profalbert.updateStatus = updateStatus

local function updatePower(self, event, unit, bar, min, max)
	if max == 0 or UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
		bar:SetValue(0)
		if bar.value then
			bar.value:SetText()
		end
	elseif bar.value then
		fmt_standard(bar.value, min, max)
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
	self.Name:SetTextColor(1, 0, 1)
	self.isHighlighted = true
	UnitFrame_OnEnter(self)
end

local function OnLeave(self)
	self.isHighlighted = false
	updateName(self, nil, self.unit)
	UnitFrame_OnLeave()
end

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

local function getFontString(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	local height = getFontStringHeight(parent)
	
	fs:SetFont(defaultfont, height)
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

local function compareUnit(unit, ...)
	if not unit then return end
	for i = 1,select('#', ...) do
		local check = select(i, ...)
		if check == unit then
			return true
		end
	end
	return false
end

local function matchUnit(unit, ...)
	if not unit then return end
	for i = 1,select('#', ...) do
		local check = select(i, ...)
		if unit:match(check) then
			return true
		end
	end
	return false
end

local function setStyle(settings, self, unit)
	self.menu = menu -- Enable the menus
	self:RegisterForClicks("anyup")
	self:SetAttribute("*type2", "menu")
	self:SetScript("OnEnter", OnEnter)
	self:SetScript("OnLeave", OnLeave)

	self:SetAttribute("toggleForVehicle", true)
	self.disallowVehicleSwap = true
	if not unit or compareUnit(unit, "player", "pet") or matchUnit(unit, "party%d$", "partypet%d$") then
		self.VehicleSwap2 = true
	end

	local width = settings["initial-width"] or 100
	local height = settings["initial-height"] or 20

	local hpheight = settings["hpheight"] or 22
	local ppheight = settings["ppheight"] or 16
	local bbheight = settings["initial-height"] - (hpheight + ppheight + 2)

	-- Background
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0,0,0,1)

	-- pet TTL
	if compareUnit(unit,"pet") then
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
	bb:SetPoint("TOPLEFT")
	bb:SetPoint("TOPRIGHT")

	if settings["level"] then
		self.Lvl = getFontString(bb)
		self.Lvl:SetPoint("LEFT", bb, "LEFT", 2, 0)
	end
	self.Name = getFontString(bb)
	self.Name:SetWordWrap(false)
	if self.Lvl then
		self.Name:SetPoint("LEFT", self.Lvl, "RIGHT", 2, 0)
		self:RegisterEvent("UNIT_LEVEL", updateName)
	else
		self.Name:SetPoint("LEFT", bb, "LEFT", 2, 0)
	end
	self.Name:SetPoint("RIGHT", bb, "RIGHT", 0, 0)
	self:RegisterEvent("UNIT_NAME_UPDATE", updateName)

	-- Portrait
	local portrait
	if settings["portrait"] then
		portrait = CreateFrame("PlayerModel", nil, self)
		portrait:SetBackdropColor(0, 0, 0, .7)
		portrait:SetWidth(hpheight + ppheight)
		portrait:SetHeight(hpheight + ppheight)
		if settings["portrait"] == "right" then
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
	--[[if grid then
		hp.value:SetPoint("TOP", 0, -2)
	else
		hp.value:SetPoint("RIGHT", -2, 0)
	end--]]
	hp.value:SetPoint("CENTER")
	if unit and (unit == "player" or unit:match("party%d$") or unit:match("raid%d+$")) then
		AceTimer:ScheduleRepeatingTimer(updateStatus, 1, self)
	end

	self.PreUpdateHealth = updateBarColor
	self.Health = hp
	
	if not unit or unit == "player" or unit == "target" then
		self.HealCommBar = CreateFrame('StatusBar', nil, self.Health)
		self.HealCommBar:SetHeight(0)
		self.HealCommBar:SetWidth(0)
		self.HealCommBar:SetStatusBarTexture(self.Health:GetStatusBarTexture():GetTexture())
		self.HealCommBar:SetStatusBarColor(0, 1, 0, 0.25)
		self.HealCommBar:SetPoint('LEFT', self.Health, 'LEFT')

		-- optional flag to show overhealing
		self.allowHealCommOverflow = true
	end

	local health = settings["health"]
	local health2 = settings["health2"]
	
	
	--XXX remove
	if not health then
		print(self:GetName(), " has no health")
	end
	
	if health2 then
		hp.value2 = getFontString(hp)
		hp.value2:SetFont(defaultfont, 11)
		hp.value2:SetTextColor(1,0.3,0.3,1)
		hp.value:SetPoint("RIGHT", hp.value2, "LEFT", 1)
		hp.value2:SetPoint("RIGHT", hp, "RIGHT", 1)
	else
		health2 = function() end
	end
	self.healthfunc = health
	self.healthfunc2 = health2
	

	local function updateHealth(self, event, unit, bar, min, max)
		local status = unit_status[UnitGUID(unit)]
		local value = bar.value
		if min == max then
			if not status or not next(status) and not UnitIsDeadOrGhost(unit) then
				health(value, min, max)
				health2(bar.value2, min, max)
			--elseif event ~= "UpdateElement" then -- to prevent 
			else
				updateStatus(self)
				health2(bar.value2, min, max)
			end
		elseif UnitIsDead(unit) then
			value:SetText("Dead")
			bar:SetValue(0)
			if bar.value2 then
				bar.value2:SetText("")
			end
		elseif UnitIsGhost(unit) then
			value:SetText("Ghost")
			bar:SetValue(0)
			if bar.value2 then
				bar.value2:SetText("")
			end
		else
			health(value, min, max)
			health2(bar.value2, min, max)
		end
		self:UNIT_NAME_UPDATE(event, unit)
	end

	self.PostUpdateHealth = updateHealth

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
			-- display portrait on the other side for the target
			if compareUnit(unit, "target") then
				pp:SetPoint("RIGHT", portrait, "LEFT")
			else
				pp:SetPoint("LEFT", portrait, "RIGHT")
			end
		end

		pp.colorPower = true
		if compareUnit(unit, "player") then
			pp.frequentUpdates = true
		end
		pp.bg = pp:CreateTexture(nil, "BORDER")
		pp.bg:SetAllPoints(pp)
		pp.bg:SetTexture(statusbartexture)
		pp.bg:SetAlpha(.5)

		self.Power = pp
		self.PostUpdatePower = updatePower

		-- anything larger than tiny has text on the powerbar
		if ppheight > 5 then
			pp.value = getFontString(pp)
			pp.value:SetPoint("CENTER")
		end
	end
	--raid,	party or player gets a leader icon
	if (not unit or unit == "player") and settings["leader"] then
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
	if not unit or compareUnit(unit, "player", "pet") or matchUnit(unit, "party%dpet") then
		if micro then
			local dbh = hp:CreateTexture(nil, "OVERLAY")
			dbh:SetWidth(16)

			dbh:SetPoint("TOPLEFT", self, "TOPRIGHT")
			dbh:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT")

			dbh:SetTexture(statusbartexture)
			self.DebuffHighlight = dbh
			self.DebuffHighlightAlpha = 1
		else
			self.DebuffHighlightBackdrop = true -- oUF_DebuffHighlight Support, using the backdrop
		end
		local unfiltered = (playerClass == "ROGUE" or playerClass == "WARRIOR")
		self.DebuffHighlightFilter = not unfiltered -- only show debuffs I can cure, if I can cure any
	end

	if not unit or matchUnit(unit, "party%d$", "raid%d+$") then
		self.Banzai = Banzai
	else
		self.ignoreBanzai = true
	end


	local buffx = settings["buffs-x"]
	local buffy = settings["buffs-y"]
	local buffs = buffx and buffy and (buffx * buffy)

	local debuffx = settings["debuffs-x"]
	local debuffy = settings["debuffs-y"]
	local debuffs = debuffx and debuffy and (debuffx * debuffy)

	local buffheight = settings["buff-height"] or 16
	if not unit or compareUnit(unit, "target", "focus") then
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
		end
		if buffx and buffy then
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
		end -- settings["buffs"]
	end -- if unit-find
	if settings["range-fade"] then
	--if not unit or unit:find("partypet%d") then -- range on party, raid and party pets
		self.Range = true
		self.inRangeAlpha = 1.0
		self.outsideRangeAlpha = 0.6
		--[[if grid then
			self.outsideRangeAlpha = 0.4
		else
			self.outsideRangeAlpha = micro and 0.4 or 0.6
		end--]]
	end

	if unit == "target" then
		self.CPoints = getFontString(self)
		local font = self.CPoints:GetFont()
		self.CPoints:SetPoint("RIGHT", self, "LEFT", -9, 3)
		self.CPoints:SetFont(font, 38, "OUTLINE")
		self.CPoints:SetJustifyH("RIGHT")
	end
	self.PostCreateAuraIcon = auraIcon

	return self
end

local function merge2(result, tab1, ...)
	if not tab1 then
		return result
	end
	for k,v in pairs(tab1) do
		result[k] = v
		tab1[k] = nil
	end
	tab1 = nil
	return merge2(result, ...)
end

local function merge(default, ...)
	local result = CopyTable(default)
	return merge2(result, ...)
end

local stylemeta = {
	__call = setStyle,
}

local function newStyle(stylename, table)
	local style = setmetatable(table, stylemeta)
	oUF:RegisterStyle("pa_" .. stylename, style)
end

local default = {
	["initial-width"] = 140,
	["initial-height"] = 48,
	["hpheight"] = 22,
	["ppheight"] = 12,
	["level"] = true,
	["leader"] = true,
	["buff-height"] = 16,
	["health"] = fmt_standard,
	--["health2"] = fmt_perc,
}

local player = {
	portrait = "left",
}
player = merge(default, player)
newStyle("player",player)

local target = {
	portrait = "right",
	health2 = fmt_perc,
	["buffs-x"] = 6,
	["buffs-y"] = 1,
	["debuffs-x"] = 2,
	["debuffs-y"] = 3,
}
target = merge(default, target)
newStyle("target", target)

local focus2 = {
	["initial-width"] = 90,
	["initial-height"] = 35,
	["buffs-x"] = 6,
	["buffs-y"] = 1,
	hpheight = 18,
	ppheight = 4,
}
focus2 = merge(default, focus2)
newStyle("focus", focus2)

local party = {
	vehicleSwap = true,
	portrait = "left",
	["buffs-x"] = 6,
	["buffs-y"] = 1,
	["debuffs-x"] = 2,
	["debuffs-y"] = 3,
	["health"] = fmt_full,
	["range-rade"] = true,
}
party = merge(default, party)
newStyle("party", party)

local small = {
	["initial-width"] = 80,
	["initial-height"] = 30,
	["hpheight"] = 15,
	["ppheight"] = 3,
	["debuffs-x"] = 1,
	["debuffs-y"] = 3,
}

local pet = {
	health = fmt_standard,
}
pet = merge(small, pet)
newStyle("pet", pet)

local targettarget = {
	health = fmt_minonly,
	health2 = fmt_perc,
}
targettarget = merge(small, targettarget)
newStyle("tot", targettarget)

local partypet = {
	["health"] = fmt_standard,
}
partypet = merge(small, partypet)
newStyle("partypet", partypet)
_G.partypet = partypet

local mts = {
	--["initial-width"] = 80,
	["debuffs-y"] = 2,
	["health"] = fmt_minonly,
	["health2"] = fmt_perc,
}
mts = merge(small, mts)
newStyle("mts", mts)

local raid = {
	["initial-width"] = 60,
	["initial-height"] = 30,
	["hpheight"] = 18,
	["ppheight"] = 3,
	["debuffs-x"] = 1,
	["debuffs-y"] = 3,
	["buff-height"] = 10,
	["leader"] = true,
	["health"] = fmt_deficitnomax,
	["range-rade"] = true,
}
newStyle("raid", raid)

-- player
oUF:SetActiveStyle("pa_player")
local player = oUF:Spawn("player", "oUF_Player")
player:SetPoint("RIGHT", UIParent, "CENTER", -80, -230)
player:SetAttribute("toggleForVehicle", true)

-- target
oUF:SetActiveStyle("pa_target")
local target = oUF:Spawn("target", "oUF_Target")
target:SetPoint("LEFT", UIParent, "CENTER", 80, -230)

-- focus
oUF:SetActiveStyle("pa_focus")
local focus = oUF:Spawn("focus", "oUF_Focus")
focus:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 320, -240)

oUF:SetActiveStyle("pa_party")
-- group
local party	= oUF:Spawn("header", "oUF_Party")
party:SetAttribute("template", "oUF_profalbert_party")
party:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -50)
party:SetAttribute("yOffset", -31)
party:SetAttribute("showParty", true)
party:SetAttribute("showPlayer", true)
party:SetAttribute("toggleForVehicle", true)
RegisterStateDriver(party, "visibility", "[group:raid]hide;show")

-- pet
oUF:SetActiveStyle("pa_pet")
local pet = oUF:Spawn("pet", "oUF_Pet")
pet:SetPoint("BOTTOMRIGHT", player, "TOPLEFT", -25, -10)
pet:SetAttribute("toggleForVehicle", true)

oUF:SetActiveStyle("pa_tot")
-- targetstarget
local tot = oUF:Spawn("targettarget", "oUF_TargetTarget")
tot:SetPoint("BOTTOMLEFT", target, "TOPRIGHT", 25, 10)

-- focustarget using pa_tot
local tof = oUF:Spawn("focustarget", "oUF_Focustarget")
tof:SetPoint("LEFT", focus, "RIGHT", 25, 0)

-- contain the party-targets in a frame
local ptcontainer = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(ptcontainer, "visibility", "[group:raid]hide;show")
ptcontainer:SetPoint("TOPLEFT", party, "TOPRIGHT", 35, 0)
oUF:SetActiveStyle("pa_tot")
local pts = {}
pts[1] = oUF:Spawn("party1target", "oUF_Party1Target")
--pts[1]:SetPoint("TOPLEFT", party, "TOPRIGHT", 35, 0)
pts[1]:SetParent(ptcontainer)
pts[1]:SetPoint("TOPLEFT", ptcontainer, "TOPLEFT")
for i =2, 4 do
	pts[i] = oUF:Spawn("party"..i.."target", "oUF_Party"..i.."Target")
	pts[i]:SetPoint("TOP", pts[i-1], "BOTTOM", 0, -50)
	pts[i]:SetParent(ptcontainer)
end

local petcontainer = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(petcontainer, "visibility", "[group:raid]hide;show")
-- The pet header is being a cunt, this is a better solution
oUF:SetActiveStyle("pa_partypet")
local pets = {}
pets[1] = oUF:Spawn("partypet1", "oUF_PartyPet1")
pets[1]:SetAttribute("toggleForVehicle", true)
pets[1]:SetPoint("TOP", pts[1], "BOTTOM", 0, -5)
pets[1]:SetParent(petcontainer)
pets[1]:SetAttribute("toggleForVehicle", true)
for i =2, 4 do
	pets[i] = oUF:Spawn("partypet"..i, "oUF_PartyPet"..i)
	pets[i]:SetAttribute("toggleForVehicle", true)
	pets[i]:SetPoint("TOP", pts[i], "BOTTOM", 0, -5)
	pets[i]:SetParent(petcontainer)
	pets[i]:SetAttribute("toggleForVehicle", true)
end

-- raid frames
oUF:SetActiveStyle("pa_raid")
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
		"point", "TOP"
	)
	RegisterStateDriver(grid[i], "visibility", "[group:raid]show;hide")
end

-- MTs and mt-targets
oUF:SetActiveStyle("pa_mts")
local mts = oUF:Spawn("header", "oUF_MTs")
mts:SetPoint("TOPLEFT", grid[6], "BOTTOMLEFT", 0, -30)
mts:SetManyAttributes(
	"template", "oUF_profalbert_mtt",
	"showRaid", true,
	"yOffset", 1,
	"groupBy", "ROLE",
	"groupFilter", "MAINTANK",
	"groupingOrder", "1,2,3,4,5,6,7,8"
)
RegisterStateDriver(mts, "visibility", "[group:raid]show;hide")

local enableTargetUpdate = function(object)
	-- updating of "invalid" units.
	local OnTargetUpdate
	do
		local timer = 0
		OnTargetUpdate = function(self, elapsed)
			if(not self.unit) then
				return
			elseif(timer >= .5) then
				self:PLAYER_ENTERING_WORLD'OnTargetUpdate'
				timer = 0
			end
			timer = timer + elapsed
		end
	end

	object:SetScript("OnUpdate", OnTargetUpdate)
end

local bossContainer = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(bossContainer, "visibility", "[group:raid]show;hide")
bossContainer:SetPoint("TOPLEFT", mts, "BOTTOMLEFT", 0, -30)
oUF:SetActiveStyle("pa_tot")
local boss = {}
boss[1] = oUF:Spawn("boss1", "oUF_Boss1")
enableTargetUpdate(boss[1])
boss[1]:SetParent(bossContainer)
boss[1]:SetPoint("TOPLEFT", bossContainer, "TOPLEFT")
for i = 2,4 do
	boss[i] = oUF:Spawn("boss" .. i, "oUF_Boss" .. i)
	enableTargetUpdate(boss[i])
	boss[i]:SetPoint("TOP", boss[i-1], "BOTTOM", 0, -5)
	boss[i]:SetParent(bossContainer)
end

-- TODO castbar and targetframe sometimes
local arenaContainer = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
arenaContainer:SetPoint("TOPLEFT", UIParent, "LEFT", 10, 0)
oUF:SetActiveStyle("pa_tot")
local arena = {}
arena[1] = oUF:Spawn("arena1", "oUF_Arena1")
arena[1]:SetParent(arenaContainer)
arena[1]:SetPoint("TOPLEFT", arenaContainer, "TOPLEFT")
for i = 2,5 do
	arena[i] = oUF:Spawn("arena" .. i, "oUF_Arena" .. i)
	arena[i]:SetPoint("TOP", arena[i-1], "BOTTOM", 0, -5)
	arena[i]:SetParent(arenaContainer)
end
-- pets should work
local arenapets = {}
arenapets[1] = oUF:Spawn("arenapet1", "oUF_Arenapet1")
arenapets[1]:SetParent(arenaContainer)
arenapets[1]:SetPoint("TOPLEFT", arena[1], "TOPRIGHT", 5, 0)
for i = 2,5 do
	arenapets[i] = oUF:Spawn("arenapet" .. i, "oUF_Arenapet" .. i)
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

-- handle original bossframes at minimap
for i = 1,4 do
	local frame = _G["Boss" .. i .. "TargetFrame"]
	frame:UnregisterAllEvents()
	frame.Show = dummy
	frame:Hide()
end

-- move the RuneFrame somewhere sane
RuneFrame:ClearAllPoints()
RuneFrame:SetPoint("BOTTOM", player, "TOP", 0, 5)

-- hardcode characternames for now
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
end
