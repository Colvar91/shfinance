-------------------------------------------
-- SH FINANZEN • MINIMAP BUTTON (NEU)
-------------------------------------------

-- Standard Speicherort falls nicht vorhanden
if not SHFinanzenMiniDB then SHFinanzenMiniDB = {} end
if not SHFinanzenMiniDB.pos then SHFinanzenMiniDB.pos = 45 end  -- Startposition (rechts oben)

local button = CreateFrame("Button", "SHFinanzen_MinimapButton", Minimap)
button:SetFrameLevel(8)
button:SetSize(32, 32)
button:SetMovable(true)
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:RegisterForClicks("AnyUp")
button:RegisterForDrag("LeftButton")

-- Rundes Standard-Minimap-Button-Template
local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetSize(54, 54)
overlay:SetPoint("TOPLEFT", 0, 0)

-- ICON (Coin-Symbol)
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\inv_misc_coin_02")
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
icon:SetPoint("CENTER")
icon:SetSize(20, 20)

-------------------------------------------------
-- Positionierung — Button bleibt am Minimapradius
-------------------------------------------------
local function UpdateButtonPos()
    local angle = math.rad(SHFinanzenMiniDB.pos)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-------------------------------------------------
-- Dragging (sauber, bleibt NICHT kleben)
-------------------------------------------------
button:SetScript("OnDragStart", function(self)
    self.isMoving = true
end)

button:SetScript("OnDragStop", function(self)
    self.isMoving = false
end)

button:SetScript("OnUpdate", function(self)
    if not self.isMoving then return end
    
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    local dx = px/scale - mx
    local dy = py/scale - my

    SHFinanzenMiniDB.pos = math.deg(math.atan2(dy, dx)) % 360
    UpdateButtonPos()
end)

-------------------------------------------------
-- Sichtbar machen
-------------------------------------------------
UpdateButtonPos()
button:Show()

-------------------------------------------------
-- 🔥 CLICK-FUNKTION: Fenster öffnen/schließen
-------------------------------------------------
button:SetScript("OnClick", function(_, btn)
    if btn == "LeftButton" then
        if SHFinanzenFrame and SHFinanzenFrame:IsShown() then
            SHFinanzenFrame:Hide()
            if SHFinanzenDB then SHFinanzenDB.windowOpen = false end
        else
            SHFinanzenFrame:Show()
            if SHFinanzenDB then SHFinanzenDB.windowOpen = true end
        end
    end
end)

-------------------------------------------------
-- 🛈 Tooltip (Mouseover Anzeige)
-------------------------------------------------
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffff5555SH Finanzen|r")
    GameTooltip:AddLine("|cffFFFFFFLinksklick: Öffnen/Schließen|r")
    GameTooltip:AddLine("|cffFFFFFFLinksklick halten = verschieben|r")
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------
-- 🔄 Position wiederherstellen bei Login
---------------------------------------------------------
C_Timer.After(0.3, UpdateButtonPos)
