-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local LSM = NRSKNUI.LSM

-- Safety check
if not NorskenUI then
    error("Misc: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class Misc: AceModule, AceEvent-3.0
local MISC = NorskenUI:NewModule("Misc", "AceEvent-3.0")

-- Localization Setup
local PlaySoundFile = PlaySoundFile

-- Update db, used for profile changes
function MISC:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.WhisperSounds
end

-- Module init
function MISC:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Play whisper sound
function MISC:PlayWhisperSound(soundName)
    if not soundName or soundName == "None" then return end

    -- Fetch sound file
    local file = LSM:Fetch("sound", soundName)
    if file then
        PlaySoundFile(file, "Master")
    end
end

-- Initialize whisper sounds
function MISC:ApplySettings()
    if not MISC._Reg then
        MISC._Reg = true
        self:RegisterEvent("CHAT_MSG_WHISPER", function()
            self:PlayWhisperSound(self.db.WhisperSound)
        end)
        self:RegisterEvent("CHAT_MSG_BN_WHISPER", function()
            self:PlayWhisperSound(self.db.BNetWhisperSound)
        end)
    end
end

-- Module OnEnable
function MISC:OnEnable()
    if not self.db or not self.db.Enabled then return end
    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)
end

-- Module OnDisable
function MISC:OnDisable()
    self:UnregisterAllEvents()
    MISC._Reg = nil
end
