local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

local Config = {}
RB.Config = Config
RB:RegisterModule("config", Config)
Config.frame = nil

local function makeCheck(parent, label, y, checkedFunc, setFunc, enabledFunc)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    check:SetSize(26, 26)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(label)
    check.label = text
    check.refresh = function()
        local enabled = not enabledFunc or enabledFunc()
        check:SetEnabled(enabled)
        check:SetChecked(enabled and checkedFunc() or false)
        text:SetTextColor(enabled and 1 or 0.45, enabled and 0.82 or 0.45, enabled and 0.35 or 0.45)
    end
    check:SetScript("OnClick", function(self)
        setFunc(self:GetChecked() == true)
        Config:Refresh()
    end)
    return check
end

local function openAccentPicker()
    if not ColorPickerFrame or type(RB.GetAccentColor) ~= "function" then return end

    local r, g, b = RB:GetAccentColor()
    local previous = {r = r, g = g, b = b}

    local function applyColor()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        RB:SetAccentColor(nr, ng, nb, true)
        Config:Refresh()
    end

    local function cancelColor(values)
        local old = values or previous
        RB:SetAccentColor(old.r or old[1] or previous.r, old.g or old[2] or previous.g, old.b or old[3] or previous.b, true)
        Config:Refresh()
    end

    if type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            hasOpacity = false,
            swatchFunc = applyColor,
            cancelFunc = cancelColor,
        })
        return
    end

    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = previous
    ColorPickerFrame.func = applyColor
    ColorPickerFrame.cancelFunc = cancelColor
    ColorPickerFrame:Show()
end

function Config:CreateFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "RapzoQoLConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(540, 720)
    frame:SetPoint("CENTER")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
    frame.title:SetText("Rapzo QoL - Modulos y configuracion")

    local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -42)
    intro:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Rapzo QoL es un solo addon. Sus modulos viven dentro de la misma carpeta y puedes activar o desactivar cada funcion desde este panel.")

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -18)
    status:SetText("Estado de modulos")

    frame.statusLines = {}
    local modules = { {"tooltip","Tooltip"}, {"search","Search"}, {"vendor","Vendor"}, {"collections","Collections"}, {"afk","AFK Screen"}, {"hud","HUD Visual"} }
    local y = -112
    for i, entry in ipairs(modules) do
        local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, y)
        frame.statusLines[i] = {text=line, key=entry[1], label=entry[2]}
        y = y - 22
    end

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1); divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -250); divider:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    divider:SetColorTexture(0.45,0.55,0.65,0.35)

    local appearance = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    appearance:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -272)
    appearance:SetText("Apariencia · Accent Color")

    local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
    swatch:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -300)
    swatch:SetSize(42, 24)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    swatch:SetBackdropColor(0.02, 0.03, 0.05, 1)
    swatch:SetBackdropBorderColor(0.75, 0.80, 0.88, 0.65)
    local swatchFill = swatch:CreateTexture(nil, "ARTWORK")
    swatchFill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
    swatchFill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
    swatch.fill = swatchFill
    swatch:SetScript("OnClick", openAccentPicker)
    frame.accentSwatch = swatch

    local hexText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hexText:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
    frame.accentHexText = hexText

    local choose = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    choose:SetSize(120, 24)
    choose:SetPoint("LEFT", hexText, "RIGHT", 14, 0)
    choose:SetText("Elegir color")
    choose:SetScript("OnClick", openAccentPicker)

    local resetAccent = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetAccent:SetSize(105, 24)
    resetAccent:SetPoint("LEFT", choose, "RIGHT", 8, 0)
    resetAccent:SetText("Restablecer")
    resetAccent:SetScript("OnClick", function()
        RB:ResetAccentColor(true)
        Config:Refresh()
    end)

    local appearanceHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    appearanceHelp:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -330)
    appearanceHelp:SetText("Dark permanece oscuro; este color controla los acentos de Rapzo QoL. Los colores de clase se respetan.")

    local divider2 = frame:CreateTexture(nil, "ARTWORK")
    divider2:SetHeight(1); divider2:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -352); divider2:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    divider2:SetColorTexture(0.45,0.55,0.65,0.35)

    frame.checks = {}
    frame.checks[#frame.checks+1] = makeCheck(frame, "Tooltip avanzado", -372,
        function() return RB:IsFeatureEnabled("tooltip") end,
        function(v) RB:SetFeatureEnabled("tooltip", v, true); local db=RB:EnsureDB(); db.settings.tooltip=v end,
        function() return RB:IsModulePresent("tooltip") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Expansion del objeto", -404,
        function() return RB:EnsureDB().settings.showItemExpansion ~= false end,
        function(v) RB:EnsureDB().settings.showItemExpansion=v end,
        function() return RB:IsModulePresent("tooltip") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Tipo + Item ID", -436,
        function() local s=RB:EnsureDB().settings; return s.showItemType ~= false and s.showItemID ~= false end,
        function(v) local s=RB:EnsureDB().settings; s.showItemType=v; s.showItemID=v end,
        function() return RB:IsModulePresent("tooltip") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Buscador global", -468,
        function() return RB:IsFeatureEnabled("search") end,
        function(v) RB:SetFeatureEnabled("search", v, true) end,
        function() return RB:IsModulePresent("search") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Coleccionables (obtenido/no obtenido)", -500,
        function() return RB:IsFeatureEnabled("collections") end,
        function(v) RB:SetFeatureEnabled("collections", v, true); if RB.Collections and RB.Collections.ClearCache then RB.Collections:ClearCache() end end,
        function() return RB:IsModulePresent("collections") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Vendedor extendido", -532,
        function() local db=RB:EnsureDB(); return db.settings.vendor and db.settings.vendor.enabled ~= false end,
        function(v) if RB.Vendor and RB.Vendor.SetEnabled then RB.Vendor:SetEnabled(v) else RB:SetFeatureEnabled("vendor",v,true) end end,
        function() return RB:IsModulePresent("vendor") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Pantalla AFK", -564,
        function() return RB:IsFeatureEnabled("afk") end,
        function(v)
            if RB.AFK and RB.AFK.SetEnabled then
                RB.AFK:SetEnabled(v)
            else
                RB:SetFeatureEnabled("afk", v, true)
            end
        end,
        function() return RB:IsModulePresent("afk") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "HUD visual (cursor + minimapa + unit frames)", -596,
        function() return RB:IsFeatureEnabled("hud") end,
        function(v)
            if RB.HUD and RB.HUD.SetEnabled then
                RB.HUD:SetEnabled(v)
            else
                RB:SetFeatureEnabled("hud", v, true)
            end
        end,
        function() return RB:IsModulePresent("hud") end)

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(150, 26); reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20); reset:SetText("Reescanear ahora")
    reset:SetScript("OnClick", function() if RB.Scanner then RB.Scanner:ScanAll(RB.Scanner.bankOpen); RB:Print("Escaneo actualizado.") end end)

    local modulesButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    modulesButton:SetSize(150, 26); modulesButton:SetPoint("LEFT", reset, "RIGHT", 10, 0); modulesButton:SetText("Estado en chat")
    modulesButton:SetScript("OnClick", function() RB:ShowModules() end)

    self.frame = frame
    return frame
end

function Config:Refresh()
    local frame = self:CreateFrame()
    for _, line in ipairs(frame.statusLines or {}) do
        local loaded = RB:IsModulePresent(line.key)
        local runtime = RB:IsFeatureEnabled(line.key)
        line.text:SetText(string.format("%s: %s   Funcion: %s", line.label, loaded and "|cff38e66bLISTO|r" or "|cffef4444ERROR|r", runtime and "|cff38e66bON|r" or "|cffef4444OFF|r"))
    end
    for _, check in ipairs(frame.checks or {}) do check.refresh() end

    if type(RB.GetAccentColor) == "function" then
        local r, g, b = RB:GetAccentColor()
        if frame.accentSwatch and frame.accentSwatch.fill then
            frame.accentSwatch.fill:SetColorTexture(r, g, b, 1)
        end
        if frame.accentHexText then
            frame.accentHexText:SetText("#" .. RB:ColorToHex(r, g, b))
            frame.accentHexText:SetTextColor(r, g, b)
        end
        if frame.title then
            frame.title:SetTextColor(r, g, b)
        end
    end
end

function Config:Show()
    if not RB:IsFeatureEnabled("config") then RB:Print("Modulo Config desactivado."); return end
    local frame = self:CreateFrame(); self:Refresh(); frame:Show(); frame:Raise()
end

RB:RegisterCommand("config", function() Config:Show() end, "/rapzo config - abre el panel modular")
RB:RegisterCommand("options", function() Config:Show() end)
