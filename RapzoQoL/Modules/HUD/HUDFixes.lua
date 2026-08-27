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


local function addUniqueFrame(list, seen, frame)
    if not frame or seen[frame] then return end
    seen[frame] = true
    list[#list + 1] = frame
end

local function getNativeUnitCastBars()
    local list, seen = {}, {}

    -- Player cast bars from Blizzard's UI.
    addUniqueFrame(list, seen, _G.PlayerCastingBarFrame)
    addUniqueFrame(list, seen, _G.OverlayPlayerCastingBarFrame)

    -- Target/focus globals used by Blizzard's unit frames.
    addUniqueFrame(list, seen, _G.TargetFrameSpellBar)
    addUniqueFrame(list, seen, _G.FocusFrameSpellBar)

    -- Also support parent-key variants used by newer FrameXML layouts.
    local targetFrame = _G.TargetFrame
    if targetFrame then
        addUniqueFrame(list, seen, targetFrame.spellbar)
        addUniqueFrame(list, seen, targetFrame.SpellBar)
        addUniqueFrame(list, seen, targetFrame.castBar)
        addUniqueFrame(list, seen, targetFrame.CastBar)
    end

    local focusFrame = _G.FocusFrame
    if focusFrame then
        addUniqueFrame(list, seen, focusFrame.spellbar)
        addUniqueFrame(list, seen, focusFrame.SpellBar)
        addUniqueFrame(list, seen, focusFrame.castBar)
        addUniqueFrame(list, seen, focusFrame.CastBar)
    end

    return list
end

local function hideNativeUnitCastBars()
    -- Do not touch nameplate cast bars. Only suppress Blizzard's
    -- player/target/focus cast bars because Rapzo QoL renders its own.
    for _, bar in ipairs(getNativeUnitCastBars()) do
        if type(bar.SetAlpha) == "function" then
            safeCall(bar.SetAlpha, bar, 0)
        end
        if type(bar.EnableMouse) == "function" then
            safeCall(bar.EnableMouse, bar, false)
        end
    end
end

HUD.HideNativeUnitCastBars = hideNativeUnitCastBars

local function hidePlayerNativeRestArt()
    local frame = _G.PlayerFrame
    local content = frame and frame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local contextual = content and content.PlayerFrameContentContextual

    -- Yellow flashing status art shown while resting/in combat.
    if main and main.StatusTexture then
        safeCall(main.StatusTexture.Hide, main.StatusTexture)
        safeCall(main.StatusTexture.SetAlpha, main.StatusTexture, 0)
    end

    -- This is the large animated yellow ring seen after the portrait was removed.
    -- Blizzard calls PlayerFrame_UpdatePlayerRestLoop(true) while resting, so
    -- explicitly stop and hide both the animation frame and its texture.
    local restLoop = contextual and contextual.PlayerRestLoop
    if restLoop then
        if restLoop.PlayerRestLoopAnim then
            safeCall(restLoop.PlayerRestLoopAnim.Stop, restLoop.PlayerRestLoopAnim)
        end
        if restLoop.RestTexture then
            safeCall(restLoop.RestTexture.SetAlpha, restLoop.RestTexture, 0)
        end
        safeCall(restLoop.Hide, restLoop)
        safeCall(restLoop.SetAlpha, restLoop, 0)
    end

    -- These belong to Blizzard's portrait treatment and look detached once the
    -- portrait is hidden. Rapzo QoL uses its own tiny "zzz" indicator instead.
    if contextual then
        if contextual.AttackIcon then safeCall(contextual.AttackIcon.SetAlpha, contextual.AttackIcon, 0) end
        if contextual.PlayerPortraitCornerIcon then
            safeCall(contextual.PlayerPortraitCornerIcon.SetAlpha, contextual.PlayerPortraitCornerIcon, 0)
        end
    end
end

local function ensureRestIndicator()
    local display = HUD.unitDisplays and HUD.unitDisplays.player
    if not display then return nil end

    if display.RapzoQoLRestText then
        return display.RapzoQoLRestText
    end

    local text = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetText("zzz")
    text:SetTextColor(1.00, 0.82, 0.15)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    if STANDARD_TEXT_FONT then
        pcall(text.SetFont, text, STANDARD_TEXT_FONT, 11, "OUTLINE")
    end
    text:Hide()
    display.RapzoQoLRestText = text
    return text
end

local function updateRestIndicator()
    hidePlayerNativeRestArt()

    local text = ensureRestIndicator()
    if not text then return end

    text:ClearAllPoints()
    local display = HUD.unitDisplays and HUD.unitDisplays.player
    if display and type(HUD.GetStyle) == "function" and HUD:GetStyle() == 2 and display.health then
        text:SetPoint("BOTTOMRIGHT", display.health, "TOPRIGHT", -2, 3)
    elseif display then
        text:SetPoint("TOPRIGHT", display, "TOPRIGHT", -48, -7)
    end

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
    hidePlayerNativeRestArt()
    hideNativeUnitCastBars()
    applyAnchors()
    updateRestIndicator()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UNIT_SPELLCAST_START")
events:RegisterEvent("UNIT_SPELLCAST_STOP")
events:RegisterEvent("UNIT_SPELLCAST_FAILED")
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
events:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
events:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")

events:SetScript("OnEvent", function(_, event, unit)
    if event:find("^UNIT_SPELLCAST") and unit ~= "player" and unit ~= "target" and unit ~= "focus" then
        return
    end

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
            hidePlayerNativeRestArt()
            updateRestIndicator()
        end)
    end

    if type(PlayerFrame_UpdatePlayerRestLoop) == "function" then
        hooksecurefunc("PlayerFrame_UpdatePlayerRestLoop", function()
            hidePlayerNativeRestArt()
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

    if type(HUD.ApplyFrameStyle) == "function" then
        hooksecurefunc(HUD, "ApplyFrameStyle", function(_, unit)
            hideNativeUnitCastBars()
            if unit == nil or unit == "player" then
                updateRestIndicator()
            end
        end)
    end

    if type(HUD.Apply) == "function" then
        hooksecurefunc(HUD, "Apply", function()
            hideNativeUnitCastBars()
        end)
    end
end

if C_Timer and C_Timer.After then
    C_Timer.After(0.5, applyAll)
    C_Timer.After(2.0, applyAll)
else
    applyAll()
end
