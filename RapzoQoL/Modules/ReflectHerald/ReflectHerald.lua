local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

-- ReflectHerald: anuncia el hechizo devuelto por Spell Reflection.
-- Nota Midnight: el combat log esta restringido para addons en bosses y M+.
-- Donde la API lo permite, canta; donde no, silencio elegante (sin errores).
local ReflectHerald = {}
RB.ReflectHerald = ReflectHerald
RB:RegisterModule("reflectHerald", ReflectHerald)

local frame = CreateFrame("Frame")
local playerGUID
local sessionReflects = {}   -- [spellName] = count
local sessionTotal = 0
local combatLogAvailable = false

local function getSettings()
    local db = RB:EnsureDB()
    if type(db.settings.reflectHerald) ~= "table" then
        db.settings.reflectHerald = {}
    end
    local settings = db.settings.reflectHerald
    if settings.party == nil then settings.party = true end
    return settings
end

local function announce(spellName, srcName)
    local line = ("Reflejado: %s%s"):format(spellName or "?", srcName and (" (de " .. srcName .. ")") or "")
    -- aviso grande en pantalla
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, "|cff7fb3e8" .. line .. "|r", ChatTypeInfo["RAID_WARNING"])
    end
    RB:Print(line)
    -- aviso epico al grupo (en ingles), si esta activado
    if getSettings().party and IsInGroup() then
        local chan = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
        local epic = ("Reflected %s - sent it right back! By Varian's blade, FOR THE ALLIANCE!"):format(spellName or "the cast")
        pcall(SendChatMessage, epic, chan)
    end
end

local function onCombatLogEvent()
    if not RB:IsFeatureEnabled("reflectHerald") then return end
    -- todo defensivo: en contenido restringido los valores pueden ser secretos
    pcall(function()
        local _, sub, _, _, srcName, _, _, dstGUID, _, _, _, _, spellName, _, missType =
            CombatLogGetCurrentEventInfo()
        if sub == "SPELL_MISSED" and missType == "REFLECT" and dstGUID == playerGUID then
            sessionTotal = sessionTotal + 1
            local key = tostring(spellName or "Desconocido")
            sessionReflects[key] = (sessionReflects[key] or 0) + 1
            announce(spellName, srcName)
        end
    end)
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        getSettings()
        -- registro defensivo: si el cliente quito el evento, avisar sin crashear
        combatLogAvailable = RB:RegisterEventSafe(frame, "COMBAT_LOG_EVENT_UNFILTERED") and true or false
        if not combatLogAvailable then
            RB:Print("ReflectHerald: este cliente no expone el combat log a addons; solo funcionara el modo test.")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        onCombatLogEvent()
    end
end)
RB:RegisterEventSafe(frame, "PLAYER_LOGIN")

local function printStatus()
    local settings = getSettings()
    RB:Print(("ReflectHerald %s - anuncio al grupo %s - reflects esta sesion: %d"):format(
        RB:IsFeatureEnabled("reflectHerald") and "ON" or "OFF",
        settings.party and "ON" or "OFF",
        sessionTotal))
    if not combatLogAvailable then
        DEFAULT_CHAT_FRAME:AddMessage("  combat log no disponible en este cliente: solo funciona el modo test")
    end
end

function ReflectHerald:HandleSlash(rest)
    rest = string.lower(tostring(rest or ""))
    local command, arg = rest:match("^%s*(%S*)%s*(%S*)")
    command = command or ""
    if command == "on" then
        RB:SetFeatureEnabled("reflectHerald", true)
    elseif command == "off" then
        RB:SetFeatureEnabled("reflectHerald", false)
    elseif command == "party" then
        local settings = getSettings()
        if arg == "on" then
            settings.party = true
        elseif arg == "off" then
            settings.party = false
        else
            settings.party = not settings.party
        end
        RB:Print("ReflectHerald: anuncio al grupo " .. (settings.party and "ON" or "OFF"))
    elseif command == "test" then
        announce("Frostbolt", "Dummy")
    elseif command == "stats" then
        RB:Print("ReflectHerald: reflects esta sesion: " .. sessionTotal)
        for name, count in pairs(sessionReflects) do
            DEFAULT_CHAT_FRAME:AddMessage(("   %s x%d"):format(name, count))
        end
    elseif command == "status" or command == "" then
        printStatus()
        DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rapzo reflect on|r / |cff38bdf8off|r - activa o desactiva el modulo")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rapzo reflect party [on|off]|r - anuncio al grupo")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rapzo reflect test|r - simula un reflejo")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rapzo reflect stats|r - resumen de la sesion")
    else
        printStatus()
    end
end

RB:RegisterCommand("reflect", function(rest) ReflectHerald:HandleSlash(rest) end,
    "/rapzo reflect [status|on|off|party|test|stats] - anuncios de Spell Reflection")

-- Alias rapido heredado del addon ReflectHerald original.
SLASH_RAPZOQOLREFLECT1 = "/rh"
SlashCmdList.RAPZOQOLREFLECT = function(message)
    ReflectHerald:HandleSlash(message)
end
