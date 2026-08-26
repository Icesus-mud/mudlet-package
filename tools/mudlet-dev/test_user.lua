#!/usr/bin/env lua5.4
-- Unit tests for the v1.0.17 player-customisation layer: the layered
-- overrides (script defaults → `hud` command settings →
-- Icesus.user.lua → Icesus.custom.lua), the side-aware HUD layout, the
-- data-driven channel-feed colours, the icesus.hudReady hook, and the
-- `hud` command.
--
-- Like test_mapper.lua these load the REAL icesus.core chunk straight
-- out of package/Icesus.xml, but under a mocked Mudlet *UI* as well, so
-- icesus.install() runs for real and the assertions can look at what
-- the HUD build actually did. The mock is deliberately separate from
-- test_mapper.lua's: that one fakes the map database and skips the HUD,
-- this one fakes the widgets and skips the map.
--
-- Run:  lua5.4 tools/mudlet-dev/test_user.lua
-- Exits non-zero if any check fails.

local REPO = (arg[0]:gsub("/tools/mudlet%-dev/test_user%.lua$", ""))
if REPO == arg[0] then REPO = "." end
local XML  = REPO .. "/package/Icesus.xml"
local HOME = "/tmp/icesus-test-user-home"

-- ----------------------------------------------------------------
-- Extract the icesus.core <Script> CDATA from the package XML.
-- ----------------------------------------------------------------
local function read_file(path)
  local fh = assert(io.open(path, "r"), "cannot open " .. path)
  local s = fh:read("*a"); fh:close(); return s
end

local function write_file(path, body)
  local fh = assert(io.open(path, "w"), "cannot write " .. path)
  fh:write(body); fh:close()
end

local function extract_core_chunk(xml)
  local at = xml:find("icesus%.core", 1)
  assert(at, "icesus.core script not found in XML")
  local open = xml:find("<![CDATA[", at, true)
  local body_start = open + #"<![CDATA["
  local close = xml:find("]]>", body_start, true)
  assert(close, "CDATA close not found")
  return xml:sub(body_start, close - 1)
end

local CORE = extract_core_chunk(read_file(XML))

-- ----------------------------------------------------------------
-- Mocked Mudlet, including just enough Geyser to let the real HUD
-- build run. Every widget method is a chainable no-op; gauges hand
-- out front/back/text sub-widgets on demand.
-- ----------------------------------------------------------------
local function new_world()
  local w = {
    echoes    = {},     -- cecho() to the main console
    chat      = {},     -- cecho() to the channels miniconsole
    events    = {},     -- raiseEvent() names
    handlers  = {},     -- event name -> registered function
    widgets   = 0,      -- Geyser constructions
    borders   = {},
    miniCfg   = nil,    -- config table of the last MiniConsole built
    fontSizes = {},     -- widget name -> last setFontSize() value
    labels    = {},     -- widget name -> last echo() body
  }

  local function stub(name)
    local t = { name = name }
    return setmetatable(t, {
      __index = function(self, k)
        if k == "front" or k == "back" or k == "text" then
          local sub = stub(name .. "." .. k)
          self[k] = sub
          return sub
        end
        if k == "setFontSize" then
          return function(_, n) w.fontSizes[name] = n end
        end
        if k == "echo" then
          return function(self2, s)
            w.labels[name] = tostring(s)
            return self2
          end
        end
        if k == "cecho" then
          return function(_, s)
            if name == "icesus.channels" then w.chat[#w.chat + 1] = s end
          end
        end
        return function() return self end
      end,
    })
  end

  local function ctor(kind)
    return { new = function(_, cfg)
      cfg = cfg or {}
      w.widgets = w.widgets + 1
      if kind == "MiniConsole" then w.miniCfg = cfg end
      return stub(cfg.name or (kind .. "#" .. w.widgets))
    end }
  end

  local mud = {}

  mud.getMudletHomeDir = function() return HOME end
  mud.getPackageInfo   = function() return nil end
  mud.getPackages      = function() return {} end
  mud.getMainWindowSize = function() return 1600, 900 end
  mud.isConnected      = function() return false end
  mud.sendGMCP         = function() end
  mud.uninstallPackage = function() end
  mud.installPackage   = function() end
  mud.downloadFile     = function() end
  mud.tempTimer        = function() return 1 end
  mud.killTimer        = function() end
  mud.echo             = function() end
  mud.cecho            = function(s) w.echoes[#w.echoes + 1] = tostring(s) end
  mud.raiseEvent       = function(name) w.events[#w.events + 1] = name end
  mud.registerAnonymousEventHandler = function(ev, fn)
    w.handlers[ev] = fn
    return ev
  end
  mud.killAnonymousEventHandler = function() end
  mud.setBorderTop     = function(n) w.borders.top = n end
  mud.setBorderBottom  = function(n) w.borders.bottom = n end
  mud.setBorderLeft    = function(n) w.borders.left = n end
  mud.setBorderRight   = function(n) w.borders.right = n end
  mud.setBorderSizes   = function(a, b, c, d)
    w.borders = { top = a, right = b, bottom = c, left = d }
  end
  mud.setFont          = function() end
  mud.setFontSize      = function() end

  mud.Geyser = {
    Container   = ctor("Container"),
    Label       = ctor("Label"),
    Gauge       = ctor("Gauge"),
    HBox        = ctor("HBox"),
    VBox        = ctor("VBox"),
    MiniConsole = ctor("MiniConsole"),
  }

  mud.io = setmetatable({
    exists = function(path)
      local f = io.open(path, "r")
      if f then f:close(); return true end
      return false
    end,
  }, { __index = io })

  local function dump(v)
    if type(v) == "table" then
      local parts = {}
      for k, val in pairs(v) do
        local key = type(k) == "string"
          and ("[" .. string.format("%q", k) .. "]")
          or  ("[" .. tostring(k) .. "]")
        parts[#parts + 1] = key .. "=" .. dump(val)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    elseif type(v) == "string" then
      return string.format("%q", v)
    end
    return tostring(v)
  end

  mud.table = setmetatable({
    save = function(path, t) write_file(path, "return " .. dump(t) .. "\n") end,
    load = function(path, t)
      local chunk = assert(loadfile(path))
      local v = chunk()
      if type(v) == "table" and type(t) == "table" then
        for k, val in pairs(v) do t[k] = val end
      end
    end,
  }, { __index = table })

  w.mud = mud
  return w
end

-- Load a fresh copy of the package (so every test starts from pristine
-- defaults) after optionally seeding the player's files.
-- opts.user / opts.custom / opts.settings are file bodies / tables.
local function load_icesus(opts)
  opts = opts or {}
  os.execute("rm -rf '" .. HOME .. "' && mkdir -p '" .. HOME .. "'")
  if opts.user   then write_file(HOME .. "/Icesus.user.lua", opts.user) end
  if opts.custom then write_file(HOME .. "/Icesus.custom.lua", opts.custom) end
  if opts.settings then
    local parts = {}
    for k, v in pairs(opts.settings) do
      parts[#parts + 1] = string.format("[%q]=%s", k,
        type(v) == "string" and string.format("%q", v) or tostring(v))
    end
    write_file(HOME .. "/Icesus.settings.lua",
      "return {" .. table.concat(parts, ",") .. "}\n")
  end

  local w = new_world()
  local realG = _G
  local env
  env = setmetatable({}, {
    __index = function(_, k)
      if w.mud[k] ~= nil then return w.mud[k] end
      return realG[k]
    end,
  })
  env._G = env
  local chunk, err = load(CORE, "@icesus.core", "t", env)
  assert(chunk, "load error: " .. tostring(err))
  chunk()
  w.icesus = env.icesus
  w.env = env
  return w.icesus, w
end

-- ----------------------------------------------------------------
-- Assertion harness.
-- ----------------------------------------------------------------
local failures, total = 0, 0
local function check(name, cond, detail)
  total = total + 1
  if cond then
    print("  ok   - " .. name)
  else
    failures = failures + 1
    print("  FAIL - " .. name .. (detail and ("  [" .. detail .. "]") or ""))
  end
end

local function joined(list) return table.concat(list, "\n") end

local function saw(list, needle)
  return joined(list):find(needle, 1, true) ~= nil
end

local function warned(icesus, needle)
  for _, line in ipairs(icesus.user.warnings()) do
    if line:find(needle, 1, true) then return true end
  end
  return false
end

-- ================================================================
print("Layout arithmetic")
-- ================================================================
do
  local icesus = load_icesus()
  local L = icesus.hudLayout()
  check("default side is right", L.side == "right", L.side)
  check("right: column anchored to the right edge", L.colX == "-360", tostring(L.colX))
  check("right: strips start at x=0", L.stripX == 0, tostring(L.stripX))
  check("right: strips stop short of the column", L.stripW == "100%-360", L.stripW)
  check("right: save badge clears the column", L.badgeX == 360 + 104 + 140, tostring(L.badgeX))
  check("right: mode pill clears the column", L.modeX == 360 + 104, tostring(L.modeX))
  check("right: divider on the column's left", L.colEdge == "border-left", L.colEdge)

  icesus.config.hudSide = "left"
  local Ln = icesus.hudLayout()
  check("left: column anchored to x=0", Ln.colX == 0, tostring(Ln.colX))
  check("left: strips start past the column", Ln.stripX == 360, tostring(Ln.stripX))
  check("left: strip width unchanged", Ln.stripW == "100%-360", Ln.stripW)
  check("left: save badge hugs the window edge", Ln.badgeX == 104 + 140, tostring(Ln.badgeX))
  check("left: mode pill hugs the window edge", Ln.modeX == 104, tostring(Ln.modeX))
  check("left: divider on the column's right", Ln.colEdge == "border-right", Ln.colEdge)
  check("location width is side-independent", L.locW == Ln.locW, L.locW .. " vs " .. Ln.locW)

  icesus.config.hudSide = "right"
  icesus.config.borderRight = 420
  check("layout follows a borderRight override",
    icesus.hudLayout().colX == "-420", tostring(icesus.hudLayout().colX))
end

-- ================================================================
print("HUD build, rebuild guard, and the hudReady hook")
-- ================================================================
do
  local icesus, w = load_icesus()
  check("install() built the HUD", icesus.hud ~= nil and icesus.hud.channels ~= nil)
  check("right side reserves the right border", w.borders.right == 360, tostring(w.borders.right))
  check("right side leaves the left border alone", w.borders.left == 0, tostring(w.borders.left))
  check("hudReady raised on build", saw(w.events, "icesus.hudReady"), joined(w.events))

  local built = w.widgets
  icesus.setupHUD()
  check("a second setupHUD() is a no-op", w.widgets == built, tostring(w.widgets - built))

  icesus.rebuildHUD()
  check("rebuildHUD() forces a rebuild", w.widgets > built)

  local hits = 0
  icesus.onHudReady = function() hits = hits + 1 end
  icesus.rebuildHUD()
  check("icesus.onHudReady fires on rebuild", hits == 1, tostring(hits))
end

do
  -- The two cases the old mapSaveBadge sentinel existed to catch. A hot
  -- upgrade evaluates the new script while the old widgets are up, and
  -- the old teardown runs under pcall and can die silently.
  local icesus, w = load_icesus()
  local built = w.widgets
  icesus.version = "9.9.9"
  icesus.setupHUD()
  check("a script-version change rebuilds a standing HUD", w.widgets > built,
    tostring(w.widgets - built))
  local built2 = w.widgets
  icesus.hudSig = nil
  icesus.setupHUD()
  check("a HUD with no build signature rebuilds", w.widgets > built2,
    tostring(w.widgets - built2))
end

do
  local icesus, w = load_icesus({ user = 'return { hudSide = "left" }' })
  check("hudSide=left reserves the left border", w.borders.left == 360, tostring(w.borders.left))
  check("hudSide=left frees the right border", w.borders.right == 0, tostring(w.borders.right))
  check("column keeps its widget name across sides",
    icesus.hud.right ~= nil and icesus.hud.right.name == "icesus.right")
end

-- ================================================================
print("Icesus.user.lua — data overrides")
-- ================================================================
do
  local icesus = load_icesus()
  check("no file: nothing loaded", icesus.user.dataLoaded == false)
  check("no file: no warnings", #icesus.user.warnings() == 0)
end

do
  local icesus, w = load_icesus({ user = [[
return {
  hudSide = "left",
  fontStack = '"Fira Code", monospace',
  config = { borderRight = 420, channelTimes = false },
  palette = { ice = "#a5f3fc", hpGrad = { "#111111", "#222222" } },
  fontSizes = { channels = 11 },
  chatStyle = { channel = "SpringGreen", perChannel = { newbie = "gold" } },
  effectStyles = { silenced = { fg = "#ff0000", bg = "#001122", bd = "#334455" } },
}
]] })
  check("file loaded", icesus.user.dataLoaded == true)
  check("no warnings for a clean file", #icesus.user.warnings() == 0,
    joined(icesus.user.warnings()))
  check("hudSide applied", icesus.config.hudSide == "left")
  check("fontStack applied", icesus.fontStack == '"Fira Code", monospace')
  check("config scalar applied", icesus.config.borderRight == 420)
  check("config boolean applied", icesus.config.channelTimes == false)
  check("palette scalar applied", icesus.palette.ice == "#a5f3fc")
  check("palette gradient applied", icesus.palette.hpGrad[2] == "#222222")
  check("fontSizes applied", icesus.fontSizes.channels == 11)
  check("fontSize reached the channel widget", w.miniCfg.fontSize == 11,
    tostring(w.miniCfg and w.miniCfg.fontSize))
  check("chatStyle applied", icesus.chatStyle.channel == "SpringGreen")
  check("perChannel applied", icesus.chatStyle.perChannel.newbie == "gold")
  check("new effect style accepted", icesus.effectStyles.silenced.fg == "#ff0000")
  check("untouched defaults survive", icesus.config.borderTop == 92)
end

-- ================================================================
print("Icesus.user.lua — validation and warnings")
-- ================================================================
do
  local icesus = load_icesus({ user = [[
return {
  hudside = "left",
  config = { borderRigth = 420, borderTop = "tall" },
  palette = { icy = "#fff" },
  hudSide = "middle",
}
]] })
  check("typo'd top-level key warns", warned(icesus, "hudside"),
    joined(icesus.user.warnings()))
  check("typo'd config key warns", warned(icesus, "borderRigth"))
  check("wrong-typed value warns", warned(icesus, "borderTop"))
  check("wrong-typed value keeps the default", icesus.config.borderTop == 92)
  check("typo'd palette key warns", warned(icesus, "palette.icy"))
  check("bad hudSide warns", warned(icesus, "hudSide"))
  check("bad hudSide keeps the default", icesus.config.hudSide == "right")
end

do
  local icesus = load_icesus({ user = "return { config = { borderRight = " })
  check("syntax error warns", warned(icesus, "Icesus.user.lua"),
    joined(icesus.user.warnings()))
  check("syntax error leaves defaults intact", icesus.config.borderRight == 360)
  check("syntax error is not counted as loaded", icesus.user.dataLoaded == false)
end

do
  local icesus = load_icesus({ user = "local x = 1" })
  check("missing return warns", warned(icesus, "return { ... }"),
    joined(icesus.user.warnings()))
end

do
  local icesus = load_icesus({ user = 'return { chatStyle = "blue" }' })
  check("non-table section warns", warned(icesus, "chatStyle: expected a table"),
    joined(icesus.user.warnings()))
end

do
  -- The one knob the old README documented backwards: it now lives in
  -- the config defaults, so the override file can actually reach it.
  local icesus = load_icesus()
  check("auto-update is on by default", icesus.config.autoUpdate == true)
  local off = load_icesus({ user = 'return { config = { autoUpdate = false } }' })
  check("Icesus.user.lua can turn auto-update off",
    off.config.autoUpdate == false)
  check("turning auto-update off warns about nothing",
    #off.user.warnings() == 0, joined(off.user.warnings()))
end

-- ================================================================
print("Layering and re-application")
-- ================================================================
do
  local icesus = load_icesus({ settings = { hudSide = "left", chatSize = 9 } })
  check("hud-command side applies", icesus.config.hudSide == "left")
  check("hud-command chat size applies", icesus.fontSizes.channels == 9)
end

do
  local icesus = load_icesus({
    settings = { hudSide = "left" },
    user = 'return { hudSide = "right" }',
  })
  check("Icesus.user.lua wins over hud-command settings",
    icesus.config.hudSide == "right")
end

do
  local icesus = load_icesus({ settings = { hudFont = "Fira Code" } })
  local first = icesus.fontStack
  check("hud-command font prepends to the stack",
    first:find('"Fira Code"', 1, true) == 1, first)
  check("default stack is kept as fallback",
    first:find("JetBrains Mono", 1, true) ~= nil, first)
  icesus.user.apply()
  check("re-applying does not stack the font twice",
    icesus.fontStack == first, icesus.fontStack)
end

do
  local icesus = load_icesus({ user = 'return { config = { borderRight = 420 } }' })
  check("override in effect before edit", icesus.config.borderRight == 420)
  write_file(HOME .. "/Icesus.user.lua", "return { }")
  icesus.user.apply()
  check("deleting a key restores the default", icesus.config.borderRight == 360,
    tostring(icesus.config.borderRight))
end

-- ================================================================
print("Icesus.custom.lua — script overrides")
-- ================================================================
do
  local icesus, w = load_icesus({ custom = [[
icesus.palette.ice = "#123456"
icesus.onHudReady = function() icesus.testHudReadyRan = true end
icesus.onCommText = function() icesus.testHandlerRan = true end
]] })
  check("custom script loaded", icesus.user.scriptLoaded == true)
  check("custom script can set data", icesus.palette.ice == "#123456")
  check("custom script's onHudReady ran during the build",
    icesus.testHudReadyRan == true)

  local handler = w.handlers["gmcp.Comm.Channel.Text"]
  check("channel handler is registered", type(handler) == "function")
  handler()
  check("a replaced handler is what actually runs",
    icesus.testHandlerRan == true)
end

do
  local icesus, w = load_icesus({ custom = "this is not lua" })
  check("broken custom script warns", warned(icesus, "Icesus.custom.lua"),
    joined(icesus.user.warnings()))
  check("broken custom script still leaves a working HUD",
    icesus.hud ~= nil and icesus.hud.channels ~= nil)
end

do
  -- Late binding is the whole point: a player script loaded long after
  -- install() must be able to swap a handler out.
  local icesus, w = load_icesus()
  local ran = false
  w.env.gmcp = { Comm = { Channel = { Tell = { talker = "x", text = "y" } } } }
  icesus.onCommTell = function() ran = true end
  w.handlers["gmcp.Comm.Channel.Tell"]()
  check("handlers can be replaced after install()", ran == true)
end

-- ================================================================
print("Channel feed styling")
-- ================================================================
local function commText(w, icesus, p)
  w.chat = {}          -- drop the "--- channels ---" header line
  w.env.gmcp = { Comm = { Channel = { Text = p } } }
  icesus.onCommText()
  return joined(w.chat)
end

do
  local icesus, w = load_icesus()
  local out = commText(w, icesus,
    { channel = "chat", talker = "Pisano", text = "hello" })
  check("default channel colour", out:find("<DodgerBlue>[chat]", 1, true) ~= nil, out)
  check("default talker colour", out:find("<gold>Pisano", 1, true) ~= nil, out)
  check("time stamp is coloured by chatStyle.time",
    out:find("<grey>", 1, true) ~= nil, out)
end

do
  local icesus, w = load_icesus({ user = [[
return {
  config = { channelTimes = false },
  chatStyle = {
    channel = "SpringGreen", talker = "khaki", text = "wheat",
    perChannel = { sales = "grey" },
  },
}
]] })
  local out = commText(w, icesus,
    { channel = "chat", talker = "Ricven", text = "recoloured" })
  check("channel colour override", out:find("<SpringGreen>[chat]", 1, true) ~= nil, out)
  check("talker colour override", out:find("<khaki>Ricven", 1, true) ~= nil, out)
  check("message text colour override", out:find("<wheat>recoloured", 1, true) ~= nil, out)
  check("channelTimes=false drops the stamp",
    out:find("<grey>", 1, true) == nil, out)

  w.chat = {}
  local sales = commText(w, icesus,
    { channel = "sales", talker = "Vellis", text = "wts" })
  check("perChannel wins over the generic colour",
    sales:find("<grey>[sales]", 1, true) ~= nil, sales)
end

do
  local icesus, w = load_icesus()
  local out = commText(w, icesus,
    { channel = "chat", talker = "Idles", text = "mine", self = 1 })
  check("self lines use selfTalker", out:find("<DimGrey>you", 1, true) ~= nil, out)

  w.chat = {}
  w.env.gmcp = { Comm = { Channel = { Tell = {
    talker = "Vellis", text = "psst" } } } }
  icesus.onCommTell()
  check("tells use chatStyle.tell",
    joined(w.chat):find("<MediumOrchid>[tell]", 1, true) ~= nil, joined(w.chat))

  w.chat = {}
  local pink = commText(w, icesus,
    { channel = "chat", talker = "Arthr", text = "%^BOLD%^loud%^RESET%^" })
  check("pinkfish codes are still stripped",
    pink:find("%^", 1, true) == nil, pink)
end

do
  local icesus, w = load_icesus()
  w.env.gmcp = { Room = { Speech = {
    kind = "emote", talker = "Uno", text = "Uno waves" } } }
  icesus.onRoomSpeech()
  check("room emotes use chatStyle.emote",
    joined(w.chat):find("<SteelBlue>[emote]", 1, true) ~= nil, joined(w.chat))
end

-- ================================================================
print("The `hud` command")
-- ================================================================
do
  local icesus, w = load_icesus()
  icesus.hudCommand("")
  check("bare `hud` reports the side",
    saw(w.echoes, "column side") and saw(w.echoes, "right"), joined(w.echoes))
  check("bare `hud` names the override file",
    saw(w.echoes, "Icesus.user.lua"), joined(w.echoes))
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("side left")
  check("`hud side left` moves the column", icesus.config.hudSide == "left")
  check("`hud side left` rebuilt to the left border", w.borders.left == 360,
    tostring(w.borders.left))
  check("`hud side left` persisted", icesus.settings.hudSide == "left")

  local reloaded = load_icesus({ settings = { hudSide = "left" } })
  check("the setting survives a reload", reloaded.config.hudSide == "left")
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("side sideways")
  check("a bad side is refused", icesus.settings.hudSide == nil)
  check("a bad side explains itself", saw(w.echoes, "hud side left"), joined(w.echoes))
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("chatsize 11")
  check("`hud chatsize` applies", icesus.fontSizes.channels == 11)
  check("`hud chatsize` persisted", icesus.settings.chatSize == 11)
  check("`hud chatsize` reached the widget", w.miniCfg.fontSize == 11,
    tostring(w.miniCfg.fontSize))
  icesus.hudCommand("chatsize 99")
  check("an out-of-range chat size is refused", icesus.settings.chatSize == 11)
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("font Fira Code")
  check("`hud font` keeps the multi-word name", icesus.settings.hudFont == "Fira Code")
  check("`hud font` reaches the stack",
    icesus.fontStack:find('"Fira Code"', 1, true) == 1, icesus.fontStack)
  icesus.hudCommand("font default")
  check("`hud font default` undoes it", icesus.settings.hudFont == nil)
  check("`hud font default` restores the stack",
    icesus.fontStack:find('"JetBrains Mono"', 1, true) == 1
    and not icesus.fontStack:find("Fira Code", 1, true), icesus.fontStack)
end

do
  local icesus, w = load_icesus({ user = 'return { hudSide = "right" }' })
  icesus.hudCommand("side left")
  check("a file-pinned setting says so", saw(w.echoes, "pinned"), joined(w.echoes))
  check("a file-pinned setting stays pinned", icesus.config.hudSide == "right")
  check("a file-pinned setting is not announced as applied",
    not saw(w.echoes, "moved to the"), joined(w.echoes))
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("example")
  local path = HOME .. "/Icesus.user.lua"
  check("`hud example` wrote the starter file", w.mud.io.exists(path))
  local body = read_file(path)
  check("the starter file is valid Lua returning a table",
    type(assert(loadfile(path))()) == "table")
  check("the starter file has everything commented out",
    not body:find("\n  hudSide", 1, true), body:sub(1, 120))

  w.echoes = {}
  icesus.hudCommand("example")
  check("`hud example` refuses to overwrite", saw(w.echoes, "not overwriting"),
    joined(w.echoes))
  check("`hud example` left the file alone", read_file(path) == body)
end

do
  local icesus, w = load_icesus()
  write_file(HOME .. "/Icesus.user.lua",
    'return { config = { borderRight = 480 } }')
  icesus.hudCommand("reload")
  check("`hud reload` picks up a fresh edit", icesus.config.borderRight == 480)
  check("`hud reload` rebuilt the HUD", w.borders.right == 480, tostring(w.borders.right))
end

do
  local icesus, w = load_icesus({ settings = { hudSide = "left", chatSize = 8 } })
  icesus.hudCommand("reset")
  check("`hud reset` forgets the side", icesus.settings.hudSide == nil)
  check("`hud reset` forgets the chat size", icesus.settings.chatSize == nil)
  check("`hud reset` restores the defaults", icesus.config.hudSide == "right"
    and icesus.fontSizes.channels == 13)
  check("`hud reset` keeps the map settings",
    icesus.settings.mapSaveMode == "auto" and icesus.settings.mapperEnabled == true)
end

do
  -- The one-time discovery line: without it nobody finds `hud`.
  local icesus, w = load_icesus()
  icesus.hudHint()
  check("the hint tells a first-time player about hud",
    saw(w.echoes, "type <yellow>hud"), joined(w.echoes))
  check("the hint is recorded as shown", icesus.settings.hudHintShown == true)

  w.echoes = {}
  icesus.hudHint()
  check("the hint is not repeated in the same session",
    not saw(w.echoes, "yours to change"), joined(w.echoes))

  local next_session = load_icesus({ settings = { hudHintShown = true } })
  check("the hint survives into the next session as shown",
    next_session.settings.hudHintShown == true)
  next_session.hudCommand("reset")
  check("`hud reset` does not bring the hint back",
    next_session.settings.hudHintShown == true)
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("")
  check("`hud` links the full reference by URL",
    saw(w.echoes, "github.com/Icesus-mud/mudlet-package#customising"),
    joined(w.echoes))
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("example")
  local body = read_file(HOME .. "/Icesus.user.lua")
  check("the starter file links the reference",
    body:find("#customising", 1, true) ~= nil)
  check("the starter file says how to list colours",
    body:find("showColors", 1, true) ~= nil)
  check("the starter file says how to list fonts",
    body:find("getAvailableFonts", 1, true) ~= nil)
end

do
  local icesus, w = load_icesus()
  icesus.hudCommand("wat")
  check("an unknown subcommand is refused", saw(w.echoes, "no such HUD command"),
    joined(w.echoes))
end

-- ================================================================
print("Concealment badges (Char.Status \"stealth\")")
-- ================================================================

-- Feed one Char.Status through the real handler and hand back what the
-- effects row was told to render.
local function statusRow(icesus, w, status)
  w.env.gmcp = { Char = { Status = status } }
  icesus.onStatus()
  return w.labels["icesus.effectsRow"] or ""
end

do
  local icesus, w = load_icesus()
  check("an empty row still says so",
    statusRow(icesus, w, {}):find("no effects", 1, true) ~= nil,
    w.labels["icesus.effectsRow"])

  local row = statusRow(icesus, w, { stealth = { "moving silently" } })
  check("concealment alone lights the row up",
    row:find("no effects", 1, true) == nil, row)
  check("`moving silently` is shortened to SILENT",
    row:find("SILENT", 1, true) ~= nil, row)
  check("the long form is not what gets drawn",
    row:find("MOVING", 1, true) == nil, row)
  check("it wears its own colour, not the default grey",
    row:find("rgba(148,163,184,0.14)", 1, true) ~= nil, row)

  row = statusRow(icesus, w, { stealth = { "hiding in shadows", "invisible" } })
  check("`hiding in shadows` is shortened to HIDDEN",
    row:find("HIDDEN", 1, true) ~= nil, row)
  check("`invisible` is shortened to INVIS",
    row:find("INVIS", 1, true) ~= nil, row)

  row = statusRow(icesus, w, { stealth = { "wrapped in fog" } })
  check("an unknown state is shown as the server named it",
    row:find("WRAPPED&nbsp;IN&nbsp;FOG", 1, true) ~= nil, row)
end

do
  local icesus, w = load_icesus()
  local row = statusRow(icesus, w,
    { stealth = { "invisible" }, effects = { "bleeding" } })
  check("concealment is drawn ahead of afflictions",
    row:find("INVIS", 1, true) < row:find("BLEEDING", 1, true), row)

  row = statusRow(icesus, w, { effects = { "bleeding" } })
  check("dropping concealment leaves the affliction behind",
    row:find("INVIS", 1, true) == nil and row:find("BLEEDING", 1, true) ~= nil,
    row)

  row = statusRow(icesus, w, {})
  check("a status with neither field clears the row",
    row:find("no effects", 1, true) ~= nil, row)
end

do
  -- A server too old to send the field, and a server sending junk.
  local icesus, w = load_icesus()
  statusRow(icesus, w, { stealth = { "invisible" } })
  local row = statusRow(icesus, w, { effects = {} })
  check("a status with no stealth key drops the badge",
    row:find("no effects", 1, true) ~= nil, row)

  row = statusRow(icesus, w, { stealth = "invisible" })
  check("a non-table stealth field is ignored, not rendered",
    row:find("no effects", 1, true) ~= nil, row)
  check("state.stealth stays a table", type(icesus.state.stealth) == "table")
end

do
  local icesus, w = load_icesus({ user = [==[
return {
  effectStyles = { ["hiding in shadows"] = { fg = "#ff00ff" } },
}
]==] })
  local row = statusRow(icesus, w, { stealth = { "hiding in shadows" } })
  check("a player can restyle a concealment badge",
    row:find("#ff00ff", 1, true) ~= nil, row)
  check("the keys it did not name keep the shipped value",
    icesus.effectStyles["hiding in shadows"].bg == "rgba(165,180,252,0.14)",
    icesus.effectStyles["hiding in shadows"].bg)
end

-- ================================================================
print("Badge rows fit the column they are drawn in")
-- ================================================================

-- Character cells the rendered row asks for: badge text plus every
-- &nbsp; between and around the pills. The Label does not wrap, so
-- anything past the budget is drawn off the edge and lost.
local function rowCells(html)
  local body = html:gsub("^<center>", ""):gsub("</center>$", "")
  body = body:gsub("<[^>]->", "")          -- drop the span tags
  local n = 0
  for _ in body:gmatch("&nbsp;") do n = n + 1 end
  body = body:gsub("&nbsp;", "")
  -- The ellipsis is three bytes wide and one character wide.
  for _ in body:gmatch("\226\128\166") do n = n + 1 end
  body = body:gsub("\226\128\166", "")
  return n + #body
end

do
  local icesus, w = load_icesus()
  local budget = math.floor((360 - 12) / (11 * 0.88))

  local roomy = statusRow(icesus, w, { stealth = { "invisible" } })
  check("a roomy row keeps its wide padding",
    roomy:find("&nbsp;&nbsp;INVIS&nbsp;&nbsp;", 1, true) ~= nil, roomy)
  check("a roomy row is nowhere near the budget",
    rowCells(roomy) < budget, tostring(rowCells(roomy)))

  local tight = statusRow(icesus, w,
    { stealth = { "moving silently" }, effects = { "bleeding", "stunned" } })
  check("three badges tighten the spacing instead of clipping",
    rowCells(tight) <= budget, tostring(rowCells(tight)))
  check("three badges keep their full names",
    tight:find("BLEEDING", 1, true) ~= nil and tight:find("STUNNED", 1, true) ~= nil,
    tight)

  local full = statusRow(icesus, w, {
    stealth = { "moving silently", "hiding in shadows" },
    effects = { "bleeding", "stunned" },
  })
  check("four badges still fit the column", rowCells(full) <= budget,
    tostring(rowCells(full)))
  check("the long name is the one that gets shaved",
    full:find("BLEE", 1, true) ~= nil and full:find("BLEEDING", 1, true) == nil,
    full)
  check("a shaved name says so with an ellipsis",
    full:find("\226\128\166", 1, true) ~= nil, full)
  check("the short badges are left alone",
    full:find("SILENT", 1, true) ~= nil and full:find("HIDDEN", 1, true) ~= nil,
    full)

  -- Truncation runs off the full name every time, never off an
  -- already-shaved one — that would cut into the ellipsis bytes.
  check("no badge is cut mid-ellipsis",
    full:find("\226\128\166\226\128\166", 1, true) == nil, full)
end

do
  -- A wider column earns back the full names; a narrower one gives up
  -- more of them. Both come from icesus.hudLayout(), so `hud` settings
  -- and Icesus.user.lua reach this for free.
  local icesus, w = load_icesus({ user = "return { config = { borderRight = 620 } }" })
  local row = statusRow(icesus, w, {
    stealth = { "moving silently", "hiding in shadows" },
    effects = { "bleeding", "stunned" },
  })
  check("a wide column keeps every name intact",
    row:find("BLEEDING", 1, true) ~= nil and row:find("STUNNED", 1, true) ~= nil,
    row)
  check("a wide column keeps the wide padding",
    row:find("&nbsp;&nbsp;SILENT&nbsp;&nbsp;", 1, true) ~= nil, row)
end

do
  -- A badge font this big cannot fit three names in a 360px column at
  -- any spacing. The row gives up its names rather than its badges:
  -- a truncated word still tells the player the effect is on.
  local icesus, w = load_icesus({ user = "return { fontSizes = { badges = 20 } }" })
  local status = { stealth = { "moving silently" },
                   effects = { "bleeding", "stunned" } }
  local big = statusRow(icesus, w, status)
  check("a bigger badge font shaves names the default size keeps",
    big:find("BLEEDING", 1, true) == nil, big)
  check("every badge survives the shaving",
    big:find("SILE", 1, true) ~= nil and big:find("BLEE", 1, true) ~= nil
      and big:find("STUN", 1, true) ~= nil, big)

  local ic2, w2 = load_icesus()
  check("the default size keeps the same three names whole",
    statusRow(ic2, w2, status):find("BLEEDING", 1, true) ~= nil)
end

-- ================================================================
print("Regression: the map settings layer is untouched")
-- ================================================================
do
  local icesus = load_icesus({ settings = { mapSaveMode = "manual",
                                            outworldMode = "roads" } })
  check("map save mode still loads", icesus.settings.mapSaveMode == "manual")
  check("outworld mode still loads", icesus.settings.outworldMode == "roads")
  check("hud keys default to nil", icesus.settings.hudSide == nil
    and icesus.settings.hudFont == nil and icesus.settings.chatSize == nil)
end

os.execute("rm -rf '" .. HOME .. "'")
print(string.format("\n%d/%d checks passed, %d failed",
  total - failures, total, failures))
os.exit(failures == 0 and 0 or 1)
