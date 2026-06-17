-- ===================================================================
-- ArcUI_Castbar_Options.lua
-- ===================================================================

local ADDON, ns = ...
ns.CastbarOptions = ns.CastbarOptions or {}

local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local function GetCastbarDB()
  local db = ns.API and ns.API.GetDB and ns.API.GetDB()
  return db and db.castbar
end

local function Refresh()
  if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
  if ns.Castbar and ns.Castbar.ApplyAppearance then ns.Castbar.ApplyAppearance() end
end

local function RefreshSegs()
  if ns.Castbar and ns.Castbar.RefreshSegmentBars then ns.Castbar.RefreshSegmentBars() end
  Refresh()
end

-- ===================================================================
-- OPTIONS TABLE
-- ===================================================================
function ns.CastbarOptions.GetOptionsTable()
  local opts = {
    type  = "group",
    name  = "Castbar",
    order = 3.5,
    args  = {

      -- ── Enable ─────────────────────────────────────────────────────
      enabled = {
        type  = "toggle",
        name  = "|cffffd100Enable Castbar|r",
        desc  = "Show a castbar while casting or channeling spells.",
        order = 1,
        width = "full",
        get   = function() local c = GetCastbarDB(); return c and c.enabled end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.enabled = v; Refresh() end end,
      },

      spacer1 = { type = "description", name = "", order = 2 },

      -- ── Bar ────────────────────────────────────────────────────────
      barHeader = { type = "header", name = "Bar", order = 10 },

      barColor = {
        type     = "color",
        name     = "Cast Color",
        desc     = "Color of the bar during a normal cast.",
        order    = 11,
        hasAlpha = true,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.barColor or {r=0.2, g=0.8, b=1, a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.barColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      channelColor = {
        type     = "color",
        name     = "Channel Color",
        desc     = "Color of the bar during a channeled spell.",
        order    = 12,
        hasAlpha = true,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.channelColor or {r=0.2, g=1, b=0.4, a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.channelColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      empowerColor = {
        type     = "color",
        name     = "Empowered Color",
        desc     = "Color of the bar during an empowered cast (used when segment colors are disabled).",
        order    = 13,
        hasAlpha = true,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.empowerColor or {r=0.6, g=0.2, b=1, a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.empowerColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      texture = {
        type          = "select",
        name          = "Texture",
        order         = 14,
        dialogControl = "LSM30_Statusbar",
        values        = LSM and LSM:HashTable("statusbar") or {},
        get           = function() local c = GetCastbarDB(); return c and c.texture or "Blizzard" end,
        set           = function(_, v) local c = GetCastbarDB(); if c then c.texture = v; Refresh() end end,
      },

      width = {
        type  = "range",
        name  = "Width",
        order = 15,
        min   = 50, max = 600, step = 1,
        get   = function() local c = GetCastbarDB(); return c and c.width or 250 end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.width = v; Refresh() end end,
      },

      height = {
        type  = "range",
        name  = "Height",
        order = 16,
        min   = 4, max = 80, step = 1,
        get   = function() local c = GetCastbarDB(); return c and c.height or 20 end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.height = v; Refresh() end end,
      },

      opacity = {
        type      = "range",
        name      = "Opacity",
        order     = 17,
        min       = 0, max = 1, step = 0.05,
        isPercent = true,
        get       = function() local c = GetCastbarDB(); return c and c.opacity or 1.0 end,
        set       = function(_, v) local c = GetCastbarDB(); if c then c.opacity = v; Refresh() end end,
      },

      -- ── Empowered Stages ───────────────────────────────────────────
      empowerStagesHeader = { type = "header", name = "Empowered Stages", order = 20 },

      empowerStagesDesc = {
        type     = "description",
        name     = "When enabled, each stage of an empowered cast (e.g. Fire Breath) fills as its own colored bar segment instead of a single bar.",
        order    = 20.1,
        fontSize = "small",
      },

      empowerSegmentColorsEnabled = {
        type  = "toggle",
        name  = "Color Stage Segments",
        desc  = "Replace the single bar with per-stage colored segments during empowered casts.",
        order = 20.2,
        width = "full",
        get   = function() local c = GetCastbarDB(); return c and c.empowerSegmentColorsEnabled end,
        set   = function(_, v)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColorsEnabled = v; RefreshSegs() end
        end,
      },

      empowerMaxStages = {
        type  = "range",
        name  = "Max Stages",
        desc  = "How many empowered stage color pickers to show, and the number of segments used in the preview. Matches the number of stages the spell actually uses (up to 8).",
        order = 20.25,
        min   = 1, max = 8, step = 1,
        get   = function() local c = GetCastbarDB(); return c and c.empowerMaxStages or 5 end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.empowerMaxStages = v; RefreshSegs() end end,
      },

      empowerSegmentColor1 = {
        type     = "color",
        name     = "Stage 1",
        desc     = "Color for stage 1.",
        order    = 20.3,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 1 > (c.empowerMaxStages or 5)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[1] or {r=0.6,g=0.2,b=1,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[1] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor2 = {
        type     = "color",
        name     = "Stage 2",
        desc     = "Color for stage 2.",
        order    = 20.4,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 2 > (c.empowerMaxStages or 5)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[2] or {r=0.9,g=0.1,b=0.6,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[2] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor3 = {
        type     = "color",
        name     = "Stage 3",
        desc     = "Color for stage 3.",
        order    = 20.5,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 3 > (c.empowerMaxStages or 5)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[3] or {r=1,g=0.3,b=0.1,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[3] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor4 = {
        type     = "color",
        name     = "Stage 4",
        desc     = "Color for stage 4.",
        order    = 20.6,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 4 > (c.empowerMaxStages or 5)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[4] or {r=1,g=0.7,b=0.1,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[4] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor5 = {
        type     = "color",
        name     = "Stage 5",
        desc     = "Color for stage 5.",
        order    = 20.7,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 5 > (c.empowerMaxStages or 5)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[5] or {r=0.1,g=0.9,b=0.3,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[5] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor6 = {
        type     = "color",
        name     = "Stage 6",
        desc     = "Color for stage 6.",
        order    = 20.8,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 6 > (c.empowerMaxStages or 5)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[6] or {r=0.1,g=0.7,b=1.0,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[6] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor7 = {
        type     = "color",
        name     = "Stage 7",
        desc     = "Color for stage 7.",
        order    = 20.9,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 7 > (c.empowerMaxStages or 4)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[7] or {r=1,g=1,b=0.2,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[7] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      empowerSegmentColor8 = {
        type     = "color",
        name     = "Stage 8",
        desc     = "Color for stage 8.",
        order    = 20.95,
        hasAlpha = true,
        hidden   = function()
          local c = GetCastbarDB()
          return not (c and c.empowerSegmentColorsEnabled) or 8 > (c.empowerMaxStages or 4)
        end,
        get = function()
          local c = GetCastbarDB()
          local col = c and c.empowerSegmentColors and c.empowerSegmentColors[8] or {r=0.8,g=0.8,b=0.8,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB()
          if c then c.empowerSegmentColors = c.empowerSegmentColors or {}; c.empowerSegmentColors[8] = {r=r,g=g,b=b,a=a}; RefreshSegs() end
        end,
      },

      -- ── Tick Marks ─────────────────────────────────────────────────
      tickMarksHeader = { type = "header", name = "Channel Tick Marks", order = 22 },

      tickMarksDesc = {
        type     = "description",
        name     = "Show dividers on channeled spells at each tick position. Set a Default Count below to apply to all channels, or configure per-spell counts in the Spell Overrides section.",
        order    = 22.1,
        fontSize = "small",
      },

      tickMarksEnabled = {
        type  = "toggle",
        name  = "Enable Tick Marks",
        desc  = "Show tick mark dividers during channeled spells.",
        order = 22.2,
        width = "full",
        get   = function() local c = GetCastbarDB(); return c and c.tickMarksEnabled end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.tickMarksEnabled = v; Refresh() end end,
      },

      tickMarksDefaultCount = {
        type  = "range",
        name  = "Default Tick Count",
        desc  = "Number of ticks to show for all channeled spells. 0 = disabled (use per-spell counts from Spell Overrides only). A per-spell override always takes priority over this value.",
        order = 22.25,
        min   = 0, max = 32, step = 1,
        width = "full",
        hidden = function() local c = GetCastbarDB(); return not (c and c.tickMarksEnabled) end,
        get    = function() local c = GetCastbarDB(); return c and c.tickMarksDefaultCount or 0 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.tickMarksDefaultCount = v end end,
      },

      tickMarksColor = {
        type     = "color",
        name     = "Tick Color",
        order    = 22.3,
        hasAlpha = true,
        hidden   = function() local c = GetCastbarDB(); return not (c and c.tickMarksEnabled) end,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.tickMarksColor or {r=1,g=1,b=1,a=0.6}
          return col.r, col.g, col.b, col.a or 0.6
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.tickMarksColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      tickMarksThickness = {
        type   = "range",
        name   = "Tick Thickness",
        order  = 22.4,
        min    = 1, max = 8, step = 1,
        hidden = function() local c = GetCastbarDB(); return not (c and c.tickMarksEnabled) end,
        get    = function() local c = GetCastbarDB(); return c and c.tickMarksThickness or 2 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.tickMarksThickness = v; Refresh() end end,
      },

      tickMarksHeightFraction = {
        type      = "range",
        name      = "Tick Height",
        desc      = "Height of tick marks as a fraction of the bar height.",
        order     = 22.5,
        min       = 0.1, max = 1.0, step = 0.05,
        isPercent = true,
        hidden    = function() local c = GetCastbarDB(); return not (c and c.tickMarksEnabled) end,
        get       = function() local c = GetCastbarDB(); return c and c.tickMarksHeightFraction or 1.0 end,
        set       = function(_, v) local c = GetCastbarDB(); if c then c.tickMarksHeightFraction = v; Refresh() end end,
      },

      -- ── Uninterruptible ────────────────────────────────────────────
      uninterruptibleHeader = { type = "header", name = "Uninterruptible Casts", order = 25 },

      uninterruptibleDesc = {
        type     = "description",
        name     = "Apply a different color and border to the bar when a cast cannot be interrupted (e.g. Divine Shield, Bladestorm).",
        order    = 25.1,
        fontSize = "small",
      },

      uninterruptibleEnabled = {
        type  = "toggle",
        name  = "Enable Uninterruptible Styling",
        order = 25.2,
        width = "full",
        get   = function() local c = GetCastbarDB(); return c and c.uninterruptibleEnabled end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.uninterruptibleEnabled = v; Refresh() end end,
      },

      uninterruptibleColor = {
        type     = "color",
        name     = "Bar Color",
        desc     = "Bar color during an uninterruptible cast.",
        order    = 25.3,
        hasAlpha = true,
        hidden   = function() local c = GetCastbarDB(); return not (c and c.uninterruptibleEnabled) end,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.uninterruptibleColor or {r=0.5,g=0.5,b=0.5,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.uninterruptibleColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      uninterruptibleBorderColor = {
        type     = "color",
        name     = "Border Color",
        desc     = "Border color during an uninterruptible cast (only applied when Show Border is enabled).",
        order    = 25.4,
        hasAlpha = true,
        hidden   = function() local c = GetCastbarDB(); return not (c and c.uninterruptibleEnabled) end,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.uninterruptibleBorderColor or {r=0.3,g=0.3,b=0.5,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.uninterruptibleBorderColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      -- ── Background ─────────────────────────────────────────────────
      bgHeader = { type = "header", name = "Background", order = 30 },

      showBackground = {
        type  = "toggle",
        name  = "Show Background",
        order = 31,
        get   = function() local c = GetCastbarDB(); return c and c.showBackground end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.showBackground = v; Refresh() end end,
      },

      backgroundColor = {
        type     = "color",
        name     = "Background Color",
        order    = 32,
        hasAlpha = true,
        hidden   = function() local c = GetCastbarDB(); return not (c and c.showBackground) end,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.backgroundColor or {r=0.1,g=0.1,b=0.1,a=0.9}
          return col.r, col.g, col.b, col.a or 0.9
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.backgroundColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      -- ── Border ─────────────────────────────────────────────────────
      borderHeader = { type = "header", name = "Border", order = 40 },

      showBorder = {
        type  = "toggle",
        name  = "Show Border",
        order = 41,
        get   = function() local c = GetCastbarDB(); return c and c.showBorder end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.showBorder = v; Refresh() end end,
      },

      borderColor = {
        type     = "color",
        name     = "Border Color",
        order    = 42,
        hasAlpha = true,
        hidden   = function() local c = GetCastbarDB(); return not (c and c.showBorder) end,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.borderColor or {r=0,g=0,b=0,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.borderColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      drawnBorderThickness = {
        type   = "range",
        name   = "Border Thickness",
        order  = 43,
        min    = 1, max = 8, step = 1,
        hidden = function() local c = GetCastbarDB(); return not (c and c.showBorder) end,
        get    = function() local c = GetCastbarDB(); return c and c.drawnBorderThickness or 2 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.drawnBorderThickness = v; Refresh() end end,
      },

      -- ── Icon ───────────────────────────────────────────────────────
      iconHeader = { type = "header", name = "Icon", order = 50 },

      showIcon = {
        type  = "toggle",
        name  = "Show Spell Icon",
        desc  = "Show the spell icon to the left of the cast bar.",
        order = 51,
        get   = function() local c = GetCastbarDB(); return c and c.showIcon end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.showIcon = v; Refresh() end end,
      },

      iconSize = {
        type   = "range",
        name   = "Icon Size",
        order  = 52,
        min    = 8, max = 64, step = 1,
        hidden = function() local c = GetCastbarDB(); return not (c and c.showIcon) end,
        get    = function() local c = GetCastbarDB(); return c and c.iconSize or 20 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.iconSize = v; Refresh() end end,
      },

      -- ── Text ───────────────────────────────────────────────────────
      textHeader = { type = "header", name = "Text", order = 60 },

      showText = {
        type  = "toggle",
        name  = "Show Spell Name",
        order = 61,
        get   = function() local c = GetCastbarDB(); return c and c.showText end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.showText = v; Refresh() end end,
      },

      showTimer = {
        type  = "toggle",
        name  = "Show Timer",
        desc  = "Show the remaining cast time.",
        order = 62,
        get   = function() local c = GetCastbarDB(); return c and c.showTimer end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.showTimer = v; Refresh() end end,
      },

      font = {
        type          = "select",
        name          = "Font",
        order         = 63,
        dialogControl = "LSM30_Font",
        values        = LSM and LSM:HashTable("font") or {},
        get           = function() local c = GetCastbarDB(); return c and c.font or "2002 Bold" end,
        set           = function(_, v) local c = GetCastbarDB(); if c then c.font = v; Refresh() end end,
      },

      fontSize = {
        type  = "range",
        name  = "Font Size",
        order = 64,
        min   = 6, max = 32, step = 1,
        get   = function() local c = GetCastbarDB(); return c and c.fontSize or 14 end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.fontSize = v; Refresh() end end,
      },

      textColor = {
        type     = "color",
        name     = "Text Color",
        order    = 65,
        hasAlpha = true,
        get      = function()
          local c = GetCastbarDB()
          local col = c and c.textColor or {r=1,g=1,b=1,a=1}
          return col.r, col.g, col.b, col.a or 1
        end,
        set = function(_, r, g, b, a)
          local c = GetCastbarDB(); if c then c.textColor = {r=r,g=g,b=b,a=a}; Refresh() end
        end,
      },

      textOutline = {
        type   = "select",
        name   = "Text Outline",
        order  = 66,
        values = { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
        get    = function()
          local c = GetCastbarDB()
          local v = c and c.textOutline or "THICKOUTLINE"
          return (v == "" or v == nil) and "NONE" or v
        end,
        set = function(_, v)
          local c = GetCastbarDB()
          if c then c.textOutline = (v == "NONE") and "NONE" or v; Refresh() end
        end,
      },

      -- ── Behavior ───────────────────────────────────────────────────
      behaviorHeader = { type = "header", name = "Behavior", order = 70 },

      hideOutOfCombat = {
        type  = "toggle",
        name  = "Hide Out of Combat",
        desc  = "Do not show the castbar when out of combat.",
        order = 71,
        get   = function() local c = GetCastbarDB(); return c and c.hideOutOfCombat end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.hideOutOfCombat = v end end,
      },

      hideChannels = {
        type  = "toggle",
        name  = "Hide Channels",
        desc  = "Do not show the castbar for channeled spells.",
        order = 72,
        get   = function() local c = GetCastbarDB(); return c and c.hideChannels end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.hideChannels = v end end,
      },

      reverseFill = {
        type  = "toggle",
        name  = "Reverse Fill",
        desc  = "Invert fill direction: casts drain right-to-left; channels fill left-to-right.",
        order = 73,
        get   = function() local c = GetCastbarDB(); return c and c.reverseFill end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.reverseFill = v end end,
      },

      -- ── Frame Strata ───────────────────────────────────────────────
      strataHeader = { type = "header", name = "Frame Strata", order = 80 },

      barFrameStrata = {
        type   = "select",
        name   = "Strata",
        order  = 81,
        values = {
          BACKGROUND = "Background",
          LOW        = "Low",
          MEDIUM     = "Medium",
          HIGH       = "High",
          DIALOG     = "Dialog",
        },
        get = function() local c = GetCastbarDB(); return c and c.barFrameStrata or "MEDIUM" end,
        set = function(_, v) local c = GetCastbarDB(); if c then c.barFrameStrata = v; Refresh() end end,
      },

      barFrameLevel = {
        type  = "range",
        name  = "Frame Level",
        order = 82,
        min   = 1, max = 200, step = 1,
        get   = function() local c = GetCastbarDB(); return c and c.barFrameLevel or 10 end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.barFrameLevel = v; Refresh() end end,
      },

      -- ── Anchor to Group ────────────────────────────────────────────
      anchorGroupHeader = { type = "header", name = "Anchor to Group", order = 88 },

      anchorGroupDesc = {
        type     = "description",
        name     = "Attach the castbar to a CDM Group container. The bar follows the group automatically. Enable Match Size to inherit the group's width.",
        order    = 88.1,
        fontSize = "small",
      },

      anchorToGroup = {
        type  = "toggle",
        name  = "Anchor to Group",
        order = 88.2,
        width = "full",
        get   = function() local c = GetCastbarDB(); return c and c.anchorToGroup end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.anchorToGroup = v; Refresh() end end,
      },

      anchorGroupName = {
        type   = "select",
        name   = "Target Group",
        desc   = "Select which CDM Group to anchor to.",
        order  = 88.3,
        width  = 1.3,
        values = function()
          local groups = {}
          if ns.CDMGroups and ns.CDMGroups.groups then
            for name, _ in pairs(ns.CDMGroups.groups) do groups[name] = name end
          end
          return groups
        end,
        hidden = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup) end,
        get    = function() local c = GetCastbarDB(); return (c and c.anchorGroupName ~= "" and c.anchorGroupName) or nil end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.anchorGroupName = v or ""; Refresh() end end,
      },

      anchorPoint = {
        type     = "select",
        name     = "Side",
        desc     = "Which side of the group to attach the castbar to.",
        order    = 88.4,
        width    = 0.8,
        values   = { TOP = "Above", BOTTOM = "Below", LEFT = "Left", RIGHT = "Right" },
        sorting  = { "TOP", "BOTTOM", "LEFT", "RIGHT" },
        hidden   = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup) end,
        get      = function() local c = GetCastbarDB(); return c and c.anchorPoint or "BOTTOM" end,
        set      = function(_, v) local c = GetCastbarDB(); if c then c.anchorPoint = v; Refresh() end end,
      },

      matchGroupWidth = {
        type   = "toggle",
        name   = "Match Size",
        desc   = "Resize the castbar to match the group's width (or height for Left/Right anchors).",
        order  = 88.5,
        width  = 0.75,
        hidden = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup) end,
        get    = function() local c = GetCastbarDB(); return c and c.matchGroupWidth end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.matchGroupWidth = v; Refresh() end end,
      },

      matchSlotsOnly = {
        type   = "toggle",
        name   = "Match Slots",
        desc   = "Match the icon slot area exactly rather than the full container frame.",
        order  = 88.6,
        width  = 0.75,
        hidden = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup and c.matchGroupWidth) end,
        get    = function() local c = GetCastbarDB(); return c and c.matchSlotsOnly end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.matchSlotsOnly = v; Refresh() end end,
      },

      matchWidthAdjust = {
        type   = "range",
        name   = "Size Adjust",
        desc   = "Fine-tune the matched size in pixels. Negative values shrink the bar.",
        order  = 88.7,
        min    = -200, max = 200, step = 1,
        hidden = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup and c.matchGroupWidth) end,
        get    = function() local c = GetCastbarDB(); return c and c.matchWidthAdjust or 0 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.matchWidthAdjust = v; Refresh() end end,
      },

      anchorOffsetX = {
        type   = "range",
        name   = "X Offset",
        order  = 88.8,
        min    = -200, max = 200, step = 0.5,
        hidden = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup) end,
        get    = function() local c = GetCastbarDB(); return c and c.anchorOffsetX or 0 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.anchorOffsetX = v; Refresh() end end,
      },

      anchorOffsetY = {
        type   = "range",
        name   = "Y Offset",
        order  = 88.9,
        min    = -200, max = 200, step = 0.5,
        hidden = function() local c = GetCastbarDB(); return not (c and c.anchorToGroup) end,
        get    = function() local c = GetCastbarDB(); return c and c.anchorOffsetY or -2 end,
        set    = function(_, v) local c = GetCastbarDB(); if c then c.anchorOffsetY = v; Refresh() end end,
      },

      -- ── Position ───────────────────────────────────────────────────
      positionHeader = { type = "header", name = "Position", order = 90 },

      barMovable = {
        type  = "toggle",
        name  = "Allow Dragging",
        desc  = "Left-click and drag the castbar to reposition it.",
        order = 91,
        get   = function() local c = GetCastbarDB(); return c and c.barMovable ~= false end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c.barMovable = v; Refresh() end end,
      },

      positionDesc = {
        type     = "description",
        name     = "|cffaaaaaaDrag the grip handle (visible while this panel is open) or adjust X/Y below. Position is saved automatically.|r",
        order    = 92,
        fontSize = "small",
      },

      posX = {
        type    = "range",
        name    = "X Offset",
        desc    = "Horizontal offset from screen center.",
        order   = 93,
        min     = -2000, max = 2000, step = 1, bigStep = 10,
        get     = function()
          local c = GetCastbarDB()
          return (c and c.barPosition and c.barPosition.x) or 0
        end,
        set = function(_, v)
          local c = GetCastbarDB()
          if c then
            c.barPosition = c.barPosition or {point="CENTER",relPoint="CENTER",x=0,y=0}
            c.barPosition.x = v
            Refresh()
          end
        end,
      },

      posY = {
        type    = "range",
        name    = "Y Offset",
        desc    = "Vertical offset from screen center.",
        order   = 94,
        min     = -1000, max = 1000, step = 1, bigStep = 10,
        get     = function()
          local c = GetCastbarDB()
          return (c and c.barPosition and c.barPosition.y) or 0
        end,
        set = function(_, v)
          local c = GetCastbarDB()
          if c then
            c.barPosition = c.barPosition or {point="CENTER",relPoint="CENTER",x=0,y=0}
            c.barPosition.y = v
            Refresh()
          end
        end,
      },

      -- ── Skins & Auto-Switch ────────────────────────────────────────
      skinsHeader = { type = "header", name = "Skins & Auto-Switch", order = 100 },

      skinsDesc = {
        type     = "description",
        name     = "Save the current castbar appearance as a named skin, then add rules to automatically load a skin when you switch spec or talents.",
        order    = 100.1,
        fontSize = "small",
      },

      saveSkinName = {
        type  = "input",
        name  = "Skin Name",
        order = 100.2,
        width = 1.4,
        get   = function() local c = GetCastbarDB(); return (c and c._saveSkinNameInput) or "" end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c._saveSkinNameInput = v end end,
      },

      saveSkinButton = {
        type  = "execute",
        name  = "Save Skin",
        order = 100.3,
        width = 0.6,
        func  = function()
          local c = GetCastbarDB()
          if not c then return end
          local name = c._saveSkinNameInput and c._saveSkinNameInput:match("^%s*(.-)%s*$")
          if not name or name == "" then
            print("|cff00ccffArcUI|r: Enter a skin name first.")
            return
          end
          if ns.Presets and ns.Presets.SaveSkin then
            ns.Presets.SaveSkin(name, c, "castbar")
            c._saveSkinNameInput = ""
            print("|cff00ccffArcUI|r: Castbar skin |cffffd100'" .. name .. "'|r saved.")
            if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
          end
        end,
      },

      autoSwitchAddRule = {
        type   = "execute",
        name   = "+ Add Auto-Switch Rule",
        desc   = "Add a rule to automatically load a skin on spec or talent change. Rules are checked top-down; first match wins.",
        order  = 100.4,
        width  = "full",
        hidden = function()
          if not ns.Presets then return true end
          return ns.Presets.GetSkinCount("castbar") == 0
        end,
        func = function()
          local c = GetCastbarDB()
          if not c then return end
          if not c.presets then c.presets = {} end
          if not c.presets.autoSwitch then c.presets.autoSwitch = { rules = {} } end
          local rules = c.presets.autoSwitch.rules
          rules[#rules + 1] = { specIndices = {}, skinName = nil, talentConditions = nil, talentMatchMode = "all" }
          if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
        end,
      },

      -- ── Spell Overrides ────────────────────────────────────────────
      spellOverrideHeader = { type = "header", name = "Spell Overrides", order = 105 },

      spellOverrideDesc = {
        type     = "description",
        name     = "Override bar color, texture, and tick count for specific spells (including item on-use casts). Enter a spell ID and click Add. Find spell IDs with /dump C_Spell.GetSpellInfo(spellID) in-game.",
        order    = 105.1,
        fontSize = "small",
      },

      debugHint = {
        type     = "description",
        name     = "Tip: use |cff88aaff/arccastdebug|r to toggle debug output — it prints the active spell ID, name, channel/empower state, and interruptible flag.",
        order    = 105.15,
        fontSize = "small",
      },

      spellOverrideAddID = {
        type  = "input",
        name  = "Spell ID",
        desc  = "Spell ID to add an override for.",
        order = 105.2,
        width = 0.8,
        get   = function() local c = GetCastbarDB(); return (c and c._addSpellIDInput) or "" end,
        set   = function(_, v) local c = GetCastbarDB(); if c then c._addSpellIDInput = v end end,
      },

      spellOverrideAddBtn = {
        type  = "execute",
        name  = "Add Override",
        order = 105.3,
        width = 0.7,
        func  = function()
          local c = GetCastbarDB()
          if not c then return end
          local idStr = c._addSpellIDInput and c._addSpellIDInput:match("^%s*(.-)%s*$")
          local id    = idStr and tonumber(idStr)
          if not id or id <= 0 then
            print("|cff00ccffArcUI|r: Enter a valid spell ID first.")
            return
          end
          c.spellOverrides = c.spellOverrides or {}
          for _, ov in ipairs(c.spellOverrides) do
            if ov.spellID == id then
              print("|cff00ccffArcUI|r: Override for spell " .. id .. " already exists.")
              return
            end
          end
          if #c.spellOverrides >= 20 then
            print("|cff00ccffArcUI|r: Maximum of 20 spell overrides reached.")
            return
          end
          c.spellOverrides[#c.spellOverrides + 1] = {
            spellID              = id,
            barColorEnabled      = false,
            barColor             = {r=1, g=1, b=1, a=1},
            textureOverrideEnabled = false,
            texture              = "Blizzard",
            tickCount            = 0,
          }
          c._addSpellIDInput = ""
          if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
        end,
      },

    }, -- args
  }

  -- ── Dynamic auto-switch rules ──────────────────────────────────────
  local MAX_RULES = 10
  local args = opts.args

  local function asHidden(ri)
    if not ns.Presets or ns.Presets.GetSkinCount("castbar") == 0 then return true end
    local c = GetCastbarDB()
    if not c or not c.presets or not c.presets.autoSwitch then return true end
    local rules = c.presets.autoSwitch.rules
    return not rules or ri > #rules
  end

  local function asGetRule(ri)
    local c = GetCastbarDB()
    if not c or not c.presets or not c.presets.autoSwitch then return nil end
    return c.presets.autoSwitch.rules and c.presets.autoSwitch.rules[ri]
  end

  local function asSkinNames()
    return ns.Presets and ns.Presets.GetSkinNames("castbar") or {}
  end

  local function asToggleSpec(rule, specNum, value)
    if not rule.specIndices then rule.specIndices = {} end
    if value then
      for _, s in ipairs(rule.specIndices) do if s == specNum then return end end
      table.insert(rule.specIndices, specNum)
    else
      if #rule.specIndices == 0 then
        for i = 1, (GetNumSpecializations() or 4) do table.insert(rule.specIndices, i) end
      end
      for i = #rule.specIndices, 1, -1 do
        if rule.specIndices[i] == specNum then table.remove(rule.specIndices, i) end
      end
    end
  end

  local function asHasSpec(rule, specNum)
    if not rule.specIndices or #rule.specIndices == 0 then return true end
    for _, s in ipairs(rule.specIndices) do if s == specNum then return true end end
    return false
  end

  for ri = 1, MAX_RULES do
    local ruleIdx = ri
    local base    = 100.5 + (ri - 1) * 0.01

    args["csR" .. ri .. "Skin"] = {
      type   = "select",
      name   = "|cffffd700Rule " .. ri .. "|r  Skin",
      desc   = "Skin to load when this rule matches.",
      values = asSkinNames,
      order  = base,
      width  = 1.1,
      hidden = function() return asHidden(ruleIdx) end,
      get    = function() local rule = asGetRule(ruleIdx); return rule and rule.skinName end,
      set    = function(_, v) local rule = asGetRule(ruleIdx); if rule then rule.skinName = v end end,
    }

    args["csR" .. ri .. "Talents"] = {
      type   = "execute",
      name   = function()
        local rule = asGetRule(ruleIdx)
        if rule and rule.talentConditions and #rule.talentConditions > 0 then
          return "|cff00ff00Talents *|r"
        end
        return "Talents"
      end,
      desc   = "Open the talent picker to set conditions for this rule.",
      order  = base + 0.001,
      width  = 0.6,
      hidden = function() return asHidden(ruleIdx) end,
      func   = function()
        if not (ns.TalentPicker and ns.TalentPicker.OpenPicker) then
          print("|cff00ccffArcUI|r: Talent picker not available")
          return
        end
        local rule = asGetRule(ruleIdx)
        if not rule then return end
        ns.TalentPicker.OpenPicker(rule.talentConditions, rule.talentMatchMode or "all", function(conditions, mode)
          local r = asGetRule(ruleIdx)
          if r then
            r.talentConditions = conditions
            r.talentMatchMode  = mode
            if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
          end
        end)
      end,
    }

    args["csR" .. ri .. "Remove"] = {
      type   = "execute",
      name   = "X",
      desc   = "Remove this rule.",
      order  = base + 0.002,
      width  = 0.3,
      hidden = function() return asHidden(ruleIdx) end,
      func   = function()
        local c = GetCastbarDB()
        if c and c.presets and c.presets.autoSwitch and c.presets.autoSwitch.rules then
          table.remove(c.presets.autoSwitch.rules, ruleIdx)
          if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
        end
      end,
    }

    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 4
    for si = 1, numSpecs do
      local specIdx = si
      local _, specName, _, specIcon = GetSpecializationInfo(specIdx)
      local iconStr = specIcon and ("|T" .. specIcon .. ":14:14|t") or ("Spec " .. specIdx)
      args["csR" .. ri .. "Spec" .. si] = {
        type   = "toggle",
        name   = iconStr,
        desc   = specName or ("Spec " .. specIdx),
        order  = base + 0.003 + si * 0.0001,
        width  = 0.3,
        hidden = function() return asHidden(ruleIdx) end,
        get    = function()
          local rule = asGetRule(ruleIdx)
          return rule and asHasSpec(rule, specIdx)
        end,
        set    = function(_, value)
          local rule = asGetRule(ruleIdx)
          if rule then asToggleSpec(rule, specIdx, value) end
        end,
      }
    end
  end

  -- ── Dynamic spell override slots (up to 20) ──────────────────────
  local MAX_OVERRIDES = 20

  local function soHidden(oi)
    local c = GetCastbarDB()
    if not c or not c.spellOverrides then return true end
    return oi > #c.spellOverrides
  end

  local function soGet(oi)
    local c = GetCastbarDB()
    if not c or not c.spellOverrides then return nil end
    return c.spellOverrides[oi]
  end

  for oi = 1, MAX_OVERRIDES do
    local idx  = oi
    local base = 105.5 + (oi - 1) * 0.01

    args["soN" .. oi .. "Name"] = {
      type  = "description",
      order = base,
      name  = function()
        local ov = soGet(idx)
        if not ov then return "" end
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(ov.spellID)
        local nm   = (info and info.name) or "Unknown Spell"
        return "|cffffd100[" .. ov.spellID .. "]|r " .. nm
      end,
      hidden = function() return soHidden(idx) end,
    }

    args["soN" .. oi .. "ColorOn"] = {
      type   = "toggle",
      name   = "Override Color",
      order  = base + 0.001,
      width  = 0.7,
      hidden = function() return soHidden(idx) end,
      get    = function() local ov = soGet(idx); return ov and ov.barColorEnabled end,
      set    = function(_, v)
        local ov = soGet(idx); if ov then ov.barColorEnabled = v; Refresh() end
      end,
    }

    args["soN" .. oi .. "Color"] = {
      type     = "color",
      name     = "Color",
      order    = base + 0.002,
      hasAlpha = true,
      hidden   = function()
        if soHidden(idx) then return true end
        local ov = soGet(idx); return not (ov and ov.barColorEnabled)
      end,
      get = function()
        local ov  = soGet(idx)
        local col = (ov and ov.barColor) or {r=1,g=1,b=1,a=1}
        return col.r, col.g, col.b, col.a or 1
      end,
      set = function(_, r, g, b, a)
        local ov = soGet(idx); if ov then ov.barColor = {r=r,g=g,b=b,a=a}; Refresh() end
      end,
    }

    args["soN" .. oi .. "TexOn"] = {
      type   = "toggle",
      name   = "Override Texture",
      order  = base + 0.003,
      width  = 0.85,
      hidden = function() return soHidden(idx) end,
      get    = function() local ov = soGet(idx); return ov and ov.textureOverrideEnabled end,
      set    = function(_, v)
        local ov = soGet(idx); if ov then ov.textureOverrideEnabled = v; Refresh() end
      end,
    }

    args["soN" .. oi .. "Tex"] = {
      type          = "select",
      name          = "Texture",
      order         = base + 0.004,
      dialogControl = "LSM30_Statusbar",
      values        = LSM and LSM:HashTable("statusbar") or {},
      hidden        = function()
        if soHidden(idx) then return true end
        local ov = soGet(idx); return not (ov and ov.textureOverrideEnabled)
      end,
      get = function() local ov = soGet(idx); return (ov and ov.texture) or "Blizzard" end,
      set = function(_, v) local ov = soGet(idx); if ov then ov.texture = v; Refresh() end end,
    }

    args["soN" .. oi .. "Ticks"] = {
      type   = "range",
      name   = "Channel Ticks",
      desc   = "Number of ticks for this channeled spell. Shows N-1 dividers on the bar. Set to 0 to disable tick marks for this spell.",
      order  = base + 0.005,
      min    = 0, max = 32, step = 1,
      width  = 1.0,
      hidden = function() return soHidden(idx) end,
      get    = function() local ov = soGet(idx); return (ov and ov.tickCount) or 0 end,
      set    = function(_, v) local ov = soGet(idx); if ov then ov.tickCount = v end end,
    }

    args["soN" .. oi .. "Remove"] = {
      type   = "execute",
      name   = "Remove",
      order  = base + 0.006,
      width  = 0.45,
      hidden = function() return soHidden(idx) end,
      func   = function()
        local c = GetCastbarDB()
        if c and c.spellOverrides then
          table.remove(c.spellOverrides, idx)
          if AceConfigRegistry then AceConfigRegistry:NotifyChange("ArcUI") end
        end
      end,
    }
  end

  return opts
end
