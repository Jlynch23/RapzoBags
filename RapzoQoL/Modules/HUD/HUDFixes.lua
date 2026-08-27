local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local Fixes = {}
HUD.Fixes = Fixes

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function hidePlayerStatusTexture()
    local frame = _G.PlayerFrame
    local content = frame and frame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    if main and main.StatusTexture then
        safeCall(main.StatusTexture.SetAlpha, main.StatusTexture, 0)
    end
end

local function ensureRestIndicator()
    local display = HUD.unitDisplays and HUD.unitDisplays.player
    if not display then return nil end

    if display.RapzoQoLRestText then
        return display.RapzoQoLRestText
    end

    local text = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPRIGHT", display, "TOPRIGHT", -48, -7)
    text:SetText("zzz")
    text:SetTextColor(1.00, 0.82, 0.15)
    text:Hide()
    display.RapzoQoLRestText = text
    return text
end

local function updateRestIndicator()
    hidePlayerStatusTexture()

    local text = ensureRestIndicator()
    if not text then return end

    local resting = false
    if type(IsResting) == "function" then
        local ok, value = pcall(IsResting)
        if ok and not isSecret(value) then
            resting = value == true
        end
    end

    text:SetShown(resting)
end

local function anchorDisplay(unit)
    local display = HUD.unitDisplays and HUD.unitDisplays[unit]
    if not display then return end

    local nativeFrame
    if unit == "player" then
        nativeFrame = _G.PlayerFrame
    elseif unit == "target" then
        nativeFrame = _G.TargetFrame
    elseif unit == "focus" then
        nativeFrame = _G.FocusFrame
    end

    if not nativeFrame then return end

    display:ClearAllPoints()
    display:SetPoint("TOPLEFT", nativeFrame, "TOPLEFT", -2, -18)
end

local function applyAnchors()
    anchorDisplay("player")
    anchorDisplay("target")
    anchorDisplay("focus")
end

local function applyAll()
    hidePlayerStatusTexture()
    applyAnchors()
    updateRestIndicator()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, applyAll)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, applyAll)
            C_Timer.After(2.0, applyAll)
        end
    else
        applyAll()
    end
end)

if type(hooksecurefunc) == "function" then
    if type(PlayerFrame_UpdateStatus) == "function" then
        hooksecurefunc("PlayerFrame_UpdateStatus", function()
            hidePlayerStatusTexture()
            updateRestIndicator()
        end)
    end

    if type(HUD.CreateUnitDisplays) == "function" then
        hooksecurefunc(HUD, "CreateUnitDisplays", function()
            applyAll()
        end)
    end

    if type(HUD.UpdateUnitFrames) == "function" then
        hooksecurefunc(HUD, "UpdateUnitFrames", function()
            applyAnchors()
            updateRestIndicator()
        end)
    end
end

if C_Timer and C_Timer.After then
    C_Timer.After(0.5, applyAll)
    C_Timer.After(2.0, applyAll)
else
    applyAll()
end
