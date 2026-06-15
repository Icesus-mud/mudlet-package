#!/usr/bin/env lua5.4
-- Unit tests for the Icesus package mapper: the v1.0.14 walking/combat
-- fluidity work.
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

local function bump(name) calls[name] = (calls[name] or 0) + 1 end

local function fresh_world()
  calls = {}
  rooms = {}
  MOCK_TIME = 1000
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
mud.cecho            = function() end
mud.echo             = function() end

-- Partial overrides of stdlib tables the package uses.
mud.os = setmetatable({ time = function() return MOCK_TIME end }, { __index = os })
mud.io = setmetatable({ exists = function() return false end }, { __index = io })
mud.table = setmetatable({
  save = function() bump("table_save") end,
  load = function() end,
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
  return env.icesus
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

print(string.format("\n%d/%d checks passed, %d failed", total - failures, total, failures))
os.exit(failures == 0 and 0 or 1)
