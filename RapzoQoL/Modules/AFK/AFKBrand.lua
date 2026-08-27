local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.AFK then return end

local AFK = RB.AFK

local function applyBrand()
    local frame = AFK.frame
    if not frame or frame.RapzoQoLBrandApplied then return end
    frame.RapzoQoLBrandApplied = true

    if frame.logo then
        frame.logo:Hide()
    end

    local card = frame.card
    if not card then return end

    local badge = CreateFrame("Frame", nil, card, "BackdropTemplate")
    badge:SetPoint("TOP", card, "TOP", 0, -40)
    badge:SetSize(92, 92)
    badge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    badge:SetBackdropColor(0.005, 0.012, 0.020, 0.96)
    badge:SetBackdropBorderColor(0.12, 0.82, 1.00, 0.90)

    local mark = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    mark:SetPoint("CENTER", badge, "CENTER", 0, 1)
    local fontPath = STANDARD_TEXT_FONT
    if fontPath then
        pcall(mark.SetFont, mark, fontPath, 36, "OUTLINE")
    end
    mark:SetText("RQ")
    mark:SetTextColor(0.16, 0.84, 1.00)

    frame.RapzoQoLBadge = badge
    frame.RapzoQoLMark = mark

    if frame.title then
        frame.title:ClearAllPoints()
        frame.title:SetPoint("TOP", badge, "BOTTOM", 0, -12)
        frame.title:SetText("|cff38bdf8RAPZO|r |cffffffffQoL|r")
    end

    if frame.quote then
        frame.quote:SetText("Quality of life, the Rapzo way.")
    end
end

local function refreshFooter()
    local frame = AFK.frame
    if not frame or not frame.footer then return end

    local current = frame.footer:GetText()
    if type(current) == "string" and current ~= "" then
        current = current:gsub("RapzoBags", "Rapzo QoL")
        frame.footer:SetText(current)
    end
end

if type(hooksecurefunc) == "function" then
    hooksecurefunc(AFK, "CreateFrame", function()
        applyBrand()
    end)

    hooksecurefunc(AFK, "UpdateDisplay", function()
        applyBrand()
        refreshFooter()
    end)
end

if AFK.frame then
    applyBrand()
    refreshFooter()
end
