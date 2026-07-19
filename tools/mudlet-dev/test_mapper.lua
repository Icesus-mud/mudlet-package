#!/usr/bin/env lua5.4
-- Unit tests for the Icesus package mapper: the v1.0.14 walking/combat
-- fluidity work, the v1.0.15 save modes / pause toggle / deleted-room
-- recovery, the channel-feed colour-code strip, and the map-integrity
-- layer (atomic saves, paired backups, crash sentinel, mapper restore).
--
-- These load the REAL icesus.core Lua chunk straight out of
-- package/Icesus.xml under a mocked Mudlet API, then drive
-- icesus.mapper.* directly and assert on the recorded driver calls.
-- No GUI, no Mudlet, deterministic (os.time/os.date are mocked); the
-- persistence layer runs against a real scratch dir under /tmp that
-- is wiped between tests.
--
-- Run:  lua5.4 tools/mudlet-dev/test_mapper.lua
-- Exits non-zero on the first failing assertion.

local REPO = (arg[0]:gsub("/tools/mudlet%-dev/test_mapper%.lua$", ""))
if REPO == arg[0] then REPO = "." end
local XML = REPO .. "/package/Icesus.xml"

-- ----------------------------------------------------------------
-- Extract the icesus.core <Script> CDATA from the package XML.
-- ----------------------------------------------------------------
local function read_file(path)
  local fh = assert(io.open(path, "r"), "cannot open " .. path)
  local s = fh:read("*a"); fh:close(); return s
end

local function extract_core_chunk(xml)
  local at = xml:find("icesus%.core", 1)
  assert(at, "icesus.core script not found in XML")
  local open = xml:find("<![CDATA[", at, true)
  assert(open, "CDATA open not found after icesus.core")
  local body_start = open + #"<![CDATA["
  local close = xml:find("]]>", body_start, true)
  assert(close, "CDATA close not found")
  return xml:sub(body_start, close - 1)
end

-- ----------------------------------------------------------------
-- Mocked Mudlet environment.
-- ----------------------------------------------------------------
local MOCK_TIME = 1000          -- controllable clock (seconds)
local calls                     -- per-test driver call counters
local rooms                     -- fake Mudlet room DB: id -> room
local SETTINGS_ON_DISK = nil    -- non-nil: table.load fills from this

-- The persistence layer (atomic sidecar writes, paired backups, the
-- crash sentinel) manipulates real files, so the mock home is a real
-- scratch directory wiped between tests instead of a pure no-op.
local HOME = "/tmp/icesus-test-home"

local function bump(name) calls[name] = (calls[name] or 0) + 1 end

local function fresh_world()
  calls = {}
  rooms = {}
  MOCK_TIME = 1000
  SETTINGS_ON_DISK = nil
  os.execute("rm -rf '" .. HOME .. "' && mkdir -p '" .. HOME .. "'")
end

local mud = {}

mud.getMudletHomeDir = function() return HOME end
mud.createRoomID     = function() return 1 end

mud.addRoom = function(id)
  bump("addRoom")
  if rooms[id] then return false end
  rooms[id] = { exits = {}, special = {}, stub = {} }
  return true
end
mud.roomExists  = function(id) return rooms[id] ~= nil end
mud.getRoomArea = function(id) return rooms[id] and rooms[id].area or -1 end
mud.getRoomName = function(id) return rooms[id] and (rooms[id].name or "") or nil end
mud.setRoomName = function(id, n) bump("setRoomName"); if rooms[id] then rooms[id].name = n end end
mud.setRoomArea = function(id, a) bump("setRoomArea"); if rooms[id] then rooms[id].area = a end end
mud.addAreaName = function(name) bump("addAreaName"); return 1 end
mud.setRoomCoordinates = function(id, x, y, z)
  bump("setRoomCoordinates"); if rooms[id] then rooms[id].coords = { x, y, z } end
end
mud.setGridMode      = function(a, on) bump("setGridMode") end
mud.setRoomChar      = function(id, c) bump("setRoomChar"); if rooms[id] then rooms[id].char = c end end
mud.setRoomEnv       = function(id, e) bump("setRoomEnv"); if rooms[id] then rooms[id].env = e end end
mud.setCustomEnvColor = function() bump("setCustomEnvColor") end
mud.setExit = function(id, dest, dir)
  bump("setExit")
  if not rooms[id] then return end
  if dest == -1 then rooms[id].exits[dir] = nil else rooms[id].exits[dir] = dest end
end
mud.setExitStub      = function(id, dir, b) bump("setExitStub") end
mud.setSpecialExit   = function(id, dest, cmd) bump("setSpecialExit"); if rooms[id] then rooms[id].special[cmd] = dest end end
mud.clearSpecialExits = function(id) bump("clearSpecialExits"); if rooms[id] then rooms[id].special = {} end end
mud.getRoomExits     = function(id) return rooms[id] and rooms[id].exits or {} end
mud.getSpecialExits  = function(id) return rooms[id] and rooms[id].special or {} end
mud.centerview       = function(id) bump("centerview") end
mud.updateMap        = function() bump("updateMap") end
mud.deleteRoom       = function(id) bump("deleteRoom"); rooms[id] = nil end
mud.saveMap          = function(path)
  bump("saveMap")
  -- saveMapAtomic() validates the written file (non-empty) before
  -- promoting it, so the mock has to actually produce one.
  local f = io.open(path, "wb")
  if f then f:write("MOCKMAP\n"); f:close() end
end
mud.loadMap          = function(path) bump("loadMap"); return true end
mud.tempTimer        = function(secs, fn) bump("tempTimer"); return (calls.tempTimer or 0) end
mud.killTimer        = function(id) bump("killTimer") end
mud.cecho            = function() bump("cecho") end
mud.echo             = function() end

-- Partial overrides of stdlib tables the package uses. os.date rides
-- the mock clock so backup stamps are deterministic and distinct when
-- a test advances MOCK_TIME.
mud.os = setmetatable({
  time = function() return MOCK_TIME end,
  date = function(fmt, t) return os.date(fmt, t or MOCK_TIME) end,
}, { __index = os })

local SETTINGS_PATH = HOME .. "/Icesus.settings.lua"

-- Settings keep the historic in-memory fixture (SETTINGS_ON_DISK);
-- everything else hits the real scratch directory so the atomic-write
-- and backup plumbing is exercised for real.
mud.io = setmetatable({
  exists = function(path)
    if path == SETTINGS_PATH then return SETTINGS_ON_DISK ~= nil end
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
  end,
}, { __index = io })

-- Minimal serialiser standing in for Mudlet's table.save format:
-- enough for the idmap's nested string/number/boolean tables.
local function dump(v)
  if type(v) == "table" then
    local parts = {}
    for k, val in pairs(v) do
      local key
      if type(k) == "string" then key = "[" .. string.format("%q", k) .. "]"
      else key = "[" .. tostring(k) .. "]" end
      parts[#parts + 1] = key .. "=" .. dump(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(v) == "string" then
    return string.format("%q", v)
  else
    return tostring(v)
  end
end

mud.table = setmetatable({
  save = function(path, t)
    bump("table_save")
    if path == SETTINGS_PATH then return end
    local f = assert(io.open(path, "w"), "table.save: cannot open " .. path)
    f:write("return " .. dump(t) .. "\n")
    f:close()
  end,
  load = function(path, t)
    bump("table_load")
    if path == SETTINGS_PATH then
      if SETTINGS_ON_DISK and type(t) == "table" then
        for k, v in pairs(SETTINGS_ON_DISK) do t[k] = v end
      end
      return
    end
    -- Mudlet's table.load raises on a missing/corrupt file; callers
    -- pcall it, so mirror that with assert.
    local chunk = assert(loadfile(path))
    local v = chunk()
    if type(v) == "table" and type(t) == "table" then
      for k, val in pairs(v) do t[k] = val end
    end
  end,
}, { __index = table })

-- Mudlet bundles luafilesystem; plain Lua doesn't. Shell out for the
-- three calls the backup code uses.
mud.lfs = {
  mkdir = function(p) os.execute("mkdir -p '" .. p .. "'"); return true end,
  attributes = function(p, what)
    local f = io.popen("test -d '" .. p .. "' && echo yes")
    local out = f:read("*a"); f:close()
    if out:find("yes") then return "directory" end
    return nil
  end,
  dir = function(p)
    local f = io.popen("ls -a '" .. p .. "' 2>/dev/null")
    local all = {}
    for line in f:lines() do all[#all + 1] = line end
    f:close()
    local i = 0
    return function() i = i + 1; return all[i] end
  end,
}

-- ----------------------------------------------------------------
-- Load the chunk under the mock env.
-- ----------------------------------------------------------------
local function load_icesus()
  fresh_world()
  local realG = _G
  local env
  env = setmetatable({}, {
    __index = function(_, k)
      if mud[k] ~= nil then return mud[k] end
      return realG[k]
    end,
  })
  env._G = env
  local code = extract_core_chunk(read_file(XML))
  -- Strip the trailing bootstrap call so we load the definitions
  -- without running the full Geyser HUD build (which would need the
  -- entire Mudlet UI API mocked). The mapper functions under test are
  -- untouched; we drive icesus.mapper.* directly below.
  code = code:gsub("icesus%.install%(%)%s*$", "")
  local chunk, err = load(code, "@icesus.core", "t", env)
  assert(chunk, "load error: " .. tostring(err))
  chunk()
  return env.icesus, env
end

-- ----------------------------------------------------------------
-- Tiny assertion harness.
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

local function roominfo(id, opts)
  opts = opts or {}
  return {
    id = id,
    name = opts.name or ("Room " .. id),
    area = opts.area or "Testland",
    exits = opts.exits or { north = "0" },
    coords = opts.coords,
    terrain = opts.terrain,
  }
end

-- ================================================================
-- Fast-path: revisiting an unchanged room must not rewrite the map.
-- ================================================================
do
  local icesus = load_icesus()
  icesus.mapper.idMap = nil   -- force a clean load on first onRoomInfo

  local r = roominfo("aaaaaaaa", { exits = { north = "bbbbbbbb" } })
  icesus.mapper.onRoomInfo(r)         -- first visit: full build
  local firstBuildWrote = (calls.addRoom or 0) > 0 and (calls.setRoomName or 0) > 0
  check("first visit builds the room", firstBuildWrote)
  check("first visit marks map dirty", icesus.mapper.dirty == true)

  -- second, identical visit
  calls = {}
  icesus.mapper.dirty = false
  icesus.mapper.onRoomInfo(r)
  check("revisit makes no addRoom call", (calls.addRoom or 0) == 0, "addRoom=" .. (calls.addRoom or 0))
  check("revisit makes no setRoomName call", (calls.setRoomName or 0) == 0)
  check("revisit makes no setExit call", (calls.setExit or 0) == 0, "setExit=" .. (calls.setExit or 0))
  check("revisit still recenters the view", (calls.centerview or 0) == 1)
  check("revisit leaves dirty flag untouched", icesus.mapper.dirty == false)
end

-- ================================================================
-- A genuinely changed room must still trigger a rebuild.
-- ================================================================
do
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  local r1 = roominfo("cccccccc", { exits = { north = "0" } })
  icesus.mapper.onRoomInfo(r1)
  calls = {}
  icesus.mapper.dirty = false
  -- same room id, but an exit appeared
  local r2 = roominfo("cccccccc", { exits = { north = "0", east = "0" } })
  icesus.mapper.onRoomInfo(r2)
  check("changed exits trigger a rebuild (setExit fires)", (calls.setExit or 0) > 0)
  check("changed room re-marks dirty", icesus.mapper.dirty == true)
end

-- ================================================================
-- Save deferral: maybeFlush() only writes the map when idle / capped.
-- ================================================================
local function setup_flush_state(icesus)
  icesus.mapper.idMap = { idToRoom = {}, areaToInt = {}, placed = {},
                          gridmoded = {}, areaCoords = {}, seen = {}, next_id = 1 }
  icesus.state = icesus.state or {}
end

do
  local icesus = load_icesus()
  setup_flush_state(icesus)

  -- dirty, just moved, not in combat -> no save yet
  icesus.mapper.dirty = true
  icesus.mapper.lastSave = MOCK_TIME
  icesus.mapper.lastActivity = MOCK_TIME
  icesus.state.inCombat = false
  calls = {}
  icesus.mapper.maybeFlush()
  check("no save immediately after moving", (calls.saveMap or 0) == 0)

  -- 9s idle: still below the 10s threshold
  MOCK_TIME = MOCK_TIME + 9
  calls = {}
  icesus.mapper.maybeFlush()
  check("no save at 9s idle", (calls.saveMap or 0) == 0)

  -- 11s idle: crosses the idle threshold -> save, dirty cleared
  MOCK_TIME = MOCK_TIME + 2
  calls = {}
  icesus.mapper.maybeFlush()
  check("save fires after >=10s idle", (calls.saveMap or 0) == 1)
  check("flush clears the dirty flag", icesus.mapper.dirty == false)

  -- already clean: a follow-up tick is a no-op
  calls = {}
  icesus.mapper.maybeFlush()
  check("no save when not dirty", (calls.saveMap or 0) == 0)
end

do
  -- In combat: even when long-idle, do not save (until the cap).
  local icesus = load_icesus()
  setup_flush_state(icesus)
  icesus.mapper.dirty = true
  icesus.mapper.lastSave = MOCK_TIME
  icesus.mapper.lastActivity = MOCK_TIME - 60   -- idle a full minute
  icesus.state.inCombat = true
  calls = {}
  icesus.mapper.maybeFlush()
  check("no save during combat despite idle", (calls.saveMap or 0) == 0)
end

do
  -- 5-minute hard cap: save even if in combat / active.
  local icesus = load_icesus()
  setup_flush_state(icesus)
  icesus.mapper.dirty = true
  icesus.mapper.lastActivity = MOCK_TIME       -- actively moving
  icesus.mapper.lastSave = MOCK_TIME - 301      -- last save >5min ago
  icesus.state.inCombat = true
  calls = {}
  icesus.mapper.maybeFlush()
  check("5-min cap forces a save even in combat", (calls.saveMap or 0) == 1)
end

-- ================================================================
-- install() must still load cleanly under the mock (smoke).
-- ================================================================
do
  local icesus = load_icesus()
  local ok, err = pcall(function() icesus.mapper.install() end)
  check("mapper.install() runs without error", ok, tostring(err))
end

-- ================================================================
-- Issue #7: a room deleted in Mudlet's map editor must be recreated
-- on the next visit, not silently trusted via the idmap cache.
-- ================================================================
do
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  local r = roominfo("delroom1", { exits = { north = "nbr00001" } })
  icesus.mapper.onRoomInfo(r)                       -- full build
  local rid = icesus.mapper.idMap.idToRoom["delroom1"]
  check("room built with an id", rid ~= nil)

  mud.deleteRoom(rid)                               -- player deletes it
  calls = {}
  icesus.mapper.dirty = false
  icesus.mapper.onRoomInfo(r)                       -- identical payload
  check("deleted room is re-added", (calls.addRoom or 0) >= 1)
  check("deleted room fully rebuilt", (calls.setRoomName or 0) >= 1)
  check("recreated under the same integer id",
        icesus.mapper.idMap.idToRoom["delroom1"] == rid and rooms[rid] ~= nil)
  check("recreation re-marks dirty", icesus.mapper.dirty == true)

  calls = {}
  icesus.mapper.onRoomInfo(r)                       -- third, normal visit
  check("fast path re-arms after recreation", (calls.setRoomName or 0) == 0)
end

do
  -- Deleting a room also severs each neighbour's exit into it, and the
  -- neighbours' signatures still match — walking back into the deleted
  -- room must invalidate them so the return path rewires.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  local rA = roominfo("roomAAAA", { exits = { north = "roomBBBB" } })
  local rB = roominfo("roomBBBB", { exits = { south = "roomAAAA" } })
  icesus.mapper.onRoomInfo(rA)
  icesus.mapper.onRoomInfo(rB)
  local idB = icesus.mapper.idMap.idToRoom["roomBBBB"]

  mud.deleteRoom(idB)
  icesus.mapper.onRoomInfo(rB)                      -- walk into deleted room
  check("deleted neighbour rebuilt in place", rooms[idB] ~= nil)
  check("deletion invalidates the neighbour's signature",
        icesus.mapper.idMap.seen["roomAAAA"] == nil)

  calls = {}
  icesus.mapper.onRoomInfo(rA)                      -- walk back out
  check("neighbour full-rebuilds to rewire its exit", (calls.setExit or 0) > 0)
end

do
  -- A deleted room referenced only as an exit destination must be
  -- re-added as a stub when a changed neighbour rebuilds.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("stubAAAA", { exits = { north = "stubBBBB" } }))
  local idB = icesus.mapper.idMap.idToRoom["stubBBBB"]
  mud.deleteRoom(idB)

  calls = {}
  icesus.mapper.onRoomInfo(
    roominfo("stubAAAA", { exits = { north = "stubBBBB", east = "0" } }))
  check("stub destination re-added by neighbour rebuild", rooms[idB] ~= nil)
  check("stub keeps its integer id",
        icesus.mapper.idMap.idToRoom["stubBBBB"] == idB)
end

-- ================================================================
-- v1.0.15 save modes: manual never saves on a timer; the reminder is
-- idle-gated and throttled to one per 15 minutes.
-- ================================================================
do
  local icesus = load_icesus()
  setup_flush_state(icesus)
  icesus.loadSettings()
  check("default save mode is auto", icesus.settings.mapSaveMode == "auto")
  check("default mapper state is enabled", icesus.settings.mapperEnabled == true)

  icesus.settings.mapSaveMode = "manual"
  icesus.mapper.dirty = true
  icesus.mapper.dirtyCount = 3
  icesus.mapper.dirtySince = MOCK_TIME
  icesus.mapper.lastSave = MOCK_TIME - 10000        -- far past the 300s cap
  icesus.mapper.lastActivity = MOCK_TIME - 60
  icesus.state.inCombat = false
  calls = {}
  icesus.mapper.maybeFlush()
  check("manual mode: no timed save even past the cap", (calls.saveMap or 0) == 0)
  check("manual mode: no reminder before 15 min", (calls.cecho or 0) == 0)

  MOCK_TIME = MOCK_TIME + 900
  icesus.mapper.lastActivity = MOCK_TIME - 60
  calls = {}
  icesus.mapper.maybeFlush()
  check("manual mode: reminder fires after 15 min", (calls.cecho or 0) == 1)
  check("manual mode: reminder does not save", (calls.saveMap or 0) == 0)
  calls = {}
  icesus.mapper.maybeFlush()
  check("manual mode: reminder is throttled", (calls.cecho or 0) == 0)

  MOCK_TIME = MOCK_TIME + 900
  icesus.mapper.lastActivity = MOCK_TIME - 60
  calls = {}
  icesus.mapper.maybeFlush()
  check("manual mode: reminder repeats after another 15 min", (calls.cecho or 0) == 1)

  -- In-combat and just-moved must both suppress the reminder.
  MOCK_TIME = MOCK_TIME + 900
  icesus.state.inCombat = true
  icesus.mapper.lastActivity = MOCK_TIME - 60
  calls = {}
  icesus.mapper.maybeFlush()
  check("manual mode: no reminder during combat", (calls.cecho or 0) == 0)
  icesus.state.inCombat = false
  icesus.mapper.lastActivity = MOCK_TIME            -- just moved
  calls = {}
  icesus.mapper.maybeFlush()
  check("manual mode: no reminder right after moving", (calls.cecho or 0) == 0)

  -- `mapper save` still flushes on demand.
  calls = {}
  icesus.mapper.saveCommand()
  check("mapper save flushes in manual mode", (calls.saveMap or 0) == 1)
  check("flush resets dirty state and counter",
        icesus.mapper.dirty == false and icesus.mapper.dirtyCount == 0)
end

do
  -- Auto mode is untouched by the reminder plumbing: dirty + idle
  -- still flushes exactly as v1.0.14 did (regression guard).
  local icesus = load_icesus()
  setup_flush_state(icesus)
  icesus.loadSettings()
  icesus.mapper.dirty = true
  icesus.mapper.dirtySince = MOCK_TIME
  icesus.mapper.lastSave = MOCK_TIME
  icesus.mapper.lastActivity = MOCK_TIME - 11
  icesus.state.inCombat = false
  calls = {}
  icesus.mapper.maybeFlush()
  check("auto mode still flushes when idle", (calls.saveMap or 0) == 1)
end

-- ================================================================
-- Unsaved-changes counter: one per mapped room, zeroed on flush.
-- ================================================================
do
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("cnt00001"))
  icesus.mapper.onRoomInfo(roominfo("cnt00002"))
  icesus.mapper.onRoomInfo(roominfo("cnt00003"))
  check("dirty counter counts mapped rooms", icesus.mapper.dirtyCount == 3,
        "dirtyCount=" .. tostring(icesus.mapper.dirtyCount))
  icesus.mapper.onRoomInfo(roominfo("cnt00003"))    -- unchanged revisit
  check("fast path does not bump the counter", icesus.mapper.dirtyCount == 3)
  icesus.mapper.flushSave()
  check("flush zeroes the counter", icesus.mapper.dirtyCount == 0)
end

-- ================================================================
-- `mapper off` pauses Room.Info processing entirely.
-- ================================================================
do
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.settings = { mapSaveMode = "auto", mapperEnabled = false }
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("paused01"))
  check("mapper off: Room.Info ignored",
        (calls.addRoom or 0) == 0 and icesus.mapper.dirty ~= true)
  icesus.settings.mapperEnabled = true
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("paused01"))
  check("mapper on: Room.Info processed again", (calls.addRoom or 0) > 0)
end

-- ================================================================
-- Settings: persistence, validation, and survival of mapper reset.
-- ================================================================
do
  local icesus = load_icesus()
  setup_flush_state(icesus)
  icesus.loadSettings()
  calls = {}
  icesus.mapper.setSaveMode("manual")
  check("setSaveMode persists to disk", (calls.table_save or 0) == 1)
  check("mode recorded", icesus.settings.mapSaveMode == "manual")
  icesus.mapper.toggleSaveMode()
  check("toggle flips back to auto", icesus.settings.mapSaveMode == "auto")
  icesus.mapper.setEnabled(false)
  check("setEnabled(false) recorded", icesus.settings.mapperEnabled == false)

  icesus.mapper.setSaveMode("manual")
  local ok, err = pcall(function() icesus.mapper.reset(true) end)
  check("mapper reset runs without error", ok, tostring(err))
  check("mapper reset keeps the save mode", icesus.settings.mapSaveMode == "manual")
  check("mapper reset keeps the pause state", icesus.settings.mapperEnabled == false)
end

do
  local icesus = load_icesus()
  SETTINGS_ON_DISK = { mapSaveMode = "manual", mapperEnabled = false }
  icesus.loadSettings()
  check("settings load from disk: manual mode", icesus.settings.mapSaveMode == "manual")
  check("settings load from disk: paused", icesus.settings.mapperEnabled == false)
  SETTINGS_ON_DISK = { mapSaveMode = "bogus", mapperEnabled = 1 }
  icesus.loadSettings()
  check("bogus save mode falls back to auto", icesus.settings.mapSaveMode == "auto")
  check("non-false enabled flag reads as true", icesus.settings.mapperEnabled == true)
  SETTINGS_ON_DISK = nil
end

-- ================================================================
-- Issue Icesus-mud/issues#667: raw pinkfish tokens (%^BOLD%^ etc.)
-- leaking into GMCP chat text must not reach the channel feed.
-- ================================================================
do
  local icesus, env = load_icesus()
  local lines = {}
  icesus.hud = { channels = { cecho = function(self, s) lines[#lines+1] = s end } }
  env.gmcp = { Comm = { Channel = { Text = {
    channel = "event-info", talker = "Ruk",
    text = "The hunt for %^BOLD%^%^RED%^Razorwing%^RESET%^ begins!",
  } } } }
  icesus.onCommText()
  check("channel line rendered", #lines == 1)
  check("pinkfish tokens stripped", lines[1] ~= nil and not lines[1]:find("%%%^"))
  check("message text kept",
        lines[1] ~= nil and lines[1]:find("Razorwing", 1, true) ~= nil)

  env.gmcp.Comm.Channel.Tell = {
    talker = "Ruk", text = "psst %^B_GREEN%^hey%^RESET%^ you",
  }
  icesus.onCommTell()
  check("tell line stripped too", #lines == 2 and not lines[2]:find("%%%^"))
  check("tell text kept", #lines == 2 and lines[2]:find("hey you", 1, true) ~= nil)
end

-- ================================================================
-- Map integrity: atomic sidecar writes, paired hourly backups, the
-- crash-loop sentinel, and `mapper restore`.
-- ================================================================
local function fileExists(p)
  local f = io.open(p, "r")
  if f then f:close(); return true end
  return false
end
local function readAll(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end
local function countGlob(pattern)
  local f = io.popen("ls '" .. HOME .. "' '" .. HOME .. "/Icesus.backup' 2>/dev/null | grep -c '" .. pattern .. "'")
  local n = tonumber(f:read("*a")) or 0
  f:close()
  return n
end

do
  -- Atomic flush: live pair written, sidecars promoted (not left).
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("atom0001"))
  icesus.mapper.flushSave()
  check("flush writes the live map file", fileExists(HOME .. "/Icesus.map.dat"))
  check("flush writes the live idmap file", fileExists(HOME .. "/Icesus.idmap.lua"))
  check("map sidecar promoted, not left behind",
        not fileExists(HOME .. "/Icesus.map.dat.new"))
  check("idmap sidecar promoted, not left behind",
        not fileExists(HOME .. "/Icesus.idmap.lua.new"))
  local t = {}
  local ok = pcall(function()
    for k, v in pairs(assert(loadfile(HOME .. "/Icesus.idmap.lua"))()) do t[k] = v end
  end)
  check("saved idmap parses and keeps the room",
        ok and type(t.idToRoom) == "table" and t.idToRoom["atom0001"] ~= nil)
end

do
  -- A failed map write must keep dirty set and the live file intact.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("fail0001"))
  icesus.mapper.flushSave()
  local before = readAll(HOME .. "/Icesus.map.dat")
  icesus.mapper.onRoomInfo(roominfo("fail0002"))
  local realSaveMap = mud.saveMap
  mud.saveMap = function(path) bump("saveMap") end     -- writes nothing
  icesus.mapper.flushSave()
  mud.saveMap = realSaveMap
  check("failed save keeps the dirty flag", icesus.mapper.dirty == true)
  check("failed save leaves the live map untouched",
        readAll(HOME .. "/Icesus.map.dat") == before)
  icesus.mapper.flushSave()                             -- retry succeeds
  check("retry after failure flushes cleanly", icesus.mapper.dirty == false)
end

do
  -- Backup cadence: first flush snapshots, hourly spacing after that,
  -- `mapper save` always snapshots, rotation caps the history.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  local function backups()
    local f = io.popen("ls '" .. HOME .. "/Icesus.backup' 2>/dev/null | grep -c 'map.dat$'")
    local n = tonumber(f:read("*a")) or 0
    f:close()
    return n
  end
  icesus.mapper.onRoomInfo(roominfo("bkp00001"))
  icesus.mapper.flushSave()
  check("first flush of the session takes a backup", backups() == 1,
        "backups=" .. backups())

  MOCK_TIME = MOCK_TIME + 60
  icesus.mapper.onRoomInfo(roominfo("bkp00002"))
  icesus.mapper.flushSave()
  check("flush inside the hour: no new generation", backups() == 1)

  MOCK_TIME = MOCK_TIME + 3601
  icesus.mapper.onRoomInfo(roominfo("bkp00003"))
  icesus.mapper.flushSave()
  check("flush after an hour: new generation", backups() == 2)

  MOCK_TIME = MOCK_TIME + 60
  icesus.mapper.onRoomInfo(roominfo("bkp00004"))
  icesus.mapper.saveCommand()
  check("explicit mapper save ignores the spacing", backups() == 3)

  MOCK_TIME = MOCK_TIME + 60
  icesus.mapper.saveCommand()                           -- map is clean
  check("explicit save on a clean map still snapshots", backups() == 4)

  for _ = 1, 4 do
    MOCK_TIME = MOCK_TIME + 60
    icesus.mapper.saveCommand()
  end
  check("rotation keeps 5 recent pairs + the day's first", backups() == 6,
        "backups=" .. backups())

  -- Day rollover: one forced backup per day for 9 days. Retention
  -- must converge to the 5 most recent pairs plus the first pair of
  -- each of the last 7 days (which coincide here), and prune the
  -- older days' pairs including day 0's protected first.
  for _ = 1, 9 do
    MOCK_TIME = MOCK_TIME + 86400
    icesus.mapper.saveCommand()
  end
  check("daily retention keeps the last 7 days' first pairs",
        backups() == 7, "backups=" .. backups())
end

do
  -- `mapper restore N` rolls the live pair back and reloads it.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("res00001"))
  icesus.mapper.flushSave()                    -- generation 1: res00001
  MOCK_TIME = MOCK_TIME + 3601
  icesus.mapper.onRoomInfo(roominfo("res00002"))
  icesus.mapper.saveCommand()                  -- generation 2: both rooms

  calls = {}
  icesus.mapper.restoreCommand("1")            -- newest first
  check("restore empties the engine before loading",
        (calls.deleteRoom or 0) >= 2)
  check("restore 1 reloads the newest idmap",
        icesus.mapper.idMap.idToRoom["res00002"] ~= nil)
  check("restore quarantines the replaced pair",
        countGlob("idmap.lua.bad-") >= 1)
  check("restore leaves a clean dirty state", icesus.mapper.dirty == false)

  MOCK_TIME = MOCK_TIME + 60
  icesus.mapper.restoreCommand("2")            -- oldest generation
  check("restore 2 rolls back before the newer room",
        icesus.mapper.idMap.idToRoom["res00002"] == nil
        and icesus.mapper.idMap.idToRoom["res00001"] ~= nil)

  calls = {}
  icesus.mapper.restoreCommand("99")
  check("restore rejects an unknown index", (calls.cecho or 0) == 1)
end

do
  -- Redundant-load guard: Mudlet auto-loads the profile's map before
  -- scripts run, and reloading the .dat over those rooms freezes the
  -- client for minutes on a big map. install() must only touch the
  -- .dat when the engine doesn't already hold our rooms.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("liv00001"))
  icesus.mapper.flushSave()                    -- .dat + idmap on disk
  icesus.mapper.idMap = nil                    -- fresh boot, rooms live
  calls = {}
  icesus.mapper.install()
  check("rooms already live: .dat not reloaded", (calls.loadMap or 0) == 0)
  check("rooms already live: idmap reloaded",
        icesus.mapper.idMap.idToRoom["liv00001"] ~= nil)

  rooms = {}                                   -- empty engine this time
  icesus.mapper.idMap = nil
  calls = {}
  icesus.mapper.install()
  check("empty engine: .dat loaded from disk", (calls.loadMap or 0) == 1)
end

do
  -- Crash sentinel: a leftover Icesus.map.loading at install means the
  -- previous session died inside loadMap. Boot WITHOUT loading the
  -- map, leave the files alone, and tell the player.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("sen00001"))
  icesus.mapper.flushSave()                    -- live pair + backup exist
  local live = readAll(HOME .. "/Icesus.map.dat")

  local f = io.open(HOME .. "/Icesus.map.loading", "w")
  f:write("loading"); f:close()
  rooms = {}                                   -- engine came up empty
  icesus.mapper.idMap = nil                    -- simulate a fresh boot
  calls = {}
  icesus.mapper.install()
  check("crash recovery announces itself", (calls.cecho or 0) >= 1)
  check("recovery boot does not reload the map file",
        (calls.loadMap or 0) == 0)
  check("live pair left untouched",
        readAll(HOME .. "/Icesus.map.dat") == live
        and countGlob("map.dat.bad-") == 0)
  check("idmap still loaded on the recovery boot",
        icesus.mapper.idMap.idToRoom["sen00001"] ~= nil)
  check("recovery boot does not reset the stale-looking idmap",
        next(icesus.mapper.idMap.idToRoom) ~= nil
        and fileExists(HOME .. "/Icesus.idmap.lua"))
  check("sentinel removed after recovery",
        not fileExists(HOME .. "/Icesus.map.loading"))

  icesus.mapper.idMap = nil                    -- normal boot afterwards
  calls = {}
  icesus.mapper.install()
  check("clean install leaves no sentinel",
        not fileExists(HOME .. "/Icesus.map.loading"))
end

do
  -- Pre-created neighbours must inherit the current room's area
  -- immediately — created on sight but visited later (or never),
  -- they otherwise collect in Mudlet's "Default Area" and draw a
  -- ghost outline of the explored map there.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("area0001", { exits = { north = "area0002" } }))
  local idB = icesus.mapper.idMap.idToRoom["area0002"]
  check("pre-created neighbour inherits the current area",
        idB ~= nil and rooms[idB].area == 1)
end

do
  -- Outworld thinning: `mapper outworld roads|off` caps the giant
  -- gridmode area that dominates map size.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.loadSettings()
  check("outworld mode defaults to full", icesus.settings.outworldMode == "full")

  icesus.settings.outworldMode = "roads"
  local rA = roominfo("road0001", { coords = {10,20,0}, terrain = "road",
                                    exits = { east = "road0002", north = "plain001" } })
  calls = {}
  icesus.mapper.onRoomInfo(rA)
  check("roads mode maps a road tile",
        icesus.mapper.idMap.idToRoom["road0001"] ~= nil)
  check("roads mode does not pre-create neighbours",
        (calls.addRoom or 0) == 1, "addRoom=" .. (calls.addRoom or 0))

  calls = {}
  icesus.mapper.onRoomInfo(roominfo("plain001",
    { coords = {10,21,0}, terrain = "plains", exits = { south = "road0001" } }))
  check("roads mode skips a plains tile",
        icesus.mapper.idMap.idToRoom["plain001"] == nil)
  local curId = icesus.mapper.idMap.cursorRoom
  check("skipped tile spawns the position cursor",
        curId ~= nil and rooms[curId] ~= nil and rooms[curId].char == "@")
  check("cursor sits at the tile's grid coords",
        rooms[curId].coords ~= nil and rooms[curId].coords[1] == 10
        and rooms[curId].coords[2] == -21)
  check("cursor recenters the view on the skipped tile",
        (calls.centerview or 0) == 1)

  icesus.mapper.onRoomInfo(roominfo("road0002",
    { coords = {11,20,0}, terrain = "road", exits = { west = "road0001" } }))
  local idA = icesus.mapper.idMap.idToRoom["road0001"]
  local idB = icesus.mapper.idMap.idToRoom["road0002"]
  check("adjacent road tiles link forward", rooms[idB].exits.west == idA)
  check("adjacent road tiles link back (grid symmetry)",
        rooms[idA].exits.east == idB)

  -- Special tiles must survive roads mode: unknown codes (city gates
  -- 'c', points of interest '?'), missing terrain, and bulk terrain
  -- that carries a special exit.
  icesus.mapper.onRoomInfo(roominfo("gate0001",
    { coords = {13,20,0}, terrain = "c", exits = { east = "road0002" } }))
  check("roads mode keeps a city-gate tile ('c')",
        icesus.mapper.idMap.idToRoom["gate0001"] ~= nil)
  local idGate = icesus.mapper.idMap.idToRoom["gate0001"]
  check("unknown short code renders as its own glyph",
        rooms[idGate].char == "c")

  icesus.mapper.onRoomInfo(roominfo("poi00001",
    { coords = {14,20,0}, terrain = "?", exits = { west = "gate0001" } }))
  check("roads mode keeps a point-of-interest tile ('?')",
        icesus.mapper.idMap.idToRoom["poi00001"] ~= nil)

  icesus.mapper.onRoomInfo(roominfo("bare0001",
    { coords = {15,20,0}, exits = { west = "poi00001" } }))
  check("roads mode keeps a tile with no terrain",
        icesus.mapper.idMap.idToRoom["bare0001"] ~= nil)

  icesus.mapper.onRoomInfo(roominfo("cave0001",
    { coords = {16,20,0}, terrain = "forest",
      exits = { west = "bare0001", ["enter cave"] = "indoor01" } }))
  check("roads mode keeps bulk terrain with a special exit",
        icesus.mapper.idMap.idToRoom["cave0001"] ~= nil)

  calls = {}
  icesus.mapper.onRoomInfo(roominfo("plainzz1",
    { coords = {17,20,0}, terrain = "plains", exits = { west = "cave0001" } }))
  check("roads mode still skips plain bulk terrain",
        icesus.mapper.idMap.idToRoom["plainzz1"] == nil)
  check("cursor is reused, not duplicated",
        (calls.addRoom or 0) == 0 and icesus.mapper.idMap.cursorRoom == curId)
  check("cursor follows to the new tile",
        rooms[curId].coords[1] == 17 and rooms[curId].coords[2] == -20)

  icesus.settings.outworldMode = "off"
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("plain002",
    { coords = {12,20,0}, terrain = "forest" }))
  check("off mode adds no outworld tile", (calls.addRoom or 0) == 0)
  calls = {}
  icesus.mapper.onRoomInfo(rA)                 -- mapped before the switch
  check("off mode still recenters on mapped tiles",
        (calls.centerview or 0) == 1 and (calls.setRoomName or 0) == 0)
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("inn00001"))   -- indoor, no coords
  check("off mode still maps indoor zones", (calls.addRoom or 0) >= 1)

  calls = {}
  icesus.mapper.outworldCommand("roads")
  check("mapper outworld roads persists",
        (calls.table_save or 0) == 1 and icesus.settings.outworldMode == "roads")
  icesus.mapper.outworldCommand("full")
  check("switching back to full removes the cursor",
        icesus.mapper.idMap.cursorRoom == nil and rooms[curId] == nil)
  SETTINGS_ON_DISK = { outworldMode = "off" }
  icesus.loadSettings()
  check("outworld mode loads from disk", icesus.settings.outworldMode == "off")
  SETTINGS_ON_DISK = { outworldMode = "bogus" }
  icesus.loadSettings()
  check("bogus outworld mode falls back to full",
        icesus.settings.outworldMode == "full")
  SETTINGS_ON_DISK = nil
end

do
  -- Off mode freezes the map: arriving on a room that predates area
  -- inheritance — still sitting in Default Area — must repair its
  -- area before centering, or the whole view flips to Default Area.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.loadSettings()
  icesus.settings.outworldMode = "off"
  icesus.mapper.onRoomInfo(roominfo("seed0001"))   -- boot the idmap
  local m = icesus.mapper.idMap
  local strayId = m.next_id
  m.next_id = strayId + 1
  mud.addRoom(strayId)                     -- old-era stray: no area set
  m.idToRoom["plainold"] = strayId
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("plainold",
    { coords = {6,5,0}, terrain = "plains" }))
  check("off mode: stray room's area repaired before centering",
        rooms[strayId].area == 1)
  check("off mode: stray visit recenters on the room",
        (calls.centerview or 0) == 1)
  check("off mode: stray room is kept (map frozen)",
        rooms[strayId] ~= nil and (calls.deleteRoom or 0) == 0)
end

do
  -- Roads mode self-prunes: riding over a full-mode-era bulk tile
  -- deletes its room, so the map converges to the lean atlas.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.loadSettings()
  icesus.settings.outworldMode = "roads"
  icesus.mapper.onRoomInfo(roominfo("road0010",
    { coords = {5,5,0}, terrain = "road" }))
  local m = icesus.mapper.idMap
  local strayId = m.next_id
  m.next_id = strayId + 1
  mud.addRoom(strayId)
  m.idToRoom["plainprn"] = strayId
  m.placed["plainprn"] = { 6, -5, 0 }
  m.seen["plainprn"] = "old-signature"
  icesus.mapper.dirty = false
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("plainprn",
    { coords = {6,5,0}, terrain = "plains", exits = { west = "road0010" } }))
  check("riding over a bulk-era room deletes it",
        (calls.deleteRoom or 0) == 1 and rooms[strayId] == nil)
  check("pruned room forgotten by the idmap",
        m.idToRoom["plainprn"] == nil and m.seen["plainprn"] == nil
        and m.placed["plainprn"] == nil)
  check("cursor takes over the view on the pruned tile",
        m.cursorRoom ~= nil and rooms[m.cursorRoom] ~= nil
        and (calls.centerview or 0) >= 1)
  check("prune marks the map dirty", icesus.mapper.dirty == true)
  check("kept road tile is untouched",
        rooms[m.idToRoom["road0010"]] ~= nil)

  -- A bulk tile properly mapped in full mode (area assigned) must be
  -- KEPT and recentered — only Default Area strays are pruned.
  local keptId = m.next_id
  m.next_id = keptId + 1
  mud.addRoom(keptId)
  rooms[keptId].area = 1                   -- full-era tile, real area
  m.idToRoom["plainkpt"] = keptId
  calls = {}
  icesus.mapper.onRoomInfo(roominfo("plainkpt",
    { coords = {7,5,0}, terrain = "plains" }))
  check("area-assigned bulk tile is kept",
        rooms[keptId] ~= nil and (calls.deleteRoom or 0) == 0)
  check("kept bulk tile recenters the view", (calls.centerview or 0) == 1)
  check("kept bulk tile is not rebuilt", (calls.setRoomName or 0) == 0)
end

do
  -- Wipe guard: when the in-memory map has been emptied out from
  -- under a non-empty idmap (a load that came out broken), flushSave
  -- must refuse to overwrite the good on-disk snapshot.
  local icesus = load_icesus()
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("wip00001"))
  icesus.mapper.flushSave()
  local good = readAll(HOME .. "/Icesus.map.dat")
  icesus.mapper.onRoomInfo(roominfo("wip00002"))
  rooms = {}                                   -- engine wiped under us
  calls = {}
  icesus.mapper.flushSave()
  check("wiped engine: save refused", (calls.saveMap or 0) == 0)
  check("wiped engine: good file untouched",
        readAll(HOME .. "/Icesus.map.dat") == good)
  check("wiped engine: warning shown", (calls.cecho or 0) == 1)
  check("wiped engine: dirty flag kept", icesus.mapper.dirty == true)
  icesus.mapper.flushSave()
  check("wiped engine: warning not repeated", (calls.cecho or 0) == 1)
end

do
  -- Corrupt idmap on disk: loadIdMap must warn and start clean
  -- instead of silently doubling the map.
  local icesus = load_icesus()
  local f = io.open(HOME .. "/Icesus.idmap.lua", "w")
  f:write("return {{{ this is not lua"); f:close()
  calls = {}
  icesus.mapper.idMap = nil
  icesus.mapper.onRoomInfo(roominfo("cor00001"))
  check("corrupt idmap triggers a warning", (calls.cecho or 0) >= 1)
  check("mapper still maps after a corrupt idmap",
        icesus.mapper.idMap.idToRoom["cor00001"] ~= nil)
end

print(string.format("\n%d/%d checks passed, %d failed", total - failures, total, failures))
os.exit(failures == 0 and 0 or 1)
