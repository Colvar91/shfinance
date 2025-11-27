-----------------------------------------
-- SH FINANZEN - CORE
-----------------------------------------

-- SavedVariables vorbereiten
if not SHFinanzenDB then SHFinanzenDB = {} end
if not SHFinanzenDB.transactions then SHFinanzenDB.transactions = {} end
if SHFinanzenDB.balance       == nil then SHFinanzenDB.balance       = 0      end
if SHFinanzenDB.daily         == nil then SHFinanzenDB.daily         = 0      end  -- Tageslohn (Silber)
if SHFinanzenDB.dailyExpense  == nil then SHFinanzenDB.dailyExpense  = 0      end  -- Lebensunterhalt (Silber)
if SHFinanzenDB.rent          == nil then SHFinanzenDB.rent          = 0      end  -- Miete (Silber/Monat)
if SHFinanzenDB.lease         == nil then SHFinanzenDB.lease         = 0      end  -- Pacht (Silber/Monat)
if SHFinanzenDB.lastPayout    == nil then SHFinanzenDB.lastPayout    = ""     end  -- letztes Tagesdatum
if SHFinanzenDB.lastMonth     == nil then SHFinanzenDB.lastMonth     = ""     end  -- letzter Monat
if SHFinanzenDB.initialSet    == nil then SHFinanzenDB.initialSet    = false  end  -- Startkapital gesetzt?

-----------------------------------------
-- Hauptfenster
-----------------------------------------
local frame = CreateFrame("Frame", "SHFinanzenFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(445, 400)
frame:SetClampedToScreen(true)

-----------------------------------------
-- Fensterposition speichern / laden
-----------------------------------------
local function RestorePos()
    frame:ClearAllPoints()
    if SHFinanzenDB.point then
        frame:SetPoint(
            SHFinanzenDB.point,
            UIParent,
            SHFinanzenDB.relativePoint,
            SHFinanzenDB.xOfs,
            SHFinanzenDB.yOfs
        )
    else
        frame:SetPoint("CENTER")
    end
end

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    SHFinanzenDB.point         = p
    SHFinanzenDB.relativePoint = rp
    SHFinanzenDB.xOfs          = x
    SHFinanzenDB.yOfs          = y
end)

-----------------------------------------
-- Titel
-----------------------------------------
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", 0, -5)

-----------------------------------------
-- TAB 1: Übersicht (Design)
-----------------------------------------
local overview = CreateFrame("Frame", nil, frame)
overview:SetPoint("TOPLEFT", 15, -70)
overview:SetPoint("BOTTOMRIGHT", -15, 15)

-------------------------------------------------
-- RP-Name aus TotalRP3 (falls vorhanden)
-------------------------------------------------
local function GetRPNameColored()

    local default = UnitName("player")

    if not TRP3_API or not TRP3_API.profile or not TRP3_API.profile.getData then
        return default
    end

    local p = TRP3_API.profile.getData("player")
    if not p or not p.characteristics then return default end

    local C = p.characteristics
    local FN = C.FN or ""

    -- Name formen
    local name = (FN .. " "):gsub("%s+"," "):gsub("^%s*(.-)%s*$","%1")
    if name == "" then name = default end

    -- 🔥 Jetzt korrekt mit CH-Farbcode
    if C.CH and C.CH ~= "" then
        return "|cff" .. C.CH .. name .. "|r"
    end

    return name -- fallback
end

-- Begrüßung
local helloText = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
helloText:SetPoint("TOP", 0, 5)
helloText:SetFont(helloText:GetFont(), 16, "OUTLINE")
helloText:SetText("|cffffffaaLade RP-Name...|r")

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function()
    C_Timer.After(0.3, function()
        helloText:SetText("Hallo " .. GetRPNameColored() .. "!")
    end)
end)

-- Linie oberhalb Kontostand
local line_top = overview:CreateTexture(nil, "BACKGROUND")
line_top:SetColorTexture(1, 1, 1, 0.25)
line_top:SetPoint("TOP", helloText, "BOTTOM", 0, -6)
line_top:SetSize(260, 1)

-- Titel "Kontostand"
local title = overview:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", line_top, "BOTTOM", 0, -10)
title:SetText("|cffffd700Kontostand|r")

-- Kontostand-Anzeige
local balanceDisplay = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
balanceDisplay:SetPoint("TOP", title, "BOTTOM", 0, -14)
balanceDisplay:SetFont(balanceDisplay:GetFont(), 16, "OUTLINE")

-- Linie unter Kontostand
local line_mid = overview:CreateTexture(nil, "BACKGROUND")
line_mid:SetColorTexture(1, 1, 1, 0.20)
line_mid:SetPoint("TOP", balanceDisplay, "BOTTOM", 0, -10)
line_mid:SetSize(260, 1)

-- "Tägliche Finanzen"
local dailyHeader = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dailyHeader:SetPoint("TOP", line_mid, "BOTTOM", 0, -10)
dailyHeader:SetText("|cffffff00Tägliche Finanzen|r")

local dailyText = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dailyText:SetPoint("TOP", dailyHeader, "BOTTOM", 0, -6)

-- Linie zwischen täglich / monatlich
local line_bottom = overview:CreateTexture(nil, "BACKGROUND")
line_bottom:SetColorTexture(1, 1, 1, 0.20)
line_bottom:SetPoint("TOP", dailyText, "BOTTOM", 0, -10)
line_bottom:SetSize(260, 1)

-- "Monatliche Finanzen"
local monthlyHeader = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
monthlyHeader:SetPoint("TOP", line_bottom, "BOTTOM", 0, -10)
monthlyHeader:SetText("|cffffff00Monatliche Finanzen|r")

local rentText = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
rentText:SetPoint("TOP", monthlyHeader, "BOTTOM", 0, -6)

local pachtText = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pachtText:SetPoint("TOP", rentText, "BOTTOM", 0, 0  )

-------------------------------------------------
-- Anzeige aktualisieren
-------------------------------------------------
local function UpdateOverview()
    local bal = SHFinanzenDB.balance or 0
    local g = math.floor(bal / 10000)
    local s = math.floor((bal % 10000) / 100)
    local c = bal % 100

    balanceDisplay:SetText(
        g .. " |TInterface\\MONEYFRAME\\UI-GoldIcon:12:12|t  " ..
        s .. " |TInterface\\MONEYFRAME\\UI-SilverIcon:12:12|t  " ..
        c .. " |TInterface\\MONEYFRAME\\UI-CopperIcon:12:12|t"
    )

    dailyText:SetText(
        "Tageslohn: " .. (SHFinanzenDB.daily or 0) .. " Silber\n" ..
        "Lebensunterhalt: " .. (SHFinanzenDB.dailyExpense or 0) .. " Silber"
    )

    rentText:SetText("Miete: " .. (SHFinanzenDB.rent or 0) .. " Silber")
    pachtText:SetText("Pacht: " .. (SHFinanzenDB.lease or 0) .. " Silber")
end

-----------------------------------------
-- TAB 2: Transaktionen
-----------------------------------------
local transactions = CreateFrame("Frame", nil, frame)
transactions:SetPoint("TOPLEFT", 15, -70)
transactions:SetPoint("BOTTOMRIGHT", -15, 15)
transactions:Hide()

local header = transactions:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOPLEFT", 0, 0)
header:SetText("Neue Transaktion hinzufügen")

transactions.type = "income"

local incomeBtn = CreateFrame("CheckButton", nil, transactions, "UIRadioButtonTemplate")
incomeBtn:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
incomeBtn.text:SetText("Einnahme")
incomeBtn:SetChecked(true)

local expenseBtn = CreateFrame("CheckButton", nil, transactions, "UIRadioButtonTemplate")
expenseBtn:SetPoint("LEFT", incomeBtn, "RIGHT", 80, 0)
expenseBtn.text:SetText("Ausgabe")

incomeBtn:SetScript("OnClick", function()
    transactions.type = "income"
    incomeBtn:SetChecked(true)
    expenseBtn:SetChecked(false)
end)

expenseBtn:SetScript("OnClick", function()
    transactions.type = "expense"
    expenseBtn:SetChecked(true)
    incomeBtn:SetChecked(false)
end)

-- Betrag
local amountLabel = transactions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
amountLabel:SetPoint("TOPLEFT", incomeBtn, "BOTTOMLEFT", 0, -20)
amountLabel:SetText("Betrag:")

transactions.gold = CreateFrame("EditBox", nil, transactions, "InputBoxTemplate")
transactions.gold:SetSize(45, 25)
transactions.gold:SetPoint("LEFT", amountLabel, "RIGHT", 8, 0)
transactions.gold:SetNumeric(true)
transactions.gold:SetAutoFocus(false)

local gLabel = transactions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gLabel:SetPoint("LEFT", transactions.gold, "RIGHT", 4, 0)
gLabel:SetText("G")

transactions.silver = CreateFrame("EditBox", nil, transactions, "InputBoxTemplate")
transactions.silver:SetSize(45, 25)
transactions.silver:SetPoint("LEFT", gLabel, "RIGHT", 8, 0)
transactions.silver:SetNumeric(true)
transactions.silver:SetAutoFocus(false)

local sLabel = transactions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sLabel:SetPoint("LEFT", transactions.silver, "RIGHT", 4, 0)
sLabel:SetText("S")

transactions.copper = CreateFrame("EditBox", nil, transactions, "InputBoxTemplate")
transactions.copper:SetSize(45, 25)
transactions.copper:SetPoint("LEFT", sLabel, "RIGHT", 8, 0)
transactions.copper:SetNumeric(true)
transactions.copper:SetAutoFocus(false)

local cLabel = transactions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cLabel:SetPoint("LEFT", transactions.copper, "RIGHT", 4, 0)
cLabel:SetText("K")

-- Limit für Silber/Kupfer: max 99
local function LimitTo99(self)
    local v = tonumber(self:GetText()) or 0
    if v > 99 then
        self:SetText("99")
    end
end
transactions.silver:SetScript("OnTextChanged", LimitTo99)
transactions.copper:SetScript("OnTextChanged", LimitTo99)

-- Beschreibung
local descLabel = transactions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
descLabel:SetPoint("TOPLEFT", amountLabel, "BOTTOMLEFT", 0, -30)
descLabel:SetText("Beschreibung:")

transactions.desc = CreateFrame("EditBox", nil, transactions, "InputBoxTemplate")
transactions.desc:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
transactions.desc:SetPoint("RIGHT", -10, 0)
transactions.desc:SetHeight(25)
transactions.desc:SetAutoFocus(false)

-- Hinzufügen-Button
local addBtn = CreateFrame("Button", nil, transactions, "UIPanelButtonTemplate")
addBtn:SetSize(120, 30)
addBtn:SetPoint("BOTTOMLEFT", 0, 0)
addBtn:SetText("Hinzufügen")

addBtn:SetScript("OnClick", function()
    local G = tonumber(transactions.gold:GetText())   or 0
    local S = tonumber(transactions.silver:GetText()) or 0
    local C = tonumber(transactions.copper:GetText()) or 0
    local D = transactions.desc:GetText()
    if D == "" then D = "Keine Beschreibung" end

    local amount = G * 10000 + S * 100 + C
    if transactions.type == "expense" then
        amount = -amount
    end

    table.insert(SHFinanzenDB.transactions, {
        time        = date("%Y-%m-%d %H:%M"),
        type        = transactions.type,
        gold        = G,
        silver      = S,
        copper      = C,
        copperValue = amount,
        desc        = D,
    })

    SHFinanzenDB.balance = (SHFinanzenDB.balance or 0) + amount

    transactions.gold:SetText("")
    transactions.silver:SetText("")
    transactions.copper:SetText("")
    transactions.desc:SetText("")

    UpdateOverview()
end)

-----------------------------------------
-- TAB 3: Historie
-----------------------------------------
local history = CreateFrame("Frame", nil, frame)
history:SetPoint("TOPLEFT", 15, -70)
history:SetPoint("BOTTOMRIGHT", -15, 15)
history:Hide()

local scroll = CreateFrame("ScrollFrame", nil, history, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, -18)
scroll:SetPoint("BOTTOMRIGHT", -25, 0)
scroll.ScrollBar:SetAlpha(0)
scroll.ScrollBar:HookScript("OnShow", function() scroll.ScrollBar:SetAlpha(1) end)

local tableFrame = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(tableFrame)
tableFrame:SetSize(1, 1)

-- Header
local headers = {
    { "Datum",        100 },
    { "Art",           60 },
    { "Betrag",       100 },
    { "Beschreibung", 145 },
    { "",              30 }, -- Icon
}
local headerRow = CreateFrame("Frame", nil, history)
headerRow:SetPoint("TOPLEFT", history, "TOPLEFT", 0, 0)
headerRow:SetSize(435, 18)

local hx = 0
for _, H in ipairs(headers) do
    local t = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", hx, 0)
    t:SetWidth(H[2])
    t:SetJustifyH("CENTER")
    t:SetText(H[1])
    hx = hx + H[2]
end

local function RefreshHistory()
    for _, r in ipairs({ tableFrame:GetChildren() }) do r:Hide() end

    local y = -3
    for i = #SHFinanzenDB.transactions, 1, -1 do
        local e = SHFinanzenDB.transactions[i]
        local d = string.sub(e.time or "", 1, 10)
        local col = (e.copperValue or 0) >= 0 and "00ff00" or "ff0000"

        local row = CreateFrame("Frame", nil, tableFrame)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(435, 18)

        local col_Del    = 6
        local col_Date   = 50
        local col_Type   = 130
        local col_Amount = 210
        local col_Desc   = 332

        local t1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t1:SetPoint("CENTER", row, "LEFT", col_Date, 0)
        t1:SetText(d)

        local t2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t2:SetPoint("CENTER", row, "LEFT", col_Type, 0)
        t2:SetText(e.type == "income" and "Einnahme" or "Ausgabe")

        local t3 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t3:SetPoint("CENTER", row, "LEFT", col_Amount, 0)
        t3:SetText("|cff"..col..
            ((e.copperValue or 0) >= 0 and "+" or "")..
            (e.gold or 0).."g "..(e.silver or 0).."s "..(e.copper or 0).."k|r")

        local t4 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t4:SetPoint("CENTER", row, "LEFT", col_Desc, 0)
        t4:SetText(e.desc or "")

        local del = CreateFrame("Button", nil, row)
        del:SetPoint("CENTER", row, "LEFT", col_Del, 0)
        del:SetSize(14, 14)
        del:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        del:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
        del:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")

        del:SetScript("OnClick", function()
            local old = e.copperValue or 0
            SHFinanzenDB.balance = (SHFinanzenDB.balance or 0) - old
            table.remove(SHFinanzenDB.transactions, i)

            local a = math.abs(old)
            local g = math.floor(a / 10000)
            local s = math.floor((a % 10000) / 100)
            local c = a % 100
            local formatted =
                (g > 0 and g.."g " or "") ..
                (s > 0 and s.."s " or "") ..
                (c > 0 and c.."k " or "")

            local color = old > 0 and "ff3333" or "33ff33"
            local sign  = old > 0 and "-" or "+"

            print("|cffff4444[SH Finanzen]|r Transaktion gelöscht: "
            .. (e.desc or "Keine Beschreibung") .. " ("..sign.." "..formatted..")")

            UpdateOverview()
            RefreshHistory()
        end)

        y = y - 18
    end

    -- Höhe setzen
local totalHeight = -y + 20
tableFrame:SetHeight(totalHeight)

-- Scrollbar nur anzeigen wenn nötig
local needsScroll = totalHeight > history:GetHeight() - 20

if needsScroll then
    scroll.ScrollBar:Show()
else
    scroll.ScrollBar:Hide()
end 
end

-----------------------------------------
-- TAB 4: Einstellungen
-----------------------------------------
local settings = CreateFrame("Frame", nil, frame)
settings:SetPoint("TOPLEFT", 15, -70)
settings:SetPoint("BOTTOMRIGHT", -15, 15)
settings:Hide()

-- Tageslohn
local wageLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
wageLabel:SetPoint("TOPLEFT", 0, -10)
wageLabel:SetText("Tageslohn (Silber pro Tag):")

local wageBox = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
wageBox:SetSize(60, 25)
wageBox:SetPoint("LEFT", wageLabel, "RIGHT", 10, 0)
wageBox:SetAutoFocus(false)
wageBox:SetNumeric(true)
wageBox:SetText(SHFinanzenDB.daily and tostring(SHFinanzenDB.daily) or "0")
wageBox:SetScript("OnTextChanged", function(self)
    SHFinanzenDB.daily = tonumber(self:GetText()) or 0
end)

-- Lebensunterhalt
local lifeLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lifeLabel:SetPoint("TOPLEFT", wageLabel, "BOTTOMLEFT", 0, -13)
lifeLabel:SetText("Lebensunterhalt (Silber pro Tag):")

local lifeBox = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
lifeBox:SetSize(60, 25)
lifeBox:SetPoint("LEFT", lifeLabel, "RIGHT", 10, 0)
lifeBox:SetAutoFocus(false)
lifeBox:SetNumeric(true)
lifeBox:SetText(SHFinanzenDB.dailyExpense and tostring(SHFinanzenDB.dailyExpense) or "0")
lifeBox:SetScript("OnTextChanged", function(self)
    SHFinanzenDB.dailyExpense = tonumber(self:GetText()) or 0
end)

-- Miete
local rentLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rentLabel:SetPoint("TOPLEFT", lifeLabel, "BOTTOMLEFT", 0, -40)
rentLabel:SetText("Miete (Silber pro Monat):")

local rentBox = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
rentBox:SetSize(60, 25)
rentBox:SetPoint("LEFT", rentLabel, "RIGHT", 10, 0)
rentBox:SetAutoFocus(false)
rentBox:SetNumeric(true)
rentBox:SetText(SHFinanzenDB.rent or "0")
rentBox:SetScript("OnTextChanged", function(self)
    SHFinanzenDB.rent = tonumber(self:GetText()) or 0
end)

-- Pacht
local leaseLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leaseLabel:SetPoint("TOPLEFT", rentLabel, "BOTTOMLEFT", 0, -15)
leaseLabel:SetText("Pacht (Silber pro Monat):")

local leaseBox = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
leaseBox:SetSize(60, 25)
leaseBox:SetPoint("LEFT", leaseLabel, "RIGHT", 10, 0)
leaseBox:SetAutoFocus(false)
leaseBox:SetNumeric(true)
leaseBox:SetText(SHFinanzenDB.lease or "0")
leaseBox:SetScript("OnTextChanged", function(self)
    SHFinanzenDB.lease = tonumber(self:GetText()) or 0
end)

local function UpdateWageBox()
    wageBox:SetText(tostring(SHFinanzenDB.daily or 0))
    lifeBox:SetText(tostring(SHFinanzenDB.dailyExpense or 0))
    rentBox:SetText(tostring(SHFinanzenDB.rent or 0))
    leaseBox:SetText(tostring(SHFinanzenDB.lease or 0))
end

-- Reset mit Popup
StaticPopupDialogs["SHFINANZEN_RESET_CONFIRM"] = {
    text = "Willst du wirklich alles zurücksetzen?\nAlle Daten gehen unwiderruflich verloren!",
    button1 = "Ja löschen",
    button2 = "Abbrechen",
    OnAccept = function()
        SHFinanzenDB.transactions = {}
        SHFinanzenDB.balance      = 0
        SHFinanzenDB.lastPayout   = ""
        SHFinanzenDB.lastMonth    = ""
        SHFinanzenDB.daily        = 0
        SHFinanzenDB.dailyExpense = 0
        SHFinanzenDB.rent         = 0
        SHFinanzenDB.lease        = 0
        SHFinanzenDB.initialSet   = false

        UpdateOverview()
        RefreshHistory()
        ReloadUI()
        print("|cffff4444[SH Finanzen]|r Alle Daten wurden zurückgesetzt.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local resetBtn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
resetBtn:SetSize(100, 30)
resetBtn:SetPoint("BOTTOMRIGHT", -5, 5)
resetBtn:SetText("Zurücksetzen")
resetBtn:SetScript("OnClick", function()
    StaticPopup_Show("SHFINANZEN_RESET_CONFIRM")
end)

------------------------------------------------------------
-- Startvermögen-Button
------------------------------------------------------------
local startBtn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
startBtn:SetSize(150, 26)
startBtn:SetPoint("BOTTOM", settings, "BOTTOM", 0, 5)
startBtn:SetText("Vermögen festlegen")

local initCheck = CreateFrame("Frame")
initCheck:RegisterEvent("PLAYER_LOGIN") -- WICHTIG ‼ nicht ADDON_LOADED
initCheck:SetScript("OnEvent", function()
    if SHFinanzenDB.initialSet == true then
        startBtn:Hide()
    else
        startBtn:Show()
    end
end)

------------------------------------------------------------
-- Popup für Startkapital
------------------------------------------------------------
local startWindow = CreateFrame("Frame", "SH_StartKapitalFrame", UIParent, "BasicFrameTemplateWithInset")
startWindow:SetSize(260, 160)
startWindow:SetPoint("CENTER")
startWindow:Hide()

startWindow.title = startWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
startWindow.title:SetPoint("TOP", 0, -5)
startWindow.title:SetText("Startkapital eingeben")

local sg = startWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sg:SetPoint("TOPLEFT", 15, -35)
sg:SetText("Gold:")

local gBox = CreateFrame("EditBox", nil, startWindow, "InputBoxTemplate")
gBox:SetSize(55, 25)
gBox:SetPoint("LEFT", sg, "RIGHT", 10, 0)
gBox:SetNumeric(true)

local ss = startWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ss:SetPoint("TOPLEFT", sg, "BOTTOMLEFT", 0, -15)
ss:SetText("Silber:")

local sBox = CreateFrame("EditBox", nil, startWindow, "InputBoxTemplate")
sBox:SetSize(55, 25)
sBox:SetPoint("LEFT", ss, "RIGHT", 10, 0)
sBox:SetNumeric(true)
sBox:SetScript("OnTextChanged", function(self)
    if tonumber(self:GetText()) and tonumber(self:GetText()) > 99 then
        self:SetText("99")
    end
end)

local sk = startWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sk:SetPoint("TOPLEFT", ss, "BOTTOMLEFT", 0, -15)
sk:SetText("Kupfer:")

local cBox = CreateFrame("EditBox", nil, startWindow, "InputBoxTemplate")
cBox:SetSize(55, 25)
cBox:SetPoint("LEFT", sk, "RIGHT", 10, 0)
cBox:SetNumeric(true)
cBox:SetScript("OnTextChanged", function(self)
    if tonumber(self:GetText()) and tonumber(self:GetText()) > 99 then
        self:SetText("99")
    end
end)

local ok = CreateFrame("Button", nil, startWindow, "UIPanelButtonTemplate")
ok:SetSize(90, 24)
ok:SetPoint("BOTTOMLEFT", 15, 10)
ok:SetText("Übernehmen")

local cancel = CreateFrame("Button", nil, startWindow, "UIPanelButtonTemplate")
cancel:SetSize(90, 24)
cancel:SetPoint("BOTTOMRIGHT", -15, 10)
cancel:SetText("Abbrechen")

startBtn:SetScript("OnClick", function()
    startWindow:Show()
end)

ok:SetScript("OnClick", function()
    local g = tonumber(gBox:GetText()) or 0
    local s = tonumber(sBox:GetText()) or 0
    local c = tonumber(cBox:GetText()) or 0

    local total = g*10000 + s*100 + c
    if total <= 0 then
        print("|cffff4444[SH Finanzen]|r Kein Startkapital eingegeben.")
        return
    end

    SHFinanzenDB.balance    = (SHFinanzenDB.balance or 0) + total
    SHFinanzenDB.initialSet = true

    table.insert(SHFinanzenDB.transactions, {
        time        = date("%Y-%m-%d"),
        type        = "income",
        gold        = g,
        silver      = s,
        copper      = c,
        copperValue = total,
        desc        = "Startkapital"
    })

    UpdateOverview()
    if history:IsShown() then RefreshHistory() end

    print("|cffff4444[SH Finanzen]|r Startkapital gespeichert: "
    ..g.."g "..s.."s "..c.."k")

    startWindow:Hide()
    startBtn:Hide()
end)

cancel:SetScript("OnClick", function()
    startWindow:Hide()
end)

-- Speichern-Button (Reload)
local saveBtn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
saveBtn:SetSize(100, 26)
saveBtn:SetPoint("BOTTOMLEFT", 10, 5)
saveBtn:SetText("Speichern")
saveBtn:SetScript("OnClick", function()
    ReloadUI()
end)

-----------------------------------------
-- Tabs
-----------------------------------------
local tabs = { "Übersicht", "Transaktionen", "Historie", "Einstellungen" }
local buttons = {}

local function SelectTab(i)
    for n, b in ipairs(buttons) do
        if n == i then b:LockHighlight() else b:UnlockHighlight() end
    end

    overview:Hide()
    transactions:Hide()
    history:Hide()
    settings:Hide()

    if i == 1 then overview:Show() end
    if i == 2 then transactions:Show() end
    if i == 3 then history:Show(); RefreshHistory() end
    if i == 4 then settings:Show(); UpdateWageBox() end

    frame.title:SetText("SH Finanzen – " .. tabs[i])
end

local fw = frame:GetWidth()
local bw = 105
local gap = (fw - (#tabs * bw)) / (#tabs + 1)

for i, name in ipairs(tabs) do
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(bw, 25)
    b:SetText(name)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", gap * i + bw * (i - 1), -30)
    b:SetScript("OnClick", function() SelectTab(i) end)
    buttons[i] = b
end

-----------------------------------------
-- Tägliche und monatliche Buchung
-----------------------------------------
C_Timer.After(0.1, function()

---------------------------------------------------------
-- 🔥 Offline-Nachzahlung (Lohn + Unterhalt für Fehltage)
---------------------------------------------------------
local function DaysBetween(oldDate, newDate)
    local oy,om,od = oldDate:match("(%d+)-(%d+)-(%d+)")
    local ny,nm,nd = newDate:match("(%d+)-(%d+)-(%d+)")
    if not oy or not ny then return 0 end

    local t1 = time({year=oy, month=om, day=od})
    local t2 = time({year=ny, month=nm, day=nd})
    return math.floor((t2 - t1) / 86400)
end

local today    = date("%Y-%m-%d")
local last     = SHFinanzenDB.lastPayout or today
local diffDays = DaysBetween(last, today)

if diffDays > 0 then
    local wage      = (SHFinanzenDB.daily or 0) * diffDays * 100
    local cost      = (SHFinanzenDB.dailyExpense or 0) * diffDays * 100
    local result    = wage - cost
    SHFinanzenDB.balance = SHFinanzenDB.balance + result
    SHFinanzenDB.lastPayout = today

    table.insert(SHFinanzenDB.transactions,{
        time=today,type=(result>=0)and"income"or"expense",
        gold=math.floor(math.abs(result)/10000),
        silver=math.floor((math.abs(result)%10000)/100),
        copper=math.abs(result)%100,
        copperValue=result,
        desc=diffDays.." Tage Nachzahlung"
    })

    print("|cffff5555[SH Finanzen]|r Nachzahlung für "..diffDays.." Tage:")
    print("   |cff00ff00+ "..(wage/100).." Silber Lohn|r")
    print("   |cffff3333- "..(cost/100).." Silber Unterhalt|r")
    print("   |cffffff00Ergebnis: "..(result/100).." Silber|r")
end

-----------------------------------------

    -- Wenn Startkapital noch nicht gesetzt wurde, dann nichts buchen.
    if not SHFinanzenDB.initialSet then
        RestorePos()
        UpdateOverview()
        SelectTab(1)
        return
    end

    -- 1) Tägliche Auszahlung / Belastung
    local today = date("%Y-%m-%d")

    if SHFinanzenDB.lastPayout ~= today then

        -- Tageslohn
        if (SHFinanzenDB.daily or 0) > 0 then
            local copper = (SHFinanzenDB.daily or 0) * 100
            SHFinanzenDB.balance = (SHFinanzenDB.balance or 0) + copper

            table.insert(SHFinanzenDB.transactions, {
                time        = date("%Y-%m-%d"),
                type        = "income",
                gold        = math.floor(copper / 10000),
                silver      = math.floor((copper % 10000) / 100),
                copper      = copper % 100,
                copperValue = copper,
                desc        = "Tageslohn"
            })
        end

        -- Lebensunterhalt
        if (SHFinanzenDB.dailyExpense or 0) > 0 then
            local cost = (SHFinanzenDB.dailyExpense or 0) * 100
            local neg  = -cost
            SHFinanzenDB.balance = (SHFinanzenDB.balance or 0) + neg

            table.insert(SHFinanzenDB.transactions, {
                time        = date("%Y-%m-%d"),
                type        = "expense",
                gold        = math.floor(cost / 10000),
                silver      = math.floor((cost % 10000) / 100),
                copper      = cost % 100,
                copperValue = neg,
                desc        = "Lebensunterhalt"
            })
        end

        SHFinanzenDB.lastPayout = today
    end

-- Monatsabrechnung + Nachzahlung wenn mehrere Monate verpasst wurden
do
    local rent  = (SHFinanzenDB.rent  or 0) * 100
    local lease = (SHFinanzenDB.lease or 0) * 100
    local monthCost = rent + lease

    if monthCost > 0 then
        local now = date("%Y-%m")
        local last = SHFinanzenDB.lastMonth or now

        local y1,m1 = last:match("(%d+)%-(%d+)")
        local y2,m2 = tonumber(date("%Y")), tonumber(date("%m"))

        y1,m1 = tonumber(y1) or y2, tonumber(m1) or m2

        -- 🔥 Fehlende Monate berechnen
        local missed = (y2-y1)*12 + (m2-m1)
        if missed < 1 then missed = 0 end

        if missed > 0 then
            local total = monthCost * missed
            SHFinanzenDB.balance = SHFinanzenDB.balance - total

            table.insert(SHFinanzenDB.transactions,{
                time = date("%Y-%m-%d"),
                type = "expense",
                gold = math.floor(total / 10000),
                silver = math.floor((total % 10000) / 100),
                copper = total % 100,
                copperValue = -total,
                desc = "Nachzahlungen"
            })

            print("|cffff3333[SH Finanzen]|r Monatliche Kosten gebucht: "
            ..missed.." Monat(e) |cffffff00-"..(total/100).." Silber|r")
        end

        SHFinanzenDB.lastMonth = now
    end
end

RestorePos()
UpdateOverview()

if SHFinanzenDB.windowOpen == nil then SHFinanzenDB.windowOpen = false end

if SHFinanzenDB.windowOpen == true then
    SHFinanzenFrame:Show()
else
    SHFinanzenFrame:Hide()
end
-----------------------------------------
-- Debug-Slashbefehle
-----------------------------------------

-- Erzwingt nächste Tages- und Monatsbuchung
SLASH_SHFORCE1 = "/shforce"
SlashCmdList["SHFORCE"] = function()
    SHFinanzenDB.lastPayout = "0"
    SHFinanzenDB.lastMonth  = "0"
    print("|cffff4444[SH Finanzen]|r Nächster Reload bucht Tages- und Monatswerte neu.")
end

-- Zeigt aktuelle gespeicherte Daten
SLASH_SHDEBUG1 = "/shdebug"
SlashCmdList["SHDEBUG"] = function()
    print("======== SH DEBUG =========")
    print("Daily       ", SHFinanzenDB.daily,        " (type:", type(SHFinanzenDB.daily),        ")")
    print("DailyExpense", SHFinanzenDB.dailyExpense, " (type:", type(SHFinanzenDB.dailyExpense), ")")
    print("Rent        ", SHFinanzenDB.rent,         " (type:", type(SHFinanzenDB.rent),         ")")
    print("Lease       ", SHFinanzenDB.lease,        " (type:", type(SHFinanzenDB.lease),        ")")
    print("Balance     ", SHFinanzenDB.balance)
    print("Transactions", #SHFinanzenDB.transactions)
    print("LastPayout  ", SHFinanzenDB.lastPayout)
    print("LastMonth   ", SHFinanzenDB.lastMonth)
    print("===========================")
end

-------------------------------------------------
-- Slash-Command: /shfin zum Öffnen/Schließen
-------------------------------------------------
SLASH_SHFIN1 = "/shfin"
SlashCmdList["SHFIN"] = function()
    if SHFinanzenFrame:IsShown() then
        SHFinanzenFrame:Hide()
        SHFinanzenDB.windowOpen = false
    else
        SHFinanzenFrame:Show()
        SHFinanzenDB.windowOpen = true
    end
end

end)