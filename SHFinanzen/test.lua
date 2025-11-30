------------------------------------------------------------
--   SCHATTENHAIN FINANZEN – CORE LUA
------------------------------------------------------------
SHF_SAVED = SHF_SAVED or { rates = {} }


------------------------------------------------------------
-- 🖥 Hauptfenster
------------------------------------------------------------
local frame = CreateFrame("Frame","SHF_MainFrame",UIParent,"BackdropTemplate")
frame:SetSize(495,400)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",frame.StartMoving)
frame:SetScript("OnDragStop",frame.StopMovingOrSizing)

frame:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/DialogFrame/UI-DialogBox-Border",
    tile=true,tileSize=16,edgeSize=18
})
frame:SetBackdropColor(0,0,0,0.85)


------------------------------------------------------------
-- Titel
------------------------------------------------------------
local title = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
title:SetPoint("TOP",0,-10)
title:SetText("Schattenhain Finanzen")


------------------------------------------------------------
-- Tabs
------------------------------------------------------------
local TABNAMES={"Übersicht","Transaktion","Historie","Raten"}
local tabs,pages={},{}

for i,name in ipairs(TABNAMES) do
    local b=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    b:SetSize(110,24)
    b:SetText(name)
    b:SetPoint("TOPLEFT",20+(i-1)*115,-40)
    tabs[i]=b
end

for i=1,#TABNAMES do
    local page=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    page:SetSize(495,320)
    page:SetPoint("TOP",0,-85)
    page:Hide()
    pages[i]=page
end

local function ShowPage(i)
    for n=1,#pages do pages[n]:Hide() end
    pages[i]:Show()
end

ShowPage(1)


------------------------------------------------------------
-- 📄 TAB 1 – ÜBERSICHT
------------------------------------------------------------
local overview = pages[1]


---------------
-- Kontostand Header
---------------
local kontoTitle=overview:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
kontoTitle:SetPoint("TOP",0,-55)
kontoTitle:SetText("|cffffd100Kontostand|r")


---------------
-- Geldanzeige Gold/Silber/Kupfer
---------------
local MONEY={
    {icon="Interface\\MoneyFrame\\UI-GoldIcon",amount=0},
    {icon="Interface\\MoneyFrame\\UI-SilverIcon",amount=0},
    {icon="Interface\\MoneyFrame\\UI-CopperIcon",amount=0},
}
local spacing=80
local startX= -((#MONEY-1)*spacing)/2

for i,m in ipairs(MONEY) do
    local holder=CreateFrame("Frame",nil,overview)
    holder:SetPoint("TOP",startX+(i-1)*spacing,-90)
    holder:SetSize(70,30)

    local icon=holder:CreateTexture(nil,"ARTWORK")
    icon:SetSize(18,18)
    icon:SetPoint("LEFT")
    icon:SetTexture(m.icon)

    local t=holder:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
    t:SetPoint("LEFT",icon,"RIGHT",6,0)
    t:SetText(m.amount)
end


---------------
-- 🟨 Tägliche & Monatliche Anzeige dynamisch
---------------
local dailyTitle=overview:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
dailyTitle:SetPoint("TOPLEFT",50,-135)
dailyTitle:SetText("|cffffd100Tägliche Finanzen|r")

local dailyValues=overview:CreateFontString(nil,"OVERLAY","GameFontHighlight")
dailyValues:SetPoint("TOPLEFT",50,-160)
dailyValues:SetJustifyH("LEFT")
dailyValues:SetSpacing(3)


local line3=overview:CreateTexture(nil,"ARTWORK")
line3:SetColorTexture(1,1,1,0.18)
line3:SetSize(400,1)
line3:SetPoint("TOPLEFT",50,-205)

local monthTitle=overview:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
monthTitle:SetPoint("TOPLEFT",50,-225)
monthTitle:SetText("|cffffd100Monatliche Finanzen|r")

local monthValues=overview:CreateFontString(nil,"OVERLAY","GameFontHighlight")
monthValues:SetPoint("TOPLEFT",50,-250)
monthValues:SetJustifyH("LEFT")
monthValues:SetSpacing(3)


------------------------------------------------------------
-- 🔥 Dynamische Übersicht basierend auf Raten
------------------------------------------------------------
local function UpdateOverviewLists()
    local d="", m=""

    for _,e in ipairs(SHF_SAVED.rates) do
        local color=(e.mode=="income") and "|cff00ff00+" or "|cffff4444-"
        local line=color..e.silver.."|r Silber – "..e.name.."\n"
        if e.type=="daily"   then d=d..line end
        if e.type=="monthly" then m=m..line end
    end

    dailyValues:SetText(d~="" and d or "|c888888Keine täglichen Einträge|r")
    monthValues:SetText(m~="" and m or "|c888888Keine monatlichen Einträge|r")
end


------------------------------------------------------------
-- TAB 4 – RATEN + POPUP HINZUFÜGEN
------------------------------------------------------------
local rates = pages[4]

-- Öffnen Popup Button
local openAdd=CreateFrame("Button",nil,rates,"UIPanelButtonTemplate")
openAdd:SetSize(120,26)
openAdd:SetPoint("BOTTOMRIGHT",-20,20)
openAdd:SetText("Hinzufügen")


---------------------- Popup Fenster ----------------------
local popup=CreateFrame("Frame","SHF_AddPopup",rates,"BackdropTemplate")
popup:SetSize(260,240)
popup:SetPoint("TOPRIGHT",frame,"TOPRIGHT",270,-20)
popup:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/DialogFrame/UI-DialogBox-Border",tile=true,tileSize=16,edgeSize=18})
popup:SetBackdropColor(0,0,0,0.9)
popup:Hide()

openAdd:SetScript("OnClick",function() popup:Show() end)

---------------------- Popup Inhalt ----------------------
local lbl=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
lbl:SetPoint("TOP",0,-10)
lbl:SetText("Neuen Eintrag")

local nameLabel=popup:CreateFontString(nil,"OVERLAY","GameFontHighlight")
nameLabel:SetPoint("TOPLEFT",15,-50)
nameLabel:SetText("Name:")

local nameBox=CreateFrame("EditBox",nil,popup,"InputBoxTemplate")
nameBox:SetSize(160,24)
nameBox:SetPoint("TOPLEFT",nameLabel,"BOTTOMLEFT",0,-4)
nameBox:SetAutoFocus(false)

local amountLabel=popup:CreateFontString(nil,"OVERLAY","GameFontHighlight")
amountLabel:SetPoint("TOPLEFT",15,-100)
amountLabel:SetText("Silber:")

local amountBox=CreateFrame("EditBox",nil,popup,"InputBoxTemplate")
amountBox:SetSize(40,24)
amountBox:SetPoint("LEFT",amountLabel,"RIGHT",10,0)
amountBox:SetNumeric(true)
amountBox:SetAutoFocus(false)

local typeLabel=popup:CreateFontString(nil,"OVERLAY","GameFontHighlight")
typeLabel:SetPoint("TOPLEFT",15,-140)
typeLabel:SetText("Abrechnung:")

local pDaily=CreateFrame("CheckButton",nil,popup,"UICheckButtonTemplate")
pDaily:SetPoint("TOPLEFT",typeLabel,"BOTTOMLEFT",0,-6)
pDaily.text:SetText("Täglich")

local pMonthly=CreateFrame("CheckButton",nil,popup,"UICheckButtonTemplate")
pMonthly:SetPoint("LEFT",pDaily.text,"RIGHT",35,0)
pMonthly.text:SetText("Monatlich")

pDaily:SetScript("OnClick",function() pMonthly:SetChecked(false) end)
pMonthly:SetScript("OnClick",function() pDaily:SetChecked(false) end)

local modeLabel=popup:CreateFontString(nil,"OVERLAY","GameFontHighlight")
modeLabel:SetPoint("TOPLEFT",15,-185)
modeLabel:SetText("Art:")

local pIncome=CreateFrame("CheckButton",nil,popup,"UICheckButtonTemplate")
pIncome:SetPoint("TOPLEFT",modeLabel,"BOTTOMLEFT",0,-6)
pIncome.text:SetText("Einnahme")

local pOutcome=CreateFrame("CheckButton",nil,popup,"UICheckButtonTemplate")
pOutcome:SetPoint("LEFT",pIncome.text,"RIGHT",35,0)
pOutcome.text:SetText("Ausgabe")

pIncome:SetScript("OnClick",function() pOutcome:SetChecked(false) end)
pOutcome:SetScript("OnClick",function() pIncome:SetChecked(false) end)


---------------------- Eintrag erstellen ----------------------
local add=CreateFrame("Button",nil,popup,"UIPanelButtonTemplate")
add:SetSize(80,26)
add:SetPoint("BOTTOM",0,15)
add:SetText("OK")

add:SetScript("OnClick",function()

    local name=nameBox:GetText()
    local value=amountBox:GetNumber()
    local rate=pDaily:GetChecked() and "daily" or pMonthly:GetChecked() and "monthly"
    local mode=pIncome:GetChecked() and "income" or "outcome"

    -- ❗ Max 4 pro Kategorie
    local count=0
    for _,e in ipairs(SHF_SAVED.rates) do if e.type==rate then count=count+1 end end
    if count>=4 then
        UIErrorsFrame:AddMessage("|cffff0000Max 4 pro Kategorie!|r",1,0,0,3)
        return
    end

    if name~="" and value>0 and rate then
        table.insert(SHF_SAVED.rates,{name=name,silver=value,type=rate,mode=mode})
    end

    nameBox:SetText("")
    amountBox:SetText("")
    popup:Hide()

    RenderRateList()
    UpdateOverviewLists()
end)



------------------------------------------------------------
-- TAB4 – LISTENANSICHT (Live rendern)
------------------------------------------------------------
local listFrame=CreateFrame("Frame",nil,rates,"BackdropTemplate")
listFrame:SetSize(450,250)
listFrame:SetPoint("TOPLEFT",20,-20)

local function RenderRateList()

    for _,child in pairs({listFrame:GetChildren()}) do child:Hide() end

    local y=-10
    for i,e in ipairs(SHF_SAVED.rates) do

        local row=CreateFrame("Frame",nil,listFrame)
        row:SetSize(430,18)
        row:SetPoint("TOPLEFT",10,y)
        y=y-22

        local text=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        local col=(e.mode=="income") and "|cff00ff00+" or "|cffff4444-"
        text:SetPoint("LEFT")
        text:SetText(col..e.silver.."|r Silber – "..e.name.." ("..(e.type=="daily" and "täglich" or "monatlich")..")")

        local del=CreateFrame("Button",nil,row,"UIPanelCloseButton")
        del:SetSize(18,18)
        del:SetPoint("RIGHT",0,0)

        del:SetScript("OnClick",function()
            table.remove(SHF_SAVED.rates,i)
            RenderRateList()
            UpdateOverviewLists()
        end)
    end
end


------------------------------------------------------------
-- TAB WECHSEL HANDLER
------------------------------------------------------------
tabs[1]:SetScript("OnClick",function() ShowPage(1) UpdateOverviewLists() end)
tabs[4]:SetScript("OnClick",function() ShowPage(4) RenderRateList() end)

UpdateOverviewLists()
RenderRateList()