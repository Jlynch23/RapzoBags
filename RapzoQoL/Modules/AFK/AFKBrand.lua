local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.AFK then return end

local AFK = RB.AFK

local function applyBrand()
    local frame = AFK.frame
    if not frame then return end

    -- Brand layer only. Do not add a badge, logo box or extra frame:
    -- the AFK screen is intentionally minimal and uses text hierarchy only.
    if frame.logo then
        frame.logo:Hide()
    end

    if frame.RapzoQoLBadge then
        frame.RapzoQoLBadge:Hide()
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
