local TTCLootAlert = TTCLootAlert or {}
TTCLootAlert.name = "TTCLootAlert"
TTCLootAlert.author = "@Leahcim70"

local DEFAULT_THRESHOLD_GOLD = 1000
local DEFAULT_DEBUG_ENABLED = false
local THRESHOLD_GOLD = DEFAULT_THRESHOLD_GOLD
local DEBUG_ENABLED = DEFAULT_DEBUG_ENABLED

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

local function Debug(msg)
    if not DEBUG_ENABLED then return end
    Chat("|cFFD700[LootAlert-DBG]|r " .. tostring(msg))
end

local missingLibPriceWarned = false
local function GetLibPriceGold(itemLink)
    if not itemLink or itemLink == "" then return nil end
    if not LibPrice or not LibPrice.ItemLinkToPriceGold then return nil end

    local gold = LibPrice.ItemLinkToPriceGold(itemLink)
    return tonumber(gold)
end

local function OnLootReceived(eventCode, lootedBy, itemLink, quantity, itemSound, lootType, lootedBySelf, isStolen)
    Debug(string.format("EVENT_LOOT_RECEIVED: self=%s item=%s qty=%s stolen=%s", tostring(lootedBySelf), tostring(itemLink), tostring(quantity), tostring(isStolen)))
    if not lootedBySelf then return end
    if not itemLink or itemLink == "" then return end

    local suggested = GetLibPriceGold(itemLink)
    if not suggested then
        if not LibPrice or not LibPrice.ItemLinkToPriceGold then
            if not missingLibPriceWarned then
                Debug("LibPrice missing or ItemLinkToPriceGold not available.")
                missingLibPriceWarned = true
            end
        else
            Debug("LibPrice returned nil for item.")
        end
        return
    end
    if suggested < THRESHOLD_GOLD then
        Debug(string.format("Below threshold: %s < %s", tostring(suggested), tostring(THRESHOLD_GOLD)))
        return
    end

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

    local function HandleDebugCommand(text)
        local trimmed = (text or ""):match("^%s*(.-)%s*$"):lower()
        if trimmed == "" then
            Chat(string.format("|cFFD700[LootAlert-DBG]|r Debug %s.", DEBUG_ENABLED and "enabled" or "disabled"))
            return
        end

        if trimmed == "on" or trimmed == "1" or trimmed == "true" then
            DEBUG_ENABLED = true
            TTCLootAlert.savedVars.debug = true
            Chat("|cFFD700[LootAlert-DBG]|r Debug enabled.")
            return
        end

        if trimmed == "off" or trimmed == "0" or trimmed == "false" then
            DEBUG_ENABLED = false
            TTCLootAlert.savedVars.debug = false
            Chat("|cFFD700[LootAlert-DBG]|r Debug disabled.")
            return
        end

        Chat("|cFFD700[LootAlert-DBG]|r Usage: /ttcalertdebug [on|off]")
    end

    SLASH_COMMANDS["/ttcalertdebug"] = HandleDebugCommand
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= TTCLootAlert.name then return end
    EVENT_MANAGER:UnregisterForEvent(TTCLootAlert.name, EVENT_ADD_ON_LOADED)

    TTCLootAlert.savedVars = ZO_SavedVars:NewAccountWide("TTCLootAlertSavedVariables", 1, nil, {
        threshold = DEFAULT_THRESHOLD_GOLD,
        debug = DEFAULT_DEBUG_ENABLED,
    })
    THRESHOLD_GOLD = TTCLootAlert.savedVars.threshold or DEFAULT_THRESHOLD_GOLD
    DEBUG_ENABLED = TTCLootAlert.savedVars.debug ~= false

    RegisterSlashCommand()
    EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_LOOT_RECEIVED, OnLootReceived)
    Debug(string.format("Addon loaded, events registered. LibPrice=%s", tostring(LibPrice ~= nil)))

    local function OnPlayerActivated()
        EVENT_MANAGER:UnregisterForEvent(TTCLootAlert.name, EVENT_PLAYER_ACTIVATED)
        Chat(string.format(GetString(TTCLootAlert_ADDON_LOADED), TTCLootAlert.name, FormatGold(THRESHOLD_GOLD)))
        Debug(string.format("Player activated. Threshold=%s Debug=%s", tostring(THRESHOLD_GOLD), tostring(DEBUG_ENABLED)))
    end

    EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
