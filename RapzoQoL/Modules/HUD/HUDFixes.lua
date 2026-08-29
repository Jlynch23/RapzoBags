local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local Fixes = {}
HUD.Fixes = Fixes
local nativeCastBarState = setmetatable({}, {__mode = "k"})

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function hudFramesActive()
    if type(HUD.IsEnabled) == "function" and not HUD:IsEnabled() then
        return false
    end

    local cfg = HUD.config
    return not cfg or cfg.unitFrames ~= false
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

local function shouldHideNativeUnitCastBars()
    return hudFramesActive()
        and type(HUD.GetStyle) == "function"
        and HUD:GetStyle() == 2
end

local function restoreNativeUnitCastBars()
    -- If Rapzo previously hid a Blizzard cast bar, restore it exactly once.
    -- With HUD/frames already OFF and no Rapzo state recorded this function is
    -- a no-op and, importantly, never touches TargetFrameSpellBar/FocusFrameSpellBar.
    for bar, state in pairs(nativeCastBarState) do
        if state and state.modified then
            if type(bar.SetAlpha) == "function" and state.alpha ~= nil then
                safeCall(bar.SetAlpha, bar, state.alpha)
            end
            if type(bar.EnableMouse) == "function" and state.mouseEnabled ~= nil then
                safeCall(bar.EnableMouse, bar, state.mouseEnabled == true)
            end
            state.modified = false
        end
    end
end

local function syncNativeUnitCastBars()
    -- V2 renders its own player/target/focus cast bars. Outside active V2 we
    -- only restore bars that Rapzo itself changed; otherwise do not mutate
    -- Blizzard/mUI cast bars at all.
    local hide = shouldHideNativeUnitCastBars()
    if not hide then
        restoreNativeUnitCastBars()
        return
    end

    for _, bar in ipairs(getNativeUnitCastBars()) do
        local state = nativeCastBarState[bar]
        if not state then
            state = {}
            nativeCastBarState[bar] = state
        end
        if state.alpha == nil and type(bar.GetAlpha) == "function" then
            local ok, alpha = pcall(bar.GetAlpha, bar)
            if ok then state.alpha = alpha end
        end
        if state.mouseEnabled == nil and type(bar.IsMouseEnabled) == "function" then
            local ok, enabled = pcall(bar.IsMouseEnabled, bar)
            if ok then state.mouseEnabled = enabled and true or false end
        end
        if not state.onShowHooked and type(bar.HookScript) == "function" then
            state.onShowHooked = true
            safeCall(bar.HookScript, bar, "OnShow", function()
                -- Only reconcile while Rapzo V2 is actively owning the visual
                -- castbar state. Once disabled/restored, this hook becomes inert.
                if not shouldHideNativeUnitCastBars() then return end
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0, syncNativeUnitCastBars)
                else
                    syncNativeUnitCastBars()
                end
            end)
        end

        state.modified = true
        if type(bar.SetAlpha) == "function" then
            safeCall(bar.SetAlpha, bar, 0)
        end
        if type(bar.EnableMouse) == "function" then
            safeCall(bar.EnableMouse, bar, false)
        end
    end
end

HUD.SyncNativeUnitCastBars = syncNativeUnitCastBars
-- Compatibility for any external caller from an earlier alpha. The function
-- now synchronizes instead of hiding unconditionally.
HUD.HideNativeUnitCastBars = syncNativeUnitCastBars

local function hidePlayerNativeRestArt()
    if not hudFramesActive() then return end

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
    if not hudFramesActive() then
        local display = HUD.unitDisplays and HUD.unitDisplays.player
        if display and display.RapzoQoLRestText then
            display.RapzoQoLRestText:Hide()
        end
        return
    end

    hidePlayerNativeRestArt()

    local text = ensureRestIndicator()
    if not text then return end

    text:ClearAllPoints()
    local display = HUD.unitDisplays and HUD.unitDisplays.player
    if display and type(HUD.GetStyle) == "function" and HUD:GetStyle() == 2
        and display.levelText and display.health then
        -- Toxi layout: rest state precedes the level on the same baseline
        -- instead of replacing/overlapping it in the upper-right corner.
        text:SetPoint("RIGHT", display.levelText, "LEFT", -4, 0)
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
    if unit ~= "player" and type(HUD.GetStyle) == "function" and HUD:GetStyle() == 1 then
        -- Preserve the mirrored target/focus placement of the classic style.
        display:SetPoint("TOPRIGHT", nativeFrame, "TOPRIGHT", 2, -18)
    else
        display:SetPoint("TOPLEFT", nativeFrame, "TOPLEFT", -2, -18)
    end
end

local function applyAnchors()
    if not hudFramesActive() then return end
    anchorDisplay("player")
    anchorDisplay("target")
    anchorDisplay("focus")
end

local function applyAll()
    if not hudFramesActive() then
        restoreNativeUnitCastBars()
        updateRestIndicator()
        return
    end

    hidePlayerNativeRestArt()
    syncNativeUnitCastBars()
    applyAnchors()
    updateRestIndicator()
end

HUD.ApplyStyleFixes = applyAll

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
            if not hudFramesActive() then return end
            hidePlayerNativeRestArt()
            updateRestIndicator()
        end)
    end

    if type(PlayerFrame_UpdatePlayerRestLoop) == "function" then
        hooksecurefunc("PlayerFrame_UpdatePlayerRestLoop", function()
            if not hudFramesActive() then return end
            hidePlayerNativeRestArt()
        end)
    end

    if type(HUD.CreateUnitDisplays) == "function" then
        hooksecurefunc(HUD, "CreateUnitDisplays", function()
            applyAll()
        end)
    end

    if type(HUD.Apply) == "function" then
        hooksecurefunc(HUD, "Apply", function()
            syncNativeUnitCastBars()
        end)
    end

    if type(HUD.SetEnabled) == "function" then
        hooksecurefunc(HUD, "SetEnabled", syncNativeUnitCastBars)
    end

    if type(HUD.SetPart) == "function" then
        hooksecurefunc(HUD, "SetPart", function(_, part)
            if part == "frames" then syncNativeUnitCastBars() end
        end)
    end
end

if C_Timer and C_Timer.After then
    C_Timer.After(0.5, applyAll)
    C_Timer.After(2.0, applyAll)
else
    applyAll()
end
