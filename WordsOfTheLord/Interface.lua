-- The book: one tabbed window styled as an open book (Library, Favorites, Settings, My sayings).
-- Everything is drawn with plain textures and fonts, so it needs no art files and no templates.
-- The text follows the game client's language through ns.L.
local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------

local WIDTH, HEIGHT = 780, 520
local PAGE_W, PAGE_H = 370, 438
local PAD = 30
local CONTENT_W = PAGE_W - 2 * PAD   -- 310

local LEATHER      = { 0.17, 0.10, 0.05 }
local LEATHER_EDGE = { 0.43, 0.30, 0.17 }
local PARCHMENT    = { 0.93, 0.85, 0.66 }
local PARCH_LIGHT  = { 0.98, 0.93, 0.79 }
local GUTTER       = { 0.55, 0.43, 0.25 }
local INK          = { 0.23, 0.16, 0.10 }
local MUTED        = { 0.42, 0.31, 0.18 }
local LINE         = { 0.74, 0.60, 0.36 }
local WINE         = { 0.48, 0.17, 0.17 }
local GOLD         = { 0.72, 0.54, 0.16 }
local CREAM        = { 0.96, 0.91, 0.78 }
local BROWN_BTN    = { 0.29, 0.18, 0.10 }

local RIBBONS = {
    { key = "lib",  label = "TAB_LIBRARY",   color = { 0.48, 0.17, 0.17 } },
    { key = "fav",  label = "TAB_FAVORITES", color = { 0.18, 0.31, 0.23 } },
    { key = "set",  label = "TAB_SETTINGS",  color = { 0.17, 0.25, 0.40 } },
    { key = "mine", label = "TAB_MINE",      color = { 0.36, 0.23, 0.40 } },
}

local HEAD_FONT = "Fonts\\MORPHEUS.ttf"
local BODY_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- State and the data the window shows (no frames in this part)
---------------------------------------------------------------------------

local ui = { tab = "lib", selected = nil, cat = nil, query = "" }
ns.ui = ui

local win
local refreshers = {}

-- Categories the library offers in the current language (Québec only exists in Québec mode).
function ui.Categories()
    local list = {}
    for _, category in ipairs(ns.CATEGORIES) do
        if category.key ~= "quebec" or ns.GetLang() == "qc" then
            list[#list + 1] = category
        end
    end
    return list
end

-- The sayings listed on the Library tab (category and search applied) or the Favorites tab.
function ui.Rows(tab)
    tab = tab or ui.tab
    local rows = {}
    local query = ns.Fold(ui.query)
    for _, shown in ipairs(ns.GetLibrary()) do
        local keep
        if tab == "fav" then
            keep = shown.favorite
        else
            keep = (not ui.cat or shown.cat == ui.cat)
            if keep and query ~= "" then
                keep = ns.Fold(shown.text .. " " .. (shown.ref or "")):find(query, 1, true) ~= nil
            end
        end
        if keep then
            rows[#rows + 1] = shown
        end
    end
    return rows
end

-- Keep the selection on something that is really in the list.
function ui.EnsureSelection()
    if ui.tab ~= "lib" and ui.tab ~= "fav" then
        return
    end
    local rows = ui.Rows()
    for _, shown in ipairs(rows) do
        if shown.id == ui.selected then
            return
        end
    end
    ui.selected = rows[1] and rows[1].id or nil
end

function ui.Selected()
    return ui.selected and ns.FindSayingById(ui.selected) or nil
end

-- Clicking the active chip clears the filter; "All" (key nil) always clears it.
function ui.SetCategory(key)
    if ui.cat == key then
        ui.cat = nil
    else
        ui.cat = key
    end
end

function ui.OwnSayings()
    local list = {}
    for i, text in ipairs(ns.db.custom) do
        list[i] = { index = i, text = text }
    end
    return list
end

---------------------------------------------------------------------------
-- Small drawing helpers
---------------------------------------------------------------------------

local function newTexture(parent, layer, color, alpha)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    return texture
end

local function setFont(fontString, path, size)
    if not fontString:SetFont(path, size, "") then
        fontString:SetFont(BODY_FONT, size, "")
    end
end

local function newText(parent, size, color, head, justify)
    local fontString = parent:CreateFontString(nil, "OVERLAY")
    setFont(fontString, head and HEAD_FONT or BODY_FONT, size)
    fontString:SetTextColor(color[1], color[2], color[3])
    fontString:SetJustifyH(justify or "LEFT")
    return fontString
end

local function addBorder(frame, color, alpha)
    local top = newTexture(frame, "BORDER", color, alpha)
    top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(1)
    local bottom = newTexture(frame, "BORDER", color, alpha)
    bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(1)
    local left = newTexture(frame, "BORDER", color, alpha)
    left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(1)
    local right = newTexture(frame, "BORDER", color, alpha)
    right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(1)
end

local function addRefresher(fn)
    refreshers[#refreshers + 1] = fn
end

local function capitalize(text)
    return (text:gsub("^%l", string.upper))
end

-- A diamond, used where a book would use a small ornament and where the list marks a favorite.
local function newDiamond(parent, size, color)
    local diamond = newTexture(parent, "ARTWORK", color)
    diamond:SetSize(size, size)
    if diamond.SetRotation then
        diamond:SetRotation(math.pi / 4)
    end
    return diamond
end

-- A page heading: title, then a thin rule with a diamond in the middle.
local function newHeader(parent)
    local header = {}
    header.title = newText(parent, 16, INK, true, "CENTER")
    header.title:SetPoint("TOP", parent, "TOP", 0, -22)
    header.title:SetWidth(CONTENT_W)
    local left = newTexture(parent, "ARTWORK", GOLD, 0.8)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -50) left:SetSize(CONTENT_W / 2 - 10, 1)
    local right = newTexture(parent, "ARTWORK", GOLD, 0.8)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -50) right:SetSize(CONTENT_W / 2 - 10, 1)
    local diamond = newDiamond(parent, 7, GOLD)
    diamond:SetPoint("TOP", parent, "TOP", 0, -47)
    return header
end

local function newSectionLabel(parent, x, y)
    local label = newText(parent, 11, MUTED, true)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(CONTENT_W)
    return label
end

-- style: "plain" (light), "active" (dark, for a selected choice) or "primary" (the main action).
local function styleButton(button, style)
    local bg, text = PARCH_LIGHT, INK
    if style == "active" then
        bg, text = BROWN_BTN, CREAM
    elseif style == "primary" then
        bg, text = BROWN_BTN, CREAM
    end
    button.bg:SetColorTexture(bg[1], bg[2], bg[3], style == "plain" and 0.65 or 1)
    button.label:SetTextColor(text[1], text[2], text[3])
end

local function newButton(parent, width, height, onClick, headFont)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.bg = newTexture(button, "BACKGROUND", PARCH_LIGHT, 0.65)
    button.bg:SetAllPoints()
    addBorder(button, MUTED, 0.9)
    button.hover = newTexture(button, "HIGHLIGHT", WINE, 0.14)
    button.hover:SetAllPoints()
    button.label = newText(button, headFont and 11 or 13, INK, headFont, "CENTER")
    button.label:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    return button
end

-- A row of choices (language, channel, weight). `options` is a list of keys.
local function newChoiceRow(parent, x, y, options, perRow, width, height, gap, labelOf, isActive, onPick)
    local buttons = {}
    for i, key in ipairs(options) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local button = newButton(parent, width, height, function() onPick(key) end)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x + col * (width + gap), y - row * (height + gap))
        button.choice = key
        buttons[i] = button
    end
    addRefresher(function()
        for i, key in ipairs(options) do
            buttons[i].label:SetText(labelOf(key))
            styleButton(buttons[i], isActive(key) and "active" or "plain")
        end
    end)
    return buttons
end

-- A switch row: label on the left, an on/off track on the right.
local function newSwitch(parent, x, y, labelOf, get, set)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 26)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = newText(row, 14, INK)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(CONTENT_W - 56)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(42, 22)
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local track = newTexture(button, "BACKGROUND", MUTED)
    track:SetAllPoints()
    local knob = newTexture(button, "ARTWORK", CREAM)
    knob:SetSize(18, 18)
    button:SetScript("OnClick", function()
        set(not get())
    end)
    addRefresher(function()
        label:SetText(labelOf())
        local on = get()
        local c = on and WINE or MUTED
        track:SetColorTexture(c[1], c[2], c[3], 1)
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", button, "LEFT", on and 22 or 2, 0)
    end)
    return row
end

-- A "− value +" stepper on the right of a label row.
local function newStepper(parent, x, y, labelOf, valueOf, onLess, onMore)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 26)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = newText(row, 14, INK)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(CONTENT_W - 130)
    local more = newButton(row, 24, 24, onMore)
    more:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    more.label:SetText("+")
    local value = newText(row, 14, INK, false, "CENTER")
    value:SetPoint("RIGHT", more, "LEFT", -4, 0)
    value:SetWidth(64)
    local less = newButton(row, 24, 24, onLess)
    less:SetPoint("RIGHT", value, "LEFT", -4, 0)
    less.label:SetText("-")
    addRefresher(function()
        label:SetText(labelOf())
        value:SetText(valueOf())
    end)
    return row
end

---------------------------------------------------------------------------
-- The scrolling list (a fixed set of row frames that show a window of the data)
---------------------------------------------------------------------------

-- kind "saying": diamond, reference and one line of text. kind "own": wrapped text and a remove button.
local function newList(parent, x, y, rowCount, rowHeight, kind)
    local list = { rows = {}, offset = 0, data = {}, kind = kind, rowCount = rowCount }
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder:SetSize(CONTENT_W, rowCount * rowHeight)
    holder:EnableMouseWheel(true)
    list.holder = holder

    local rule = newTexture(holder, "BORDER", LINE)
    rule:SetPoint("TOPLEFT") rule:SetPoint("TOPRIGHT") rule:SetHeight(1)

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("VERTICAL")
    slider:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    slider:SetSize(8, rowCount * rowHeight)
    local trackTexture = newTexture(slider, "BACKGROUND", LINE, 0.5)
    trackTexture:SetAllPoints()
    local thumb = newTexture(slider, "OVERLAY", MUTED)
    thumb:SetSize(8, 36)
    slider:SetThumbTexture(thumb)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetValue(0)
    list.slider = slider

    local settingSlider = false
    function list:Update()
        for i = 1, rowCount do
            local row = self.rows[i]
            local item = self.data[self.offset + i]
            row.item = item
            if item then
                row:Show()
                self.fill(row, item, self)
            else
                row:Hide()
            end
        end
    end

    function list:SetData(data)
        self.data = data
        local maxOffset = math.max(0, #data - rowCount)
        self.offset = math.min(self.offset, maxOffset)
        settingSlider = true
        slider:SetMinMaxValues(0, maxOffset)
        slider:SetValue(self.offset)
        settingSlider = false
        slider:SetShown(maxOffset > 0)
        self:Update()
    end

    function list:Scroll(steps)
        local maxOffset = math.max(0, #self.data - rowCount)
        local offset = math.min(maxOffset, math.max(0, self.offset + steps))
        if offset ~= self.offset then
            self.offset = offset
            settingSlider = true
            slider:SetValue(offset)
            settingSlider = false
            self:Update()
        end
    end

    holder:SetScript("OnMouseWheel", function(_, delta) list:Scroll(-delta) end)
    slider:SetScript("OnValueChanged", function(_, value)
        if settingSlider then
            return
        end
        local offset = math.floor(value + 0.5)
        if offset ~= list.offset then
            list.offset = offset
            list:Update()
        end
    end)

    for i = 1, rowCount do
        local row = CreateFrame("Button", nil, holder)
        row:SetSize(CONTENT_W - 14, rowHeight)
        row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * rowHeight)
        row.selected = newTexture(row, "BACKGROUND", WINE, 0.16)
        row.selected:SetAllPoints()
        row.selected:Hide()
        row.hover = newTexture(row, "HIGHLIGHT", WINE, 0.08)
        row.hover:SetAllPoints()
        local line = newTexture(row, "BORDER", LINE, 0.8)
        line:SetPoint("BOTTOMLEFT") line:SetPoint("BOTTOMRIGHT") line:SetHeight(1)

        if kind == "saying" then
            local mark = CreateFrame("Button", nil, row)
            mark:SetSize(26, rowHeight)
            mark:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.markOuter = newDiamond(mark, 13, MUTED)
            row.markOuter:SetPoint("CENTER", mark, "CENTER", 0, 0)
            row.markInner = newDiamond(mark, 9, PARCHMENT)
            row.markInner:SetPoint("CENTER", mark, "CENTER", 0, 0)
            mark:SetScript("OnClick", function()
                if row.item then
                    ns.ToggleFavorite(row.item.id)
                    ui.Refresh()
                end
            end)
            row.mark = mark
            row.ref = newText(row, 10, MUTED, true)
            row.ref:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -4)
            row.ref:SetWidth(CONTENT_W - 50)
            row.text = newText(row, 13, INK)
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -18)
            row.text:SetWidth(CONTENT_W - 50)
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function()
                if row.item then
                    ui.selected = row.item.id
                    ui.Refresh()
                end
            end)
        else
            row.text = newText(row, 13, INK)
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -4)
            row.text:SetWidth(CONTENT_W - 56)
            row.text:SetHeight(rowHeight - 8)
            row.text:SetWordWrap(true)
            local remove = newButton(row, 24, 24, function()
                if row.item then
                    ns.RemoveCustom(row.item.index)
                    ui.Refresh()
                end
            end)
            remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            remove.label:SetText("x")
            row.remove = remove
        end
        list.rows[i] = row
    end

    if kind == "saying" then
        list.fill = function(row, item)
            row.ref:SetText(item.ref or "")
            row.text:SetText(item.text)
            row.selected:SetShown(item.id == ui.selected)
            local inner = item.favorite and GOLD or PARCHMENT
            row.markInner:SetColorTexture(inner[1], inner[2], inner[3], 1)
            local outer = item.favorite and GOLD or MUTED
            row.markOuter:SetColorTexture(outer[1], outer[2], outer[3], 1)
            row.text:SetAlpha(item.excluded and 0.45 or 1)
            row.ref:SetAlpha(item.excluded and 0.45 or 1)
        end
    else
        list.fill = function(row, item)
            row.text:SetText(item.text)
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------

local function build()
    win = CreateFrame("Frame", "WordsOfTheLordWindow", UIParent)
    win:SetSize(WIDTH, HEIGHT)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, "WordsOfTheLordWindow")   -- Escape closes it
    end

    -- Cover and edge
    local edge = newTexture(win, "BACKGROUND", LEATHER_EDGE)
    edge:SetAllPoints()
    local cover = newTexture(win, "BORDER", LEATHER)
    cover:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -4)
    cover:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)

    local title = newText(win, 15, { 0.85, 0.71, 0.42 }, true)
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 24, -20)
    title:SetText("WORDS OF THE LORD")

    local close = newButton(win, 26, 26, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -18, -16)
    close.label:SetText("X")

    -- Pages
    local left = CreateFrame("Frame", nil, win)
    left:SetSize(PAGE_W, PAGE_H)
    left:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -60)
    local leftBg = newTexture(left, "ARTWORK", PARCHMENT)
    leftBg:SetAllPoints()
    local right = CreateFrame("Frame", nil, win)
    right:SetSize(PAGE_W, PAGE_H)
    right:SetPoint("TOPLEFT", win, "TOPLEFT", 390, -60)
    local rightBg = newTexture(right, "ARTWORK", PARCHMENT)
    rightBg:SetAllPoints()
    -- The gutter: a dark strip with a soft shadow on each side.
    local gutter = newTexture(win, "OVERLAY", GUTTER)
    gutter:SetPoint("TOP", win, "TOP", 0, -60) gutter:SetSize(4, PAGE_H)
    local shadeL = newTexture(win, "OVERLAY", GUTTER, 0.35)
    shadeL:SetPoint("TOPRIGHT", gutter, "TOPLEFT", 0, 0) shadeL:SetSize(14, PAGE_H)
    local shadeR = newTexture(win, "OVERLAY", GUTTER, 0.35)
    shadeR:SetPoint("TOPLEFT", gutter, "TOPRIGHT", 0, 0) shadeR:SetSize(14, PAGE_H)

    local function group(page)
        local g = CreateFrame("Frame", nil, page)
        g:SetAllPoints(page)
        return g
    end
    local gLib, gFav, gSet, gMine = group(left), group(left), group(left), group(left)
    local rReader, rSet, rMine = group(right), group(right), group(right)

    ---------------------------------------------------------------------
    -- Library (left)
    ---------------------------------------------------------------------
    local libHeader = newHeader(gLib)
    local search = CreateFrame("EditBox", nil, gLib)
    search:SetSize(CONTENT_W, 28)
    search:SetPoint("TOPLEFT", gLib, "TOPLEFT", PAD, -64)
    search:SetAutoFocus(false)
    search:SetFont(BODY_FONT, 13, "")
    search:SetTextColor(INK[1], INK[2], INK[3])
    search:SetTextInsets(8, 8, 0, 0)
    search:SetMaxLetters(60)
    local searchBg = newTexture(search, "BACKGROUND", PARCH_LIGHT, 0.7)
    searchBg:SetAllPoints()
    addBorder(search, MUTED, 0.9)
    local searchHint = newText(search, 13, MUTED)
    searchHint:SetPoint("LEFT", search, "LEFT", 8, 0)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        ui.query = self:GetText() or ""
        searchHint:SetShown(ui.query == "")
        ui.Refresh()
    end)
    ui.searchBox = search

    -- Category chips: "All" plus one per category, wrapped onto two lines if needed.
    local chips = {}
    local function addChip(key)
        local chip = newButton(gLib, 60, 22, function()
            ui.SetCategory(key)
            ui.Refresh()
        end)
        chip.key = key
        chips[#chips + 1] = chip
        return chip
    end
    addChip(nil)
    for _, category in ipairs(ns.CATEGORIES) do
        addChip(category.key)
    end
    ui.chips = chips

    local libList = newList(gLib, PAD, -154, 7, 36, "saying")
    ui.libList = libList

    addRefresher(function()
        libHeader.title:SetText(L.TITLE_LIBRARY)
        searchHint:SetText(L.SEARCH_HINT)
        local available = {}
        for _, category in ipairs(ui.Categories()) do available[category.key] = category end
        if ui.cat and not available[ui.cat] then
            ui.cat = nil
        end
        local x, y = 0, 0
        for _, chip in ipairs(chips) do
            local category = chip.key and available[chip.key]
            if chip.key == nil or category then
                chip.label:SetText(chip.key == nil and L.CHIP_ALL or category[ns.UILang()])
                local width = math.ceil((chip.label:GetStringWidth() or 40) + 18)
                if x > 0 and x + width > CONTENT_W then
                    x, y = 0, y + 26
                end
                chip:SetWidth(width)
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", gLib, "TOPLEFT", PAD + x, -100 - y)
                chip:Show()
                styleButton(chip, ui.cat == chip.key and "active" or "plain")
                x = x + width + 4
            else
                chip:Hide()
            end
        end
        libList:SetData(ui.Rows("lib"))
    end)

    ---------------------------------------------------------------------
    -- Favorites (left)
    ---------------------------------------------------------------------
    local favHeader = newHeader(gFav)
    local favHint = newText(gFav, 13, MUTED)
    favHint:SetPoint("TOPLEFT", gFav, "TOPLEFT", PAD, -64)
    favHint:SetWidth(CONTENT_W)
    local favList = newList(gFav, PAD, -90, 9, 36, "saying")
    local favEmpty = newText(gFav, 14, MUTED)
    favEmpty:SetPoint("TOPLEFT", gFav, "TOPLEFT", PAD + 4, -108)
    favEmpty:SetWidth(CONTENT_W - 8)
    ui.favList = favList
    addRefresher(function()
        favHeader.title:SetText(L.TITLE_FAVORITES)
        favHint:SetText(L.FAV_HINT)
        favEmpty:SetText(L.FAV_EMPTY)
        local rows = ui.Rows("fav")
        favList:SetData(rows)
        favEmpty:SetShown(#rows == 0)
    end)

    ---------------------------------------------------------------------
    -- Reader (right, shared by Library and Favorites)
    ---------------------------------------------------------------------
    local readerHeader = newHeader(rReader)
    local body = newText(rReader, 19, INK, false, "CENTER")
    body:SetPoint("TOP", rReader, "TOP", 0, -92)
    body:SetWidth(CONTENT_W)
    body:SetHeight(230)
    body:SetJustifyV("MIDDLE")
    local category = newText(rReader, 11, MUTED, true, "CENTER")
    category:SetPoint("TOP", rReader, "TOP", 0, -334)
    category:SetWidth(CONTENT_W)
    local preach = newButton(rReader, 128, 30, function()
        local shown = ui.Selected()
        if shown then ns.Preach(nil, shown) end
    end, true)
    preach:SetPoint("BOTTOMLEFT", rReader, "BOTTOMLEFT", PAD, 28)
    local favorite = newButton(rReader, 88, 30, function()
        if ui.selected then
            ns.ToggleFavorite(ui.selected)
            ui.Refresh()
        end
    end, true)
    favorite:SetPoint("LEFT", preach, "RIGHT", 7, 0)
    local never = newButton(rReader, 88, 30, function()
        if ui.selected then
            ns.ToggleExcluded(ui.selected)
            ui.Refresh()
        end
    end, true)
    never:SetPoint("LEFT", favorite, "RIGHT", 7, 0)
    addRefresher(function()
        local shown = ui.Selected()
        readerHeader.title:SetText(shown and shown.ref or "")
        body:SetText(shown and ("\"" .. shown.text .. "\"") or "")
        if shown and ns.GetLang() ~= "en" then
            body:SetText("« " .. shown.text .. " »")
        end
        local label = ""
        if shown then
            for _, c in ipairs(ns.CATEGORIES) do
                if c.key == shown.cat then label = c[ns.UILang()] end
            end
        end
        category:SetText(label)
        preach.label:SetText(L.BTN_PREACH)
        styleButton(preach, "primary")
        favorite.label:SetText(shown and shown.favorite and L.BTN_FAVORITED or L.BTN_FAVORITE)
        styleButton(favorite, shown and shown.favorite and "active" or "plain")
        never.label:SetText(shown and shown.excluded and L.BTN_NEVER_ON or L.BTN_NEVER)
        styleButton(never, shown and shown.excluded and "active" or "plain")
    end)

    ---------------------------------------------------------------------
    -- Settings (left page: how to preach)
    ---------------------------------------------------------------------
    local setHeader = newHeader(gSet)
    local langLabel = newSectionLabel(gSet, PAD, -66)
    newChoiceRow(gSet, PAD, -84, { "en", "fr", "qc" }, 3, 100, 26, 5,
        function(key) return L.LANG_NAMES[key] end,
        function(key) return ns.GetLang() == key end,
        function(key)
            ns.db.lang = key
            ns.ResetBag()
            ui.Refresh()
        end)
    local channelLabel = newSectionLabel(gSet, PAD, -124)
    newChoiceRow(gSet, PAD, -142, ns.CHANNEL_ORDER, 4, 74, 26, 4,
        function(key) return capitalize(ns.ChannelLabel(key)) end,
        function(key) return ns.db.channel == key end,
        function(key)
            ns.db.channel = key
            ui.Refresh()
        end)
    newSwitch(gSet, PAD, -214, function() return L.SET_AUTO end,
        function() return ns.db.autoEnabled end,
        function(on)
            ns.db.autoEnabled = on
            ns.UpdateAutoPreach()
            ui.Refresh()
        end)
    newStepper(gSet, PAD, -246, function() return L.SET_EVERY end,
        function() return L.SET_MINUTES:format(ns.db.autoMinutes) end,
        function()
            ns.db.autoMinutes = math.max(ns.AUTO_MIN_MINUTES, ns.db.autoMinutes - 1)
            ns.UpdateAutoPreach()
            ui.Refresh()
        end,
        function()
            ns.db.autoMinutes = math.min(120, ns.db.autoMinutes + 1)
            ns.UpdateAutoPreach()
            ui.Refresh()
        end)
    -- The auto-preach channel: click to step through the channels.
    local autoChannelRow = CreateFrame("Frame", nil, gSet)
    autoChannelRow:SetSize(CONTENT_W, 26)
    autoChannelRow:SetPoint("TOPLEFT", gSet, "TOPLEFT", PAD, -278)
    local autoChannelLabel = newText(autoChannelRow, 14, INK)
    autoChannelLabel:SetPoint("LEFT", autoChannelRow, "LEFT", 0, 0)
    autoChannelLabel:SetWidth(CONTENT_W - 110)
    local autoChannelButton = newButton(autoChannelRow, 100, 24, function()
        local order, nextIndex = ns.CHANNEL_ORDER, 1
        for i, channel in ipairs(order) do
            if channel == ns.db.autoChannel then nextIndex = (i % #order) + 1 break end
        end
        ns.db.autoChannel = order[nextIndex]
        ns.UpdateAutoPreach()
        ui.Refresh()
    end)
    autoChannelButton:SetPoint("RIGHT", autoChannelRow, "RIGHT", 0, 0)
    ui.autoChannelButton = autoChannelButton
    addRefresher(function()
        autoChannelLabel:SetText(L.SET_AUTO_CHANNEL)
        autoChannelButton.label:SetText(capitalize(ns.ChannelLabel(ns.db.autoChannel)))
    end)
    newSwitch(gSet, PAD, -310, function() return L.SET_REACT end,
        function() return ns.db.reactions end,
        function(on) ns.db.reactions = on ui.Refresh() end)
    addRefresher(function()
        setHeader.title:SetText(L.TITLE_PREACHER)
        langLabel:SetText(L.SET_LANGUAGE)
        channelLabel:SetText(L.SET_CHANNEL)
    end)

    ---------------------------------------------------------------------
    -- Settings (right page: what to preach)
    ---------------------------------------------------------------------
    local weightHeader = newHeader(rSet)
    local weightLabel = newSectionLabel(rSet, PAD, -66)
    newChoiceRow(rSet, PAD, -84, { 1, 2, 3, 4, 5 }, 5, 58, 26, 5,
        function(n) return tostring(n) end,
        function(n) return ns.FavoriteWeight() == n end,
        function(n)
            ns.db.favoriteWeight = n
            ui.Refresh()
        end)
    local weightNote = newText(rSet, 12, MUTED)
    weightNote:SetPoint("TOPLEFT", rSet, "TOPLEFT", PAD, -116)
    weightNote:SetWidth(CONTENT_W)
    weightNote:SetHeight(30)
    weightNote:SetWordWrap(true)
    weightNote:SetJustifyV("TOP")
    local categoriesLabel = newSectionLabel(rSet, PAD, -156)
    local categoryButtons = {}
    for i, c in ipairs(ns.CATEGORIES) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local button = CreateFrame("Button", nil, rSet)
        button:SetSize(CONTENT_W / 2 - 4, 24)
        button:SetPoint("TOPLEFT", rSet, "TOPLEFT", PAD + col * (CONTENT_W / 2 + 4), -174 - row * 26)
        local box = newTexture(button, "ARTWORK", MUTED)
        box:SetSize(16, 16)
        box:SetPoint("LEFT", button, "LEFT", 0, 0)
        local boxInner = newTexture(button, "OVERLAY", PARCH_LIGHT)
        boxInner:SetSize(12, 12)
        boxInner:SetPoint("CENTER", box, "CENTER", 0, 0)
        local check = newTexture(button, "OVERLAY", WINE)
        check:SetSize(8, 8)
        check:SetPoint("CENTER", box, "CENTER", 0, 0)
        local text = newText(button, 13, INK)
        text:SetPoint("LEFT", box, "RIGHT", 6, 0)
        text:SetWidth(CONTENT_W / 2 - 30)
        button:SetScript("OnClick", function()
            ns.SetCategory(c.key, not ns.CategoryEnabled(c.key))
            ui.Refresh()
        end)
        categoryButtons[i] = { text = text, check = check, key = c.key, category = c }
    end
    newStepper(rSet, PAD, -262, function() return L.SET_QC_SHARE end,
        function() return ns.QuebecShare() .. "%" end,
        function()
            ns.db.quebecShare = math.max(0, ns.QuebecShare() - 5)
            ui.Refresh()
        end,
        function()
            ns.db.quebecShare = math.min(100, ns.QuebecShare() + 5)
            ui.Refresh()
        end)
    newSwitch(rSet, PAD, -298, function() return L.SET_BUILTIN end,
        function() return ns.db.useBuiltin end,
        function(on) ns.db.useBuiltin = on ui.Refresh() end)
    newSwitch(rSet, PAD, -330, function() return L.SET_BUTTON_SHOWN end,
        function() return ns.db.button.shown end,
        function(on)
            ns.db.button.shown = on
            ns.UpdateButton()
            ui.Refresh()
        end)
    newSwitch(rSet, PAD, -362, function() return L.SET_BUTTON_LOCKED end,
        function() return ns.db.button.locked end,
        function(on) ns.db.button.locked = on ui.Refresh() end)
    addRefresher(function()
        weightHeader.title:SetText(L.TITLE_WEIGHTS)
        weightLabel:SetText(L.SET_WEIGHT)
        weightNote:SetText(L.SET_WEIGHT_NOTE:format(ns.FavoriteWeight()))
        categoriesLabel:SetText(L.SET_CATEGORIES)
        for _, item in ipairs(categoryButtons) do
            item.text:SetText(item.category[ns.UILang()])
            item.check:SetShown(ns.CategoryEnabled(item.key))
        end
    end)

    ---------------------------------------------------------------------
    -- My sayings
    ---------------------------------------------------------------------
    local mineHeader = newHeader(gMine)
    local writeLabel = newSectionLabel(gMine, PAD, -66)
    local boxFrame = CreateFrame("Frame", nil, gMine)
    boxFrame:SetSize(CONTENT_W, 150)
    boxFrame:SetPoint("TOPLEFT", gMine, "TOPLEFT", PAD, -86)
    local boxBg = newTexture(boxFrame, "BACKGROUND", PARCH_LIGHT, 0.7)
    boxBg:SetAllPoints()
    addBorder(boxFrame, MUTED, 0.9)
    local edit = CreateFrame("EditBox", nil, boxFrame)
    edit:SetPoint("TOPLEFT", boxFrame, "TOPLEFT", 8, -8)
    edit:SetSize(CONTENT_W - 16, 134)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(BODY_FONT, 14, "")
    edit:SetTextColor(INK[1], INK[2], INK[3])
    edit:SetMaxLetters(400)
    local editHint = newText(boxFrame, 14, MUTED)
    editHint:SetPoint("TOPLEFT", boxFrame, "TOPLEFT", 8, -8)
    editHint:SetWidth(CONTENT_W - 16)
    editHint:SetJustifyV("TOP")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self)
        editHint:SetShown((self:GetText() or "") == "")
    end)
    ui.editBox = edit
    local add = newButton(gMine, 160, 30, function()
        local index = ns.AddCustom(edit:GetText())
        if index then
            edit:SetText("")
            edit:ClearFocus()
            ns.Print(L.ADDED:format(index))
            ui.Refresh()
        end
    end, true)
    add:SetPoint("TOPLEFT", gMine, "TOPLEFT", PAD, -250)
    addRefresher(function()
        mineHeader.title:SetText(L.TITLE_MINE)
        writeLabel:SetText(L.MINE_WRITE)
        editHint:SetText(L.MINE_PLACEHOLDER)
        add.label:SetText(L.BTN_ADD)
        styleButton(add, "primary")
    end)

    local voiceHeader = newHeader(rMine)
    local ownList = newList(rMine, PAD, -66, 8, 40, "own")
    local ownEmpty = newText(rMine, 14, MUTED)
    ownEmpty:SetPoint("TOPLEFT", rMine, "TOPLEFT", PAD + 4, -84)
    ownEmpty:SetWidth(CONTENT_W - 8)
    ui.ownList = ownList
    addRefresher(function()
        voiceHeader.title:SetText(L.TITLE_VOICE)
        ownEmpty:SetText(L.MINE_EMPTY)
        local own = ui.OwnSayings()
        ownList:SetData(own)
        ownEmpty:SetShown(#own == 0)
    end)

    ---------------------------------------------------------------------
    -- Ribbons (the tabs)
    ---------------------------------------------------------------------
    ui.ribbons = {}
    for i, def in ipairs(RIBBONS) do
        local ribbon = CreateFrame("Button", nil, win)
        ribbon:SetFrameLevel(win:GetFrameLevel() + 10)
        ribbon:SetSize(104, 66)
        ribbon:SetPoint("TOPLEFT", win, "TOPLEFT", 200 + (i - 1) * 112, 0)
        ribbon.bg = newTexture(ribbon, "BACKGROUND", def.color)
        ribbon.bg:SetAllPoints()
        local stitch = newTexture(ribbon, "BORDER", CREAM, 0.35)
        stitch:SetPoint("TOPLEFT", ribbon, "TOPLEFT", 5, 0)
        stitch:SetPoint("BOTTOMLEFT", ribbon, "BOTTOMLEFT", 5, 0)
        stitch:SetWidth(1)
        local stitch2 = newTexture(ribbon, "BORDER", CREAM, 0.35)
        stitch2:SetPoint("TOPRIGHT", ribbon, "TOPRIGHT", -5, 0)
        stitch2:SetPoint("BOTTOMRIGHT", ribbon, "BOTTOMRIGHT", -5, 0)
        stitch2:SetWidth(1)
        ribbon.hover = newTexture(ribbon, "HIGHLIGHT", CREAM, 0.12)
        ribbon.hover:SetAllPoints()
        ribbon.label = newText(ribbon, 12, CREAM, true, "CENTER")
        ribbon.label:SetPoint("TOP", ribbon, "TOP", 0, -16)
        ribbon.label:SetWidth(96)
        ribbon:SetScript("OnClick", function()
            ui.tab = def.key
            ui.Refresh()
        end)
        ribbon.key = def.key
        ui.ribbons[i] = ribbon
    end

    addRefresher(function()
        for i, def in ipairs(RIBBONS) do
            local ribbon = ui.ribbons[i]
            ribbon.label:SetText(L[def.label])
            ribbon:SetHeight(ui.tab == def.key and 82 or 66)
        end
    end)

    -- Which groups show on which tab
    ui.groups = {
        lib  = { gLib, rReader },
        fav  = { gFav, rReader },
        set  = { gSet, rSet },
        mine = { gMine, rMine },
    }
    ui.allGroups = { gLib, gFav, gSet, gMine, rReader, rSet, rMine }

    win:SetScript("OnShow", function() ui.Refresh() end)
end

---------------------------------------------------------------------------
-- Refresh and public entry points
---------------------------------------------------------------------------

function ui.Refresh()
    if not win then
        return
    end
    ui.EnsureSelection()
    for _, g in ipairs(ui.allGroups) do
        g:Hide()
    end
    for _, g in ipairs(ui.groups[ui.tab]) do
        g:Show()
    end
    for _, fn in ipairs(refreshers) do
        fn()
    end
end

function ns.RefreshWindow()
    if win and win:IsShown() then
        ui.Refresh()
    end
end

function ns.OpenWindow(tab)
    if not win then
        build()
    end
    if tab then
        ui.tab = tab
    end
    win:Show()
    ui.Refresh()
end

function ns.CloseWindow()
    if win then
        win:Hide()
    end
end

function ns.ToggleWindow()
    if win and win:IsShown() then
        win:Hide()
    else
        ns.OpenWindow()
    end
end
