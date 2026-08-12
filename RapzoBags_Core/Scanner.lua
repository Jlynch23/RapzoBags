local _, RB = ...

local Scanner = {}
RB.Scanner = Scanner

Scanner.frame = CreateFrame("Frame")
Scanner.bankOpen = false
Scanner.initialized = false

local function addItem(bucket, itemID, count, link)
    itemID = tonumber(itemID)
    count = tonumber(count) or 1
    if not itemID or count <= 0 then
        return
    end

    local entry = bucket[itemID]
    if type(entry) ~= "table" then
        entry = { count = 0 }
        bucket[itemID] = entry
    end

    entry.count = (tonumber(entry.count) or 0) + count
    if link and not entry.link then
        entry.link = link
    end
end

local function safeContainerSlots(bagID)
    if not C_Container or not C_Container.GetContainerNumSlots then
        return 0
    end
    local ok, slots = pcall(C_Container.GetContainerNumSlots, bagID)
    if not ok then
        return 0
    end
    return tonumber(slots) or 0
end

local function safeContainerInfo(bagID, slot)
    if not C_Container or not C_Container.GetContainerItemInfo then
        return nil
    end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)
    if not ok then
        return nil
    end
    return info
end

local function safeContainerLink(bagID, slot)
    if not C_Container or not C_Container.GetContainerItemLink then
        return nil
    end
    local ok, link = pcall(C_Container.GetContainerItemLink, bagID, slot)
    if ok then
        return link
    end
    return nil
end

local function itemIDFromInfo(info, bagID, slot)
    if type(info) == "table" and tonumber(info.itemID) then
        return tonumber(info.itemID)
    end
    if C_Container and C_Container.GetContainerItemID then
        local ok, itemID = pcall(C_Container.GetContainerItemID, bagID, slot)
        if ok then return tonumber(itemID) end
    end
    return nil
end

local function countFromInfo(info)
    if type(info) ~= "table" then
        return 1
    end
    return tonumber(info.stackCount) or tonumber(info.count) or 1
end

local function scanBagIDs(bagIDs)
    local bucket = {}
    local containersWithSlots = 0

    for _, bagID in ipairs(bagIDs) do
        local slots = safeContainerSlots(bagID)
        if slots > 0 then
            containersWithSlots = containersWithSlots + 1
            for slot = 1, slots do
                local info = safeContainerInfo(bagID, slot)
                local itemID = itemIDFromInfo(info, bagID, slot)
                if itemID then
                    local link = safeContainerLink(bagID, slot)
                    addItem(bucket, itemID, countFromInfo(info), link)
                end
            end
        end
    end

    return bucket, containersWithSlots
end

local function uniqueInsert(target, seen, value)
    value = tonumber(value)
    if value and not seen[value] then
        seen[value] = true
        target[#target + 1] = value
    end
end

function Scanner:GetBagIndexes()
    local bagIDs, seen = {}, {}

    if Enum and type(Enum.BagIndex) == "table" then
        for name, value in pairs(Enum.BagIndex) do
            if name == "Backpack" or name == "ReagentBag" or string.match(name, "^Bag_%d+$") then
                uniqueInsert(bagIDs, seen, value)
            end
        end
    end

    if #bagIDs == 0 then
        for bagID = 0, 5 do
            uniqueInsert(bagIDs, seen, bagID)
        end
    end

    table.sort(bagIDs)
    return bagIDs
end

function Scanner:GetBankIndexes()
    local characterBank, accountBank = {}, {}
    local seenCharacter, seenAccount = {}, {}

    if Enum and type(Enum.BagIndex) == "table" then
        for name, value in pairs(Enum.BagIndex) do
            local lower = string.lower(name)
            if string.find(lower, "account", 1, true) or string.find(lower, "warband", 1, true) then
                uniqueInsert(accountBank, seenAccount, value)
            elseif string.find(lower, "bank", 1, true) then
                uniqueInsert(characterBank, seenCharacter, value)
            end
        end
    end

    -- Fallbacks for older/current layouts. Invalid or unavailable containers simply return 0 slots.
    if #characterBank == 0 then
        uniqueInsert(characterBank, seenCharacter, -1)
        uniqueInsert(characterBank, seenCharacter, -3)
        for bagID = 6, 12 do
            uniqueInsert(characterBank, seenCharacter, bagID)
        end
    end

    table.sort(characterBank)
    table.sort(accountBank)
    return characterBank, accountBank
end

function Scanner:ScanInventory()
    local character = RB:GetCurrentCharacter()
    local bucket = scanBagIDs(self:GetBagIndexes())
    character.bags = bucket
    RB:TouchCharacter()
end

function Scanner:ScanEquipment()
    local character = RB:GetCurrentCharacter()
    local bucket = {}

    if GetInventoryItemID then
        for slot = 1, 19 do
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil
                addItem(bucket, itemID, 1, link)
            end
        end
    end

    character.equipped = bucket
    RB:TouchCharacter()
end

function Scanner:ScanBanks()
    local characterBankIDs, accountBankIDs = self:GetBankIndexes()

    local characterBucket, characterContainers = scanBagIDs(characterBankIDs)
    if characterContainers > 0 then
        local character = RB:GetCurrentCharacter()
        character.bank = characterBucket
        character.bankLastSeen = time and time() or 0
    end

    local accountBucket, accountContainers = scanBagIDs(accountBankIDs)
    if accountContainers > 0 then
        local db = RB:EnsureDB()
        db.account.bank = accountBucket
        db.account.bankLastSeen = time and time() or 0
    end

    RB:TouchCharacter()
end

function Scanner:ScanAll(includeBanks)
    self:ScanInventory()
    self:ScanEquipment()
    if includeBanks or self.bankOpen then
        self:ScanBanks()
    end
end

function Scanner:ScheduleScan(includeBanks)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            Scanner:ScanAll(includeBanks)
        end)
    else
        self:ScanAll(includeBanks)
    end
end

function Scanner:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    local events = {
        "BAG_UPDATE_DELAYED",
        "PLAYER_EQUIPMENT_CHANGED",
        "BANKFRAME_OPENED",
        "BANKFRAME_CLOSED",
        "PLAYERBANKSLOTS_CHANGED",
        "PLAYERBANKBAGSLOTS_CHANGED",
        "PLAYERREAGENTBANKSLOTS_CHANGED",
        -- Newer retail/account-bank events are registered only when the client knows them.
        "ACCOUNT_BANK_PANEL_OPENED",
        "ACCOUNT_BANK_PANEL_CLOSED",
        "ACCOUNT_BANK_TAB_SLOTS_CHANGED",
        "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
    }

    for _, event in ipairs(events) do
        RB:RegisterEventSafe(self.frame, event)
    end

    self.frame:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" or event == "ACCOUNT_BANK_PANEL_OPENED" then
            Scanner.bankOpen = true
            Scanner:ScheduleScan(true)
        elseif event == "BANKFRAME_CLOSED" or event == "ACCOUNT_BANK_PANEL_CLOSED" then
            Scanner.bankOpen = false
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            Scanner:ScanEquipment()
        elseif event == "BAG_UPDATE_DELAYED" then
            Scanner:ScanInventory()
            if Scanner.bankOpen then
                Scanner:ScheduleScan(true)
            end
        else
            if Scanner.bankOpen then
                Scanner:ScheduleScan(true)
            end
        end
    end)

    self:ScanAll(false)
end
