local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

-- Rapzo QoL: automatically prefer content from the current expansion in
-- Auction House and customer Crafting Orders searches.
local ExpansionFilters = {}
RB.ExpansionFilters = ExpansionFilters
RB:RegisterModule("expansionFilters", ExpansionFilters)

ExpansionFilters.auctionHouseHooked = false
ExpansionFilters.craftingOrdersHooked = false

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function getCurrentExpansionFilter()
    return Enum
        and Enum.AuctionHouseFilter
        and Enum.AuctionHouseFilter.CurrentExpansionOnly
end

local function getAuctionHouseSearchBar(searchBar)
    if searchBar then return searchBar end
    local frame = _G.AuctionHouseFrame
    return frame and frame.SearchBar or nil
end

local function applyAuctionHouseFilter(searchBar)
    if not RB:IsFeatureEnabled("expansionFilters") then return false end

    local currentExpansionOnly = getCurrentExpansionFilter()
    if currentExpansionOnly == nil then return false end

    searchBar = getAuctionHouseSearchBar(searchBar)

    -- We only change the filter state; we never send a browse query ourselves.
    -- Collect every filter table Blizzard may be reading from: the file-level
    -- state exposed as a global (when it is one) and the live FilterButton's
    -- own table on the search bar.
    local applied = false

    local state = _G.g_auctionHouseFilters
    local filters = state and state.filters
    if type(filters) == "table" then
        filters[currentExpansionOnly] = true
        applied = true
    end

    local filterButton = searchBar and searchBar.FilterButton
    if filterButton and type(filterButton.filters) == "table" then
        filterButton.filters[currentExpansionOnly] = true
        applied = true
    end

    if not applied then return false end

    -- Keep the reset/clear-filters visual state in sync when the search bar
    -- already exists.
    if searchBar and type(searchBar.UpdateClearFiltersButton) == "function" then
        safeCall(searchBar.UpdateClearFiltersButton, searchBar)
    end

    return true
end

local function getCraftingOrdersBrowsePage(browsePage)
    if browsePage and browsePage.SearchBar then
        return browsePage
    end

    local frame = _G.ProfessionsCustomerOrdersFrame
    return frame and frame.BrowseOrders or nil
end

local function applyCraftingOrdersFilter(browsePage)
    if not RB:IsFeatureEnabled("expansionFilters") then return false end

    local currentExpansionOnly = getCurrentExpansionFilter()
    browsePage = getCraftingOrdersBrowsePage(browsePage)
    if currentExpansionOnly == nil or not browsePage then return false end

    local searchBar = browsePage.SearchBar
    local dropdown = searchBar and searchBar.FilterDropdown
    if not dropdown then return false end

    local filters = dropdown.filters
    if type(filters) ~= "table" then
        -- Blizzard normally creates this table in SetDefaultFilters(). Start
        -- from an empty set (its own Init/SetDefaultFilters fills the real
        -- defaults) rather than copying foreign Auction House defaults.
        filters = {}
        dropdown.filters = filters
    end

    filters[currentExpansionOnly] = true

    -- Keep the reset-X state synchronized with Blizzard's filter dropdown.
    if type(dropdown.ValidateResetState) == "function" then
        safeCall(dropdown.ValidateResetState, dropdown)
    end

    return filters[currentExpansionOnly] == true
end

local function scheduleCraftingOrdersFilter(browsePage)
    applyCraftingOrdersFilter(browsePage)

    -- A zero-delay pass runs after the complete Blizzard OnShow/Init chain.
    -- This is important because BrowseOrders:Init() calls SetDefaultFilters()
    -- every time the customer-order window opens.
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            applyCraftingOrdersFilter(browsePage)
        end)
    end
end

function ExpansionFilters:HookAuctionHouse()
    if not self.auctionHouseHooked
        and type(hooksecurefunc) == "function"
        and type(AuctionHouseSearchBarMixin) == "table"
        and type(AuctionHouseSearchBarMixin.OnShow) == "function"
    then
        self.auctionHouseHooked = true

        -- OnShow runs whenever the AH search bar is shown. This means that even if
        -- the player manually disables the filter, closing/reopening the AH restores
        -- "Current Expansion Only" automatically.
        hooksecurefunc(AuctionHouseSearchBarMixin, "OnShow", function(searchBar)
            applyAuctionHouseFilter(searchBar)
        end)
    end

    -- Mixin hooks do not fire for a frame that copied OnShow before the hook
    -- was installed (the search bar is created while Blizzard_AuctionHouseUI
    -- loads), so hook the live frame directly as well.
    local searchBar = getAuctionHouseSearchBar(nil)
    if searchBar and type(searchBar.HookScript) == "function" and not searchBar.RapzoQoLExpansionFilterHooked then
        searchBar.RapzoQoLExpansionFilterHooked = true
        searchBar:HookScript("OnShow", function(bar)
            applyAuctionHouseFilter(bar)
        end)
    end

    -- The saved filter table already exists once Blizzard_AuctionHouseUI loads,
    -- so seed it immediately as well.
    applyAuctionHouseFilter(searchBar)
end

function ExpansionFilters:HookCraftingOrders()
    if self.craftingOrdersHooked then
        scheduleCraftingOrdersFilter(nil)
        return
    end

    if type(ProfessionsCustomerOrdersBrowsePageMixin) ~= "table"
        or type(ProfessionsCustomerOrdersBrowsePageMixin.SetDefaultFilters) ~= "function"
        or type(hooksecurefunc) ~= "function"
    then
        return
    end

    self.craftingOrdersHooked = true

    -- Blizzard resets this table inside BrowseOrders:Init(). Re-apply our
    -- preference immediately after that reset.
    hooksecurefunc(ProfessionsCustomerOrdersBrowsePageMixin, "SetDefaultFilters", function(browsePage)
        applyCraftingOrdersFilter(browsePage)
    end)

    -- This second hook is the definitive guard: it runs after SetDefaultFilters
    -- AND InitFilterDropdown have both finished.
    if type(ProfessionsCustomerOrdersBrowsePageMixin.Init) == "function" then
        hooksecurefunc(ProfessionsCustomerOrdersBrowsePageMixin, "Init", function(browsePage)
            scheduleCraftingOrdersFilter(browsePage)
        end)
    end

    -- Hook the real Blizzard frame too. This protects the preference even if
    -- another addon calls/rearranges the mixin methods during the same OnShow.
    local frame = _G.ProfessionsCustomerOrdersFrame
    if frame and type(frame.HookScript) == "function" and not frame.RapzoQoLExpansionFilterHooked then
        frame.RapzoQoLExpansionFilterHooked = true
        frame:HookScript("OnShow", function(customerOrdersFrame)
            scheduleCraftingOrdersFilter(customerOrdersFrame and customerOrdersFrame.BrowseOrders)
        end)
    end

    -- If the Blizzard UI was already open by the time the module hooked it,
    -- update the existing frame immediately instead of waiting for reopen.
    scheduleCraftingOrdersFilter(frame and frame.BrowseOrders)
end

function ExpansionFilters:TryHookLoadedBlizzardUI()
    if type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
        if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
            self:HookAuctionHouse()
        end
        if C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
            self:HookCraftingOrders()
        end
        return
    end

    if type(IsAddOnLoaded) == "function" then
        if IsAddOnLoaded("Blizzard_AuctionHouseUI") then
            self:HookAuctionHouse()
        end
        if IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
            self:HookCraftingOrders()
        end
    end
end

function ExpansionFilters:Initialize()
    if self.initialized then return end
    self.initialized = true

    local events = CreateFrame("Frame")
    self.eventFrame = events
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon == "Blizzard_AuctionHouseUI" then
            ExpansionFilters:HookAuctionHouse()
        elseif loadedAddon == "Blizzard_ProfessionsCustomerOrders" then
            ExpansionFilters:HookCraftingOrders()
        end
    end)

    self:TryHookLoadedBlizzardUI()
end

RB:RegisterCommand("expfilter", function(rest)
    rest = string.lower(tostring(rest or "")):match("^%s*(%S*)") or ""
    if rest == "on" then
        RB:SetFeatureEnabled("expansionFilters", true)
    elseif rest == "off" then
        RB:SetFeatureEnabled("expansionFilters", false)
    else
        RB:Print("Filtro de expansion actual: "
            .. (RB:IsFeatureEnabled("expansionFilters") and "ON" or "OFF")
            .. " | Uso: /rapzo expfilter on|off")
    end
end, "/rapzo expfilter on|off - filtro 'solo expansion actual' en AH y pedidos")

ExpansionFilters:Initialize()
