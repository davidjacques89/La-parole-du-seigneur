-- A small draggable button: left-click preaches, right-click changes the default channel.
-- A click counts as a "hardware event", which is what lets /say and /yell go out in the open world.
local addonName, ns = ...
local L = ns.L

local ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"
local button

function ns.ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(L.TOOLTIP_TITLE)
    GameTooltip:AddLine(L.TOOLTIP_LEFT:format(ns.ChannelLabel(ns.db.channel)), 1, 1, 1)
    GameTooltip:AddLine(L.TOOLTIP_RIGHT, 1, 1, 1)
    if owner == button and not ns.db.button.locked then
        GameTooltip:AddLine(L.TOOLTIP_DRAG, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

function ns.CycleChannel()
    local order = ns.CHANNEL_ORDER
    local nextIndex = 1
    for i, channel in ipairs(order) do
        if channel == ns.db.channel then
            nextIndex = (i % #order) + 1
            break
        end
    end
    ns.db.channel = order[nextIndex]
    ns.Print(L.CHANNEL_SET:format(ns.ChannelLabel(ns.db.channel)))
    if button and GameTooltip:GetOwner() == button then
        ns.ShowTooltip(button)
    end
end

local function savePosition(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    local saved = ns.db.button
    saved.point, saved.relPoint, saved.x, saved.y = point, relPoint, x, y
end

function ns.UpdateButton()
    if not button then
        return
    end
    local saved = ns.db.button
    button:ClearAllPoints()
    button:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    button:SetShown(saved.shown)
end

function ns.CreateButton()
    if button then
        return button
    end
    button = CreateFrame("Button", addonName .. "Button", UIParent)
    button:SetSize(36, 36)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- trim the icon's built-in border

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.CycleChannel()
        else
            ns.Preach()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        if not ns.db.button.locked then
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
    end)
    button:SetScript("OnEnter", ns.ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateButton()
    return button
end
