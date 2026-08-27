local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local anchoring = false

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function nativeFrameFor(unit)
    if unit == "target" then return _G.TargetFrame end
    if unit == "focus" then return _G.FocusFrame end
end

local function anchorAuraContainer(unit)
    if anchoring then return end

    local display = HUD.unitDisplays and HUD.unitDisplays[unit]
    local nativeFrame = nativeFrameFor(unit)
    if not display or not nativeFrame or type(nativeFrame.GetAuraContainer) ~= "function" then
        return
    end

    local ok, auraContainer = pcall(nativeFrame.GetAuraContainer, nativeFrame)
    if not ok or not auraContainer then return end

    anchoring = true

    -- Blizzard owns aura creation/filtering. Rapzo QoL only changes the visual
    -- anchor so the first aura starts directly above our custom Target/Focus bar.
    safeCall(auraContainer.ClearAllPoints, auraContainer)
    safeCall(auraContainer.SetPoint, auraContainer, "BOTTOMLEFT", display, "TOPLEFT", 0, 6)

    -- Match the useful width of our custom unit frame so FlowContainer wraps
    -- auras relative to the frame the player actually sees.
    if type(auraContainer.SetWidth) == "function" then
        safeCall(auraContainer.SetWidth, auraContainer, display:GetWidth())
    end

    anchoring = false
end

local function anchorAllAuras()
    anchorAuraContainer("target")
    anchorAuraContainer("focus")
end

local function schedule(unit)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if unit then
                anchorAuraContainer(unit)
            else
                anchorAllAuras()
            end
        end)
    elseif unit then
        anchorAuraContainer(unit)
    else
        anchorAllAuras()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        schedule("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        schedule("focus")
    else
        schedule()
    end

    if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
        C_Timer.After(0.5, anchorAllAuras)
        C_Timer.After(2.0, anchorAllAuras)
    end
end)

if type(hooksecurefunc) == "function" and type(TargetFrameMixin) == "table" then
    if type(TargetFrameMixin.UpdateAuras) == "function" then
        hooksecurefunc(TargetFrameMixin, "UpdateAuras", function(frame)
            if frame == _G.TargetFrame then
                schedule("target")
            elseif frame == _G.FocusFrame then
                schedule("focus")
            end
        end)
    end

    if type(HUD.CreateUnitDisplays) == "function" then
        hooksecurefunc(HUD, "CreateUnitDisplays", function()
            schedule()
        end)
    end
end

schedule()
