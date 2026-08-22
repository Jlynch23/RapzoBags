local RB = _G.RapzoBags
if not RB or not RB.Vendor then return end

local Vendor = RB.Vendor
local originalBuybackPoint

local function captureOriginalBuybackPoint()
    if originalBuybackPoint or not MerchantBuyBackItem then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = MerchantBuyBackItem:GetPoint(1)
    if not point then return end

    originalBuybackPoint = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs,
    }
end

local function restoreBuybackPoint()
    if not MerchantBuyBackItem then return end

    captureOriginalBuybackPoint()
    if not originalBuybackPoint then return end

    MerchantBuyBackItem:ClearAllPoints()
    MerchantBuyBackItem:SetPoint(
        originalBuybackPoint.point,
        originalBuybackPoint.relativeTo,
        originalBuybackPoint.relativePoint,
        originalBuybackPoint.xOfs,
        originalBuybackPoint.yOfs
    )
end

local function anchorBuybackToExtendedGrid()
    if not MerchantFrame or MerchantFrame.selectedTab ~= 1 or not MerchantBuyBackItem then
        return
    end

    local db = RB:EnsureDB()
    local cfg = db and db.settings and db.settings.vendor
    if not cfg or cfg.enabled == false then
        restoreBuybackPoint()
        return
    end

    local rows = tonumber(cfg.rows) or 5
    local columns = tonumber(cfg.columns) or 4
    local lastSlot = _G["MerchantItem" .. tostring(rows * columns)]
    if not lastSlot then return end

    captureOriginalBuybackPoint()

    -- Blizzard anchors MerchantBuyBackItem to MerchantItem10 because the
    -- stock merchant grid is 2x5. RapzoBags expands that grid, so item 10 can
    -- sit in the middle of the window. Keep the undo/buyback control attached
    -- to the actual final slot instead.
    MerchantBuyBackItem:ClearAllPoints()
    MerchantBuyBackItem:SetPoint("TOPLEFT", lastSlot, "BOTTOMLEFT", 30, -53)
end

hooksecurefunc(Vendor, "LayoutMerchantSlots", anchorBuybackToExtendedGrid)
hooksecurefunc(Vendor, "RestoreBuybackLayout", restoreBuybackPoint)
hooksecurefunc(Vendor, "RestoreDefaultMerchantLayout", restoreBuybackPoint)
