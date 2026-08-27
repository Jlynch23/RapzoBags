local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

HUD.previewFrame = nil
HUD.previewDisplays = HUD.previewDisplays or {}

local function makePanel(parent, width, height, color)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.005, 0.009, 0.015, 0.96)
    frame.RapzoQoLPanel = bg

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    accent:SetHeight(2)
    accent:SetColorTexture(color[1], color[2], color[3], 0.95)

    local edges = {}
    local function edge(a, b, c, d, w, h)
        local tex = frame:CreateTexture(nil, "OVERLAY")
        edges[#edges + 1] = tex
        tex:SetPoint(a, frame, a, b, c)
        if d then tex:SetPoint(d, frame, d, -b, -c) end
        if w then tex:SetWidth(w) end
        if h then tex:SetHeight(h) end
        tex:SetColorTexture(color[1], color[2], color[3], 0.34)
    end

    edge("TOPLEFT", -1, 1, "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", -1, 1, "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, nil)

    frame.RapzoQoLAccent = accent
    frame.RapzoQoLEdges = edges
    return frame
end

local function makeStatusBar(parent, height, color)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar:SetStatusBarTexture(WHITE_TEXTURE)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(82)
    bar:SetStatusBarColor(color[1], color[2], color[3])

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0.015, 0.022, 0.034, 0.98)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    bar.RapzoQoLText = text
    return bar
end

local function getPreviewClassColor(classFile, fallback)
    fallback = fallback or {0.92, 0.66, 0.10}
    if type(RAID_CLASS_COLORS) ~= "table" then return fallback end
    local color = RAID_CLASS_COLORS[classFile]
    if not color then return fallback end
    return {color.r or fallback[1], color.g or fallback[2], color.b or fallback[3]}
end

local function makeDemo(parent, key, title, color, classFile, isMob)
    local display = makePanel(parent, 232, 68, color)
    display.key = key
    display.color = color

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(string.upper(key))
    label:SetTextColor(color[1], color[2], color[3])
    label:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 42)
    display.previewLabel = label

    local name = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -8)
    name:SetPoint("RIGHT", display, "RIGHT", -4, 0)
    name:SetHeight(14)
    name:SetJustifyH("LEFT")
    name:SetText(title)
    display.nameText = name

    local tag = display:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tag:SetPoint("TOPRIGHT", display, "TOPRIGHT", -6, -8)
    tag:SetText(string.upper(key))
    tag:SetTextColor(color[1], color[2], color[3])
    display.unitTag = tag

    local health = makeStatusBar(display, 24, color)
    health:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -25)
    health:SetPoint("RIGHT", display, "RIGHT", -4, 0)
    health.RapzoQoLText:SetText(key == "player" and "1.24M / 1.24M  100%" or "82%")
    display.health = health

    local power = makeStatusBar(display, 9, {0.22, 0.28, 0.38})
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -3)
    power:SetPoint("RIGHT", health, "RIGHT", 0, 0)
    power:SetValue(key == "player" and 72 or 58)
    power.RapzoQoLText:SetText(key == "player" and "RAGE 72" or "POWER")
    display.power = power

    local auraRow = CreateFrame("Frame", nil, display)
    auraRow:SetSize(232, 22)
    auraRow:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 6, 6)
    display.previewAuras = auraRow

    for i = 1, 5 do
        local aura = CreateFrame("Frame", nil, auraRow)
        aura:SetSize(20, 20)
        aura:SetPoint("LEFT", auraRow, "LEFT", (i - 1) * 25, 0)

        local tex = aura:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(aura)
        local palette = {
            {0.95, 0.56, 0.12},
            {0.22, 0.66, 0.96},
            {0.70, 0.25, 0.92},
            {0.24, 0.78, 0.42},
            {0.94, 0.26, 0.18},
        }
        local c = palette[i]
        tex:SetColorTexture(c[1], c[2], c[3], 0.94)

        if type(aura.CreateMaskTexture) == "function" and type(tex.AddMaskTexture) == "function" then
            local mask = aura:CreateMaskTexture()
            mask:SetAllPoints(tex)
            mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            tex:AddMaskTexture(mask)
        end

        local duration = aura:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        duration:SetPoint("TOP", aura, "BOTTOM", 0, -1)
        duration:SetText(({"2m", "38s", "18s", "9s", "4s"})[i])
    end

    local cast = makeStatusBar(display, 14, {0.92, 0.63, 0.12})
    cast:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 6, -4)
    cast:SetPoint("RIGHT", display, "RIGHT", -4, 0)
    cast:SetValue(key == "target" and 48 or 68)
    cast.RapzoQoLText:SetText(key == "target" and "Golpe demo  1.2 / 2.0" or "Lanzamiento demo")
    display.previewCast = cast

    HUD.previewDisplays[key] = display
    return display
end

local function setPreviewShellVisible(display, visible)
    if not display then return end
    if display.RapzoQoLPanel then display.RapzoQoLPanel:SetAlpha(visible and 1 or 0) end
    if display.RapzoQoLAccent then display.RapzoQoLAccent:SetAlpha(visible and 1 or 0) end
    for _, edge in ipairs(display.RapzoQoLEdges or {}) do
        edge:SetAlpha(visible and 1 or 0)
    end
end

local function applyPreviewStyle(display, style)
    if not display then return end

    if style == 2 then
        setPreviewShellVisible(display, false)
        display:SetSize(232, 56)

        display.health:ClearAllPoints()
        display.health:SetHeight(31)
        display.health:SetPoint("TOPLEFT", display, "TOPLEFT", 0, -15)
        display.health:SetPoint("RIGHT", display, "RIGHT", 0, 0)

        display.power:ClearAllPoints()
        display.power:SetHeight(7)
        display.power:SetPoint("TOPLEFT", display.health, "BOTTOMLEFT", 0, -1)
        display.power:SetPoint("RIGHT", display.health, "RIGHT", 0, 0)

        display.nameText:ClearAllPoints()
        display.nameText:SetHeight(14)
        display.nameText:SetPoint("BOTTOMLEFT", display.health, "TOPLEFT", 2, 1)
        display.nameText:SetPoint("RIGHT", display.health, "RIGHT", -2, 0)
        display.nameText:SetJustifyH("LEFT")

        display.previewAuras:ClearAllPoints()
        display.previewAuras:SetSize(232, 22)
        display.previewAuras:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 22)

        display.previewCast:ClearAllPoints()
        display.previewCast:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -4)
        display.previewCast:SetPoint("RIGHT", display, "RIGHT", 0, 0)

        display.previewAuras:Show()
        display.previewCast:Show()
        display.unitTag:Hide()
    else
        setPreviewShellVisible(display, true)
        display:SetSize(240, 64)

        display.nameText:ClearAllPoints()
        display.nameText:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -8)
        display.nameText:SetPoint("RIGHT", display, "RIGHT", -6, 0)

        display.health:ClearAllPoints()
        display.health:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -25)
        display.health:SetPoint("RIGHT", display, "RIGHT", -6, 0)

        display.power:ClearAllPoints()
        display.power:SetPoint("TOPLEFT", display.health, "BOTTOMLEFT", 0, -4)
        display.power:SetPoint("RIGHT", display.health, "RIGHT", 0, 0)

        display.previewCast:Hide()
        display.unitTag:Show()

        if display.key == "player" then
            display.previewAuras:Hide()
        else
            display.previewAuras:Show()
            display.previewAuras:ClearAllPoints()
            display.previewAuras:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 7)
        end
    end

end

function HUD:CreatePreview()
    if self.previewFrame then return self.previewFrame end

    local frame = CreateFrame("Frame", "RapzoQoLHUDPreviewFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(920, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
    title:SetText("Rapzo QoL - HUD Preview")
    frame.RapzoQoLTitle = title

    local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -38)
    intro:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Preview seguro: son frames falsos de demostracion. Puedes comparar Estilo 1 y Estilo 2 sin necesitar target, focus ni entrar en combate.")

    local style1 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    style1:SetSize(150, 26)
    style1:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -68)
    style1:SetText("Estilo 1 - Actual")
    style1:SetScript("OnClick", function()
        HUD:SetStyle(1)
        HUD:ShowPreview()
    end)

    local style2 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    style2:SetSize(260, 26)
    style2:SetPoint("LEFT", style1, "RIGHT", 10, 0)
    style2:SetText("Estilo 2 - ToxiUI")
    style2:SetScript("OnClick", function()
        HUD:SetStyle(2)
        HUD:ShowPreview()
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("LEFT", style2, "RIGHT", 16, 0)
    hint:SetText("/rapzo hud style 1|2")
    hint:SetTextColor(0.55, 0.75, 0.95)

    local player = makeDemo(frame, "player", "Rapzo", getPreviewClassColor("WARRIOR", {0.92, 0.66, 0.10}), "WARRIOR", false)
    player:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -190)

    local target = makeDemo(frame, "target", "Muñeco de entrenamiento", {0.92, 0.30, 0.09}, nil, true)
    target:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -70, -190)

    local focus = makeDemo(frame, "focus", "Focus Rogue", getPreviewClassColor("ROGUE", {1.00, 0.96, 0.41}), "ROGUE", false)
    focus:SetPoint("BOTTOM", frame, "BOTTOM", 0, 82)

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18)
    note:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Estilo 2 Toxi: nombre arriba, health principal, power fino, sin iconos, auras arriba y castbar abajo.")

    self.previewFrame = frame

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "RapzoQoLHUDPreviewFrame"
    end

    self:RefreshPreview()
    frame:Hide()
    return frame
end

function HUD:RefreshPreview()
    local frame = self.previewFrame
    if not frame then return end
    local style = self:GetStyle()
    for _, key in ipairs({"player", "target", "focus"}) do
        applyPreviewStyle(self.previewDisplays[key], style)
    end
end

function HUD:ShowPreview()
    local frame = self:CreatePreview()
    self:RefreshPreview()
    frame:Show()
    frame:Raise()
end

function HUD:HidePreview()
    if self.previewFrame then self.previewFrame:Hide() end
end

function HUD:TogglePreview(value)
    value = string.lower(tostring(value or ""))

    if value == "off" then
        self:HidePreview()
        RB:Print("HUD preview: OFF")
        return
    end

    if value == "on" then
        self:ShowPreview()
        RB:Print("HUD preview: ON")
        return
    end

    local frame = self:CreatePreview()
    if frame:IsShown() then
        self:HidePreview()
        RB:Print("HUD preview: OFF")
    else
        self:ShowPreview()
        RB:Print("HUD preview: ON")
    end
end
