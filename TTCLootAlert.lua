TTCLootAlert = TTCLootAlert or {}
TTCLootAlert.name = "TTCLootAlert"
TTCLootAlert.author = "@Leahcim70"

local DEFAULT_THRESHOLD_GOLD = 1000
local THRESHOLD_GOLD = DEFAULT_THRESHOLD_GOLD
local LANGUAGE_CODE = "en"

local DEFAULT_LOCALIZATION = {
    lootMessage = "|cFFD700[TTC]|r %s: Suggested %sg (x%d = %sg)",
    thresholdCurrent = "|cFFD700[TTC]|r Current threshold: %sg. Use /ttcalert <gold> to set.",
    invalidValue = "|cFFD700[TTC]|r Invalid value. Use /ttcalert <gold>.",
    thresholdSet = "|cFFD700[TTC]|r Threshold set to %sg.",
    addonLoaded = "|cFFD700[TTC]|r %s by %s loaded (threshold: %sg).",
}

local function LoadLocalization()
    local localization = TTCLootAlert_Localization or {}
    local english = localization.en or {}
    setmetatable(english, { __index = DEFAULT_LOCALIZATION })
    local langCode = "en"

    if GetCVar then
        langCode = (GetCVar("Language.2") or "en"):lower()
    end

    if langCode ~= "en" then
        local localized = localization[langCode]
        if localized then
            setmetatable(localized, { __index = english })
            LANGUAGE_CODE = langCode
            TTCLootAlert.langCode = langCode
            return localized
        end
    end

    LANGUAGE_CODE = langCode
    TTCLootAlert.langCode = langCode
    return english
end

local L = LoadLocalization()

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

local function GetTTCSuggestedPrice(itemLink)
    if not itemLink or itemLink == "" then return nil end
    if not TamrielTradeCentrePrice or not TamrielTradeCentrePrice.GetPriceInfo then return nil end

    local info = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
    if not info then return nil end

    -- TTC PriceInfo: SuggestedPrice = suggested price low (high = *1.25)
    local suggested = info.SuggestedPrice
    if not suggested then return nil end

    return tonumber(suggested)
end

local function OnLootReceived(eventCode, lootedBy, itemLink, quantity, itemSound, lootType, lootedBySelf, isStolen)
    if not lootedBySelf then return end
    if not itemLink or itemLink == "" then return end

    local suggested = GetTTCSuggestedPrice(itemLink)
    if not suggested or suggested < THRESHOLD_GOLD then return end

    quantity = tonumber(quantity) or 1
    local total = suggested * quantity

    Chat(string.format(L.lootMessage, itemLink, FormatGold(suggested), quantity, FormatGold(total)))
end

local function RegisterSlashCommand()
    local function HandleSlashCommand(text)
        local trimmed = (text or ""):match("^%s*(.-)%s*$")
        if trimmed == "" then
            Chat(string.format(L.thresholdCurrent, FormatGold(THRESHOLD_GOLD)))
            return
        end

        local newThreshold = tonumber(trimmed)
        if not newThreshold then
            Chat(L.invalidValue)
            return
        end

        if newThreshold < 0 then newThreshold = 0 end

        THRESHOLD_GOLD = newThreshold
        TTCLootAlert.savedVars.threshold = newThreshold
        Chat(string.format(L.thresholdSet, FormatGold(newThreshold)))
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
        Chat(string.format(L.addonLoaded, TTCLootAlert.name, TTCLootAlert.author, FormatGold(THRESHOLD_GOLD)))
    end

    EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(TTCLootAlert.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
