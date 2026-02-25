-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

-- Get module reference
local function GetModule()
    return NorskenUI:GetModule("TimeSpiral", true)
end

-- Register Time Spiral tab content
GUIFrame:RegisterContent("TimeSpiral", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.TimeSpiral
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local TSP = GetModule()
    local allWidgets = {}
    local glowWidgets = {}
    local textWidgets = {}

    local function ApplySettings()
        if TSP and TSP.ApplySettings then
            TSP:ApplySettings()
        end
    end

    local function ApplyModuleState(enabled)
        if not TSP then return end
        db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("TimeSpiral")
        else
            NorskenUI:DisableModule("TimeSpiral")
        end
    end

    local function UpdateGlowWidgetStates()
        local glowEnabled = db.GlowEnabled ~= false
        for _, widget in ipairs(glowWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(glowEnabled)
            end
        end
    end

    local function UpdateTextWidgetStates()
        local textEnabled = db.ShowText ~= false
        for _, widget in ipairs(textWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(textEnabled)
            end
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        -- Update sub-toggles only if main is enabled
        if mainEnabled then
            UpdateGlowWidgetStates()
            UpdateTextWidgetStates()
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Time Spiral Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Time Spiral Tracker", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Time Spiral Tracker", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Time Spiral Tracker", "On", "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Display & Glow Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Display & Glow Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Icon Size Slider
    local row2a = GUIFrame:CreateRow(card2.content, 40)
    local iconSizeSlider = GUIFrame:CreateSlider(row2a, "Icon Size", 20, 100, 1,
        db.IconSize or 50, nil,
        function(val)
            db.IconSize = val
            ApplySettings()
        end)
    row2a:AddWidget(iconSizeSlider, 1)
    table_insert(allWidgets, iconSizeSlider)
    card2:AddRow(row2a, 40)

    -- Separator
    local rowSep1 = GUIFrame:CreateRow(card2.content, 8)
    local sep1 = GUIFrame:CreateSeparator(rowSep1)
    rowSep1:AddWidget(sep1, 1)
    table_insert(allWidgets, sep1)
    card2:AddRow(rowSep1, 8)

    -- Enable Glow Checkbox
    local row2b = GUIFrame:CreateRow(card2.content, 40)
    local enableGlowCheck = GUIFrame:CreateCheckbox(row2b, "Enable Glow Effect", db.GlowEnabled ~= false,
        function(checked)
            db.GlowEnabled = checked
            UpdateGlowWidgetStates()
            ApplySettings()
        end)
    row2b:AddWidget(enableGlowCheck, 0.5)
    table_insert(allWidgets, enableGlowCheck)
    card2:AddRow(row2b, 40)

    -- Glow Type Dropdown and Glow Color Picker (same row)
    local row2c = GUIFrame:CreateRow(card2.content, 36)
    local glowTypeList = {
        { key = "pixel",    text = "Pixel Border" },
        { key = "autocast", text = "Auto Cast" },
        { key = "button",   text = "Button Glow" },
        { key = "proc",     text = "Proc Glow" },
    }
    local glowTypeDropdown = GUIFrame:CreateDropdown(row2c, "Glow Type", glowTypeList, db.GlowType or "pixel", 45,
        function(key)
            db.GlowType = key
            ApplySettings()
        end)
    row2c:AddWidget(glowTypeDropdown, 0.5)
    table_insert(allWidgets, glowTypeDropdown)
    table_insert(glowWidgets, glowTypeDropdown)

    local glowColorPicker = GUIFrame:CreateColorPicker(row2c, "Glow Color",
        db.GlowColor or { 0.95, 0.95, 0.32, 1 },
        function(r, g, b, a)
            db.GlowColor = { r, g, b, a }
            ApplySettings()
        end)
    row2c:AddWidget(glowColorPicker, 0.5)
    table_insert(allWidgets, glowColorPicker)
    table_insert(glowWidgets, glowColorPicker)
    card2:AddRow(row2c, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Text Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Text Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Show Text Checkbox and Text Color Picker (same row)
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local showTextCheck = GUIFrame:CreateCheckbox(row3a, "Show Text Label", db.ShowText ~= false,
        function(checked)
            db.ShowText = checked
            UpdateTextWidgetStates()
            ApplySettings()
        end)
    row3a:AddWidget(showTextCheck, 0.5)
    table_insert(allWidgets, showTextCheck)

    local textColorPicker = GUIFrame:CreateColorPicker(row3a, "Text Color",
        db.TextColor or { 1, 1, 1, 1 },
        function(r, g, b, a)
            db.TextColor = { r, g, b, a }
            ApplySettings()
        end)
    row3a:AddWidget(textColorPicker, 0.5)
    table_insert(allWidgets, textColorPicker)
    table_insert(textWidgets, textColorPicker)
    card3:AddRow(row3a, 40)

    -- Text Label EditBox
    local row3b = GUIFrame:CreateRow(card3.content, 40)
    local textLabelEdit = GUIFrame:CreateEditBox(row3b, "Text Label", db.TextLabel or "FREE MOVE",
        function(text)
            db.TextLabel = text
            ApplySettings()
        end)
    row3b:AddWidget(textLabelEdit, 1)
    table_insert(allWidgets, textLabelEdit)
    table_insert(textWidgets, textLabelEdit)
    card3:AddRow(row3b, 40)

    -- Separator
    local rowSep2 = GUIFrame:CreateRow(card3.content, 8)
    local sep2 = GUIFrame:CreateSeparator(rowSep2)
    rowSep2:AddWidget(sep2, 1)
    table_insert(allWidgets, sep2)
    card3:AddRow(rowSep2, 8)

    -- Font lookup
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face and Size
    local row3c = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3c, "Font", fontList, db.FontFace or "MEERES FONT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3c:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)
    table_insert(textWidgets, fontDropdown)

    -- Font Size Slider
    local fontSizeSlider = GUIFrame:CreateSlider(card3.content, "Font Size", 8, 36, 1, db.FontSize or 13, 60,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row3c:AddWidget(fontSizeSlider, 0.5)
    table_insert(allWidgets, fontSizeSlider)
    table_insert(textWidgets, fontSizeSlider)
    card3:AddRow(row3c, 40)

    -- Font Outline Dropdown
    local row3d = GUIFrame:CreateRow(card3.content, 36)
    local outlineList = {
        { key = "NONE",         text = "None" },
        { key = "OUTLINE",      text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SOFTOUTLINE",  text = "Soft" },
    }
    local outlineDropdown = GUIFrame:CreateDropdown(row3d, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3d:AddWidget(outlineDropdown, 1)
    table_insert(allWidgets, outlineDropdown)
    table_insert(textWidgets, outlineDropdown)
    card3:AddRow(row3d, 36)

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
        showAnchorFrameType = true,
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
