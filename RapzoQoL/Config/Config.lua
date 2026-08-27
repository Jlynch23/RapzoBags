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

function Config:CreateFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "RapzoQoLConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(520, 610)
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

    frame.checks = {}
    frame.checks[#frame.checks+1] = makeCheck(frame, "Tooltip avanzado", -270,
        function() return RB:IsFeatureEnabled("tooltip") end,
        function(v) RB:SetFeatureEnabled("tooltip", v, true); local db=RB:EnsureDB(); db.settings.tooltip=v end,
        function() return RB:IsModulePresent("tooltip") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Expansion del objeto", -302,
        function() return RB:EnsureDB().settings.showItemExpansion ~= false end,
        function(v) RB:EnsureDB().settings.showItemExpansion=v end,
        function() return RB:IsModulePresent("tooltip") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Tipo + Item ID", -334,
        function() local s=RB:EnsureDB().settings; return s.showItemType ~= false and s.showItemID ~= false end,
        function(v) local s=RB:EnsureDB().settings; s.showItemType=v; s.showItemID=v end,
        function() return RB:IsModulePresent("tooltip") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Buscador global", -366,
        function() return RB:IsFeatureEnabled("search") end,
        function(v) RB:SetFeatureEnabled("search", v, true) end,
        function() return RB:IsModulePresent("search") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Coleccionables (obtenido/no obtenido)", -398,
        function() return RB:IsFeatureEnabled("collections") end,
        function(v) RB:SetFeatureEnabled("collections", v, true); if RB.Collections and RB.Collections.ClearCache then RB.Collections:ClearCache() end end,
        function() return RB:IsModulePresent("collections") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Vendedor extendido", -430,
        function() local db=RB:EnsureDB(); return db.settings.vendor and db.settings.vendor.enabled ~= false end,
        function(v) if RB.Vendor and RB.Vendor.SetEnabled then RB.Vendor:SetEnabled(v) else RB:SetFeatureEnabled("vendor",v,true) end end,
        function() return RB:IsModulePresent("vendor") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "Pantalla AFK", -462,
        function() return RB:IsFeatureEnabled("afk") end,
        function(v)
            if RB.AFK and RB.AFK.SetEnabled then
                RB.AFK:SetEnabled(v)
            else
                RB:SetFeatureEnabled("afk", v, true)
            end
        end,
        function() return RB:IsModulePresent("afk") end)
    frame.checks[#frame.checks+1] = makeCheck(frame, "HUD visual (cursor + minimapa + unit frames)", -494,
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
    reset:SetSize(150, 26); reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18); reset:SetText("Reescanear ahora")
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
end

function Config:Show()
    if not RB:IsFeatureEnabled("config") then RB:Print("Modulo Config desactivado."); return end
    local frame = self:CreateFrame(); self:Refresh(); frame:Show(); frame:Raise()
end

RB:RegisterCommand("config", function() Config:Show() end, "/rapzo config - abre el panel modular")
RB:RegisterCommand("options", function() Config:Show() end)
