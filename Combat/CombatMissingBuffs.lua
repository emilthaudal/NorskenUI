-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Safety check
if not NorskenUI then
    error("MissingBuffs: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class MissingBuffs: AceModule, AceEvent-3.0
local MBUFFS = NorskenUI:NewModule("MissingBuffs", "AceEvent-3.0")

-- Localization
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local UnitClass, UnitExists, UnitIsDeadOrGhost = UnitClass, UnitExists, UnitIsDeadOrGhost
local UnitIsConnected, UnitCanAssist, UnitIsPlayer = UnitIsConnected, UnitCanAssist, UnitIsPlayer
local UnitPosition = UnitPosition
local InCombatLockdown = InCombatLockdown
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local GetTime = GetTime
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local CreateFrame = CreateFrame
local GetInventorySlotInfo, GetInventoryItemLink = GetInventorySlotInfo, GetInventoryItemLink
local GetItemInfo, GetInventoryItemTexture = GetItemInfo, GetInventoryItemTexture
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local issecretvalue = issecretvalue
local GetShapeshiftForm, GetShapeshiftFormInfo = GetShapeshiftForm, GetShapeshiftFormInfo
local tostring, tonumber = tostring, tonumber
local C_Spell, C_SpellBook = C_Spell, C_SpellBook
local C_PetBattles, C_ChallengeMode = C_PetBattles, C_ChallengeMode
local AuraUtil = AuraUtil
local UIParent = UIParent
local C_Timer = C_Timer

-- Constants
local CHECK_THROTTLE = 0.25
local MISSING_TEXT = "MISSING"
local REAPPLY_TEXT = ""
local GENERALBUFF_TEXT = ""

-- Default icon for weapon enchants
local WEAPON_ENCHANT_ICON = 136244

-- SAFE_BUFFS: Always trackable, never secret spellIds
local SAFE_BUFFS = {
    -- Raid Buffs
    { spellId = 1126,   class = "DRUID",   buffType = "raid" },                          -- Mark of the Wild
    { spellId = 1459,   class = "MAGE",    buffType = "raid" },                          -- Arcane Intellect
    { spellId = 6673,   class = "WARRIOR", buffType = "raid", ignoreRangeCheck = true }, -- Battle Shout
    { spellId = 21562,  class = "PRIEST",  buffType = "raid" },                          -- Power Word: Fortitude
    { spellId = 462854, class = "SHAMAN",  buffType = "raid" },                          -- Skyfury
    {
        spellId = 381748,
        class = "EVOKER",
        buffType = "raid",
        ignoreRangeCheck = true,
        extraBuffSpellIds = { 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 }
    }, -- Blessing of the Bronze

    -- Rogue Poisons (self buffs)
    { spellId = 2823,             class = "ROGUE", buffType = "poison", poisonType = "lethal" },    -- Deadly Poison
    { spellId = 8679,             class = "ROGUE", buffType = "poison", poisonType = "lethal" },    -- Wound Poison
    { spellId = 315584,           class = "ROGUE", buffType = "poison", poisonType = "lethal" },    -- Instant Poison
    { spellId = 381664,           class = "ROGUE", buffType = "poison", poisonType = "lethal" },    -- Amplifying Poison
    { spellId = 3408,             class = "ROGUE", buffType = "poison", poisonType = "nonlethal" }, -- Crippling Poison
    { spellId = 5761,             class = "ROGUE", buffType = "poison", poisonType = "nonlethal" }, -- Numbing Poison
    { spellId = 381637,           class = "ROGUE", buffType = "poison", poisonType = "nonlethal" }, -- Atrophic Poison

    -- Weapon Enchants
    { buffType = "weaponEnchant", slot = "main",   text = "MH",         dbKey = "MHEnchant" },
    { buffType = "weaponEnchant", slot = "off",    text = "OH",         dbKey = "OHEnchant" },
}

-- Food buff names, used ID's before but for my own sanity, we just check name instead (There are a million different food types and ID's :))
local WELL_FED_NAME = C_Spell.GetSpellName(19705)
local HEARTY_WELL_FED_NAME = C_Spell.GetSpellName(462187)

-- RESTRICTED_BUFFS: Secret spellIds, skip in combat/M+
local RESTRICTED_BUFFS = {
    -- Flasks
    { spellId = 1235110, category = "Flask" }, -- Flask of the Blood Knights
    { spellId = 1235057, category = "Flask" }, -- Flask of Thalassian Resistance
    { spellId = 1235111, category = "Flask" }, -- Flask of the Shattered Sun
    { spellId = 1235108, category = "Flask" }, -- Flask of the Magisters
    { spellId = 432021,  category = "Flask" }, -- Alchemical Chaos
    { spellId = 431971,  category = "Flask" }, -- Flask of Tempered Aggression
    { spellId = 431972,  category = "Flask" }, -- Flask of Tempered Swiftness
    { spellId = 431974,  category = "Flask" }, -- Flask of Tempered Mastery
    { spellId = 431973,  category = "Flask" }, -- Flask of Tempered Versatility

    -- Spec-specific self buffs
    {
        spellId = 210126,
        class = "MAGE",
        specId = 62,
        talentId = 205022,
        buffType = "self",
        onlySelf = true
    }, -- Arcane Familiar
}

-- Assassination talent that allows 2 lethal + 2 non-lethal
local ASSA_DOUBLE_POISON_TALENT = 381801

-- Poison spell IDs for icon display
local POISON_IDS = {
    ATROPHIC = 381637,
    NUMBING = 5761,
    CRIPPLING = 3408,
    AMPLIFYING = 381664,
    DEADLY = 2823,
    INSTANT = 315584,
    WOUND = 8679,
}

-- Spec ID to name mapping for each class
local SPEC_ID_TO_NAME = {
    -- Warrior
    [71] = "Arms",
    [72] = "Fury",
    [73] = "Protection",
    -- Paladin
    [65] = "Holy",
    [66] = "Protection",
    [70] = "Retribution",
    -- Druid
    [102] = "Balance",
    [103] = "Feral",
    [104] = "Guardian",
    [105] = "Restoration",
    -- Priest
    [256] = "Discipline",
    [257] = "Holy",
    [258] = "Shadow",
    -- Evoker
    [1467] = "Devastation",
    [1468] = "Preservation",
    [1473] = "Augmentation",
}

-- Unit strings for group checking
local UNIT_STRINGS = { raid = {}, party = {} }
for i = 1, 40 do
    UNIT_STRINGS.raid[i] = "raid" .. i
    if i <= 5 then
        UNIT_STRINGS.party[i] = "party" .. i
    end
end

-- Module state
local playerClass = nil
local isThrottled = false
local lastCheckTime = 0

-- Frame state
local containerFrame = nil
local stanceFrame = nil
local stanceTextFrame = nil
local iconPool = {}
local activeIcons = {}
local currentMissingBuffs = {}

-- Preview state
local isPreviewActive = false

-- Load condition checker
local function IsLoadConditionMet(loadCondition)
    if not loadCondition or loadCondition == "ALWAYS" then return true end
    local groupSize = GetNumGroupMembers()
    local inRaid = IsInRaid()
    local inGroup = groupSize > 0

    if loadCondition == "ANYGROUP" then
        return inGroup
    elseif loadCondition == "PARTY" then
        return inGroup and not inRaid
    elseif loadCondition == "RAID" then
        return inRaid
    elseif loadCondition == "NOGROUP" then
        return not inGroup
    end

    return true -- Default to true for unknown conditions
end

-- Small helpers to get spell info and texture
local function IsSpellKnown(spellId)
    return spellId and C_SpellBook.IsSpellKnown(spellId)
end
local function GetSpellTexture(spellId)
    if spellId and spellId > 0 then
        return C_Spell.GetSpellTexture(spellId)
    end
    return nil
end

-- Checker for valid units to track,
-- basically filter out units that cannot be affected and/or affect buff status
local function IsValidTarget(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsConnected(unit) then return false end
    if not UnitIsPlayer(unit) then return false end
    if not UnitCanAssist("player", unit) then return false end
    -- Filter out units not in the same instance as the player, ty echo wizards for suggestion
    local _, _, _, playerInstanceId = UnitPosition("player")
    local _, _, _, unitInstanceId = UnitPosition(unit)
    if playerInstanceId and unitInstanceId and playerInstanceId ~= unitInstanceId then
        return false
    end
    return true
end

-- Check player buff status
local function PlayerHasBuff(spellId, extraSpellIds)
    if not spellId then return false, nil end

    local hasBuff = false
    local expirationTime = nil

    AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraInfo)
        if issecretvalue(auraInfo.spellId) then return end
        if not auraInfo or not auraInfo.spellId then return false end

        if auraInfo.spellId == spellId then
            hasBuff = true
            expirationTime = auraInfo.expirationTime
            return true
        end

        if extraSpellIds then
            for _, extraId in ipairs(extraSpellIds) do
                if auraInfo.spellId == extraId then
                    hasBuff = true
                    expirationTime = auraInfo.expirationTime
                    return true
                end
            end
        end
        return false
    end, true)

    return hasBuff, expirationTime
end

-- Check unit buff status
local function UnitHasBuff(unit, spellId, extraSpellIds)
    if issecretvalue(unit) or issecretvalue(spellId) or issecretvalue(extraSpellIds) then return end
    if not unit or not IsValidTarget(unit) then return true end
    local hasBuff = false

    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraInfo)
        if issecretvalue(auraInfo) or issecretvalue(auraInfo.spellId) then return end -- Note, still need these checks since they can try to check any aura
        if not auraInfo or not auraInfo.spellId then return false end

        if auraInfo.spellId == spellId then
            hasBuff = true
            return true
        end

        if extraSpellIds then
            for _, extraId in ipairs(extraSpellIds) do
                if auraInfo.spellId == extraId then
                    hasBuff = true
                    return true
                end
            end
        end
        return false
    end, true)

    return hasBuff
end

-- Check if we should track the buff at all
local function ShouldTrackBuff(buff)
    -- Class check
    if buff.class and buff.class ~= playerClass then return false end

    -- Spec check
    if buff.specId then
        local currentSpec = GetSpecialization()
        if currentSpec then
            local specId = GetSpecializationInfo(currentSpec)
            if specId ~= buff.specId then return false end
        else
            return false
        end
    end

    -- Talent check
    if buff.talentId and not IsSpellKnown(buff.talentId) then return false end

    -- User settings enabled check
    local dbKey = buff.dbKey or buff.category
    if dbKey and MBUFFS.db then
        local settings = MBUFFS.db.Consumables and MBUFFS.db.Consumables[dbKey]
        if settings then
            if settings.Enabled == false then return false end
            if not IsLoadConditionMet(settings.LoadCondition) then return false end
        end
    end

    return true
end

-- Check buff status and return count info for raid buffs
local function CheckBuffWithCount(buff)
    local result = {
        isMissing = false,
        needsReapply = false,
        buffedCount = 0,
        totalCount = 0,
        buff = buff,
    }

    -- Player check
    local hasBuff, expTime = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
    if hasBuff then
        result.buffedCount = 1
    else
        result.isMissing = true
    end

    -- Reapply check
    if expTime and expTime > 0 then
        local timeLeft = (expTime - GetTime()) / 60
        if MBUFFS.db and MBUFFS.db.NotifyLowDuration and timeLeft <= MBUFFS.db.LowDurationThreshold then
            result.needsReapply = true
        end
    end

    -- Group check for raid buffs
    if buff.buffType == "raid" and not buff.onlySelf then
        local groupSize = GetNumGroupMembers()
        if groupSize > 0 then
            result.totalCount = 1 -- Start with player

            local units = IsInRaid() and UNIT_STRINGS.raid or UNIT_STRINGS.party
            local maxIndex = IsInRaid() and groupSize or (groupSize - 1)

            for i = 1, maxIndex do
                local unit = units[i]
                if IsValidTarget(unit) then
                    result.totalCount = result.totalCount + 1
                    if UnitHasBuff(unit, buff.spellId, buff.extraBuffSpellIds) then
                        result.buffedCount = result.buffedCount + 1
                    elseif not result.isMissing then
                        -- Check range
                        if buff.ignoreRangeCheck or C_Spell.IsSpellInRange(buff.spellId, unit) then
                            result.isMissing = true
                        end
                    end
                end
            end
        else
            result.totalCount = 1
        end
    else
        result.totalCount = 1
    end

    return result
end

-- Format display text for buffs
local function GetBuffDisplayText(buff, checkResult, isOwnClassBuff)
    if buff.text then return buff.text end

    -- Raid buffs, show count if player is the class that provides this buff, feature requested by Sir
    if buff.buffType == "raid" and isOwnClassBuff and checkResult and checkResult.totalCount > 1 then
        return checkResult.buffedCount .. "/" .. checkResult.totalCount
    end
    return ""
end

-- Get buff-providing classes present in the group and in the same instance as the player
local function GetGroupBuffClasses()
    local classesInGroup = {}
    local groupSize = GetNumGroupMembers()
    local _, _, _, playerInstanceId = UnitPosition("player")

    -- Solo we only check player's own class
    if groupSize == 0 then
        if playerClass then
            classesInGroup[playerClass] = true
        end
        return classesInGroup
    end

    if IsInRaid() then
        for i = 1, groupSize do
            local unit = UNIT_STRINGS.raid[i]
            if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
                local _, _, _, unitInstanceId = UnitPosition(unit)
                if not playerInstanceId or not unitInstanceId or playerInstanceId == unitInstanceId then
                    local _, class = UnitClass(unit)
                    if class then
                        classesInGroup[class] = true
                    end
                end
            end
        end
    else
        if playerClass then
            classesInGroup[playerClass] = true
        end
        for i = 1, groupSize - 1 do
            local unit = UNIT_STRINGS.party[i]
            if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
                local _, _, _, unitInstanceId = UnitPosition(unit)
                if not playerInstanceId or not unitInstanceId or playerInstanceId == unitInstanceId then
                    local _, class = UnitClass(unit)
                    if class then
                        classesInGroup[class] = true
                    end
                end
            end
        end
    end

    return classesInGroup
end

-- Check weapon enchant status
local function HasWeaponEnchant(slot)
    local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
    local slotName = slot == "main" and "MAINHANDSLOT" or slot == "off" and "SECONDARYHANDSLOT"
    if not slotName then return nil, nil, false end
    local slotID = GetInventorySlotInfo(slotName)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then return nil, nil, false end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc then return nil, nil, false end

    if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then return nil, nil, false end

    local hasEnchant
    if slot == "main" then
        hasEnchant = hasMain
    else
        hasEnchant = hasOff
    end
    local icon = GetInventoryItemTexture("player", slotID)

    if not icon then return hasEnchant, nil, false end
    return hasEnchant, icon, true
end

-- Check buffs that blizzy made non secret so we can check these always
local function CheckSafeBuffs()
    local missing = {}
    if not MBUFFS.db then return missing end
    local consumablesDb = MBUFFS.db.Consumables or {}
    local raidBuffsSettings = consumablesDb.RaidBuffs or {}
    local raidBuffsEnabled = raidBuffsSettings.Enabled ~= false
    local raidBuffsLoadMet = IsLoadConditionMet(raidBuffsSettings.LoadCondition)
    local poisonSettings = consumablesDb.Poisons or {}
    local poisonsEnabled = poisonSettings.Enabled ~= false
    local poisonsLoadMet = IsLoadConditionMet(poisonSettings.LoadCondition)

    -- Track which buff classes are in the group
    local groupBuffClasses = GetGroupBuffClasses()

    -- Poison tracking state
    local lethalCount = 0
    local nonLethalCount = 0
    local spec = GetSpecialization()
    local specId = spec and GetSpecializationInfo(spec)
    local isAssassination = specId == 259
    local hasDoublePoisonTalent = isAssassination and IsSpellKnown(ASSA_DOUBLE_POISON_TALENT)
    local requiredLethal = hasDoublePoisonTalent and 2 or 1
    local requiredNonLethal = hasDoublePoisonTalent and 2 or 1

    -- Count poisons player has
    if playerClass == "ROGUE" and poisonsEnabled and poisonsLoadMet then
        for _, buff in ipairs(SAFE_BUFFS) do
            if buff.buffType == "poison" and PlayerHasBuff(buff.spellId) then
                if buff.poisonType == "lethal" then
                    lethalCount = lethalCount + 1
                else
                    nonLethalCount = nonLethalCount + 1
                end
            end
        end
    end

    -- Check raid buffs
    for _, buff in ipairs(SAFE_BUFFS) do
        if buff.buffType == "raid" and raidBuffsEnabled and raidBuffsLoadMet then
            local isOwnClassBuff = buff.class == playerClass

            if isOwnClassBuff then
                -- Player can cast this buff
                -- Shows count checker of total elligible units in the instance vs units that currently have buff, for example "5/20"
                if IsSpellKnown(buff.spellId) then
                    local result = CheckBuffWithCount(buff)
                    if result.isMissing or result.needsReapply then
                        local displayText = GetBuffDisplayText(buff, result, true)
                        missing[#missing + 1] = {
                            buff = buff,
                            text = displayText,
                            checkResult = result,
                        }
                    end
                end
            else
                -- Buff from another class, only show if that class is in group and player themselves is missing it
                if groupBuffClasses[buff.class] then
                    local hasBuff = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
                    if not hasBuff then
                        missing[#missing + 1] = {
                            buff = buff,
                            text = "",
                        }
                    end
                end
            end
        end
    end

    -- Check weapon enchants
    for _, buff in ipairs(SAFE_BUFFS) do
        if buff.buffType == "weaponEnchant" and ShouldTrackBuff(buff) then
            local hasEnchant, icon, hasItem = HasWeaponEnchant(buff.slot)
            if hasItem and not hasEnchant then
                missing[#missing + 1] = {
                    buff = {
                        spellId = 0,
                        text = buff.text,
                        iconTexture = icon or WEAPON_ENCHANT_ICON,
                    },
                    text = buff.text,
                }
            end
        end
    end

    -- Check rogue poisons
    if playerClass == "ROGUE" and poisonsEnabled and poisonsLoadMet then
        local lethalMissing = requiredLethal - lethalCount
        local nonLethalMissing = requiredNonLethal - nonLethalCount

        if lethalMissing > 0 then
            local lethalIcons = {}
            if isAssassination then
                lethalIcons[1] = POISON_IDS.DEADLY
                if hasDoublePoisonTalent then
                    lethalIcons[2] = IsSpellKnown(POISON_IDS.AMPLIFYING) and POISON_IDS.AMPLIFYING or POISON_IDS.INSTANT
                end
            else
                lethalIcons[1] = POISON_IDS.INSTANT
            end

            for i = 1, lethalMissing do
                local iconSpellId = lethalIcons[i] or lethalIcons[1]
                missing[#missing + 1] = {
                    buff = { spellId = iconSpellId, text = "" },
                    text = "",
                }
            end
        end

        if nonLethalMissing > 0 then
            local nonLethalIcons = {}
            nonLethalIcons[1] = POISON_IDS.ATROPHIC
            if hasDoublePoisonTalent then
                nonLethalIcons[2] = POISON_IDS.CRIPPLING
            end

            for i = 1, nonLethalMissing do
                local iconSpellId = nonLethalIcons[i] or nonLethalIcons[1]
                missing[#missing + 1] = {
                    buff = { spellId = iconSpellId, text = "" },
                    text = "",
                }
            end
        end
    end

    return missing
end

-- Check for food buff by name
local function PlayerHasFoodBuff()
    local hasBuff = false
    local foundSpellId = nil

    AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraInfo)
        if not auraInfo or not auraInfo.name then return false end

        if auraInfo.name == WELL_FED_NAME or auraInfo.name == HEARTY_WELL_FED_NAME then
            hasBuff = true
            foundSpellId = auraInfo.spellId
            return true
        end
        return false
    end, true)

    return hasBuff, foundSpellId
end

-- Check buffs that are still secret in combat/m+
local function CheckRestrictedBuffs()
    local missing = {}
    if not MBUFFS.db then return missing end
    if InCombatLockdown() or C_ChallengeMode.IsChallengeModeActive() then return missing end -- Skip in combat or M+
    local consumablesDb = MBUFFS.db.Consumables or {}
    local categorySatisfied = {}

    -- Check food by name
    local foodSettings = consumablesDb.Food or {}
    if foodSettings.Enabled ~= false and IsLoadConditionMet(foodSettings.LoadCondition) then
        local hasFood = PlayerHasFoodBuff()
        if hasFood then
            categorySatisfied["Food"] = true
        end
    end

    -- Check flask and self buffs
    for _, buff in ipairs(RESTRICTED_BUFFS) do
        if ShouldTrackBuff(buff) then
            if buff.category then
                -- Flask category
                if not categorySatisfied[buff.category] then
                    if PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds) then
                        categorySatisfied[buff.category] = true
                    end
                end
            elseif buff.buffType == "self" then
                -- Self buff, like Arcane Familiar
                local hasBuff = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
                if not hasBuff then
                    missing[#missing + 1] = {
                        buff = buff,
                        text = "",
                    }
                end
            end
        end
    end

    -- Check if food is missing
    if foodSettings.Enabled ~= false and IsLoadConditionMet(foodSettings.LoadCondition) then
        if not categorySatisfied["Food"] then
            missing[#missing + 1] = {
                buff = {
                    spellId = 19705,
                    text = "",
                },
                text = "",
            }
        end
    end

    -- Create missing entries
    local categorySeen = {}
    for _, buff in ipairs(RESTRICTED_BUFFS) do
        if buff.category and ShouldTrackBuff(buff) then
            if not categorySatisfied[buff.category] and not categorySeen[buff.category] then
                categorySeen[buff.category] = true
                missing[#missing + 1] = {
                    buff = {
                        spellId = buff.spellId,
                        text = "",
                    },
                    text = "",
                }
            end
        end
    end

    return missing
end

-- General buff icon creation and handling
local function CreateIcon()
    local raidDb = MBUFFS.db.RaidBuffDisplay
    local iconFrame = NRSKNUI:CreateIconFrame(containerFrame, raidDb.IconSize)
    NRSKNUI:ApplyFontSettings(iconFrame, raidDb, nil)
    iconFrame.text:SetTextColor(1, 1, 1, 1)
    iconFrame.text:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    iconFrame:Hide()
    return iconFrame
end

local function AcquireIcon()
    for _, icon in ipairs(iconPool) do
        if not icon.inUse then
            icon.inUse = true
            return icon
        end
    end

    local newIcon = CreateIcon()
    newIcon.inUse = true
    iconPool[#iconPool + 1] = newIcon
    return newIcon
end

local function ReleaseIcon(icon)
    icon.inUse = false
    icon:Hide()
    icon:ClearAllPoints()
end

local function ReleaseAllIcons()
    for _, icon in ipairs(activeIcons) do
        ReleaseIcon(icon)
    end
    wipe(activeIcons)
end

-- Container for general buff icons
local function CreateContainerFrame()
    if containerFrame then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay
    containerFrame = CreateFrame("Frame", "NRSKNUI_MissingBuffContainer", UIParent)
    containerFrame:SetSize(400, raidDb.IconSize)
    NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)
    containerFrame:Hide()
end

-- Warrior stance spell IDs
local WARRIOR_STANCE_SPELLS = {
    [386164] = true, -- Battle Stance
    [386196] = true, -- Berserker Stance
    [386208] = true, -- Defensive Stance
}
local STANCE_TIMER_DURATION = 3

-- Stance timer state
local stanceTimerHandle = nil
local stanceTimerActive = false

-- Stance icon creation
local function CreateStanceFrame()
    if stanceFrame then return end
    local stanceDb = MBUFFS.db.StanceDisplay

    stanceFrame = NRSKNUI:CreateIconFrame(UIParent, stanceDb.IconSize, {
        name = "NRSKNUI_MissingStanceIcon",
    })

    -- Position text above the icon
    stanceFrame.text:ClearAllPoints()
    stanceFrame.text:SetPoint("BOTTOM", stanceFrame, "TOP", 1, 4)

    -- Create cooldown frame for stance timer
    local cooldown = CreateFrame("Cooldown", nil, stanceFrame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(stanceFrame)
    cooldown:SetFrameLevel(stanceFrame:GetFrameLevel() + 1)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(false)

    -- Style cooldown text
    local cdText = cooldown:GetRegions()
    if cdText and cdText.SetFont then
        cdText:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, stanceDb.IconSize * 0.5, "OUTLINE")
        cdText:SetShadowColor(0, 0, 0, 0)
        cdText:SetShadowOffset(0, 0)
        cdText:ClearAllPoints()
        cdText:SetPoint("CENTER", stanceFrame, "CENTER", 1, 0)
    end

    -- Store for later use
    stanceFrame.cooldown = cooldown

    NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)
    NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
    stanceFrame.text:SetTextColor(1, 1, 1, 1)
    stanceFrame:Hide()
end

-- Stance text frame
local function CreateStanceTextFrame()
    if stanceTextFrame then return end
    local textDb = MBUFFS.db.StanceText

    -- Create frame using helper
    stanceTextFrame = NRSKNUI:CreateTextFrame(UIParent, 200, 30, {
        name = "NRSKNUI_StanceTextDisplay",
    })

    -- Apply position and font settings
    NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)
    NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)

    -- Text alignment based on anchor point
    local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
    local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
    stanceTextFrame.text:ClearAllPoints()
    stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
    stanceTextFrame.text:SetJustifyH(textJustify)
    stanceTextFrame.text:SetTextColor(1, 1, 1, 1)

    stanceTextFrame:Hide()
end

-- Show the stance icon
local function ShowStanceIcon(spellId, reverseIcon, currentSpellId)
    if not stanceFrame then CreateStanceFrame() end
    local stanceDb = MBUFFS.db.StanceDisplay
    if stanceFrame then
        -- Apply texture settings
        local displaySpellId = (reverseIcon and currentSpellId) and currentSpellId or spellId
        local texture = GetSpellTexture(displaySpellId)
        stanceFrame.icon:SetTexture(texture)

        -- Apply Font Settings
        NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
        stanceFrame.text:SetText(reverseIcon and "" or MISSING_TEXT)

        -- Apply icon size settings
        stanceFrame:SetSize(stanceDb.IconSize, stanceDb.IconSize)
        stanceFrame.icon:SetSize(stanceDb.IconSize, stanceDb.IconSize)

        -- Apply position with custom anchor frame
        NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)

        -- Show frame
        stanceFrame:Show()
    end
end

-- Stance text display functions
local function UpdateStanceTextDisplay()
    if not MBUFFS.db then return end
    local textDb = MBUFFS.db.StanceText

    -- Check if stance text is enabled
    if not textDb.Enabled then
        if stanceTextFrame then stanceTextFrame:Hide() end
        return
    end

    -- Only show for warrior/paladin
    if playerClass ~= "WARRIOR" and playerClass ~= "PALADIN" then
        if stanceTextFrame then stanceTextFrame:Hide() end
        return
    end

    -- Create frame if needed
    if not stanceTextFrame then CreateStanceTextFrame() end

    -- Get current form/stance
    local currentForm = GetShapeshiftForm()
    local currentSpellId = nil

    if currentForm > 0 then
        local _, _, _, formSpellId = GetShapeshiftFormInfo(currentForm)
        currentSpellId = formSpellId
    end

    -- For paladin, check auras via buff
    if playerClass == "PALADIN" then
        local paladinAuras = { 465, 317920, 32223 }
        for _, auraId in ipairs(paladinAuras) do
            if PlayerHasBuff(auraId) then
                currentSpellId = auraId
                break
            end
        end
    end
    if stanceTextFrame then
        -- No stance active
        if not currentSpellId then
            stanceTextFrame:Hide()
            return
        end

        -- Get settings for this stance
        local classData = textDb[playerClass]
        if not classData then
            stanceTextFrame:Hide()
            return
        end

        local stanceKey = tostring(currentSpellId)
        local stanceSettings = classData[stanceKey]

        if not stanceSettings or not stanceSettings.Enabled then
            stanceTextFrame:Hide()
            return
        end

        -- Update text and color
        local text = stanceSettings.Text or "Stance"
        local color = stanceSettings.Color or { 1, 1, 1, 1 }

        stanceTextFrame.text:SetText(text)
        stanceTextFrame.text:SetTextColor(color[1], color[2], color[3], color[4] or 1)

        -- Update font
        NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)

        -- Update position
        NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)

        -- Update text alignment based on anchor point
        local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
        local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
        stanceTextFrame.text:ClearAllPoints()
        stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
        stanceTextFrame.text:SetJustifyH(textJustify)
        stanceTextFrame:Show()
    end
end

-- Update icon texture, font and size
local function UpdateIconAppearance(iconFrame, buff, text)
    -- Apply texture settings
    local texture = GetSpellTexture(buff.spellId)
    if not texture then texture = buff.iconTexture or WEAPON_ENCHANT_ICON end
    iconFrame.icon:SetTexture(texture)

    -- Apply font settings
    NRSKNUI:ApplyFontSettings(iconFrame, MBUFFS.db.RaidBuffDisplay, nil)
    iconFrame.text:SetText(text or buff.text or GENERALBUFF_TEXT)

    -- Apply size settings
    iconFrame:SetSize(MBUFFS.db.RaidBuffDisplay.IconSize, MBUFFS.db.RaidBuffDisplay.IconSize)
    iconFrame.icon:SetAllPoints(iconFrame)
end

-- Icon arranger, uses center horizontal layout
-- TODO: Maybe add left and right layout?
local function ArrangeIcons()
    if not containerFrame then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay or {}
    local count = #activeIcons

    if count == 0 then
        containerFrame:Hide()
        return
    end

    local totalWidth = (raidDb.IconSize * count) + (raidDb.IconSpacing * (count - 1))
    containerFrame:SetSize(totalWidth, raidDb.IconSize)

    local startX = -totalWidth / 2 + raidDb.IconSize / 2
    for i, iconFrame in ipairs(activeIcons) do
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("CENTER", containerFrame, "CENTER", startX + (i - 1) * (raidDb.IconSize + raidDb.IconSpacing),
            0)
        iconFrame:Show()
    end

    -- Update container position
    NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)

    containerFrame:Show()
end

-- Check stances/forms
local function CheckStances()
    if playerClass == "WARRIOR" and stanceTimerActive then
        UpdateStanceTextDisplay()
        return
    end

    if stanceFrame then
        stanceFrame:Hide()
    end
    -- Also update stance text display
    UpdateStanceTextDisplay()
    if not MBUFFS.db then return end

    -- Check if stances feature is enabled at all
    local stancesDb = MBUFFS.db.Stances
    if not stancesDb then return end
    if stancesDb.Enabled == false then return end

    -- Get current spec info
    local spec = GetSpecialization()
    if not spec then return end
    local currentSpecId = GetSpecializationInfo(spec)
    local specName = SPEC_ID_TO_NAME[currentSpecId]

    -- Get class settings
    local classSettings = stancesDb[playerClass]
    if not classSettings then return end

    -- Special handling for Priest
    if playerClass == "PRIEST" then
        if not classSettings.ShadowEnabled then return end
        if currentSpecId ~= 258 then return end

        -- When you enter voidform cd, standard tracking is overriden and we cant check this in combat
        -- This is fine since almost always, you would want to be in shadowform pre combat so we just return early here
        if InCombatLockdown or C_ChallengeMode.IsChallengeModeActive() then
            return
        end

        -- Check for Shadowform
        local shadowformSpellId = 232698
        local hasShadowform = PlayerHasBuff(shadowformSpellId, { 194249 }) -- Shadowform or Voidform
        if not hasShadowform and IsSpellKnown(shadowformSpellId) then
            ShowStanceIcon(shadowformSpellId)
        end
        return
    end

    -- Special handling for Druid
    if playerClass == "DRUID" then
        local druidSpecs = {
            [102] = { toggleKey = "BalanceEnabled", spellId = 24858 },
            [103] = { toggleKey = "FeralEnabled", spellId = 768 },
            [104] = { toggleKey = "GuardianEnabled", spellId = 5487 },
        }

        local specData = druidSpecs[currentSpecId]
        if not specData then return end
        if not classSettings[specData.toggleKey] then return end

        -- Get current form
        local currentForm = GetShapeshiftForm()
        local currentSpellId = nil
        if currentForm > 0 then
            local _, _, _, formSpellId = GetShapeshiftFormInfo(currentForm)
            currentSpellId = formSpellId
        end

        -- Check if missing required form
        if currentSpellId ~= specData.spellId then
            if IsSpellKnown(specData.spellId) then
                ShowStanceIcon(specData.spellId)
            end
        end
        return
    end

    -- Special handling for Evoker
    if playerClass == "EVOKER" then
        if not classSettings.AugmentationEnabled then return end
        if currentSpecId ~= 1473 then return end

        local requiredSpellId = tonumber(classSettings.Augmentation) or 403264

        -- Check if has attunement buff
        local hasAttunement = PlayerHasBuff(requiredSpellId)
        if not hasAttunement and IsSpellKnown(requiredSpellId) then
            ShowStanceIcon(requiredSpellId)
        end
        return
    end

    -- Warrior and Paladin use per-spec toggles only
    if not specName then return end

    -- Default required stances per spec
    local DEFAULT_STANCES = {
        WARRIOR = {
            Arms = 386164,       -- Battle Stance
            Fury = 386196,       -- Berserker Stance
            Protection = 386208, -- Defensive Stance
        },
        PALADIN = {
            Holy = 465,          -- Devotion Aura
            Protection = 465,    -- Devotion Aura
            Retribution = 32223, -- Crusader Aura
        },
    }

    -- Check if spec toggle is enabled
    local specEnabledKey = specName .. "Enabled"
    if not classSettings[specEnabledKey] then return end

    -- Get required stance
    local classDefaults = DEFAULT_STANCES[playerClass]
    local defaultStance = classDefaults and classDefaults[specName]
    local requiredStanceId = tonumber(classSettings[specName]) or defaultStance
    if not requiredStanceId then return end

    -- Get reverse icon setting
    local reverseIconKey = specName .. "ReverseIcon"
    local reverseIcon = classSettings[reverseIconKey] and true or false

    -- Get current form/stance
    local currentForm = GetShapeshiftForm()
    local currentSpellId = nil
    if currentForm > 0 then
        local _, _, _, formSpellId = GetShapeshiftFormInfo(currentForm)
        currentSpellId = formSpellId
    end

    -- For Paladin, check auras via buffs
    if playerClass == "PALADIN" then
        local paladinAuras = { 465, 317920, 32223 }
        for _, auraId in ipairs(paladinAuras) do
            if PlayerHasBuff(auraId) then
                currentSpellId = auraId
                break
            end
        end
    end

    -- Check if missing required stance
    if currentSpellId ~= requiredStanceId then
        if IsSpellKnown(requiredStanceId) then
            ShowStanceIcon(requiredStanceId, reverseIcon, currentSpellId)
        end
    end
end

-- Show stance timer for warrior
local function ShowStanceTimer(spellId)
    if not stanceFrame then CreateStanceFrame() end
    if not stanceFrame then return end
    if not stanceFrame.cooldown then return end

    -- Mark timer as active
    stanceTimerActive = true

    -- Show the icon for the stance we switched to
    local texture = GetSpellTexture(spellId)
    if texture then
        stanceFrame.icon:SetTexture(texture)
    end
    stanceFrame.text:SetText("")

    -- Start cooldown animation
    stanceFrame.cooldown:SetAllPoints(stanceFrame)
    stanceFrame.cooldown:SetCooldown(GetTime(), STANCE_TIMER_DURATION)
    stanceFrame:Show()

    -- Cancel existing timer if any
    if stanceTimerHandle then
        stanceTimerHandle:Cancel()
    end

    -- After duration, clear flag and re-check stances
    stanceTimerHandle = C_Timer.NewTimer(STANCE_TIMER_DURATION, function()
        stanceTimerHandle = nil
        stanceTimerActive = false
        if stanceFrame and not isPreviewActive then
            CheckStances()
        end
    end)
end

-- Show missing buffs
local function ShowMissingBuffs(missingList)
    ReleaseAllIcons()
    for _, entry in ipairs(missingList) do
        local iconFrame = AcquireIcon()
        UpdateIconAppearance(iconFrame, entry.buff, entry.text)
        activeIcons[#activeIcons + 1] = iconFrame
    end
    ArrangeIcons()
end

-- Hide only the raid buff container
local function HideMissingBuffIcons()
    ReleaseAllIcons()
    if containerFrame then
        containerFrame:Hide()
    end
end

-- Hide everything
local function HideAllNotifications()
    HideMissingBuffIcons()
    if stanceFrame then
        stanceFrame:Hide()
    end
    if stanceTextFrame then
        stanceTextFrame:Hide()
    end
end

-- Check only weapon enchants (for combat-safe checking)
local function CheckWeaponEnchants()
    if not MBUFFS.db then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay or {}

    for _, buff in ipairs(SAFE_BUFFS) do
        if buff.buffType == "weaponEnchant" and ShouldTrackBuff(buff) then
            local hasEnchant, icon, hasItem = HasWeaponEnchant(buff.slot)
            if hasItem and not hasEnchant then
                local iconFrame = AcquireIcon()
                local displayIcon = icon or WEAPON_ENCHANT_ICON
                local text = buff.text or GENERALBUFF_TEXT
                local iconSize = raidDb.IconSize

                iconFrame.icon:SetTexture(displayIcon)
                iconFrame:SetSize(iconSize, iconSize)
                iconFrame.icon:SetSize(iconSize, iconSize)
                NRSKNUI:ApplyFontSettings(iconFrame, raidDb, nil)
                iconFrame.text:SetText(text)
                activeIcons[#activeIcons + 1] = iconFrame
                currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = text }
            end
        end
    end
end

-- Check combat-safe elements (weapon enchants and stances)
local function CheckCombatSafeElements()
    if isPreviewActive then return end
    if not MBUFFS.db or not MBUFFS.db.Enabled then return end
    if UnitIsDeadOrGhost("player") or C_PetBattles.IsInBattle() then return end
    ReleaseAllIcons()
    wipe(currentMissingBuffs)
    -- Check weapon enchants and stances
    CheckWeaponEnchants()
    CheckStances()
    ArrangeIcons()
end

-- Check if tracking should be paused
local function IsTrackingPaused()
    return isPreviewActive
end

-- Main Check Function
local function CheckForMissingBuffs()
    -- Don't run checks when GUI or edit mode is open
    if IsTrackingPaused() then return end
    -- Throttled checks
    local currentTime = GetTime()
    if currentTime - lastCheckTime < CHECK_THROTTLE then
        if not isThrottled then
            isThrottled = true
            C_Timer.After(CHECK_THROTTLE, function()
                isThrottled = false
                CheckForMissingBuffs()
            end)
        end
        return
    end
    lastCheckTime = currentTime
    if not MBUFFS.db or not MBUFFS.db.Enabled then
        HideAllNotifications()
        return
    end
    -- In combat: only check combat-safe elements
    if InCombatLockdown() then
        CheckCombatSafeElements()
        return
    end
    if UnitIsDeadOrGhost("player") or C_PetBattles.IsInBattle() then
        HideAllNotifications()
        return
    end

    wipe(currentMissingBuffs)

    -- Check SAFE_BUFFS
    local safeMissing = CheckSafeBuffs()
    for _, entry in ipairs(safeMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    -- Check RESTRICTED_BUFFS
    -- Only runs when NOT in combat and NOT in M+
    local restrictedMissing = CheckRestrictedBuffs()
    for _, entry in ipairs(restrictedMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    -- Check stances/forms
    CheckStances()
    if #currentMissingBuffs > 0 then
        ShowMissingBuffs(currentMissingBuffs)
    else
        HideMissingBuffIcons()
    end
end

-- Event Handlers
local function OnAuraChange(unit, updateInfo)
    if not MBUFFS.db or not MBUFFS.db.Enabled then return end
    if IsTrackingPaused() then return end
    if unit ~= "player" and not (unit and (unit:find("party") or unit:find("raid"))) then return end
    if InCombatLockdown() then return end
    if updateInfo and not updateInfo.isFullUpdate then
        local hasRelevant = false
        if updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if issecretvalue(aura.isHelpful) then return end
                if aura.isHelpful then
                    hasRelevant = true
                    break
                end
            end
        end
        if updateInfo.removedAuraInstanceIDs and #updateInfo.removedAuraInstanceIDs > 0 then
            hasRelevant = true
        end
        if not hasRelevant then
            return
        end
    end
    CheckForMissingBuffs()
end

-- Update db, used for profile changes
function MBUFFS:UpdateDB()
    self.db = NRSKNUI.db.profile.MissingBuffs
end

-- Module init
function MBUFFS:OnInitialize()
    self:UpdateDB()
    local _, class = UnitClass("player")
    playerClass = class
    self:SetEnabledState(false)
end

-- Module OnEnable
function MBUFFS:OnEnable()
    if not self.db or not self.db.Enabled then return end

    -- Create frames
    CreateContainerFrame()
    CreateStanceFrame()
    CreateStanceTextFrame()

    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)

    -- Register events
    self:RegisterEvent("UNIT_AURA", function(_, unit, updateInfo) OnAuraChange(unit, updateInfo) end)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        HideMissingBuffIcons()
        CheckCombatSafeElements()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("PLAYER_ALIVE", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_DEAD", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_UNGHOST", function() CheckForMissingBuffs() end)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("SCENARIO_UPDATE", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("START_TIMER", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", function() C_Timer.After(0, CheckForMissingBuffs) end)
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("SPELLS_CHANGED", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        CheckForMissingBuffs()
        UpdateStanceTextDisplay()
    end)
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
        CheckForMissingBuffs()
        UpdateStanceTextDisplay()
    end)

    -- For Warrior stance changes
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        if playerClass ~= "WARRIOR" then return end
        if not WARRIOR_STANCE_SPELLS[spellID] then return end
        if isPreviewActive then return end

        -- Check if stance display is enabled
        local stanceDb = self.db and self.db.StanceDisplay
        if not stanceDb or not stanceDb.Enabled then return end

        -- Get current spec and required stance
        local stancesDb = self.db and self.db.Stances
        local classSettings = stancesDb and stancesDb.WARRIOR
        if not classSettings then return end

        local spec = GetSpecialization()
        if not spec then return end
        local specId = GetSpecializationInfo(spec)
        local specName = SPEC_ID_TO_NAME[specId]
        if not specName then return end

        -- Check if this spec has tracking enabled
        local specEnabledKey = specName .. "Enabled"
        if not classSettings[specEnabledKey] then return end

        -- Get required stance for this spec
        local DEFAULT_STANCES = {
            Arms = 386164,
            Fury = 386196,
            Protection = 386208,
        }
        local requiredStanceId = tonumber(classSettings[specName]) or DEFAULT_STANCES[specName]

        -- If switching to required stance, instantly hide and cancel timer
        if spellID == requiredStanceId then
            if stanceTimerHandle then
                stanceTimerHandle:Cancel()
                stanceTimerHandle = nil
            end
            stanceTimerActive = false
            if stanceFrame then
                stanceFrame:Hide()
            end
        else
            -- Switching to wrong stance, show 3s timer
            ShowStanceTimer(spellID)
        end
    end)

    -- M+ events
    self:RegisterEvent("CHALLENGE_MODE_START", function() C_Timer.After(1, CheckForMissingBuffs) end)

    C_Timer.After(2, CheckForMissingBuffs)

    -- Register with edit mode
    self:RegisterEditModeElements()
end

-- Register all edit mode elements
function MBUFFS:RegisterEditModeElements()
    if not NRSKNUI.EditMode then return end

    -- Ensure frames exist before registering
    if not containerFrame then CreateContainerFrame() end
    if not stanceFrame then CreateStanceFrame() end
    if not stanceTextFrame then CreateStanceTextFrame() end

    local raidDb = self.db.RaidBuffDisplay
    local stanceDb = self.db.StanceDisplay
    local textDb = self.db.StanceText

    -- Raid buff container
    NRSKNUI.EditMode:RegisterElement({
        key = "MissingBuffs",
        displayName = "Missing Buffs",
        frame = containerFrame,
        getPosition = function()
            return raidDb.Position or {}
        end,
        setPosition = function(pos)
            raidDb.Position = raidDb.Position or {}
            raidDb.Position.AnchorFrom = pos.AnchorFrom
            raidDb.Position.AnchorTo = pos.AnchorTo
            raidDb.Position.XOffset = pos.XOffset
            raidDb.Position.YOffset = pos.YOffset
            if containerFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(raidDb.anchorFrameType, raidDb.ParentFrame)
                containerFrame:ClearAllPoints()
                containerFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
        onEditModeEnter = function() self:SetEditModeActive(true) end,
        onEditModeExit = function() self:SetEditModeActive(false) end,
    })

    -- Stance icon frame
    NRSKNUI.EditMode:RegisterElement({
        key = "MissingStanceIcon",
        displayName = "Missing Stance Icon",
        frame = stanceFrame,
        getPosition = function()
            return stanceDb.Position or {}
        end,
        setPosition = function(pos)
            stanceDb.Position = stanceDb.Position or {}
            stanceDb.Position.AnchorFrom = pos.AnchorFrom
            stanceDb.Position.AnchorTo = pos.AnchorTo
            stanceDb.Position.XOffset = pos.XOffset
            stanceDb.Position.YOffset = pos.YOffset
            if stanceFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(stanceDb.anchorFrameType, stanceDb.ParentFrame)
                stanceFrame:ClearAllPoints()
                stanceFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
        onEditModeEnter = function() self:SetEditModeActive(true) end,
        onEditModeExit = function() self:SetEditModeActive(false) end,
    })

    -- Stance text frame
    NRSKNUI.EditMode:RegisterElement({
        key = "StanceText",
        displayName = "Stance Text",
        frame = stanceTextFrame,
        getPosition = function()
            return textDb.Position or {}
        end,
        setPosition = function(pos)
            textDb.Position = textDb.Position or {}
            textDb.Position.AnchorFrom = pos.AnchorFrom
            textDb.Position.AnchorTo = pos.AnchorTo
            textDb.Position.XOffset = pos.XOffset
            textDb.Position.YOffset = pos.YOffset
            if stanceTextFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(textDb.anchorFrameType, textDb.ParentFrame)
                stanceTextFrame:ClearAllPoints()
                stanceTextFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
        onEditModeEnter = function() self:SetEditModeActive(true) end,
        onEditModeExit = function() self:SetEditModeActive(false) end,
    })
end

-- Module OnDisable
function MBUFFS:OnDisable()
    self:UnregisterAllEvents()
    HideAllNotifications()

    -- Cancel stance timer if active
    if stanceTimerHandle then
        stanceTimerHandle:Cancel()
        stanceTimerHandle = nil
    end
    stanceTimerActive = false

    -- Unregister from edit mode
    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:UnregisterElement("MissingBuffs")
        NRSKNUI.EditMode:UnregisterElement("MissingStanceIcon")
        NRSKNUI.EditMode:UnregisterElement("StanceText")
    end
end

-- Public API
function MBUFFS:Refresh()
    if self.db and self.db.Enabled then
        self:OnEnable()
        if not IsTrackingPaused() then
            CheckForMissingBuffs()
        end
    else
        self:OnDisable()
    end
end

-- Public settings applier, called from GUI when the user makes changes
function MBUFFS:ApplySettings()
    if not self.db then return end
    if not self.db.Enabled then return end

    -- If preview is showing, refresh preview with new settings
    if IsTrackingPaused() then
        self:RefreshPreview()
        return
    end

    local raidDb = self.db.RaidBuffDisplay
    local stanceDb = self.db.StanceDisplay
    local textDb = self.db.StanceText

    -- Update container frame
    if containerFrame then
        NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)
    end

    -- Update stance frame
    if stanceFrame then
        stanceFrame:SetSize(stanceDb.IconSize, stanceDb.IconSize)
        NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)

        -- Update stance frame font
        NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
    end

    -- Update stance text frame
    if stanceTextFrame then
        NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)
        NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)

        -- Update text alignment based on anchor point
        local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
        local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
        stanceTextFrame.text:ClearAllPoints()
        stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
        stanceTextFrame.text:SetJustifyH(textJustify)

        -- Show/hide based on enabled state
        if not textDb.Enabled then
            stanceTextFrame:Hide()
        end
    end

    -- Update all active icons
    for i, iconFrame in ipairs(activeIcons) do
        if currentMissingBuffs[i] then
            UpdateIconAppearance(iconFrame, currentMissingBuffs[i].buff, currentMissingBuffs[i].text)
        end
    end
    ArrangeIcons()
    UpdateStanceTextDisplay()
end

-- Setup preview stuff
local function ShowPreviewIcons()
    -- Create frames if needed
    if not containerFrame then CreateContainerFrame() end
    if not stanceFrame then CreateStanceFrame() end
    if not stanceTextFrame then CreateStanceTextFrame() end

    local raidDb = MBUFFS.db.RaidBuffDisplay or {}
    local stanceDb = MBUFFS.db.StanceDisplay or {}
    local textDb = MBUFFS.db.StanceText or {}

    -- Show raid buff preview with sample buffs
    local previewBuffs = {
        { buff = { spellId = 381748, text = "" },   text = "" },
        { buff = { spellId = 1126, text = "" },     text = "" },
        { buff = { spellId = 21562, text = "" },    text = "" },
        { buff = { spellId = 1459, text = "" },     text = "" },
        { buff = { spellId = 462854, text = "" },   text = "" },
        { buff = { spellId = 6673, text = "" },     text = "" },
        { buff = { spellId = 1235110, text = "" },  text = "" },
        { buff = { spellId = 462181, text = "" },   text = "" },
        { buff = { spellId = 1264426, text = "" },  text = "" },
        { buff = { spellId = 180608, text = "MH" }, text = "MH" },
        { buff = { spellId = 180608, text = "OH" }, text = "OH" },

        -- Poisions
        { buff = { spellId = POISON_IDS.ATROPHIC, text = "" },     text = "" },
        { buff = { spellId = POISON_IDS.CRIPPLING, text = "" },  text = "" },
        { buff = { spellId = POISON_IDS.AMPLIFYING, text = "" },   text = "" },
        { buff = { spellId = POISON_IDS.DEADLY, text = "" },  text = "" },
    }

    wipe(currentMissingBuffs)
    for _, entry in ipairs(previewBuffs) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end
    ShowMissingBuffs(previewBuffs)

    -- Show stance icon preview
    local previewStanceSpell = 386164
    local texture = GetSpellTexture(previewStanceSpell)
    if texture and stanceFrame then
        stanceFrame.icon:SetTexture(texture)
        stanceFrame.text:SetText("MISSING")
        stanceFrame:SetSize(stanceDb.IconSize, stanceDb.IconSize)
        NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
        NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)
        stanceFrame:Show()
    end

    -- Show stance text preview - respect Enabled toggle
    if stanceTextFrame then
        -- Check if stance text is enabled
        if not textDb.Enabled then
            stanceTextFrame:Hide()
        else
            -- Apply font settings
            NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)

            -- Get preview text and color from per-stance settings
            local previewText = "Battle Stance"
            local previewColor = { 1, 1, 1, 1 }

            -- Check if we have per-stance settings for the preview stance
            local classData = textDb["WARRIOR"]
            if classData then
                local stanceSettings = classData["386164"]
                if stanceSettings then
                    if stanceSettings.Text and stanceSettings.Text ~= "" then
                        previewText = stanceSettings.Text
                    end
                    if stanceSettings.Color then
                        previewColor = stanceSettings.Color
                    end
                end
            end

            stanceTextFrame.text:SetText(previewText)
            stanceTextFrame.text:SetTextColor(previewColor[1], previewColor[2], previewColor[3], previewColor[4] or 1)

            NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)

            -- Update text alignment based on anchor point
            local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
            local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
            stanceTextFrame.text:ClearAllPoints()
            stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
            stanceTextFrame.text:SetJustifyH(textJustify)
            stanceTextFrame:Show()
        end
    end
end

-- Check if tracking is currently paused
function MBUFFS:IsPaused()
    return IsTrackingPaused()
end

-- Refresh preview appearance
function MBUFFS:RefreshPreview()
    if not IsTrackingPaused() then return end
    ShowPreviewIcons()
end

-- Public ShowPreview for PreviewManager
function MBUFFS:ShowPreview()
    -- Ensure frames exist
    if not containerFrame then CreateContainerFrame() end
    if not stanceFrame then CreateStanceFrame() end
    if not stanceTextFrame then CreateStanceTextFrame() end
    isPreviewActive = true
    ShowPreviewIcons()
end

-- Public HidePreview for PreviewManager
function MBUFFS:HidePreview()
    isPreviewActive = false
    HideAllNotifications()
    wipe(currentMissingBuffs)
    if self.db and self.db.Enabled then C_Timer.After(0.1, CheckForMissingBuffs) end
end
