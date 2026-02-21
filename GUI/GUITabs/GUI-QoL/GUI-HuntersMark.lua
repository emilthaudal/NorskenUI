-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

-- Helper to get HuntersMark module
local function GetHuntersMarkModule()
    if NorskenUI then
        return NorskenUI:GetModule("HuntersMark", true)
    end
    return nil
end

-- Register HuntersMark tab content
GUIFrame:RegisterContent("HuntersMark", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.HuntersMark
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local HUNTMARK = GetHuntersMarkModule()
    local allWidgets = {}

    local function ApplySettings()
        if HUNTMARK then
            HUNTMARK:ApplySettings()
        end
    end

    local function ApplyModuleState(enabled)
        if not HUNTMARK then return end
        db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("HuntersMark")
        else
            NorskenUI:DisableModule("HuntersMark")
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Hunters Mark Tracking (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Hunters Mark Tracking", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Hunters Mark Tracking", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Hunters Mark Tracking", "On", "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Text Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Text Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Color picker
    local row2a = GUIFrame:CreateRow(card2.content, 40)
    local colorPicker = GUIFrame:CreateColorPicker(row2a, "Alert Color", db.Color or { 0, 1, 0, 1 },
        function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplySettings()
        end)
    row2a:AddWidget(colorPicker, 1)
    table_insert(allWidgets, colorPicker)
    card2:AddRow(row2a, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Font Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Font lookup
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face and Size
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    local fontSizeSlider = GUIFrame:CreateSlider(card3.content, "Font Size", 8, 72, 1, db.FontSize or 24, 60,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row3a:AddWidget(fontSizeSlider, 0.5)
    table_insert(allWidgets, fontSizeSlider)
    card3:AddRow(row3a, 40)

    -- Font Outline Dropdown
    local row3b = GUIFrame:CreateRow(card3.content, 37)
    local outlineList = {
        { key = "NONE", text = "None" },
        { key = "OUTLINE", text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SOFTOUTLINE", text = "Soft" },
    }
    local outlineDropdown = GUIFrame:CreateDropdown(row3b, "Outline", outlineList, db.FontOutline or "SOFTOUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3b:AddWidget(outlineDropdown, 1)
    table_insert(allWidgets, outlineDropdown)
    card3:AddRow(row3b, 37)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Position Settings
    ----------------------------------------------------------------
    local card4, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        dbKeys = {
            anchorFrameType = "anchorFrameType",
            anchorFrameFrame = "ParentFrame",
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
            strata = "Strata",
        },
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })

    if card4.positionWidgets then
        for _, widget in ipairs(card4.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card4)

    yOffset = newOffset

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)
