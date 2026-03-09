-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Safety check
if not NorskenUI then
    error("CombatCross: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class CombatCross: AceModule, AceEvent-3.0
local CC = NorskenUI:NewModule("CombatCross", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIFrameFadeIn = UIFrameFadeIn
local UIParent = UIParent
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local C_Spell = C_Spell
local UnitExists = UnitExists

-- Constants
local FONT_SIZE_MULTIPLIER = 2
local RANGE_UPDATE_THROTTLE = 0.1

-- Melee specs
local MELEE_RANGE_ABILITIES = {
    -- Melee DPS
    [71]  = 6552,   -- Arms Warrior: Pummel
    [72]  = 6552,   -- Fury Warrior: Pummel
    [251] = 49020,  -- Frost DK: Obliterate
    [252] = 49998,  -- Unholy DK: Death Strike
    [577] = 162794, -- Havoc DH: Chaos Strike
    [103] = 22568,  -- Feral Druid: Ferocious Bite
    [255] = 186270, -- Survival Hunter: Raptor Strike
    [259] = 1329,   -- Assassination Rogue: Mutilate
    [260] = 193315, -- Outlaw Rogue: Sinister Strike
    [261] = 53,     -- Subtlety Rogue: Backstab
    [263] = 17364,  -- Enhancement Shaman: Stormstrike
    [269] = 100780, -- Windwalker Monk: Tiger Palm
    [70]  = 96231,  -- Retribution Paladin: Rebuke
    -- Tanks
    [73]  = 6552,   -- Protection Warrior: Pummel
    [250] = 49998,  -- Blood DK: Death Strike
    [581] = 225921, -- Vengeance DH: Shear
    [104] = 22568,  -- Guardian Druid: Mangle
    [268] = 100780, -- Brewmaster Monk: Tiger Palm
    [66]  = 35395,  -- Protection Paladin: Crusader Strike
}

-- Ranged DPS
local RANGED_RANGE_ABILITIES = {
    [102]  = 5176,   -- Balance Druid: Wrath (40yd)
    [1467] = 361469, -- Devastation Evoker: Living Flame (25yd)
    [1473] = 361469, -- Augmentation Evoker: Living Flame (25yd)
    [253]  = 77767,  -- Beast Mastery Hunter: Cobra Shot (40yd)
    [254]  = 185358, -- Marksmanship Hunter: Arcane Shot (40yd)
    [62]   = 30451,  -- Arcane Mage: Arcane Blast (40yd)
    [63]   = 133,    -- Fire Mage: Fireball (40yd)
    [64]   = 116,    -- Frost Mage: Frostbolt (40yd)
    [258]  = 589,    -- Shadow Priest: Shadow Word: Pain (40yd)
    [262]  = 188196, -- Elemental Shaman: Lightning Bolt (40yd)
    [265]  = 686,    -- Affliction Warlock: Shadow Bolt (40yd)
    [266]  = 686,    -- Demonology Warlock: Shadow Bolt (40yd)
    [267]  = 29722,  -- Destruction Warlock: Incinerate (40yd)
}

-- Module state
CC.frame = nil
CC.text = nil
CC.previewActive = false
CC.combatActive = false
CC.rangeAbility = nil -- resolved spell ID for current spec (number or nil)
CC.specType = nil     -- "melee", "ranged", or nil (no entry / not applicable)
CC.lastInRange = nil  -- last known in-range state (true/false/nil)

-- File-local upvalue for OnUpdate throttle (matches RangeChecker pattern)
local rangeUpdateElapsed = 0

-- Update db, used for profile changes
function CC:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatCross
end

-- Module init
function CC:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Resolve the range ability and spec type for the current spec
function CC:ResolveRangeAbility()
    local specIndex = GetSpecialization()
    if not specIndex then
        self.rangeAbility = nil
        self.specType = nil
        return
    end
    local specID = select(1, GetSpecializationInfo(specIndex))
    if not specID then
        self.rangeAbility = nil
        self.specType = nil
        return
    end
    if MELEE_RANGE_ABILITIES[specID] then
        self.rangeAbility = MELEE_RANGE_ABILITIES[specID]
        self.specType = "melee"
    elseif RANGED_RANGE_ABILITIES[specID] then
        self.rangeAbility = RANGED_RANGE_ABILITIES[specID]
        self.specType = "ranged"
    else
        self.rangeAbility = nil
        self.specType = nil
    end
end

-- Update cross color based on current range to target.
-- Called from OnUpdate; only runs when the relevant toggle is enabled,
-- rangeAbility is known, and we are in real combat (not preview-only).
function CC:UpdateRangeColor()
    if not self.text then return end
    if not UnitExists("target") then
        -- No target — restore normal color if we were showing out-of-range
        if self.lastInRange == false then
            self.lastInRange = nil
            local r, g, b, a = self:GetColor()
            self.text:SetTextColor(r, g, b, a)
        end
        return
    end

    local inRange = C_Spell.IsSpellInRange(self.rangeAbility, "target")

    if inRange == nil then
        if self.lastInRange ~= nil then
            self.lastInRange = nil
            local r, g, b, a = self:GetColor()
            self.text:SetTextColor(r, g, b, a)
        end
        return
    end

    local nowInRange = (inRange == 1 or inRange == true)
    if nowInRange == self.lastInRange then return end -- no change
    self.lastInRange = nowInRange

    if nowInRange then
        local r, g, b, a = self:GetColor()
        self.text:SetTextColor(r, g, b, a)
    else
        local c = self.db.OutOfRangeColor or { 1, 0, 0, 1 }
        self.text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
end

-- OnUpdate handler (always active while module is enabled)
function CC:OnUpdate(elapsed)
    rangeUpdateElapsed = rangeUpdateElapsed + elapsed
    if rangeUpdateElapsed < RANGE_UPDATE_THROTTLE then return end
    rangeUpdateElapsed = 0

    -- Gate on spec type and the corresponding toggle
    if not self.rangeAbility or not self.specType then return end
    if self.specType == "melee" and not self.db.RangeColorMeleeEnabled then return end
    if self.specType == "ranged" and not self.db.RangeColorRangedEnabled then return end

    -- Skip during preview-only (not real combat)
    if self.previewActive and not self.combatActive then return end

    self:UpdateRangeColor()
end

-- Module OnEnable
function CC:OnEnable()
    if not self.db.Enabled then return end
    self:CreateFrame()
    self:ApplySettings()
    self:ResolveRangeAbility()

    -- Register combat events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnExitCombat")

    -- Register spec change to re-resolve ability
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")

    -- Set up OnUpdate (always active, matching RangeChecker pattern)
    self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
end

-- Module OnDisable
function CC:OnDisable()
    self:UnregisterAllEvents()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    -- Reset range state
    self.rangeAbility = nil
    self.specType = nil
    self.lastInRange = nil
end

-- Spec changed handler
function CC:OnSpecChanged()
    self:ResolveRangeAbility()
    self.lastInRange = nil -- force color re-evaluation on next update
end

-- Get color based on color mode
function CC:GetColor()
    local colorMode = self.db.ColorMode or "custom"
    return NRSKNUI:GetAccentColor(colorMode, self.db.Color)
end

-- Create the combat cross frame
function CC:CreateFrame()
    if self.frame then return end

    -- Create frame
    self.frame = CreateFrame("Frame", "NRSKNUI_CombatCrossFrame", UIParent)
    self.frame:SetSize(30, 30)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetFrameLevel(100)
    self.frame:Hide()

    -- Create cross text
    local fontSize = self.db.Thickness * FONT_SIZE_MULTIPLIER
    self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetPoint("CENTER")
    self.text:SetFont(NRSKNUI.FONT, fontSize, "")
    self.text:SetText("+")

    if self.db.Outline then
        self.frame.softOutline = NRSKNUI:CreateSoftOutline(self.text, {
            thickness = 1,
            color = { 0, 0, 0 },
            alpha = 0.9,
        })
    end

    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
end

-- Apply settings from profile
function CC:ApplySettings()
    if not self.frame or not self.text then return end

    -- Apply position & Strata
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)

    -- Apply font
    local fontSize = self.db.Thickness * FONT_SIZE_MULTIPLIER
    self.text:SetFont(NRSKNUI.FONT, fontSize, "")

    if self.db.Outline then
        if not self.frame.softOutline then
            self.frame.softOutline = NRSKNUI:CreateSoftOutline(self.text, {
                thickness = 1,
                color = { 0, 0, 0 },
                alpha = 0.9,
            })
        else
            self.frame.softOutline:SetShown(true)
        end
    else
        if self.frame.softOutline then
            self.frame.softOutline:SetShown(false)
        end
    end

    -- Apply color (resets any range-based color override)
    local r, g, b, a = self:GetColor()
    self.text:SetTextColor(r, g, b, a)

    -- Force range color re-evaluation on next update cycle
    self.lastInRange = nil
end

-- Show combat cross
function CC:Show(isPreview)
    if not self.frame then
        self:CreateFrame()
        self:ApplySettings()
    end
    if not self.frame then return end

    -- Set active state
    if isPreview then
        self.previewActive = true
    else
        self.combatActive = true
    end

    -- Show frame if either state is active
    if self.previewActive or self.combatActive then
        if not self.frame:IsShown() then
            self.frame:Show()
            self.frame:SetAlpha(0)
            UIFrameFadeIn(self.frame, 0.3, 0, 1)
        end
    end
end

-- Hide combat cross
function CC:Hide(isPreview)
    if not self.frame then return end

    -- Clear active state
    if isPreview then
        self.previewActive = false
    else
        self.combatActive = false
        -- Restore normal color when leaving combat so it's correct on next enter
        if self.text then
            local r, g, b, a = self:GetColor()
            self.text:SetTextColor(r, g, b, a)
        end
        self.lastInRange = nil
    end

    -- Hide frame if neither state is active
    if not self.previewActive and not self.combatActive then
        self.frame:Hide()
    end
end

-- Show preview
function CC:ShowPreview()
    if InCombatLockdown() then return end
    self:Show(true)
end

-- Hide preview
function CC:HidePreview()
    if InCombatLockdown() then return end
    if not self.previewActive then return end
    self:Hide(true)
end

-- Combat enter event
function CC:OnEnterCombat()
    if not self.db.Enabled then return end
    self:Show(false)
end

-- Combat exit event
function CC:OnExitCombat()
    if not self.db.Enabled then return end
    self:Hide(false)
end

-- Refresh (called from GUI)
function CC:Refresh()
    self:ApplySettings()
end
