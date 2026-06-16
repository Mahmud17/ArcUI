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
-- DEBUG
-- Toggle with /arccastdebug
-- ===================================================================
local arcCastDebug = false
local function CastDebug(...)
  if arcCastDebug then print("|cff00ff00[ArcCast]|r", ...) end
end

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

  -- Segment bars for empowered casts — one StatusBar per stage, fills with its own color
  frame.stageSegBars = {}
  for i = 1, 4 do
    local sb = CreateFrame("StatusBar", nil, frame)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    sb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    sb:SetStatusBarColor(1, 1, 1, 1)
    sb:SetFrameLevel(frame:GetFrameLevel() + 3)
    sb:EnableMouse(false)
    sb:Hide()
    frame.stageSegBars[i] = sb
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
  if mainFrame.stageSegBars then
    for _, sb in ipairs(mainFrame.stageSegBars) do sb:SetFrameLevel(level + 3) end
  end
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
  if mainFrame.stageSegBars then
    for _, sb in ipairs(mainFrame.stageSegBars) do sb:SetStatusBarTexture(texPath) end
  end

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
-- EMPOWERED SEGMENT BARS
-- ===================================================================
local function HideEmpowerVisuals()
  if not castFrameObj then return end
  if castFrameObj.stageSegBars then
    for i = 1, 4 do
      if castFrameObj.stageSegBars[i] then castFrameObj.stageSegBars[i]:Hide() end
    end
  end
  -- Ensure the main fill bar is visible for non-segment mode
  if castFrameObj.fillBar then castFrameObj.fillBar:Show() end
end

local function PlaceSegmentBars()
  if not castFrameObj then return end
  local cfg    = GetCastbarDB()
  local barW   = castFrameObj:GetWidth()
  local barH   = castFrameObj:GetHeight()
  local segs   = castFrameObj.stageSegBars
  -- In preview mode (options panel open, no live cast) show a 4-stage demo layout
  local nStage = castEmpowerNumStages
  local props  = castEmpowerStageProps
  if castPreviewActive and nStage == 0 then
    nStage = 4
    props  = {0.25, 0.5, 0.75}
  end
  local useSegs = cfg and cfg.empowerSegmentColorsEnabled and nStage > 0

  -- Switch between single fill bar and per-segment bars
  if useSegs then
    castFrameObj.fillBar:Hide()
  else
    castFrameObj.fillBar:Show()
  end

  for i = 1, 4 do
    local sb = segs and segs[i]
    if sb then
      if useSegs and i <= nStage then
        local segStart = i > 1 and (props[i-1] or 0) or 0
        local segEnd   = props[i] or 1
        local segW     = math.max(1, PixelSize((segEnd - segStart) * barW))
        local segX     = PixelSize(segStart * barW)
        sb:SetSize(segW, barH)
        sb:ClearAllPoints()
        sb:SetPoint("TOPLEFT", castFrameObj, "TOPLEFT", segX, 0)
        local cols = cfg and cfg.empowerSegmentColors
        local c    = cols and cols[i] or {r=1, g=1, b=1, a=1}
        sb:SetStatusBarColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        sb:SetValue(0)
        sb:Show()
      else
        sb:Hide()
      end
    end
  end
end
ns.Castbar.RefreshSegmentBars = PlaceSegmentBars

-- ===================================================================
-- ONUPDATE (only runs during an active cast)
-- ===================================================================
local function CastOnUpdate(self, elapsed)
  local cfg = GetCastbarDB()
  if not cfg then return end

  -- Regular channels: refine timing on each tick until we get valid server timestamps.
  if castIsChannel and not castIsEmpowered and not castTimingRefined then
    local name, _, _, st, et = UnitChannelInfo("player")
    if name and st and st > 0 and et and et > st then
      castStartTime     = st / 1000
      castEndTime       = et / 1000
      castTimingRefined = true
    end
  end

  -- Empowered casts: refine timing if server timestamps weren't ready at EMPOWER_START time.
  if castIsEmpowered and not castTimingRefined then
    local n2, _, _, st2, et2, _, _, _, _, ns2 = UnitChannelInfo("player")
    if n2 and st2 and st2 > 0 and et2 and et2 > st2 then
      local ha = (GetUnitEmpowerHoldAtMaxTime and GetUnitEmpowerHoldAtMaxTime("player")) or 0
      castStartTime = st2 / 1000
      castEndTime   = (et2 + ha) / 1000
      if ns2 and ns2 > 0 then
        castEmpowerNumStages = ns2
        local newProps = {}
        for i = 1, ns2 - 1 do newProps[i] = i / ns2 end
        castEmpowerStageProps = newProps
        PlaceSegmentBars()
      end
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

  -- Per-stage segment fills (empowered only)
  local segs = castFrameObj and castFrameObj.stageSegBars
  if castIsEmpowered and segs and cfg.empowerSegmentColorsEnabled then
    for i = 1, castEmpowerNumStages do
      local sb = segs[i]
      if sb and sb:IsShown() then
        local props    = castEmpowerStageProps or {}
        local segStart = i > 1 and (props[i-1] or 0) or 0
        local segEnd   = props[i] or 1
        local segDur  = segEnd - segStart
        local segFill
        if segDur > 0 then
          segFill = math.max(0, math.min(1, (progress - segStart) / segDur))
        elseif progress >= segEnd then
          segFill = 1
        else
          segFill = 0
        end
        sb:SetValue(segFill)
      end
    end
  end

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
  if not cfg or not cfg.enabled then
    CastDebug("ShowCast blocked: castbar disabled (spellID=" .. tostring(spellID) .. ")")
    return
  end
  if cfg.hideOutOfCombat and not InCombatLockdown() then
    CastDebug("ShowCast blocked: hideOutOfCombat is on and not in combat (spellID=" .. tostring(spellID) .. ")")
    return
  end
  if isChannel and not isEmpowered and cfg.hideChannels then
    CastDebug("ShowCast blocked: hideChannels is on (spellID=" .. tostring(spellID) .. ")")
    return
  end
  CastDebug("ShowCast: spellID=" .. tostring(spellID)
    .. " isChannel=" .. tostring(isChannel)
    .. " isEmpowered=" .. tostring(isEmpowered)
    .. " start=" .. tostring(startTimeMS)
    .. " end=" .. tostring(endTimeMS))

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
    PlaceSegmentBars()
  else
    HideEmpowerVisuals()
  end
  mainFrame:SetScript("OnUpdate", CastOnUpdate)
end

local function StopCast()
  castActive = false
  HideEmpowerVisuals()
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

  -- Show empowered segment preview when that option is on; otherwise show plain fill bar
  if cfg.empowerSegmentColorsEnabled then
    PlaceSegmentBars()
    -- Partially fill each visible segment so the color is obvious in the preview
    if mainFrame.stageSegBars then
      for i, sb in ipairs(mainFrame.stageSegBars) do
        if sb:IsShown() then sb:SetValue(i == 1 and 1 or i == 2 and 0.6 or 0) end
      end
    end
  else
    HideEmpowerVisuals()
    local color = cfg.barColor or {r=0.2, g=0.8, b=1, a=1}
    mainFrame.fillBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    mainFrame.fillBar:SetValue(0.6)
  end
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
    HideEmpowerVisuals()
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
castEventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
castEventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")

castEventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
  if event == "PLAYER_LOGIN" then
    ns.Castbar.Init()
    return
  end

  -- Spec/talent change — re-run auto-switch presets for the castbar
  if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    C_Timer.After(0.1, function()
      local cfg = GetCastbarDB()
      if cfg and ns.Presets and ns.Presets.RunAutoSwitch then
        if ns.Presets.RunAutoSwitch(cfg, "castbar") then
          ns.Castbar.ApplyAppearance()
        end
      end
    end)
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
    CastDebug("SPELLCAST_START: spellID=" .. tostring(spellID) .. " name=" .. tostring(name))
    if name then
      ShowCast(spellID, startTimeMS, endTimeMS, false, notInterruptible)
    end

elseif event == "UNIT_SPELLCAST_CHANNEL_START"
      or event == "UNIT_SPELLCAST_EMPOWER_START" then

    local isEmpowerEvent = (event == "UNIT_SPELLCAST_EMPOWER_START")

    local function TryStartCast(savedSpellID)
      local name, _, _, startTimeMS, endTimeMS, _, _, chanSpellID, _, numStages = UnitChannelInfo("player")
      CastDebug("TryStartCast: event=" .. event
        .. " name=" .. tostring(name)
        .. " chanSpellID=" .. tostring(chanSpellID)
        .. " savedSpellID=" .. tostring(savedSpellID)
        .. " numStages=" .. tostring(numStages)
        .. " startMS=" .. tostring(startTimeMS)
        .. " endMS=" .. tostring(endTimeMS))
      if not name then
        CastDebug("TryStartCast: UnitChannelInfo returned nil — will defer")
        return false
      end

      local useSpellID   = chanSpellID or savedSpellID
      -- Treat as empowered if UnitChannelInfo says so OR if the event was EMPOWER_START
      local isEmpoweredCast = isEmpowerEvent or (numStages and numStages > 0)
      CastDebug("TryStartCast: isEmpowerEvent=" .. tostring(isEmpowerEvent)
        .. " isEmpoweredCast=" .. tostring(isEmpoweredCast))

      if isEmpoweredCast then
        local stageCount = (numStages and numStages > 0) and numStages or 4
        local ha = (GetUnitEmpowerHoldAtMaxTime and GetUnitEmpowerHoldAtMaxTime("player")) or 0
        local totalEndMS = endTimeMS + ha
        -- Equal-distribution stage boundaries (safe: avoids GetUnitEmpowerStageDuration secrets)
        local stageProps = {}
        for i = 1, stageCount - 1 do stageProps[i] = i / stageCount end
        -- Use placeholder timing if server timestamps not ready yet; CastOnUpdate refines.
        local useStart = (startTimeMS and startTimeMS > 0) and startTimeMS or (GetTime() * 1000)
        local useEnd   = ((totalEndMS - useStart) > 0)    and totalEndMS  or (useStart + 5000)
        ShowCast(useSpellID, useStart, useEnd, false, false, true, stageCount, stageProps)
      else
        ShowCast(useSpellID, startTimeMS, endTimeMS, true, false)
      end
      return true
    end

    if not TryStartCast(spellID) then
      -- UnitChannelInfo not yet populated (race condition at event fire).
      -- Defer one frame; if the cast is still active UnitChannelInfo will have data.
      -- Never fall back to isChannel=true for EMPOWER events (would be hidden by hideChannels).
      CastDebug("TryStartCast returned nil — scheduling 1-frame defer for spellID=" .. tostring(spellID))
      local savedSpellID = spellID
      C_Timer.After(0, function()
        if castActive then
          CastDebug("Deferred TryStartCast: cast already active, skipping")
          return
        end
        local n = select(1, UnitChannelInfo("player"))
        CastDebug("Deferred TryStartCast: UnitChannelInfo name=" .. tostring(n))
        if n then TryStartCast(savedSpellID) end
      end)
    end

  elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
    -- Catch-all: if EMPOWER_START was missed entirely (nil race resolved too late),
    -- initialize the bar now using current UnitChannelInfo data.
    if not castActive then
      local name, _, _, startTimeMS, endTimeMS, _, _, chanSpellID, _, numStages = UnitChannelInfo("player")
      if name then
        local useSpellID = chanSpellID or spellID
        local stageCount = (numStages and numStages > 0) and numStages or 4
        local ha = (GetUnitEmpowerHoldAtMaxTime and GetUnitEmpowerHoldAtMaxTime("player")) or 0
        local totalEndMS = endTimeMS + ha
        local stageProps = {}
        for i = 1, stageCount - 1 do stageProps[i] = i / stageCount end
        ShowCast(useSpellID, startTimeMS, totalEndMS, false, false, true, stageCount, stageProps)
      end
    end

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
      or event == "UNIT_SPELLCAST_INTERRUPTED" then
    StopCast()

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- Channels and empowered casts fire SUCCEEDED while still running (spell commits to server).
    -- Let CHANNEL_STOP / EMPOWER_STOP handle the actual end.
    if not castIsChannel and not castIsEmpowered then StopCast() end

  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP"
      or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
    StopCast()
  end
end)

-- ===================================================================
-- DEBUG SLASH COMMAND  (/arccastdebug)
-- ===================================================================
SLASH_ARCCASTDEBUG1 = "/arccastdebug"
SlashCmdList["ARCCASTDEBUG"] = function()
  arcCastDebug = not arcCastDebug
  local cfg = GetCastbarDB()
  local state = arcCastDebug and "|cff00ff00ON|r" or "|cffff4444OFF|r"
  print("|cff00ff00[ArcCast]|r Debug " .. state)
  if arcCastDebug and cfg then
    print("|cff00ff00[ArcCast]|r Config dump:")
    print("  enabled=" .. tostring(cfg.enabled))
    print("  hideChannels=" .. tostring(cfg.hideChannels))
    print("  hideOutOfCombat=" .. tostring(cfg.hideOutOfCombat))
    print("  castActive=" .. tostring(castActive))
    print("  castIsChannel=" .. tostring(castIsChannel))
    print("  castIsEmpowered=" .. tostring(castIsEmpowered))
    print("  castEmpowerNumStages=" .. tostring(castEmpowerNumStages))
    print("  InCombat=" .. tostring(InCombatLockdown()))
    local n, _, _, st, et, _, _, sid, _, ns2 = UnitChannelInfo("player")
    if n then
      print("  UnitChannelInfo: name=" .. tostring(n) .. " spellID=" .. tostring(sid)
        .. " numStages=" .. tostring(ns2) .. " startMS=" .. tostring(st) .. " endMS=" .. tostring(et))
    else
      print("  UnitChannelInfo: nil (no active channel/empower)")
    end
    local cn = select(1, UnitCastingInfo("player"))
    print("  UnitCastingInfo: name=" .. tostring(cn))
  end
end

-- Expose castbar state for the global /arcdebug command in ArcUI_Options.lua
function ns.Castbar.GetStatus()
  local cfg = GetCastbarDB()
  local kind = castIsEmpowered and "empowered" or castIsChannel and "channel" or "cast"
  return {
    enabled           = cfg and cfg.enabled         or false,
    hideChannels      = cfg and cfg.hideChannels     or false,
    hideOutOfCombat   = cfg and cfg.hideOutOfCombat  or false,
    showIcon          = cfg and cfg.showIcon         or false,
    showTimer         = cfg and cfg.showTimer        or false,
    showText          = cfg and cfg.showText         or false,
    width             = cfg and cfg.width            or 0,
    height            = cfg and cfg.height           or 0,
    castActive        = castActive,
    castKind          = kind,
    castEmpowerStages = castEmpowerNumStages,
  }
end

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
