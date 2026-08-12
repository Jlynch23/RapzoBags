local addonName = ...
local RB = _G.RapzoBags
if not RB then return end


local Tooltip = {}
RB.Tooltip = Tooltip
RB:RegisterModule("tooltip", Tooltip)
Tooltip.initialized = false

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function extractItemID(tooltip, data)
    if type(data) == "table" and data.id and not isSecret(data.id) then
        local id = tonumber(data.id)
        if id then return id end
    end

    if tooltip and tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and link and not isSecret(link) then
            if C_Item and C_Item.GetItemInfoInstant then
                local success, itemID = pcall(C_Item.GetItemInfoInstant, link)
                if success and tonumber(itemID) then
                    return tonumber(itemID)
                end
            end
            if type(link) == "string" then
                return tonumber(string.match(link, "item:(%d+)"))
            end
        end
    end

    return nil
end

local function getClassColor(classFile)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 0.8, 0.8, 0.8
end

local function locationText(entry)
    local parts = {}
    if (entry.bags or 0) > 0 then parts[#parts + 1] = "Bolsas: " .. entry.bags end
    if (entry.bank or 0) > 0 then parts[#parts + 1] = "Banco: " .. entry.bank end
    if (entry.equipped or 0) > 0 then parts[#parts + 1] = "Equipado: " .. entry.equipped end
    return table.concat(parts, "  ·  ")
end

local function isMerchantTooltip(tooltip)
    if not tooltip or type(tooltip.GetOwner) ~= "function" then
        return false
    end

    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok or not owner then
        return false
    end

    local current = owner
    for _ = 1, 8 do
        if MerchantFrame and current == MerchantFrame then
            return true
        end
        if type(current.GetName) == "function" then
            local nameOk, name = pcall(current.GetName, current)
            if nameOk and type(name) == "string" and name:match("^MerchantItem%d+") then
                return true
            end
        end
        if type(current.GetParent) ~= "function" then break end
        local parentOk, parent = pcall(current.GetParent, current)
        if not parentOk or not parent or parent == current then break end
        current = parent
    end

    return false
end

function Tooltip:GetItemMetadata(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getItemInfo) ~= "function" then return nil end

    local values = {pcall(getItemInfo, itemID)}
    if not values[1] then return nil end

    local name = values[2]
    local itemType = values[7]
    local itemSubType = values[8]
    local expacID = tonumber(values[16])

    if not name and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end

    local expansionName
    if expacID ~= nil then
        expansionName = _G["EXPANSION_NAME" .. expacID] or ("Expansion " .. expacID)
    end

    local typeText = itemSubType or itemType
    if itemType and itemSubType and itemType ~= itemSubType then
        typeText = itemType .. " · " .. itemSubType
    end

    return {
        name = name,
        itemType = itemType,
        itemSubType = itemSubType,
        typeText = typeText,
        expacID = expacID,
        expansionName = expansionName,
    }
end

function Tooltip:GetExpansionInfo(itemID)
    local info = self:GetItemMetadata(itemID)
    if not info then return nil, nil end
    return info.expacID, info.expansionName
end

function Tooltip:AddItemInfo(tooltip, itemID)
    local db = RB:EnsureDB()
    if not RB:IsFeatureEnabled("tooltip") or not db.settings.tooltip then return end
    if isMerchantTooltip(tooltip) then return end

    local metadata = self:GetItemMetadata(itemID)
    local aggregate = RB:GetItemAggregate(itemID)
    local hasCounts = aggregate and aggregate.total and aggregate.total > 0

    local showExpansion = db.settings.showItemExpansion ~= false and metadata and metadata.expansionName
    local showType = db.settings.showItemType ~= false and metadata and metadata.typeText
    local showID = db.settings.showItemID ~= false

    if not showExpansion and not showType and not showID and not hasCounts then
        return
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Rapzo Bags", 0.22, 0.74, 0.97)

    if showExpansion then
        tooltip:AddDoubleLine("Expansion", metadata.expansionName, 1.00, 0.82, 0.35, 0.95, 0.95, 0.95)
    end
    if showType then
        tooltip:AddDoubleLine("Tipo", metadata.typeText, 0.66, 0.80, 0.95, 0.90, 0.90, 0.90)
    end
    if showID then
        tooltip:AddDoubleLine("Item ID", tostring(itemID), 0.55, 0.60, 0.68, 0.80, 0.80, 0.80)
    end

    if not hasCounts then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("En tu cuenta", 0.55, 0.82, 1.00)

    local maxCharacters = tonumber(db.settings.maxCharacters) or 12
    local shown = 0
    for _, entry in ipairs(aggregate.characters) do
        if shown >= maxCharacters then break end
        shown = shown + 1
        local r, g, b = getClassColor(entry.class)
        local right = tostring(entry.total)
        if db.settings.showLocations then
            local locations = locationText(entry)
            if locations ~= "" then
                right = string.format("%d  |cff9ca3af%s|r", entry.total, locations)
            end
        end
        tooltip:AddDoubleLine(entry.name or entry.key, right, r, g, b, 1, 1, 1)
    end

    if #aggregate.characters > shown then
        tooltip:AddDoubleLine("Otros personajes", "+" .. (#aggregate.characters - shown), 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)
    end

    if aggregate.accountBank > 0 then
        tooltip:AddDoubleLine("Banco de banda de guerra", tostring(aggregate.accountBank), 0.90, 0.77, 0.37, 1, 1, 1)
    end

    if db.settings.showTotal then
        tooltip:AddDoubleLine("Total", tostring(aggregate.total), 0.22, 0.74, 0.97, 1, 1, 1)
    end
end

function Tooltip:Initialize()
    if self.initialized then return end
    self.initialized = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            local itemID = extractItemID(tooltip, data)
            if itemID then
                Tooltip:AddItemInfo(tooltip, itemID)
            end
        end)
    else
        RB:Print("El procesador moderno de tooltips no esta disponible en este cliente.")
    end
end


local function setBooleanSetting(setting, value, onText, offText, usage)
    value = string.lower(tostring(value or ""))
    local db = RB:EnsureDB()
    if value == "on" then
        db.settings[setting] = true
        if setting == "tooltip" then RB:SetFeatureEnabled("tooltip", true, true) end
        RB:Print(onText)
    elseif value == "off" then
        db.settings[setting] = false
        if setting == "tooltip" then RB:SetFeatureEnabled("tooltip", false, true) end
        RB:Print(offText)
    else
        RB:Print(usage)
    end
end

RB:RegisterCommand("tooltip", function(rest)
    setBooleanSetting("tooltip", rest, "Tooltips activados.", "Tooltips desactivados.", "Uso: /rbags tooltip on|off")
end, "/rbags tooltip on|off - activa/desactiva el tooltip avanzado")
RB:RegisterCommand("expansion", function(rest)
    setBooleanSetting("showItemExpansion", rest, "Expansion activada.", "Expansion desactivada.", "Uso: /rbags expansion on|off")
end, "/rbags expansion on|off - muestra/oculta la expansion")
RB:RegisterCommand("expa", RB.commands.expansion)
RB:RegisterCommand("itemtype", function(rest)
    setBooleanSetting("showItemType", rest, "Tipo de objeto activado.", "Tipo de objeto desactivado.", "Uso: /rbags itemtype on|off")
end, "/rbags itemtype on|off - muestra/oculta el tipo del objeto")
RB:RegisterCommand("tipo", RB.commands.itemtype)
RB:RegisterCommand("itemid", function(rest)
    setBooleanSetting("showItemID", rest, "Item ID activado.", "Item ID desactivado.", "Uso: /rbags itemid on|off")
end, "/rbags itemid on|off - muestra/oculta el Item ID")
RB:RegisterCommand("id", RB.commands.itemid)
RB:RegisterCommand("locations", function(rest)
    setBooleanSetting("showLocations", rest, "Ubicaciones detalladas activadas.", "Ubicaciones detalladas desactivadas.", "Uso: /rbags locations on|off")
end, "/rbags locations on|off - muestra/oculta ubicaciones detalladas")

Tooltip:Initialize()
