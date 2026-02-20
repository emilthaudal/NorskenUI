-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local LSM = NRSKNUI.LSM
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local PlaySoundFile = PlaySoundFile
local pairs, ipairs = pairs, ipairs

-- Helper to get Misc module
local function GetMiscVarsModule()
    if NorskenUI then
        return NorskenUI:GetModule("Misc", true)
    end
    return nil
end

-- Register Whisper Sounds tab content
GUIFrame:RegisterContent("whisperSounds", function(scrollChild, yOffset)
    -- Safety check for database
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.WhisperSounds
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Misc module
    local MISC = GetMiscVarsModule()

    -- Apply settings helper
    local function ApplySettings()
        if MISC then
            MISC:ApplySettings()
        end
    end

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply new state
    local function ApplyMiscState(enabled)
        if not MISC then return end
        MISC.db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("Misc")
        else
            NorskenUI:DisableModule("Misc")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Whisper Sounds (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Whisper Sound Alerts", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Whisper Sounds", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyMiscState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Whisper Sounds",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 40)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Sound Selection
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Sound Selection", yOffset)
    table_insert(allWidgets, card2)

    -- Build sound list from LibSharedMedia
    local soundList = {}
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            soundList[name] = name
        end
    end
    soundList["None"] = "None"

    -- Whisper Sound dropdown
    local row2a = GUIFrame:CreateRow(card2.content, 40)
    local whisperDropdown = GUIFrame:CreateDropdown(row2a, "Whisper Sound", soundList, db.WhisperSound or "None",
        60,
        function(key)
            db.WhisperSound = key
            ApplySettings()
        end)
    row2a:AddWidget(whisperDropdown, 0.6)
    table_insert(allWidgets, whisperDropdown)

    -- Test Whisper button
    local testWhisperBtn = GUIFrame:CreateButton(row2a, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.WhisperSound
            if soundName and soundName ~= "None" and LSM then
                local file = LSM:Fetch("sound", soundName)
                if file then PlaySoundFile(file, "Master") end
            end
        end,
    })
    row2a:AddWidget(testWhisperBtn, 0.4, nil, 0, -14)
    table_insert(allWidgets, testWhisperBtn)
    card2:AddRow(row2a, 40)

    -- Battle.net Sound dropdown
    local row2b = GUIFrame:CreateRow(card2.content, 37)
    local bnetDropdown = GUIFrame:CreateDropdown(row2b, "Battle.net Whisper Sound", soundList,
        db.BNetWhisperSound or "None", 60,
        function(key)
            db.BNetWhisperSound = key
            ApplySettings()
        end)
    row2b:AddWidget(bnetDropdown, 0.6)
    table_insert(allWidgets, bnetDropdown)

    -- Test BNet button
    local testBnetBtn = GUIFrame:CreateButton(row2b, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.BNetWhisperSound
            if soundName and soundName ~= "None" and LSM then
                local file = LSM:Fetch("sound", soundName)
                if file then PlaySoundFile(file, "Master") end
            end
        end,
    })
    row2b:AddWidget(testBnetBtn, 0.4, nil, 0, -14)
    table_insert(allWidgets, testBnetBtn)
    card2:AddRow(row2b, 37)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end)
