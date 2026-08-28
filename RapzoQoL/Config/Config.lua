local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

local Config = {}
RB.Config = Config
RB:RegisterModule("config", Config)
Config.frame = nil

-- Forward declaration: CreateFrame() is defined before the shared HUD style
-- choice builder. Without this local, Lua resolves the earlier reference as a
-- global and the full Rapzo QoL panel errors when it is opened.
local makeHUDStyleChoice

local function makeCheck(parent, label, y, checkedFunc, setFunc, enabledFunc, x)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 22, y)
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
        if Config.frame then Config:Refresh() end
        if Config.settingsPanel then Config:RefreshSettingsPanel() end
    end)
    return check
end

local function isCursorRingEnabled()
    local db = RB:EnsureDB()
    db.settings = type(db.settings) == "table" and db.settings or {}
    local hud = db.settings.hud
    return type(hud) ~= "table" or hud.cursor ~= false
end

local function setCursorRingEnabled(enabled)
    if RB.HUD and type(RB.HUD.SetPart) == "function" then
        RB.HUD:SetPart("cursor", enabled)
        return
    end

    local db = RB:EnsureDB()
    db.settings = type(db.settings) == "table" and db.settings or {}
    db.settings.hud = type(db.settings.hud) == "table" and db.settings.hud or {}
    db.settings.hud.cursor = enabled and true or false
end

local function openAccentPicker()
    if not ColorPickerFrame or type(RB.GetAccentColor) ~= "function" then return end

    local r, g, b = RB:GetAccentColor()
    local previous = {r = r, g = g, b = b}

    local function applyColor()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        RB:SetAccentColor(nr, ng, nb, true)
        if Config.frame then Config:Refresh() end
        if Config.settingsPanel then Config:RefreshSettingsPanel() end
    end

    local function cancelColor(values)
        local old = values or previous
        RB:SetAccentColor(old.r or old[1] or previous.r, old.g or old[2] or previous.g, old.b or old[3] or previous.b, true)
        if Config.frame then Config:Refresh() end
        if Config.settingsPanel then Config:RefreshSettingsPanel() end
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
        if Config.frame then Config:Refresh() end
        if Config.settingsPanel then Config:RefreshSettingsPanel() end
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
    frame.checks[#frame.checks+1] = makeCheck(frame, "HUD visual (frames + minimapa)", -596,
        function() return RB:IsFeatureEnabled("hud") end,
        function(v)
            if RB.HUD and RB.HUD.SetEnabled then
                RB.HUD:SetEnabled(v)
            else
                RB:SetFeatureEnabled("hud", v, true)
            end
        end,
        function() return RB:IsModulePresent("hud") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Aro del mouse", -596,
        isCursorRingEnabled,
        setCursorRingEnabled,
        function() return RB:IsModulePresent("hud") end,
        310)

    local hudStyleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudStyleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -632)
    hudStyleLabel:SetText("Estilo de Unit Frames")

    frame.hudStyleChecks = {
        makeHUDStyleChoice(frame, "V1 - Clásico", 24, -650, 1),
        makeHUDStyleChoice(frame, "V2 - ToxiUI", 190, -650, 2),
    }

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
    for _, check in ipairs(frame.hudStyleChecks or {}) do check.refresh() end

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


makeHUDStyleChoice = function(parent, label, x, y, style)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetSize(24, 24)

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(label)

    check.label = text
    check.refresh = function()
        local available = RB.HUD and type(RB.HUD.GetStyle) == "function" and type(RB.HUD.SetStyle) == "function"
        check:SetEnabled(available)
        local selected = available and RB.HUD:GetStyle() == style
        check:SetChecked(selected == true)
        if selected then
            local r, g, b = RB:GetAccentColor()
            text:SetTextColor(r, g, b)
        else
            text:SetTextColor(available and 1 or 0.45, available and 0.82 or 0.45, available and 0.35 or 0.45)
        end
    end

    check:SetScript("OnClick", function(self)
        if not (RB.HUD and type(RB.HUD.SetStyle) == "function") then
            self:SetChecked(false)
            return
        end
        RB.HUD:SetStyle(style)
        if Config.frame then Config:Refresh() end
        if Config.settingsPanel then Config:RefreshSettingsPanel() end
    end)

    return check
end

local function makeSettingsCheck(parent, label, y, checkedFunc, setFunc, enabledFunc, x)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 26, y)
    check:SetSize(26, 26)

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 5, 0)
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
        if Config.frame then Config:Refresh() end
        Config:RefreshSettingsPanel()
    end)

    return check
end

function Config:CreateSettingsPanel()
    if self.settingsPanel then return self.settingsPanel end

    local panel = CreateFrame("Frame", "RapzoQoLBlizzardSettingsPanel")
    panel.name = "Rapzo QoL"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -18)
    title:SetText("Rapzo QoL")

    local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    intro:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Configura Rapzo QoL directamente desde Opciones > AddOns. Los cambios se aplican al instante.")

    local appearance = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearance:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -24)
    appearance:SetText("Apariencia")

    local swatch = CreateFrame("Button", nil, panel, "BackdropTemplate")
    swatch:SetPoint("TOPLEFT", appearance, "BOTTOMLEFT", 2, -10)
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
    panel.accentSwatch = swatch

    local hexText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hexText:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
    panel.accentHexText = hexText

    local choose = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    choose:SetSize(120, 24)
    choose:SetPoint("LEFT", hexText, "RIGHT", 14, 0)
    choose:SetText("Elegir color")
    choose:SetScript("OnClick", openAccentPicker)

    local resetAccent = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAccent:SetSize(105, 24)
    resetAccent:SetPoint("LEFT", choose, "RIGHT", 8, 0)
    resetAccent:SetText("Restablecer")
    resetAccent:SetScript("OnClick", function()
        RB:ResetAccentColor(true)
        if Config.frame then Config:Refresh() end
        Config:RefreshSettingsPanel()
    end)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -142)
    divider:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    divider:SetColorTexture(0.45, 0.55, 0.65, 0.35)

    local modulesTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modulesTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -164)
    modulesTitle:SetText("Modulos")

    panel.settingsChecks = {}
    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Tooltip avanzado", -192,
        function() return RB:IsFeatureEnabled("tooltip") end,
        function(v) RB:SetFeatureEnabled("tooltip", v, true); local db=RB:EnsureDB(); db.settings.tooltip=v end,
        function() return RB:IsModulePresent("tooltip") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Expansion del objeto", -224,
        function() return RB:EnsureDB().settings.showItemExpansion ~= false end,
        function(v) RB:EnsureDB().settings.showItemExpansion=v end,
        function() return RB:IsModulePresent("tooltip") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Tipo + Item ID", -256,
        function() local s=RB:EnsureDB().settings; return s.showItemType ~= false and s.showItemID ~= false end,
        function(v) local s=RB:EnsureDB().settings; s.showItemType=v; s.showItemID=v end,
        function() return RB:IsModulePresent("tooltip") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Buscador global", -288,
        function() return RB:IsFeatureEnabled("search") end,
        function(v) RB:SetFeatureEnabled("search", v, true) end,
        function() return RB:IsModulePresent("search") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Coleccionables (obtenido/no obtenido)", -320,
        function() return RB:IsFeatureEnabled("collections") end,
        function(v) RB:SetFeatureEnabled("collections", v, true); if RB.Collections and RB.Collections.ClearCache then RB.Collections:ClearCache() end end,
        function() return RB:IsModulePresent("collections") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Vendedor extendido", -352,
        function() local db=RB:EnsureDB(); return db.settings.vendor and db.settings.vendor.enabled ~= false end,
        function(v) if RB.Vendor and RB.Vendor.SetEnabled then RB.Vendor:SetEnabled(v) else RB:SetFeatureEnabled("vendor",v,true) end end,
        function() return RB:IsModulePresent("vendor") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Pantalla AFK", -384,
        function() return RB:IsFeatureEnabled("afk") end,
        function(v)
            if RB.AFK and RB.AFK.SetEnabled then RB.AFK:SetEnabled(v) else RB:SetFeatureEnabled("afk", v, true) end
        end,
        function() return RB:IsModulePresent("afk") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "HUD visual", -416,
        function() return RB:IsFeatureEnabled("hud") end,
        function(v)
            if RB.HUD and RB.HUD.SetEnabled then RB.HUD:SetEnabled(v) else RB:SetFeatureEnabled("hud", v, true) end
        end,
        function() return RB:IsModulePresent("hud") end)

    panel.settingsChecks[#panel.settingsChecks + 1] = makeSettingsCheck(panel, "Aro del mouse", -416,
        isCursorRingEnabled,
        setCursorRingEnabled,
        function() return RB:IsModulePresent("hud") end,
        250)

    local hudStyleTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hudStyleTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -452)
    hudStyleTitle:SetText("Estilo de Unit Frames")

    panel.hudStyleChecks = {
        makeHUDStyleChoice(panel, "V1 - Clásico", 26, -472, 1),
        makeHUDStyleChoice(panel, "V2 - ToxiUI", 210, -472, 2),
    }

    local divider2 = panel:CreateTexture(nil, "ARTWORK")
    divider2:SetHeight(1)
    divider2:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -514)
    divider2:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    divider2:SetColorTexture(0.45, 0.55, 0.65, 0.35)

    local statusTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -536)
    statusTitle:SetText("Estado")

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 2, -8)
    status:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    status:SetJustifyH("LEFT")
    panel.statusText = status

    local hudPreview = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    hudPreview:SetSize(185, 26)
    hudPreview:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -584)
    hudPreview:SetText("Preview / depurar HUD")
    hudPreview:SetScript("OnClick", function()
        if RB.HUD and type(RB.HUD.ShowPreview) == "function" then
            RB.HUD:ShowPreview()
        else
            RB:Print("El preview del HUD no está disponible.")
        end
    end)

    local rescan = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    rescan:SetSize(150, 26)
    rescan:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -618)
    rescan:SetText("Reescanear ahora")
    rescan:SetScript("OnClick", function()
        if RB.Scanner then
            RB.Scanner:ScanAll(RB.Scanner.bankOpen)
            RB:Print("Escaneo actualizado.")
        end
        Config:RefreshSettingsPanel()
    end)

    local fullPanel = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    fullPanel:SetSize(185, 26)
    fullPanel:SetPoint("LEFT", rescan, "RIGHT", 10, 0)
    fullPanel:SetText("Abrir panel completo")
    fullPanel:SetScript("OnClick", function()
        Config:Show()
    end)

    panel:SetScript("OnShow", function()
        Config:RefreshSettingsPanel()
    end)

    self.settingsPanel = panel
    return panel
end

function Config:RefreshSettingsPanel()
    local panel = self.settingsPanel
    if not panel then return end

    for _, check in ipairs(panel.settingsChecks or {}) do
        check.refresh()
    end
    for _, check in ipairs(panel.hudStyleChecks or {}) do
        check.refresh()
    end

    if type(RB.GetAccentColor) == "function" then
        local r, g, b = RB:GetAccentColor()
        if panel.accentSwatch and panel.accentSwatch.fill then
            panel.accentSwatch.fill:SetColorTexture(r, g, b, 1)
        end
        if panel.accentHexText then
            panel.accentHexText:SetText("#" .. RB:ColorToHex(r, g, b))
            panel.accentHexText:SetTextColor(r, g, b)
        end
    end

    if panel.statusText then
        local enabled, total = 0, 0
        for _, key in ipairs({"tooltip", "search", "vendor", "collections", "afk", "hud"}) do
            if RB:IsModulePresent(key) then
                total = total + 1
                if RB:IsFeatureEnabled(key) then enabled = enabled + 1 end
            end
        end
        panel.statusText:SetText(string.format(
            "%d/%d modulos activos.  /rapzo modules muestra el detalle completo en el chat.",
            enabled,
            total
        ))
    end
end

function Config:RegisterBlizzardSettings()
    if self.settingsCategory then return true end

    local panel = self:CreateSettingsPanel()

    if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function" then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Rapzo QoL")
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category

        if category and type(category.GetID) == "function" then
            self.settingsCategoryID = category:GetID()
        end

        return true
    end

    if type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
        self.settingsCategory = panel
        return true
    end

    return false
end

function Config:OpenBlizzardSettings()
    self:RegisterBlizzardSettings()

    if Settings and type(Settings.OpenToCategory) == "function" and self.settingsCategoryID then
        Settings.OpenToCategory(self.settingsCategoryID)
        return
    end

    if type(InterfaceOptionsFrame_OpenToCategory) == "function" and self.settingsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        return
    end

    self:Show()
end

local settingsLoader = CreateFrame("Frame")
settingsLoader:RegisterEvent("PLAYER_LOGIN")
settingsLoader:SetScript("OnEvent", function()
    Config:RegisterBlizzardSettings()
    settingsLoader:UnregisterAllEvents()
end)

Config:RegisterBlizzardSettings()

RB:RegisterCommand("config", function() Config:OpenBlizzardSettings() end, "/rapzo config - abre Opciones > AddOns > Rapzo QoL")
RB:RegisterCommand("options", function() Config:OpenBlizzardSettings() end)

