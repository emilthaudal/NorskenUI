-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

-- Helper to get Recuperate module
local function GetRecuperateModule()
    if NorskenUI then
        return NorskenUI:GetModule("Recuperate", true)
    end
    return nil
end

-- Register Recuperate tab content
GUIFrame:RegisterContent("Recuperate", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Recuperate
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local REC = GetRecuperateModule()
    local allWidgets = {}

    local function ApplySettings()
        if REC then
            REC:ApplySettings()
        end
    end

    local function ApplyModuleState(enabled)
        if not REC then return end
        db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("Recuperate")
        else
            NorskenUI:DisableModule("Recuperate")
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
    -- Card 1: Recuperate Button (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Recuperate Button", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Recuperate Button", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Recuperate Button", "On", "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 40)

    -- Load conditions row
    local row1b = GUIFrame:CreateRow(card1.content, 36)
    local loadInRaidCheck = GUIFrame:CreateCheckbox(row1b, "Load in Raid", db.LoadInRaid ~= false,
        function(checked)
            db.LoadInRaid = checked
            if REC then REC:UpdateStateDriver() end
        end,
        true, "Load in Raid", "On", "Off"
    )
    row1b:AddWidget(loadInRaidCheck, 0.5)
    table_insert(allWidgets, loadInRaidCheck)

    local loadInPartyCheck = GUIFrame:CreateCheckbox(row1b, "Load in Party", db.LoadInParty == true,
        function(checked)
            db.LoadInParty = checked
            if REC then REC:UpdateStateDriver() end
        end,
        true, "Load in Party", "On", "Off"
    )
    row1b:AddWidget(loadInPartyCheck, 0.5)
    table_insert(allWidgets, loadInPartyCheck)
    card1:AddRow(row1b, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Size Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Size Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Size slider
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local SizeSlider = GUIFrame:CreateSlider(card2.content, "Button Size", 1, 1000, 1, db.Size or 24, 60,
        function(val)
            db.Size = val
            ApplySettings()
        end)
    row2:AddWidget(SizeSlider, 1)
    table_insert(allWidgets, SizeSlider)
    card2:AddRow(row2, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Position Settings
    ----------------------------------------------------------------
    local card3, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
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

    if card3.positionWidgets then
        for _, widget in ipairs(card3.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card3)

    yOffset = newOffset

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)
