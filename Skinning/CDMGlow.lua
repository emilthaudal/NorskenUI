-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Check for addon object
if not NorskenUI then
    error("CDMGlow: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class CDMGlow: AceModule, AceEvent-3.0
local CDMG = NorskenUI:NewModule("CDMGlow", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc

-- Update db, used for profile changes
function CDMG:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.CDMGlow
end

-- Module init
function CDMG:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Setup hook
function CDMG:SetupGlowHooks()
    if not CDMG.db.Enabled or CDMG._raidManagerHooked then return end
    if ActionButtonSpellAlertManager then
        if ActionButtonSpellAlertManager.ShowAlert then
            CDMG._raidManagerHooked = true
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
                button.SpellActivationAlert.ProcStartFlipbook:Hide() -- Hide proc glow animation
                button.SpellActivationAlert:SetFrameStrata("HIGH")   -- Set strata high so that the custom swipe in CDMOverlay.lua gets placed behind glow
                button.SpellActivationAlert.ProcLoop:Play()          -- Show the proc loop instead, 100x cleaner
            end)
        end
    end
end

function CDMG:ApplySettings()
    self:SetupGlowHooks()
end

-- Module OnEnable
function CDMG:OnEnable()
    if not self.db.Enabled then return end
    self:ApplySettings()
end

-- Module OnDisable
function CDMG:OnDisable()
end
