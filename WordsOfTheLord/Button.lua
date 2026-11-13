-- The minimap button: left-click preaches, Shift-click opens the book, right-click changes the
-- default channel, and dragging slides it around the edge of the minimap.
-- A click counts as a "hardware event", which is what lets /say and /yell go out in the open world.
local addonName, ns = ...
local L = ns.L

local ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"
local button

function ns.ShowTooltip(owner, fromCompartment)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(L.TOOLTIP_TITLE)
    if fromCompartment then
        GameTooltip:AddLine(L.TOOLTIP_OPEN, 1, 1, 1)
    else
        GameTooltip:AddLine(L.TOOLTIP_LEFT:format(ns.ChannelLabel(ns.db.channel)), 1, 1, 1)
        GameTooltip:AddLine(L.TOOLTIP_SHIFT, 1, 1, 1)
    end
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

-- Where the button sits for a given angle (degrees, 0 = right, 90 = top), as an offset from the
-- minimap's center. Round minimaps use a circle, square ones a square outline.
function ns.MinimapOffset(angle, halfWidth, shape)
    local rad = math.rad(angle)
    local cos, sin = math.cos(rad), math.sin(rad)
    local radius = halfWidth + 5
    if shape == "SQUARE" then
        local largest = math.max(math.abs(cos), math.abs(sin))
        return cos / largest * radius, sin / largest * radius
    end
    return cos * radius, sin * radius
end

function ns.UpdateButton()
    if not button then
        return
    end
    local saved = ns.db.button
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local x, y = ns.MinimapOffset(saved.angle, (Minimap:GetWidth() or 140) / 2, shape)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    button:SetShown(saved.shown)
end

-- While dragging: turn the cursor's position around the minimap's center into an angle.
function ns.DragMinimapButton()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    if not centerX or not cursorX then
        return
    end
    local scale = Minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    ns.db.button.angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
    ns.UpdateButton()
end

function ns.CreateButton()
    if button then
        return button
    end
    button = CreateFrame("Button", addonName .. "Button", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(50, 50)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.CycleChannel()
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            ns.ToggleWindow()
        else
            ns.Preach()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        if not ns.db.button.locked then
            GameTooltip:Hide()
            self:SetScript("OnUpdate", ns.DragMinimapButton)
        end
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", ns.ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateButton()
    return button
end
