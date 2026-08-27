local addonName = ...
local RB = _G.RapzoBags
if not RB then return end


local Vendor = {}
RB.Vendor = Vendor
RB:RegisterModule("vendor", Vendor)

Vendor.initialized = false
Vendor.ready = false
Vendor.extraSlots = {}
Vendor.originalSlotPoints = {}
Vendor.originalBuyBackPoint = nil
Vendor.originalFrameWidth = nil
Vendor.originalFrameHeight = nil
Vendor.originalItemsPerPage = 10
Vendor.conflictWarned = false
Vendor.maxCreatedSlots = 12
Vendor.filterBar = nil
Vendor.filteredIndices = {}
Vendor.originalAPI = {}
Vendor.apiWrapped = false

local DEFAULT_ROWS = 5
local DEFAULT_COLUMNS = 4
local MIN_ROWS = 5
local MAX_ROWS = 10
local MIN_COLUMNS = 2
local MAX_COLUMNS = 8
local FIRST_X = 11
local FIRST_Y = -69
local COLUMN_GAP = 12
local ROW_GAP = 8
local FILTER_BAR_EXTRA_HEIGHT = 30
local FILTER_BUTTON_GAP = 4
local FILTER_BAR_X = 82

local VALID_FILTERS = {
    all = true,
    uncollected = true,
    mounts = true,
    transmog = true,
    recipes = true,
}

local FILTER_BUTTONS = {
    { key = "all", label = "Todos", width = 64 },
    { key = "uncollected", label = "No obtenidos", width = 98 },
    { key = "mounts", label = "Monturas", width = 78 },
    { key = "transmog", label = "Transmog", width = 78 },
    { key = "recipes", label = "Recetas", width = 70 },
}

local function trim(text)
    text = tostring(text or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    value = math.floor(value + 0.5)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function safeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil
    end
    return pcall(func, ...)
end

local function getConfig()
    local db = RB:EnsureDB()
    db.settings.vendor = type(db.settings.vendor) == "table" and db.settings.vendor or {}
    local cfg = db.settings.vendor

    if cfg.enabled == nil then cfg.enabled = RB:IsFeatureEnabled("vendor") end
    if cfg.rows == nil then cfg.rows = DEFAULT_ROWS end
    if cfg.columns == nil then cfg.columns = DEFAULT_COLUMNS end
    if cfg.markCollected == nil then cfg.markCollected = true end
    if cfg.showOwnedCount == nil then cfg.showOwnedCount = true end
    if cfg.filterMode == nil or not VALID_FILTERS[cfg.filterMode] then cfg.filterMode = "all" end

    cfg.rows = clamp(cfg.rows, MIN_ROWS, MAX_ROWS)
    cfg.columns = clamp(cfg.columns, MIN_COLUMNS, MAX_COLUMNS)
    RB:SetFeatureEnabled("vendor", cfg.enabled, true)
    return cfg
end

local function isKrowiLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "Krowi_ExtendedVendorUI")
        return ok and loaded or false
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, "Krowi_ExtendedVendorUI")
        return ok and loaded or false
    end
    return false
end

function Vendor:HasCollections()
    return RB.Collections ~= nil and RB:IsFeatureEnabled("collections")
end

function Vendor:ClearCollectionCache()
    if self:HasCollections() and RB.Collections.ClearCache then RB.Collections:ClearCache() end
end

function Vendor:GetCollectionState(itemID)
    if self:HasCollections() and RB.Collections.GetState then return RB.Collections:GetState(itemID) end
    return false, nil
end

function Vendor:GetOwnedCount(itemID)
    local aggregate = RB:GetItemAggregate(itemID)
    return aggregate and tonumber(aggregate.total) or 0
end

function Vendor:PrepareSlot(frame)
    if not frame or frame.RapzoBagsPrepared then
        return
    end
    frame.RapzoBagsPrepared = true

    local tint = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    tint:SetColorTexture(0.08, 0.85, 0.28, 0.20)
    tint:SetPoint("TOPLEFT", frame.ItemButton, "TOPLEFT", 1, -1)
    tint:SetPoint("BOTTOMRIGHT", frame.ItemButton, "BOTTOMRIGHT", -1, 1)
    tint:Hide()
    frame.RapzoBagsCollectedTint = tint

    local mark = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mark:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -1)
    mark:SetText("|cff38e66b✓ OBTENIDO|r")
    mark:SetJustifyH("RIGHT")
    mark:Hide()
    frame.RapzoBagsCollectedMark = mark

    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 1)
    count:SetJustifyH("RIGHT")
    count:Hide()
    frame.RapzoBagsOwnedCount = count

    if frame.ItemButton and type(frame.ItemButton.SetScript) == "function" then
        local function showTooltip(button)
            if MerchantFrame.selectedTab == 1 then
                local visibleIndex = tonumber(button:GetID())
                local originalIndex = Vendor:MapVisibleIndex(visibleIndex)
                if not originalIndex then return end

                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetMerchantItem(originalIndex)
                if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip) end
                MerchantFrame.itemHover = visibleIndex

                local getID = Vendor.originalAPI.GetMerchantItemID or GetMerchantItemID
                local itemID = getID and getID(originalIndex)
                if itemID then
                    local collected, kind = Vendor:GetCollectionState(itemID)
                    local owned = Vendor:GetOwnedCount(itemID)
                    if collected then
                        GameTooltip:AddLine(string.format("Rapzo QoL: OBTENIDO%s", kind and (" - " .. kind) or ""), 0.22, 0.95, 0.40)
                    end
                    if owned > 0 then
                        GameTooltip:AddLine(string.format("Rapzo QoL: tienes %d", owned), 0.22, 0.75, 1.00)
                    end
                end
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetBuybackItem(button:GetID())
                if IsModifiedClick and IsModifiedClick("DRESSUP") and button.hasItem and ShowInspectCursor then
                    ShowInspectCursor()
                elseif ShowBuybackSellCursor then
                    ShowBuybackSellCursor(button:GetID())
                end
            end
        end

        frame.ItemButton:SetScript("OnEnter", showTooltip)
        frame.ItemButton.UpdateTooltip = showTooltip
    end
end

function Vendor:GetSlot(index)
    local frame = _G["MerchantItem" .. index]
    if not frame and MerchantFrame then
        frame = CreateFrame("Frame", "MerchantItem" .. index, MerchantFrame, "MerchantItemTemplate")
        self.extraSlots[index] = frame
    end
    if frame then
        if index > self.maxCreatedSlots then
            self.maxCreatedSlots = index
        end
        self:PrepareSlot(frame)
    end
    return frame
end

function Vendor:IsFilterActive()
    local cfg = getConfig()
    return cfg.enabled and cfg.filterMode ~= "all"
end

function Vendor:MapVisibleIndex(index)
    index = tonumber(index)
    if not index then return nil end
    if not self:IsFilterActive() then return index end
    return self.filteredIndices[index]
end

function Vendor:ItemMatchesFilter(originalIndex)
    local cfg = getConfig()
    if cfg.filterMode ~= "all" and not self:HasCollections() then return true end
    local mode = cfg.filterMode
    if mode == "all" then return true end

    local getID = self.originalAPI.GetMerchantItemID or GetMerchantItemID
    local itemID = getID and getID(originalIndex)
    itemID = tonumber(itemID)
    if not itemID then return false end

    local collected, kind = self:GetCollectionState(itemID)
    if mode == "uncollected" then
        return kind ~= nil and not collected
    elseif mode == "mounts" then
        return kind == "Montura"
    elseif mode == "transmog" then
        return kind == "Apariencia" or kind == "Conjunto"
    elseif mode == "recipes" then
        return kind == "Receta"
    end

    return true
end

function Vendor:BuildFilteredIndices()
    wipe(self.filteredIndices)
    if not self:IsFilterActive() then return end

    local getNum = self.originalAPI.GetMerchantNumItems or GetMerchantNumItems
    if type(getNum) ~= "function" then return end
    local ok, numItems = pcall(getNum)
    if not ok then return end
    numItems = tonumber(numItems) or 0

    for originalIndex = 1, numItems do
        if self:ItemMatchesFilter(originalIndex) then
            self.filteredIndices[#self.filteredIndices + 1] = originalIndex
        end
    end
end

function Vendor:WrapMerchantAPIs()
    if self.apiWrapped then return true end
    if type(GetMerchantNumItems) ~= "function" or not C_MerchantFrame or type(C_MerchantFrame.GetItemInfo) ~= "function" then
        return false
    end

    local api = self.originalAPI
    api.GetMerchantNumItems = GetMerchantNumItems
    api.GetMerchantItemInfo = GetMerchantItemInfo
    api.GetMerchantItemID = GetMerchantItemID
    api.GetMerchantItemLink = GetMerchantItemLink
    api.CanAffordMerchantItem = CanAffordMerchantItem
    api.GetMerchantItemCostInfo = GetMerchantItemCostInfo
    api.GetMerchantItemCostItem = GetMerchantItemCostItem
    api.BuyMerchantItem = BuyMerchantItem
    api.PickupMerchantItem = PickupMerchantItem
    api.GetMerchantItemMaxStack = GetMerchantItemMaxStack
    api.CGetItemInfo = C_MerchantFrame.GetItemInfo
    api.CIsMerchantItemRefundable = C_MerchantFrame.IsMerchantItemRefundable

    GetMerchantNumItems = function()
        if Vendor:IsFilterActive() and MerchantFrame and MerchantFrame.selectedTab == 1 then
            return #Vendor.filteredIndices
        end
        return api.GetMerchantNumItems()
    end

    local function map(index)
        if Vendor:IsFilterActive() and MerchantFrame and MerchantFrame.selectedTab == 1 then
            return Vendor:MapVisibleIndex(index) or index
        end
        return index
    end

    if type(api.GetMerchantItemInfo) == "function" then
        GetMerchantItemInfo = function(index) return api.GetMerchantItemInfo(map(index)) end
    end
    if type(api.GetMerchantItemID) == "function" then
        GetMerchantItemID = function(index) return api.GetMerchantItemID(map(index)) end
    end
    if type(api.GetMerchantItemLink) == "function" then
        GetMerchantItemLink = function(index) return api.GetMerchantItemLink(map(index)) end
    end
    if type(api.CanAffordMerchantItem) == "function" then
        CanAffordMerchantItem = function(index) return api.CanAffordMerchantItem(map(index)) end
    end
    if type(api.GetMerchantItemCostInfo) == "function" then
        GetMerchantItemCostInfo = function(index) return api.GetMerchantItemCostInfo(map(index)) end
    end
    if type(api.GetMerchantItemCostItem) == "function" then
        GetMerchantItemCostItem = function(index, costIndex) return api.GetMerchantItemCostItem(map(index), costIndex) end
    end
    if type(api.BuyMerchantItem) == "function" then
        BuyMerchantItem = function(index, quantity) return api.BuyMerchantItem(map(index), quantity) end
    end
    if type(api.PickupMerchantItem) == "function" then
        PickupMerchantItem = function(index)
            if index == 0 then return api.PickupMerchantItem(0) end
            return api.PickupMerchantItem(map(index))
        end
    end
    if type(api.GetMerchantItemMaxStack) == "function" then
        GetMerchantItemMaxStack = function(index) return api.GetMerchantItemMaxStack(map(index)) end
    end

    C_MerchantFrame.GetItemInfo = function(index)
        return api.CGetItemInfo(map(index))
    end
    if type(api.CIsMerchantItemRefundable) == "function" then
        C_MerchantFrame.IsMerchantItemRefundable = function(index)
            return api.CIsMerchantItemRefundable(map(index))
        end
    end

    self.apiWrapped = true
    return true
end

function Vendor:CreateFilterBar()
    if self.filterBar or not MerchantFrame then return self.filterBar end

    local bar = CreateFrame("Frame", "RapzoBagsVendorFilterBar", MerchantFrame)
    local barWidth = 0
    for index, def in ipairs(FILTER_BUTTONS) do
        barWidth = barWidth + def.width
        if index > 1 then
            barWidth = barWidth + FILTER_BUTTON_GAP
        end
    end
    bar:SetSize(barWidth, 24)
    -- Keep the filters clear of both Blizzard's portrait on the left and the
    -- class/filter dropdown on the right.
    bar:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", FILTER_BAR_X, -38)
    bar.buttons = {}

    local previous
    for _, def in ipairs(FILTER_BUTTONS) do
        local button = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        button:SetSize(def.width, 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", FILTER_BUTTON_GAP, 0)
        else
            button:SetPoint("LEFT", bar, "LEFT", 0, 0)
        end
        button:SetText(def.label)
        button.filterKey = def.key
        button:SetScript("OnClick", function(self)
            Vendor:SetFilterMode(self.filterKey)
        end)
        bar.buttons[def.key] = button
        previous = button
    end

    self.filterBar = bar
    self:UpdateFilterButtons()
    return bar
end

function Vendor:UpdateFilterButtons()
    if not self.filterBar then return end
    local cfg = getConfig()
    for key, button in pairs(self.filterBar.buttons or {}) do
        local needsCollections = key ~= "all"
        if key == cfg.filterMode or (needsCollections and not self:HasCollections()) then
            button:Disable()
        else
            button:Enable()
        end
    end
end

function Vendor:SetFilterMode(mode)
    mode = string.lower(tostring(mode or "all"))
    if mode ~= "all" and not self:HasCollections() then
        RB:Print("Ese filtro necesita RapzoBags_Collections. Activalo en la pantalla de AddOns.")
        mode = "all"
    end
    if not VALID_FILTERS[mode] then
        RB:Print("Filtro invalido. Usa: all, uncollected, mounts, transmog o recipes.")
        return
    end

    local cfg = getConfig()
    cfg.filterMode = mode
    self:ClearCollectionCache()
    self:BuildFilteredIndices()
    self:UpdateFilterButtons()

    if MerchantFrame then MerchantFrame.page = 1 end
    if self.ready and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
        MerchantFrame_Update()
    end
end

function Vendor:CaptureOriginalLayout()
    if not MerchantFrame then return end

    if not self.originalFrameWidth then
        self.originalFrameWidth, self.originalFrameHeight = MerchantFrame:GetSize()
    end
    self.originalItemsPerPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10

    if MerchantBuyBackItem and not self.originalBuyBackPoint then
        local point, relativeTo, relativePoint, xOfs, yOfs = MerchantBuyBackItem:GetPoint(1)
        self.originalBuyBackPoint = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end

    for i = 1, 12 do
        local frame = _G["MerchantItem" .. i]
        if frame and not self.originalSlotPoints[i] then
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
            self.originalSlotPoints[i] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs,
            }
        end
        if frame then
            self:PrepareSlot(frame)
        end
    end
end

function Vendor:RestoreMerchantBuyBackItem()
    local frame = MerchantBuyBackItem
    local pos = self.originalBuyBackPoint
    if not frame or not pos then return end

    frame:ClearAllPoints()
    frame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
end

function Vendor:PositionMerchantBuyBackItem()
    if not MerchantFrame or not MerchantBuyBackItem then return end

    -- Blizzard normally anchors this quick-buyback widget to MerchantItem10.
    -- In a 4-column grid MerchantItem10 moves into the middle of the grid, so
    -- keep the widget attached to the frame's bottom bar instead.
    MerchantBuyBackItem:ClearAllPoints()
    MerchantBuyBackItem:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -15, 33)
end

function Vendor:RestoreBuybackLayout()
    if not MerchantFrame then return end
    if self.filterBar then self.filterBar:Hide() end

    if self.originalFrameWidth and self.originalFrameHeight then
        MerchantFrame:SetSize(self.originalFrameWidth, self.originalFrameHeight)
    end
    self:RestoreMerchantBuyBackItem()

    for i = 1, 12 do
        local frame = _G["MerchantItem" .. i]
        local pos = self.originalSlotPoints[i]
        if frame and pos then
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
        end
    end

    local cfg = getConfig()
    local maxSlots = math.max(cfg.rows * cfg.columns, self.maxCreatedSlots or 12)
    for i = 13, maxSlots do
        local frame = _G["MerchantItem" .. i]
        if frame then frame:Hide() end
    end
end

function Vendor:RestoreDefaultMerchantLayout()
    if not MerchantFrame then return end
    if self.filterBar then self.filterBar:Hide() end

    if self.originalFrameWidth and self.originalFrameHeight then
        MerchantFrame:SetSize(self.originalFrameWidth, self.originalFrameHeight)
    end
    self:RestoreMerchantBuyBackItem()

    for i = 1, 10 do
        local frame = _G["MerchantItem" .. i]
        local pos = self.originalSlotPoints[i]
        if frame and pos then
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
        end
    end

    for i = 11, math.max(12, self.maxCreatedSlots or 12) do
        local frame = _G["MerchantItem" .. i]
        if frame then frame:Hide() end
    end
end

function Vendor:LayoutMerchantSlots()
    if not MerchantFrame or MerchantFrame.selectedTab ~= 1 then
        return
    end

    local cfg = getConfig()
    if not cfg.enabled then
        MERCHANT_ITEMS_PER_PAGE = self.originalItemsPerPage or 10
        self:RestoreDefaultMerchantLayout()
        return
    end

    local rows = cfg.rows
    local columns = cfg.columns
    local filterBar = self:CreateFilterBar()
    if filterBar then filterBar:Show() end
    self:UpdateFilterButtons()
    local total = rows * columns
    MERCHANT_ITEMS_PER_PAGE = total

    local sample = self:GetSlot(1)
    if not sample then return end
    local itemWidth, itemHeight = sample:GetSize()
    if not itemWidth or itemWidth <= 0 then itemWidth = 153 end
    if not itemHeight or itemHeight <= 0 then itemHeight = 44 end

    for index = 1, total do
        local frame = self:GetSlot(index)
        if frame then
            local row = math.floor((index - 1) / columns)
            local column = (index - 1) % columns
            frame:ClearAllPoints()
            frame:SetPoint(
                "TOPLEFT",
                MerchantFrame,
                "TOPLEFT",
                FIRST_X + column * (itemWidth + COLUMN_GAP),
                (FIRST_Y - FILTER_BAR_EXTRA_HEIGHT) - row * (itemHeight + ROW_GAP)
            )
        end
    end

    for i = total + 1, math.max(total, self.maxCreatedSlots or total) do
        local frame = _G["MerchantItem" .. i]
        if frame and i > total then frame:Hide() end
    end

    local baseWidth = self.originalFrameWidth or 336
    local baseHeight = self.originalFrameHeight or 444
    local extraColumns = math.max(0, columns - 2)
    local extraRows = math.max(0, rows - 5)
    local newWidth = baseWidth + extraColumns * (itemWidth + COLUMN_GAP)
    local newHeight = baseHeight + FILTER_BAR_EXTRA_HEIGHT + extraRows * (itemHeight + ROW_GAP)
    MerchantFrame:SetSize(newWidth, newHeight)
    self:PositionMerchantBuyBackItem()

    if MerchantFrameInset then
        MerchantFrameInset:ClearPoint("RIGHT")
        MerchantFrameInset:SetPoint("RIGHT", MerchantFrame, "RIGHT", -6, 0)
    end
end

function Vendor:ApplyCollectedVisuals()
    if not MerchantFrame or MerchantFrame.selectedTab ~= 1 then
        return
    end

    local cfg = getConfig()
    local total = cfg.enabled and (cfg.rows * cfg.columns) or (self.originalItemsPerPage or 10)

    for slotIndex = 1, total do
        local frame = _G["MerchantItem" .. slotIndex]
        if frame then
            self:PrepareSlot(frame)
            if frame.RapzoBagsCollectedTint then frame.RapzoBagsCollectedTint:Hide() end
            if frame.RapzoBagsCollectedMark then frame.RapzoBagsCollectedMark:Hide() end
            if frame.RapzoBagsOwnedCount then frame.RapzoBagsOwnedCount:Hide() end

            local button = frame.ItemButton
            local itemIndex = button and button:GetID() or nil
            local itemID = itemIndex and itemIndex > 0 and GetMerchantItemID and GetMerchantItemID(itemIndex) or nil

            if itemID and frame:IsShown() then
                local collected = false
                if cfg.markCollected then
                    collected = self:GetCollectionState(itemID)
                end
                local owned = cfg.showOwnedCount and self:GetOwnedCount(itemID) or 0

                if collected then
                    if frame.RapzoBagsCollectedTint then frame.RapzoBagsCollectedTint:Show() end
                    if frame.RapzoBagsCollectedMark then frame.RapzoBagsCollectedMark:Show() end
                    if frame.Name then
                        frame.Name:SetTextColor(0.22, 0.95, 0.40)
                    end
                    if SetItemButtonDesaturated and button then
                        SetItemButtonDesaturated(button, true)
                    end
                end

                if owned > 0 and frame.RapzoBagsOwnedCount then
                    frame.RapzoBagsOwnedCount:SetText(string.format("|cff38bdf8x%d|r", owned))
                    frame.RapzoBagsOwnedCount:Show()
                end
            end
        end
    end
end

function Vendor:Refresh()
    if not self.ready or not MerchantFrame or not MerchantFrame:IsShown() then
        return
    end

    if MerchantFrame.selectedTab == 1 then
        self:LayoutMerchantSlots()
        self:ApplyCollectedVisuals()
    else
        self:RestoreBuybackLayout()
    end
end

function Vendor:SetupMerchantFrame()
    if self.ready then
        return true
    end
    if not MerchantFrame or not _G.MerchantItem1 then
        return false
    end

    if isKrowiLoaded() then
        if not self.conflictWarned then
            self.conflictWarned = true
            RB:Print("Krowi Extended Vendor UI esta activo. Desactivo el vendedor extendido de Rapzo QoL para evitar conflictos.")
        end
        return false
    end

    self:CaptureOriginalLayout()
    self:WrapMerchantAPIs()
    self:BuildFilteredIndices()
    self:CreateFilterBar()

    local cfg = getConfig()
    local wantedSlots = cfg.rows * cfg.columns
    for i = 1, wantedSlots do
        self:GetSlot(i)
    end

    self.ready = true

    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
        if not Vendor.ready then return end
        Vendor:LayoutMerchantSlots()
        Vendor:ApplyCollectedVisuals()
    end)

    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
        if not Vendor.ready then return end
        Vendor:RestoreBuybackLayout()
    end)

    hooksecurefunc("MerchantFrame_UpdateAltCurrency", function(visibleIndex, indexOnPage)
        if not Vendor.ready or not Vendor:IsFilterActive() then return end
        local originalIndex = Vendor:MapVisibleIndex(visibleIndex)
        if not originalIndex then return end
        local frameName = "MerchantItem" .. tostring(indexOnPage) .. "AltCurrencyFrame"
        local maxCost = tonumber(MAX_ITEM_COST) or 3
        for i = 1, maxCost do
            local button = _G[frameName .. "Item" .. i]
            if button then button.index = originalIndex end
        end
    end)

    return true
end

function Vendor:SetGrid(columns, rows)
    local cfg = getConfig()
    cfg.columns = clamp(columns, MIN_COLUMNS, MAX_COLUMNS)
    cfg.rows = clamp(rows, MIN_ROWS, MAX_ROWS)

    if self.ready then
        local wantedSlots = cfg.rows * cfg.columns
        for i = 1, wantedSlots do
            self:GetSlot(i)
        end
        if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
            MerchantFrame.page = 1
            self:LayoutMerchantSlots()
            MerchantFrame_Update()
        end
    end

    RB:Print(string.format("Vendedor configurado a %d columnas x %d filas (%d objetos por pagina).", cfg.columns, cfg.rows, cfg.columns * cfg.rows))
end

function Vendor:SetEnabled(enabled)
    local cfg = getConfig()
    cfg.enabled = enabled and true or false
    RB:SetFeatureEnabled("vendor", cfg.enabled, true)
    if self.ready and MerchantFrame and MerchantFrame:IsShown() then
        MerchantFrame.page = 1
        if cfg.enabled then
            self:LayoutMerchantSlots()
        else
            MERCHANT_ITEMS_PER_PAGE = self.originalItemsPerPage or 10
            self:RestoreDefaultMerchantLayout()
        end
        MerchantFrame_Update()
    end
    RB:Print(cfg.enabled and "Vendedor extendido activado." or "Vendedor extendido desactivado.")
end

function Vendor:SetCollectedMark(enabled)
    local cfg = getConfig()
    cfg.markCollected = enabled and true or false
    if self.ready and MerchantFrame and MerchantFrame:IsShown() and type(MerchantFrame_Update) == "function" then
        MerchantFrame_Update()
    else
        self:Refresh()
    end
    RB:Print(cfg.markCollected and "Marcado de coleccionables obtenidos activado." or "Marcado de coleccionables obtenidos desactivado.")
end

function Vendor:PrintStatus()
    local cfg = getConfig()
    RB:Print(string.format(
        "Vendedor: %s | %dx%d = %d objetos/pagina | filtro: %s | obtenidos: %s | conteo propio: %s",
        cfg.enabled and "ON" or "OFF",
        cfg.columns,
        cfg.rows,
        cfg.columns * cfg.rows,
        cfg.filterMode,
        cfg.markCollected and "ON" or "OFF",
        cfg.showOwnedCount and "ON" or "OFF"
    ))
end

function Vendor:HandleSlash(rest)
    rest = trim(rest)
    local first, second = rest:match("^(%S*)%s*(.-)$")
    first = string.lower(first or "")
    second = trim(second)

    if first == "" or first == "status" then
        self:PrintStatus()
        return true
    end

    if first == "on" then
        self:SetEnabled(true)
        return true
    elseif first == "off" then
        self:SetEnabled(false)
        return true
    elseif first == "collected" or first == "obtenidos" then
        local value = string.lower(second)
        if value == "on" then
            self:SetCollectedMark(true)
        elseif value == "off" then
            self:SetCollectedMark(false)
        else
            RB:Print("Uso: /rapzo vendor obtenidos on|off")
        end
        return true
    elseif first == "filter" or first == "filtro" then
        local aliases = {
            todos = "all", all = "all",
            noobtenidos = "uncollected", uncollected = "uncollected",
            monturas = "mounts", mounts = "mounts",
            transmog = "transmog",
            recetas = "recipes", recipes = "recipes",
        }
        self:SetFilterMode(aliases[string.lower(second)] or string.lower(second))
        return true
    elseif first == "reset" then
        self:SetGrid(DEFAULT_COLUMNS, DEFAULT_ROWS)
        self:SetFilterMode("all")
        return true
    end

    local columns, rows = rest:match("^(%d+)%s*[xX]%s*(%d+)$")
    if columns and rows then
        self:SetGrid(tonumber(columns), tonumber(rows))
        return true
    end

    if first == "grid" then
        columns, rows = second:match("^(%d+)%s*[xX]%s*(%d+)$")
        if columns and rows then
            self:SetGrid(tonumber(columns), tonumber(rows))
        else
            RB:Print("Uso: /rapzo vendor 4x5")
        end
        return true
    end

    RB:Print("Uso: /rapzo vendor [status|on|off|4x5|filter all|uncollected|mounts|transmog|recipes|obtenidos on|off|reset]")
    return true
end

function Vendor:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    getConfig()

    local events = CreateFrame("Frame")
    self.eventFrame = events

    local function register(event)
        pcall(events.RegisterEvent, events, event)
    end

    register("ADDON_LOADED")
    register("MERCHANT_SHOW")
    register("MERCHANT_UPDATE")
    register("BAG_UPDATE_DELAYED")
    register("TOYS_UPDATED")
    register("PET_JOURNAL_LIST_UPDATE")
    register("NEW_MOUNT_ADDED")
    register("TRANSMOG_COLLECTION_UPDATED")
    register("HEIRLOOMS_UPDATED")
    register("NEW_RECIPE_LEARNED")
    register("GET_ITEM_INFO_RECEIVED")

    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_UIPanels_Game" then
                Vendor:SetupMerchantFrame()
            end
            return
        end

        if event == "MERCHANT_SHOW" then
            if not Vendor.ready then
                Vendor:SetupMerchantFrame()
            end
            if Vendor.ready then
                local cfg = getConfig()
                Vendor:ClearCollectionCache()
                Vendor:BuildFilteredIndices()
                MERCHANT_ITEMS_PER_PAGE = cfg.enabled and (cfg.rows * cfg.columns) or (Vendor.originalItemsPerPage or 10)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if MerchantFrame and MerchantFrame:IsShown() then
                            MerchantFrame_Update()
                        end
                    end)
                else
                    MerchantFrame_Update()
                end
            end
            return
        end

        if Vendor.ready and MerchantFrame and MerchantFrame:IsShown() then
            Vendor:ClearCollectionCache()
            Vendor:BuildFilteredIndices()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, function()
                    if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 and type(MerchantFrame_Update) == "function" then
                        MerchantFrame_Update()
                    else
                        Vendor:Refresh()
                    end
                end)
            else
                if MerchantFrame.selectedTab == 1 and type(MerchantFrame_Update) == "function" then
                    MerchantFrame_Update()
                else
                    Vendor:Refresh()
                end
            end
        end
    end)

    self:SetupMerchantFrame()
end


RB:RegisterCommand("vendor", function(rest) Vendor:HandleSlash(rest) end, "/rapzo vendor [status|on|off|4x5|filter ...] - configura el vendedor")
Vendor:Initialize()
