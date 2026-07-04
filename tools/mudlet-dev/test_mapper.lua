#!/usr/bin/env lua5.4
-- Unit tests for the Icesus package mapper: the v1.0.14 walking/combat
-- fluidity work, the v1.0.15 save modes / pause toggle / deleted-room
-- recovery, and the channel-feed colour-code strip.
--
-- These load the REAL icesus.core Lua chunk straight out of
-- package/Icesus.xml under a mocked Mudlet API, then drive
-- icesus.mapper.* directly and assert on the recorded driver calls.
-- No GUI, no Mudlet, fully deterministic (os.time is mocked).
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

local function bump(name) calls[name] = (calls[name] or 0) + 1 end

local function fresh_world()
  calls = {}
  rooms = {}
  MOCK_TIME = 1000
  SETTINGS_ON_DISK = nil
end

local mud = {}

mud.getMudletHomeDir = function() return "/tmp/icesus-test-home" end
mud.createRoomID     = function() return 1 end

mud.addRoom = function(id)
  bump("addRoom")
  if rooms[id] then return false end
  rooms[id] = { exits = {}, special = {}, stub = {} }
  return true
end
mud.roomExists  = function(id) return rooms[id] ~= nil end
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
mud.saveMap          = function(path) bump("saveMap") end
mud.tempTimer        = function(secs, fn) bump("tempTimer"); return (calls.tempTimer or 0) end
mud.killTimer        = function(id) bump("killTimer") end
mud.cecho            = function() bump("cecho") end
mud.echo             = function() end

-- Partial overrides of stdlib tables the package uses.
mud.os = setmetatable({ time = function() return MOCK_TIME end }, { __index = os })
mud.io = setmetatable({
  exists = function() return SETTINGS_ON_DISK ~= nil end,
}, { __index = io })
mud.table = setmetatable({
  save = function() bump("table_save") end,
  load = function(path, t)
    bump("table_load")
    if SETTINGS_ON_DISK and type(t) == "table" then
      for k, v in pairs(SETTINGS_ON_DISK) do t[k] = v end
    end
  end,
}, { __index = table })

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

print(string.format("\n%d/%d checks passed, %d failed", total - failures, total, failures))
os.exit(failures == 0 and 0 or 1)
