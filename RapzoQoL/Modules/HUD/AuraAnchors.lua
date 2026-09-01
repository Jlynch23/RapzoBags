local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local anchoring = false
local pendingSync = false

-- Native Target/Focus aura containers belong to Blizzard (and may also be
-- managed by mUI). When Rapzo's visual HUD or unit frames are disabled, this
-- module must become a true no-op so Edit Mode cannot inherit addon taint.
-- The containers are protected children of TargetFrame/FocusFrame, so every
-- mutation is additionally gated on InCombatLockdown and, when Rapzo changed
-- one, the original anchors/width/shown state are kept so disabling the
-- feature restores Blizzard's layout without a /reload.
local containerState = setmetatable({}, { __mode = "k" })

local function hudFramesActive()
    if type(HUD.IsEnabled) == "function" and not HUD:IsEnabled() then
        return false
    end

    local cfg = HUD.config
    if cfg and cfg.unitFrames == false then
        return false
    end

    return true
end

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function nativeFrameFor(unit)
    if unit == "target" then return _G.TargetFrame end
    if unit == "focus" then return _G.FocusFrame end
end

local function getAuraContainer(unit)
    local nativeFrame = nativeFrameFor(unit)
    if not nativeFrame or type(nativeFrame.GetAuraContainer) ~= "function" then
        return nil
    end
    local ok, auraContainer = pcall(nativeFrame.GetAuraContainer, nativeFrame)
    if not ok then return nil end
    return auraContainer
end

local function auraOffset(unit)
    if type(HUD.GetStyleAuraOffset) == "function" then
        return tonumber(HUD:GetStyleAuraOffset(unit)) or 0
    end
    return 0
end

local function auraRightInset(unit)
    if type(HUD.GetStyleAuraRightInset) == "function" then
        return tonumber(HUD:GetStyleAuraRightInset(unit)) or 0
    end
    return 0
end

local function captureContainerState(container)
    local state = containerState[container]
    if state then return state end

    state = { points = {}, modified = false }

    local okShown, shown = pcall(container.IsShown, container)
    state.shown = okShown and shown == true

    if type(container.GetWidth) == "function" then
        local ok, width = pcall(container.GetWidth, container)
        if ok and type(width) == "number" then state.width = width end
    end

    if type(container.GetNumPoints) == "function" and type(container.GetPoint) == "function" then
        local okNum, num = pcall(container.GetNumPoints, container)
        if okNum and type(num) == "number" then
            for i = 1, num do
                local okPoint, point, relativeTo, relativePoint, x, y = pcall(container.GetPoint, container, i)
                if okPoint and point then
                    state.points[#state.points + 1] = { point, relativeTo, relativePoint, x, y }
                end
            end
        end
    end

    containerState[container] = state
    return state
end

local function restoreContainer(container)
    local state = containerState[container]
    if not state or not state.modified then return end

    state.modified = false
    if #state.points > 0 then
        safeCall(container.ClearAllPoints, container)
        for _, point in ipairs(state.points) do
            safeCall(container.SetPoint, container, point[1], point[2], point[3], point[4], point[5])
        end
    end
    if state.width then
        safeCall(container.SetWidth, container, state.width)
    end
    if state.shown then
        safeCall(container.Show, container)
    else
        safeCall(container.Hide, container)
    end
end

local function syncAuraContainer(unit)
    if anchoring then return end

    local container = getAuraContainer(unit)
    if not container then return end

    if not hudFramesActive() then
        -- Only touch Blizzard's container if Rapzo modified it earlier.
        local state = containerState[container]
        if not state or not state.modified then return end
        if inCombat() then
            pendingSync = true
            return
        end
        anchoring = true
        restoreContainer(container)
        anchoring = false
        return
    end

    local display = HUD.unitDisplays and HUD.unitDisplays[unit]
    if not display then return end

    if inCombat() then
        pendingSync = true
        return
    end

    anchoring = true
    local state = captureContainerState(container)

    -- Style 2 uses Rapzo QoL-managed AuraContainers:
    -- Player = short HELPFUL combat buffs.
    -- Target/Focus = HARMFUL|PLAYER only.
    -- Hide Blizzard's mixed native target aura strip so it cannot duplicate them.
    if type(HUD.GetStyle) == "function" and HUD:GetStyle() == 2 then
        state.modified = true
        safeCall(container.Hide, container)
        anchoring = false
        return
    end

    -- Style 1 keeps Blizzard's native aura container behavior, repositioned
    -- above the Rapzo display. Anchor through UIParent absolute coordinates so
    -- the protected container never joins Rapzo's insecure anchor family.
    local left, top = display:GetLeft(), display:GetTop()
    if left and top and _G.UIParent then
        local x = auraOffset(unit)
        local rightInset = auraRightInset(unit)

        local displayScale = display:GetEffectiveScale() or 1
        local containerScale = 1
        if type(container.GetEffectiveScale) == "function" then
            local ok, value = pcall(container.GetEffectiveScale, container)
            if ok and type(value) == "number" and value > 0 then containerScale = value end
        end
        local ratio = displayScale / containerScale

        state.modified = true
        safeCall(container.Show, container)
        safeCall(container.ClearAllPoints, container)
        safeCall(container.SetPoint, container, "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", left * ratio + x, top * ratio + 10)

        if type(container.SetWidth) == "function" then
            local width = math.max(40, (display:GetWidth() or 240) - x - rightInset)
            safeCall(container.SetWidth, container, width)
        end
    end

    anchoring = false
end

local function anchorAllAuras()
    syncAuraContainer("target")
    syncAuraContainer("focus")
end

HUD.ReanchorAuras = anchorAllAuras
HUD.ScheduleAuraAnchors = function(_, unit)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if unit then
                syncAuraContainer(unit)
            else
                anchorAllAuras()
            end
        end)
    elseif unit then
        syncAuraContainer(unit)
    else
        anchorAllAuras()
    end
end

local function schedule(unit)
    HUD:ScheduleAuraAnchors(unit)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Flush anchor/restore work skipped during combat lockdown.
        if pendingSync then
            pendingSync = false
            schedule()
        end
        return
    end

    if not hudFramesActive() then return end

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

if type(hooksecurefunc) == "function" then
    if type(TargetFrameMixin) == "table" and type(TargetFrameMixin.UpdateAuras) == "function" then
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

    -- Restore (or re-anchor) immediately when the unit-frame toggle changes;
    -- SetEnabled delegates to SetPart("frames"), so this covers both.
    if type(HUD.SetPart) == "function" then
        hooksecurefunc(HUD, "SetPart", function(_, part)
            if part == "frames" then schedule() end
        end)
    end
end

schedule()
