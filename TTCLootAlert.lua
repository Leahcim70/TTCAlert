TTCLootAlert = TTCLootAlert or {}
TTCLootAlert.name = "TTCLootAlert"
TTCLootAlert.author = "@Leahcim70"

local DEFAULT_THRESHOLD_GOLD = 1000
local THRESHOLD_GOLD = DEFAULT_THRESHOLD_GOLD

local function FormatGold(n)
    n = tonumber(n) or 0
    return zo_strformat("<<1>>", ZO_CommaDelimitNumber(n))
end

local function Chat(msg)
    -- "Vanilla"-Systemmessage (sauberer als d())
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(msg)
    else
        CHAT_SYSTEM:AddMessage(msg)
    end
end

local function GetLibPriceGold(itemLink)
    if not itemLink or itemLink == "" then return nil end
    if not LibPrice or not LibPrice.ItemLinkToPriceGold then return nil end

    local gold = LibPrice.ItemLinkToPriceGold(itemLink)
    return tonumber(gold)
end

local function OnLootReceived(eventCode, lootedBy, itemLink, quantity, itemSound, lootType, lootedBySelf, isStolen)
    if not lootedBySelf then return end
    if not itemLink or itemLink == "" then return end

    local suggested = GetLibPriceGold(itemLink)
    if not suggested or suggested < THRESHOLD_GOLD then return end

    quantity = tonumber(quantity) or 1
    local total = suggested * quantity

    Chat(string.format(GetString(TTCLootAlert_LOOT_MESSAGE), itemLink, FormatGold(suggested), quantity, FormatGold(total)))
end

local function RegisterSlashCommand()
    local function HandleSlashCommand(text)
        local trimmed = (text or ""):match("^%s*(.-)%s*$")
        if trimmed == "" then
            Chat(string.format(GetString(TTCLootAlert_THRESHOLD_CURRENT), FormatGold(THRESHOLD_GOLD)))
            return
        end

        local newThreshold = tonumber(trimmed)
        if not newThreshold then
            Chat(GetString(TTCLootAlert_INVALID_VALUE))
            return
        end

        if newThreshold < 0 then newThreshold = 0 end

        THRESHOLD_GOLD = newThreshold
        TTCLootAlert.savedVars.threshold = newThreshold
        Chat(string.format(GetString(TTCLootAlert_THRESHOLD_SET), FormatGold(newThreshold)))
    end

    SLASH_COMMANDS["/ttcalert"] = HandleSlashCommand
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= TTCLootAlert.name then return end
    EVENT_MANAGER:UnregisterForEvent(TTCLootAlert.name, EVENT_ADD_ON_LOADED)

    TTCLootAlert.savedVars = ZO_SavedVars:NewAccountWide("TTCLootAlertSavedVariables", 1, nil, {
        threshold = DEFAULT_THRESHOLD_GOLD,
    })
    THRESHOLD_GOLD = TTCLootAlert.savedVars.threshold or DEFAULT_THRESHOLD_GOLD

    RegisterSlashCommand()
    EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_LOOT_RECEIVED, OnLootReceived)

    local function OnPlayerActivated()
        EVENT_MANAGER:UnregisterForEvent(TTCLootAlert.name, EVENT_PLAYER_ACTIVATED)
        Chat(string.format(GetString(TTCLootAlert_ADDON_LOADED), TTCLootAlert.name, FormatGold(THRESHOLD_GOLD)))
    end

    EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
