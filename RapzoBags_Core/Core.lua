local addonName, private = ...

local RB = _G.RapzoBags or private or {}
_G.RapzoBags = RB

RB.name = "RapzoBags"
RB.coreAddonName = addonName or "RapzoBags_Core"
RB.version = "3.0.0-alpha4"
RB.prefix = "|cff38bdf8Rapzo Bags|r"
RB.modules = RB.modules or {}
RB.commands = RB.commands or {}
RB.helpLines = RB.helpLines or {}

local eventFrame = CreateFrame("Frame")
RB.eventFrame = eventFrame

local function safeCall(func, ...)
    if type(func) ~= "function" then
        return false
    end
    return pcall(func, ...)
end

function RB:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s", self.prefix, tostring(message)))
end

function RB:RegisterEventSafe(frame, event)
    if not frame or type(event) ~= "string" then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event)
end

function RB:GetRealmNameSafe()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or "UnknownRealm"
    end
    return realm
end

function RB:GetPlayerNameSafe()
    local name = UnitName and UnitName("player")
    return name or "UnknownCharacter"
end

function RB:GetCharacterKey()
    return string.format("%s-%s", self:GetPlayerNameSafe(), self:GetRealmNameSafe())
end

function RB:EnsureDB()
    if type(RapzoBagsDB) ~= "table" then
        RapzoBagsDB = {}
    end

    local db = RapzoBagsDB
    db.schema = 5
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.account = type(db.account) == "table" and db.account or {}
    db.account.bank = type(db.account.bank) == "table" and db.account.bank or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    db.settings.modules = type(db.settings.modules) == "table" and db.settings.modules or {}

    -- Migracion desde RapzoBags 2.x: conserva tus preferencias existentes.
    if db.settings.tooltip == nil then db.settings.tooltip = true end
    if db.settings.showTotal == nil then db.settings.showTotal = true end
    if db.settings.showLocations == nil then db.settings.showLocations = true end
    if db.settings.maxCharacters == nil then db.settings.maxCharacters = 12 end
    if db.settings.showItemExpansion == nil then db.settings.showItemExpansion = true end
    if db.settings.showItemType == nil then db.settings.showItemType = true end
    if db.settings.showItemID == nil then db.settings.showItemID = true end

    local modules = db.settings.modules
    if modules.tooltip == nil then modules.tooltip = db.settings.tooltip ~= false end
    if modules.search == nil then modules.search = true end
    if modules.vendor == nil then modules.vendor = true end
    if modules.collections == nil then modules.collections = true end
    if modules.config == nil then modules.config = true end

    self.db = db
    return db
end

function RB:IsFeatureEnabled(key, defaultValue)
    local db = self:EnsureDB()
    local value = db.settings.modules[key]
    if value == nil then
        if defaultValue == nil then defaultValue = true end
        value = defaultValue and true or false
        db.settings.modules[key] = value
    end
    return value == true
end

function RB:SetFeatureEnabled(key, enabled, quiet)
    local db = self:EnsureDB()
    db.settings.modules[key] = enabled and true or false
    if key == "tooltip" then db.settings.tooltip = enabled and true or false end
    if not quiet then
        self:Print(string.format("Modulo %s: %s", tostring(key), enabled and "ON" or "OFF"))
    end
end

function RB:RegisterModule(key, module)
    if not key or not module then return end
    self.modules[key] = module
    self[key:gsub("^%l", string.upper)] = module
end

function RB:IsModulePresent(key)
    return self.modules[key] ~= nil
end

function RB:RegisterCommand(name, handler, helpText)
    name = string.lower(tostring(name or ""))
    if name == "" or type(handler) ~= "function" then return end
    self.commands[name] = handler
    if helpText then self.helpLines[name] = helpText end
end

function RB:SetDefaultAction(handler)
    if type(handler) == "function" then
        self.defaultAction = handler
    end
end

function RB:PrintHelp()
    self:Print("Comandos disponibles:")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rbags|r - abre el buscador si el modulo Search esta activo")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rbags scan|r - reescanea bolsas y equipo")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rbags status|r - resumen de la base local")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rbags modules|r - estado de los modulos")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8/rbags reset confirm|r - borra la base local")
    local keys = {}
    for name in pairs(self.helpLines) do keys[#keys + 1] = name end
    table.sort(keys)
    for _, name in ipairs(keys) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cff38bdf8" .. self.helpLines[name] .. "|r")
    end
end

function RB:GetCurrentCharacter()
    local db = self:EnsureDB()
    local key = self:GetCharacterKey()
    local character = db.characters[key]

    if type(character) ~= "table" then
        character = {
            key = key,
            name = self:GetPlayerNameSafe(),
            realm = self:GetRealmNameSafe(),
            bags = {},
            equipped = {},
            bank = {},
            money = 0,
            lastSeen = 0,
        }
        db.characters[key] = character
    end

    character.key = key
    character.name = self:GetPlayerNameSafe()
    character.realm = self:GetRealmNameSafe()
    character.bags = type(character.bags) == "table" and character.bags or {}
    character.equipped = type(character.equipped) == "table" and character.equipped or {}
    character.bank = type(character.bank) == "table" and character.bank or {}

    if UnitClass then
        local _, classFile = UnitClass("player")
        character.class = classFile or character.class
    end
    if UnitFactionGroup then
        character.faction = UnitFactionGroup("player") or character.faction
    end

    return character
end

function RB:TouchCharacter()
    local character = self:GetCurrentCharacter()
    character.lastSeen = time and time() or 0
    if GetMoney then
        character.money = GetMoney() or character.money or 0
    end
end

function RB:ApplyBagDirection()
    if not C_Container then return end
    if C_Container.SetSortBagsRightToLeft then safeCall(C_Container.SetSortBagsRightToLeft, false) end
    if C_Container.SetInsertItemsLeftToRight then safeCall(C_Container.SetInsertItemsLeftToRight, false) end
end

function RB:ApplyBagDirectionDelayed()
    self:ApplyBagDirection()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() RB:ApplyBagDirection() end)
        C_Timer.After(2, function() RB:ApplyBagDirection() end)
    end
end

local function getStoredCount(locationTable, itemID)
    if type(locationTable) ~= "table" then return 0 end
    local entry = locationTable[itemID]
    if type(entry) == "table" then return tonumber(entry.count) or 0 end
    return tonumber(entry) or 0
end

function RB:GetItemAggregate(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local db = self:EnsureDB()
    local result = { itemID = itemID, characters = {}, accountBank = 0, total = 0 }

    for key, character in pairs(db.characters) do
        if type(character) == "table" then
            local bags = getStoredCount(character.bags, itemID)
            local equipped = getStoredCount(character.equipped, itemID)
            local bank = getStoredCount(character.bank, itemID)
            local subtotal = bags + equipped + bank
            if subtotal > 0 then
                result.characters[#result.characters + 1] = {
                    key = key,
                    name = character.name or key,
                    realm = character.realm,
                    class = character.class,
                    bags = bags,
                    equipped = equipped,
                    bank = bank,
                    total = subtotal,
                    lastSeen = character.lastSeen or 0,
                }
                result.total = result.total + subtotal
            end
        end
    end

    result.accountBank = getStoredCount(db.account.bank, itemID)
    result.total = result.total + result.accountBank

    table.sort(result.characters, function(a, b)
        if a.total == b.total then return (a.name or "") < (b.name or "") end
        return a.total > b.total
    end)

    return result
end

function RB:GetKnownItemLink(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local db = self:EnsureDB()
    for _, character in pairs(db.characters) do
        for _, bucketName in ipairs({"bags", "equipped", "bank"}) do
            local bucket = character[bucketName]
            local entry = type(bucket) == "table" and bucket[itemID]
            if type(entry) == "table" and entry.link then return entry.link end
        end
    end
    local accountEntry = db.account.bank[itemID]
    if type(accountEntry) == "table" and accountEntry.link then return accountEntry.link end
    return nil
end

function RB:GetAllKnownItemIDs()
    local ids, seen = {}, {}
    local db = self:EnsureDB()
    local function absorb(bucket)
        if type(bucket) ~= "table" then return end
        for itemID in pairs(bucket) do
            itemID = tonumber(itemID)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                ids[#ids + 1] = itemID
            end
        end
    end
    for _, character in pairs(db.characters) do
        absorb(character.bags); absorb(character.equipped); absorb(character.bank)
    end
    absorb(db.account.bank)
    table.sort(ids)
    return ids
end

function RB:GetTotalMoney()
    local total = 0
    local db = self:EnsureDB()
    for _, character in pairs(db.characters) do total = total + (tonumber(character.money) or 0) end
    return total
end

function RB:ShowStatus()
    local db = self:EnsureDB()
    local characterCount = 0
    for _ in pairs(db.characters) do characterCount = characterCount + 1 end
    self:Print(string.format("v%s | %d personaje(s) | %d objeto(s) unicos", self.version, characterCount, #self:GetAllKnownItemIDs()))
end

function RB:ShowModules()
    local labels = {"tooltip", "search", "vendor", "collections", "config"}
    self:Print("Modulos Rapzo Bags:")
    for _, key in ipairs(labels) do
        local present = self:IsModulePresent(key)
        local enabled = self:IsFeatureEnabled(key)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %-12s  addon:%s  funcion:%s", key, present and "|cff38e66bCARGADO|r" or "|cffef4444NO|r", enabled and "|cff38e66bON|r" or "|cffef4444OFF|r"))
    end
end

function RB:Initialize()
    self:EnsureDB()
    self:TouchCharacter()
    self:ApplyBagDirectionDelayed()
    if self.Scanner and self.Scanner.Initialize then self.Scanner:Initialize() end
end

RB:RegisterCommand("scan", function()
    if RB.Scanner then
        RB.Scanner:ScanAll(RB.Scanner.bankOpen)
        RB:Print("Escaneo actualizado.")
    end
end)
RB:RegisterCommand("status", function() RB:ShowStatus() end)
RB:RegisterCommand("modules", function() RB:ShowModules() end)
RB:RegisterCommand("help", function() RB:PrintHelp() end)
RB:RegisterCommand("ayuda", function() RB:PrintHelp() end)
RB:RegisterCommand("reset", function(rest)
    if string.lower(tostring(rest or "")) ~= "confirm" then
        RB:Print("Uso: /rbags reset confirm")
        return
    end
    RapzoBagsDB = nil
    RB.db = nil
    RB:EnsureDB(); RB:TouchCharacter()
    if RB.Scanner then RB.Scanner:ScanAll(RB.Scanner.bankOpen) end
    RB:Print("Base de datos reiniciada.")
end)

SLASH_RAPZOBAGS1 = "/rbags"
SLASH_RAPZOBAGS2 = "/rapzobags"
SlashCmdList.RAPZOBAGS = function(message)
    message = tostring(message or "")
    local command, rest = message:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    if command == "" then
        if type(RB.defaultAction) == "function" then RB.defaultAction() else RB:PrintHelp() end
        return
    end
    local handler = RB.commands[command]
    if handler then handler(rest or "") else RB:PrintHelp() end
end

RB:RegisterEventSafe(eventFrame, "ADDON_LOADED")
RB:RegisterEventSafe(eventFrame, "PLAYER_LOGIN")
RB:RegisterEventSafe(eventFrame, "PLAYER_ENTERING_WORLD")
RB:RegisterEventSafe(eventFrame, "PLAYER_MONEY")

local initialized = false
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= RB.coreAddonName then return end
        if not initialized then initialized = true; RB:Initialize() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RB:EnsureDB(); RB:TouchCharacter(); RB:ApplyBagDirectionDelayed()
        if RB.Scanner and RB.Scanner.ScanAll then RB.Scanner:ScanAll(false) end
    elseif event == "PLAYER_MONEY" then
        RB:TouchCharacter()
    end
end)
