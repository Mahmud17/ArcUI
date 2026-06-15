-- ===================================================================
-- ArcUI_Castbar.lua
-- Player castbar - single bar showing cast progress
-- Similar in structure to resource bars (movable, configurable appearance)
-- OnUpdate only runs during an active cast (zero idle CPU)
-- ===================================================================

local ADDON, ns = ...
ns.Castbar = ns.Castbar or {}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local function PixelSize(n) return math.floor(n + 0.5) end

-- ===================================================================
-- DB ACCESSOR
-- ===================================================================
local function GetCastbarDB()
  local db = ns.API and ns.API.GetDB and ns.API.GetDB()
  return db and db.castbar
end

-- ===================================================================
-- CAST STATE
-- ===================================================================
local castFrameObj = nil
local castTextFrame = nil
local castActive = false
local castIsChannel = false
local castIsEmpowered = false
local castEmpowerNumStages = 0
local castEmpowerStageProps = {}  -- [i] = 0-1 proportion of bar width for stage-i boundary
local castStartTime = 0
local castEndTime = 0
local castPreviewActive = false
local castTimingRefined = false

-- ===================================================================
-- FRAME CREATION
-- ===================================================================
local function CreateCastbarFrames()
  -- Main bar frame
  local frame = CreateFrame("Frame", "ArcUICastbarMain", UIParent)
  frame:SetSize(250, 20)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(false)

  -- Background
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints()
  frame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
  frame.bg:SetSnapToPixelGrid(false)
  frame.bg:SetTexelSnappingBias(0)

  -- Cast fill bar
  frame.fillBar = CreateFrame("StatusBar", nil, frame)
  frame.fillBar:SetAllPoints(frame)
  frame.fillBar:SetMinMaxValues(0, 1)
  frame.fillBar:SetValue(0)
  frame.fillBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  frame.fillBar:SetStatusBarColor(0.2, 0.8, 1, 1)
  frame.fillBar:SetFrameLevel(frame:GetFrameLevel() + 2)

  -- Border overlay (4 separate textures for pixel-perfect edges)
  frame.borderOverlay = CreateFrame("Frame", nil, frame)
  frame.borderOverlay:SetAllPoints()
  frame.borderOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
  frame.borderOverlay.top    = frame.borderOverlay:CreateTexture(nil, "OVERLAY")
  frame.borderOverlay.bottom = frame.borderOverlay:CreateTexture(nil, "OVERLAY")
  frame.borderOverlay.left   = frame.borderOverlay:CreateTexture(nil, "OVERLAY")
  frame.borderOverlay.right  = frame.borderOverlay:CreateTexture(nil, "OVERLAY")
  frame.borderOverlay.top:SetSnapToPixelGrid(false);    frame.borderOverlay.top:SetTexelSnappingBias(0)
  frame.borderOverlay.bottom:SetSnapToPixelGrid(false); frame.borderOverlay.bottom:SetTexelSnappingBias(0)
  frame.borderOverlay.left:SetSnapToPixelGrid(false);   frame.borderOverlay.left:SetTexelSnappingBias(0)
  frame.borderOverlay.right:SetSnapToPixelGrid(false);  frame.borderOverlay.right:SetTexelSnappingBias(0)

  -- Icon frame (to the left of the bar)
  frame.iconFrame = CreateFrame("Frame", nil, frame)
  frame.iconFrame:SetSize(20, 20)
  frame.iconFrame:SetPoint("RIGHT", frame, "LEFT", -2, 0)
  frame.iconFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  frame.iconTex = frame.iconFrame:CreateTexture(nil, "ARTWORK")
  frame.iconTex:SetAllPoints()
  frame.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- Stage markers for empowered casts (up to 4 stages = up to 3 dividers)
  frame.stageMarkerFrame = CreateFrame("Frame", nil, frame)
  frame.stageMarkerFrame:SetAllPoints()
  frame.stageMarkerFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  frame.stageMarkers = {}
  for i = 1, 4 do
    local m = frame.stageMarkerFrame:CreateTexture(nil, "OVERLAY")
    m:SetWidth(2)
    m:SetColorTexture(1, 1, 1, 0.75)
    m:SetSnapToPixelGrid(false)
    m:SetTexelSnappingBias(0)
    m:Hide()
    frame.stageMarkers[i] = m
  end

  -- Blue "DRAG" overlay shown when drag mode is active (child of frame so it follows during move)
  local dragOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  dragOverlay:SetAllPoints()
  dragOverlay:SetFrameLevel(frame:GetFrameLevel() + 8)
  dragOverlay:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
  })
  dragOverlay:SetBackdropColor(0.1, 0.4, 0.8, 0.35)
  dragOverlay:SetBackdropBorderColor(0.3, 0.7, 1.0, 0.9)
  local dragOverlayText = dragOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  dragOverlayText:SetPoint("CENTER", dragOverlay, "CENTER", 0, 0)
  dragOverlayText:SetText("DRAG")
  dragOverlayText:SetTextColor(1, 1, 1, 0.9)
  dragOverlay:RegisterForDrag("LeftButton")
  dragOverlay:EnableMouse(false)
  dragOverlay:Hide()
  frame.dragOverlay = dragOverlay

  -- Drag toggle button (parented to UIParent, anchored above top-left of bar, same style as CDM Groups)
  local dragToggleBtn = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  dragToggleBtn:SetSize(16, 16)
  dragToggleBtn:SetFrameStrata("HIGH")
  dragToggleBtn:SetFrameLevel(200)
  dragToggleBtn:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
  dragToggleBtn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  dragToggleBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.85)
  dragToggleBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

  local moveIcon = dragToggleBtn:CreateTexture(nil, "OVERLAY")
  moveIcon:SetSize(12, 12)
  moveIcon:SetPoint("CENTER", dragToggleBtn, "CENTER", 0, 0)
  moveIcon:SetTexture("Interface\\CURSOR\\UI-Cursor-Move")
  moveIcon:SetVertexColor(0.8, 0.8, 0.8, 1)
  dragToggleBtn.moveIcon = moveIcon

  dragToggleBtn._active    = false
  dragToggleBtn._isDragging = false

  local function SaveCastbarPosition()
    local cfg = GetCastbarDB()
    if cfg then
      local point, _, relPoint, x, y = frame:GetPoint()
      if point then
        cfg.barPosition = { point = point, relPoint = relPoint, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
      end
    end
  end

  local function UpdateDragToggleBtnVisuals()
    if dragToggleBtn._active or dragToggleBtn._isDragging then
      dragToggleBtn:SetBackdropColor(0.15, 0.4, 0.7, 0.95)
      dragToggleBtn:SetBackdropBorderColor(0.3, 0.7, 1.0, 1)
      moveIcon:SetVertexColor(1, 1, 1, 1)
    else
      dragToggleBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.85)
      dragToggleBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
      moveIcon:SetVertexColor(0.8, 0.8, 0.8, 1)
    end
  end

  local function SetCastbarDragActive(active)
    dragToggleBtn._active = active
    UpdateDragToggleBtnVisuals()
    if active then
      dragOverlay:EnableMouse(true)
      dragOverlay:Show()
    else
      dragOverlay:EnableMouse(false)
      dragOverlay:Hide()
    end
  end
  dragToggleBtn.SetDragActive = SetCastbarDragActive

  dragToggleBtn:RegisterForDrag("LeftButton")

  dragToggleBtn:SetScript("OnDragStart", function(self)
    self._isDragging = true
    UpdateDragToggleBtnVisuals()
    frame:StartMoving()
  end)
  dragToggleBtn:SetScript("OnDragStop", function(self)
    frame:StopMovingOrSizing()
    self._isDragging = false
    UpdateDragToggleBtnVisuals()
    SaveCastbarPosition()
  end)
  dragToggleBtn:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" then return end
    if self._isDragging then return end
    SetCastbarDragActive(not self._active)
  end)
  dragToggleBtn:SetScript("OnEnter", function(self)
    if self._active or self._isDragging then
      self:SetBackdropColor(0.2, 0.5, 0.8, 1)
    else
      self:SetBackdropColor(0.3, 0.3, 0.3, 0.95)
    end
    self.moveIcon:SetVertexColor(1, 1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Click to toggle drag mode\nDrag to reposition castbar", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  dragToggleBtn:SetScript("OnLeave", function(self)
    if not self._isDragging then UpdateDragToggleBtnVisuals() end
    GameTooltip:Hide()
  end)
  dragToggleBtn:Hide()
  frame.dragToggleBtn = dragToggleBtn

  -- Dragging from the overlay also moves the castbar
  dragOverlay:SetScript("OnDragStart", function()
    dragToggleBtn._isDragging = true
    UpdateDragToggleBtnVisuals()
    frame:StartMoving()
  end)
  dragOverlay:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    dragToggleBtn._isDragging = false
    UpdateDragToggleBtnVisuals()
    SaveCastbarPosition()
  end)

  frame:Hide()

  -- Separate text frame: name + timer (anchored to mainFrame, not movable independently)
  local textFrame = CreateFrame("Frame", "ArcUICastbarText", UIParent)
  textFrame:SetSize(250, 20)
  textFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
  textFrame:SetFrameStrata("HIGH")
  textFrame:SetFrameLevel(200)

  textFrame.nameText = textFrame:CreateFontString(nil, "OVERLAY")
  textFrame.nameText:SetPoint("LEFT", textFrame, "LEFT", 4, 0)
  textFrame.nameText:SetPoint("RIGHT", textFrame, "RIGHT", -38, 0)
  textFrame.nameText:SetJustifyH("LEFT")
  textFrame.nameText:SetJustifyV("MIDDLE")

  textFrame.timerText = textFrame:CreateFontString(nil, "OVERLAY")
  textFrame.timerText:SetPoint("RIGHT", textFrame, "RIGHT", -4, 0)
  textFrame.timerText:SetJustifyH("RIGHT")
  textFrame.timerText:SetJustifyV("MIDDLE")

  textFrame:Hide()

  return frame, textFrame
end

local function GetOrCreateFrames()
  if not castFrameObj then
    castFrameObj, castTextFrame = CreateCastbarFrames()
  end
  return castFrameObj, castTextFrame
end

-- ===================================================================
-- BORDER DRAWING
-- ===================================================================
local function ApplyBorder(mainFrame, cfg)
  local bo = mainFrame.borderOverlay
  if cfg.showBorder then
    local bt = PixelUtil.GetNearestPixelSize(cfg.drawnBorderThickness or 2, mainFrame:GetEffectiveScale(), 1)
    local bc = cfg.borderColor or {r=0, g=0, b=0, a=1}

    for _, t in pairs({bo.top, bo.bottom, bo.left, bo.right}) do
      t:SetSnapToPixelGrid(true)
      t:SetTexelSnappingBias(1)
    end

    bo.top:ClearAllPoints()
    bo.top:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    bo.top:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    bo.top:SetHeight(bt)
    bo.top:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    bo.top:Show()

    bo.bottom:ClearAllPoints()
    bo.bottom:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, 0)
    bo.bottom:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
    bo.bottom:SetHeight(bt)
    bo.bottom:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    bo.bottom:Show()

    bo.left:ClearAllPoints()
    bo.left:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, -bt)
    bo.left:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, bt)
    bo.left:SetWidth(bt)
    bo.left:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    bo.left:Show()

    bo.right:ClearAllPoints()
    bo.right:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, -bt)
    bo.right:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, bt)
    bo.right:SetWidth(bt)
    bo.right:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    bo.right:Show()

    bo:Show()
  else
    bo.top:Hide(); bo.bottom:Hide(); bo.left:Hide(); bo.right:Hide()
    bo:Hide()
  end
end

-- ===================================================================
-- APPLY APPEARANCE
-- ===================================================================
function ns.Castbar.ApplyAppearance()
  local cfg = GetCastbarDB()
  if not cfg then return end

  local mainFrame, textFrame = GetOrCreateFrames()

  if not cfg.enabled then
    mainFrame:Hide()
    textFrame:Hide()
    return
  end

  -- Size
  local w = PixelSize(cfg.width or 250)
  local h = PixelSize(cfg.height or 20)
  mainFrame:SetSize(w, h)
  textFrame:SetSize(w, h)

  -- Position
  local pos = cfg.barPosition or {point="CENTER", relPoint="CENTER", x=0, y=-100}
  mainFrame:ClearAllPoints()
  mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or -100)
  textFrame:ClearAllPoints()
  textFrame:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)

  -- Strata and level
  local strata = cfg.barFrameStrata or "MEDIUM"
  local level  = cfg.barFrameLevel or 10
  mainFrame:SetFrameStrata(strata)
  mainFrame:SetFrameLevel(level)
  mainFrame.fillBar:SetFrameLevel(level + 2)
  if mainFrame.stageMarkerFrame then mainFrame.stageMarkerFrame:SetFrameLevel(level + 6) end
  mainFrame.borderOverlay:SetFrameLevel(level + 10)
  mainFrame.iconFrame:SetFrameLevel(level + 5)
  textFrame:SetFrameStrata(strata)
  textFrame:SetFrameLevel(level + 100)

  -- Opacity
  mainFrame:SetAlpha(cfg.opacity or 1.0)

  -- Background
  if cfg.showBackground then
    local bg = cfg.backgroundColor or {r=0.1, g=0.1, b=0.1, a=0.9}
    mainFrame.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a or 0.9)
    mainFrame.bg:Show()
  else
    mainFrame.bg:Hide()
  end

  -- Border
  ApplyBorder(mainFrame, cfg)

  -- Texture for fill bar
  local texPath = "Interface\\TargetingFrame\\UI-StatusBar"
  if LSM and cfg.texture then
    texPath = LSM:Fetch("statusbar", cfg.texture) or texPath
  end
  mainFrame.fillBar:SetStatusBarTexture(texPath)

  -- Icon
  local iconSize = PixelSize(cfg.iconSize or 20)
  mainFrame.iconFrame:SetSize(iconSize, iconSize)
  if cfg.showIcon then
    mainFrame.iconFrame:Show()
  else
    mainFrame.iconFrame:Hide()
  end

  -- Font
  local fontPath = "Fonts\\FRIZQT__.TTF"
  if LSM and cfg.font then
    fontPath = LSM:Fetch("font", cfg.font) or fontPath
  end
  local fontSize  = cfg.fontSize or 14
  local outline   = cfg.textOutline
  if outline == "NONE" or outline == "None" or outline == "" then outline = nil end
  local tc = cfg.textColor or {r=1, g=1, b=1, a=1}

  textFrame.nameText:SetFont(fontPath, fontSize, outline)
  textFrame.nameText:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)
  textFrame.timerText:SetFont(fontPath, fontSize, outline)
  textFrame.timerText:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)

  -- While options are open, keep bar visible so the user can see and drag it
  if ns._arcUIOptionsOpen and ns.Castbar.ShowPreview then
    ns.Castbar.ShowPreview()
  else
    if mainFrame.dragToggleBtn then mainFrame.dragToggleBtn:Hide() end
  end
end

-- ===================================================================
-- STAGE MARKERS (empowered casts)
-- ===================================================================
local function HideStageMarkers()
  if not castFrameObj or not castFrameObj.stageMarkers then return end
  for i = 1, 4 do
    if castFrameObj.stageMarkers[i] then castFrameObj.stageMarkers[i]:Hide() end
  end
end

local function PlaceStageMarkers()
  if not castFrameObj or not castFrameObj.stageMarkers then return end
  local barW = castFrameObj:GetWidth()
  for i = 1, 4 do
    local m = castFrameObj.stageMarkers[i]
    local p = castEmpowerStageProps[i]
    -- show dividers for stages 1 .. numStages-1 (the gaps between stages)
    if p and i < castEmpowerNumStages then
      local xOff = PixelSize(p * barW)
      m:ClearAllPoints()
      m:SetPoint("TOPLEFT",    castFrameObj, "TOPLEFT",    xOff - 1, 0)
      m:SetPoint("BOTTOMLEFT", castFrameObj, "BOTTOMLEFT", xOff - 1, 0)
      m:Show()
    else
      m:Hide()
    end
  end
end

-- ===================================================================
-- ONUPDATE (only runs during an active cast)
-- ===================================================================
local function CastOnUpdate(self, elapsed)
  local cfg = GetCastbarDB()
  if not cfg then return end

  -- Regular channels: refine timing from UnitChannelInfo on each tick until confirmed.
  -- Empowered casts already have accurate timing (castTimingRefined=true), so skip.
  if castIsChannel and not castIsEmpowered and not castTimingRefined then
    local name, _, _, st, et = UnitChannelInfo("player")
    if name and st and et and et > st then
      castStartTime     = st / 1000
      castEndTime       = et / 1000
      castTimingRefined = true
    end
  end

  local now = GetTime()
  local total = castEndTime - castStartTime
  if total <= 0 then return end

  local progress
  if castIsChannel and not castIsEmpowered then
    -- Regular channels drain from full to empty
    progress = 1.0 - (now - castStartTime) / total
  else
    -- Normal casts and empowered casts fill left to right
    progress = (now - castStartTime) / total
  end
  progress = math.max(0, math.min(1, progress))

  castFrameObj.fillBar:SetValue(progress)

  -- Live countdown timer
  if cfg.showTimer then
    local remaining = castEndTime - now
    if remaining < 0 then remaining = 0 end
    castTextFrame.timerText:SetText(string.format("%.1f", remaining))
  end
end

-- ===================================================================
-- SHOW / STOP CAST
-- ===================================================================
local function ShowCast(spellID, startTimeMS, endTimeMS, isChannel, notInterruptible, isEmpowered, numStages, stageProps)
  local cfg = GetCastbarDB()
  if not cfg or not cfg.enabled then return end
  if cfg.hideOutOfCombat and not InCombatLockdown() then return end
  if isChannel and not isEmpowered and cfg.hideChannels then return end

  local mainFrame, textFrame = GetOrCreateFrames()

  castActive            = true
  castPreviewActive     = false
  castTimingRefined     = false
  castIsChannel         = isChannel or false
  castIsEmpowered       = isEmpowered or false
  castEmpowerNumStages  = numStages or 0
  castEmpowerStageProps = stageProps or {}
  castStartTime         = (startTimeMS or 0) / 1000
  castEndTime           = (endTimeMS   or 0) / 1000

  -- Spell info (WoW 12.0: C_Spell.GetSpellInfo returns a table)
  local spellName, spellIconID
  if spellID and spellID > 0 then
    local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    if info then
      spellName  = info.name
      spellIconID = info.iconID or info.originalIconID
    end
  end

  -- Icon
  if cfg.showIcon and spellIconID then
    mainFrame.iconTex:SetTexture(spellIconID)
    mainFrame.iconFrame:Show()
  else
    mainFrame.iconFrame:Hide()
  end

  -- Spell name
  if cfg.showText then
    textFrame.nameText:SetText(spellName or "")
  else
    textFrame.nameText:SetText("")
  end

  -- Bar color: empowered > channel > cast
  local color
  if castIsEmpowered then
    color = cfg.empowerColor or {r=0.6, g=0.2, b=1, a=1}
  elseif isChannel then
    color = cfg.channelColor or {r=0.2, g=1, b=0.4, a=1}
  else
    color = cfg.barColor or {r=0.2, g=0.8, b=1, a=1}
  end
  mainFrame.fillBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)

  -- Initial fill: regular channels start full (drain R→L); casts and empowered start empty (fill L→R)
  mainFrame.fillBar:SetValue((isChannel and not castIsEmpowered) and 1 or 0)

  -- Initial timer text
  if cfg.showTimer then
    local duration = castEndTime - castStartTime
    if duration < 0 then duration = 0 end
    textFrame.timerText:SetText(string.format("%.1f", duration))
  else
    textFrame.timerText:SetText("")
  end

  if mainFrame.dragToggleBtn then mainFrame.dragToggleBtn:Hide() end
  mainFrame:Show()
  textFrame:Show()
  if castIsEmpowered then
    PlaceStageMarkers()
  else
    HideStageMarkers()
  end
  mainFrame:SetScript("OnUpdate", CastOnUpdate)
end

local function StopCast()
  castActive = false
  HideStageMarkers()
  castIsEmpowered      = false
  castEmpowerNumStages  = 0
  castEmpowerStageProps = {}
  if castFrameObj then
    castFrameObj:SetScript("OnUpdate", nil)
    castFrameObj:Hide()
  end
  if castTextFrame then
    castTextFrame:Hide()
  end
  -- Restore preview if options panel is still open
  if ns._arcUIOptionsOpen and ns.Castbar.ShowPreview then
    ns.Castbar.ShowPreview()
  end
end

-- ===================================================================
-- PREVIEW (shown while options panel is open for positioning)
-- ===================================================================
local function ShowPreview()
  local cfg = GetCastbarDB()
  if not cfg or not cfg.enabled then return end
  if castActive then return end  -- don't override a live cast

  local mainFrame, textFrame = GetOrCreateFrames()
  castPreviewActive = true

  local color = cfg.barColor or {r=0.2, g=0.8, b=1, a=1}
  mainFrame.fillBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
  mainFrame.fillBar:SetValue(0.6)
  mainFrame.iconFrame:Hide()

  textFrame.nameText:SetText(cfg.showText and "Castbar Preview" or "")
  textFrame.timerText:SetText(cfg.showTimer and "1.2" or "")

  local cfg2 = GetCastbarDB()
  if mainFrame.dragToggleBtn and cfg2 and cfg2.barMovable ~= false then
    mainFrame.dragToggleBtn:Show()
  end
  mainFrame:Show()
  textFrame:Show()
end
ns.Castbar.ShowPreview = ShowPreview

local function HidePreview()
  if not castPreviewActive then return end
  castPreviewActive = false
  if not castActive then
    if castFrameObj then
      if castFrameObj.dragToggleBtn then
        castFrameObj.dragToggleBtn.SetDragActive(false)
        castFrameObj.dragToggleBtn:Hide()
      end
      castFrameObj:Hide()
    end
    if castTextFrame then castTextFrame:Hide() end
  end
end
ns.Castbar.HidePreview = HidePreview

-- ===================================================================
-- EVENT HANDLER
-- ===================================================================
local castEventFrame = CreateFrame("Frame")
castEventFrame:RegisterEvent("PLAYER_LOGIN")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_START")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
castEventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
castEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
castEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

castEventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
  if event == "PLAYER_LOGIN" then
    ns.Castbar.Init()
    return
  end

  -- Re-evaluate hideOutOfCombat visibility on combat state changes (no unit arg)
  if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
    if not castActive then
      local cfg = GetCastbarDB()
      if cfg and cfg.enabled and cfg.hideOutOfCombat then
        if event == "PLAYER_REGEN_ENABLED" then
          if castFrameObj then
            castFrameObj:Hide()
            if castTextFrame then castTextFrame:Hide() end
          end
        end
      end
    end
    return
  end

  -- All UNIT_SPELLCAST_* events pass unit as the first argument
  if unit ~= "player" then return end

  if event == "UNIT_SPELLCAST_START" then
    local name, _, _, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo("player")
    if name then
      ShowCast(spellID, startTimeMS, endTimeMS, false, notInterruptible)
    end

  elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
    -- UnitChannelInfo is the canonical source for both regular channels and empowered casts.
    -- numEmpowerStages > 0 signals an empowered cast (fills L→R with stage dividers).
    local name, _, _, startTimeMS, endTimeMS, _, _, chanSpellID, _, numStages = UnitChannelInfo("player")
    if name then
      local useSpellID = chanSpellID or spellID
      local isEmpoweredCast = numStages and numStages > 0
      if isEmpoweredCast then
        -- Add hold-at-max time so the bar ends after the player can release at full charge
        local holdAtMax = GetUnitEmpowerHoldAtMaxTime and GetUnitEmpowerHoldAtMaxTime("player") or 0
        local totalEndMS = endTimeMS + holdAtMax
        local totalDurMS = totalEndMS - startTimeMS
        -- Calculate per-stage boundary proportions using per-stage hold durations
        local stageProps = {}
        local cumMS = 0
        for i = 1, numStages - 1 do
          local stageDur
          if GetUnitEmpowerStageDuration then
            stageDur = GetUnitEmpowerStageDuration("player", i)
          end
          if not stageDur or stageDur <= 0 then
            stageDur = totalDurMS / numStages
          end
          cumMS = cumMS + stageDur
          stageProps[i] = math.min(cumMS / totalDurMS, 0.99)
        end
        castTimingRefined = true
        ShowCast(useSpellID, startTimeMS, totalEndMS, false, false, true, numStages, stageProps)
      else
        -- Regular channel (e.g. Spinning Crane Kick): accurate timing from UnitChannelInfo directly
        castTimingRefined = true
        ShowCast(useSpellID, startTimeMS, endTimeMS, true, false)
      end
    else
      -- UnitChannelInfo unavailable at event fire (very rare edge case)
      local startMS = GetTime() * 1000
      ShowCast(spellID, startMS, startMS + 3000, true, false)
    end

  elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
    -- Stage was reached; OnUpdate handles fill progress via time comparison; nothing needed here

  elseif event == "UNIT_SPELLCAST_DELAYED" then
    -- Cast was pushed back (hit while casting); update end time
    if castActive and not castIsChannel then
      local name, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
      if name then
        castStartTime = (startTimeMS or 0) / 1000
        castEndTime   = (endTimeMS   or 0) / 1000
      end
    end

  elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
    -- Channel speed changed (e.g. Sped Up buff); skip empowered — their end time includes holdAtMax
    if castActive and castIsChannel and not castIsEmpowered then
      local name, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
      if name then
        castStartTime = (startTimeMS or 0) / 1000
        castEndTime   = (endTimeMS   or 0) / 1000
      end
    end

  elseif event == "UNIT_SPELLCAST_STOP"
      or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED"
      or event == "UNIT_SPELLCAST_SUCCEEDED"
      or event == "UNIT_SPELLCAST_CHANNEL_STOP"
      or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
    StopCast()
  end
end)

-- ===================================================================
-- INIT
-- ===================================================================
function ns.Castbar.Init()
  ns.Castbar.ApplyAppearance()
  if ns.CDMShared and ns.CDMShared.RegisterPanelCallback then
    ns.CDMShared.RegisterPanelCallback("Castbar", {
      onOpen  = ShowPreview,
      onClose = HidePreview,
    })
  end
  if ns._arcUIOptionsOpen then ShowPreview() end
end

-- ===================================================================
-- END OF ArcUI_Castbar.lua
-- ===================================================================
