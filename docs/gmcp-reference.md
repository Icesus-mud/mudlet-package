# GMCP reference (subset used by this package)

Authoritative source: `help gmcp` in-game, or `doc/help/gmcp.doc` in
the mudlib repo. This file documents only the fields **this package
consumes**, plus the closest neighbours you'd reach for when adding the
next module. If a field here disagrees with `help gmcp`, in-game wins —
open an issue.

To see the live JSON arriving on your client, run in Mudlet's command
line:

```
display(gmcp)
```

after a few seconds connected.

## Subscription

The package opts in via `Core.Supports.Set` on connect:

```
Core.Supports.Set ["Char 1", "Char.Vitals 1", "Comm 1", "Room 1"]
```

The `Char` module includes `Vitals`, `Maxstats`, `Status`, `Base`,
`Casting`, `Cooldowns`, `ExpGain`, `EnemyDeath`. `Comm` includes
`Channel`. `Room` includes `Info`.

## Char.Vitals

Sent on every HP/SP/EP change.

```
{
  "hp":   142,
  "sp":   88,
  "ep":   60
}
```

Update cadence: every tick + every damage event. **Use `Char.Maxstats`
for the cap** — `Char.Vitals` carries current values only.

## Char.Maxstats

Sent on level-up, bonus changes, equipment swaps that move the cap.

```
{
  "maxhp": 200,
  "maxsp": 120,
  "maxep": 80
}
```

## Char.Status

Sent when something the HUD cares about changes: combat state,
position, conditions, money, equipment, status effects.

```
{
  "level":   42,
  "exp":     153400,
  "tnl":     200000,
  "pos":     "standing",        // sleeping, resting, meditating, unconscious
  "state":   "combat",          // idle, combat, busy, …
  "food":    "satiated",
  "water":   "refreshed",
  "drunk":   "sober",
  "money":   1234,
  "bank":    9999,
  "dfavor":  3,
  "carry_wt":   8500,
  "max_wt":    20000,
  "carry_vol":  3200,
  "max_vol":   12000,
  "effects": ["bleeding", "stunned"],
  "wounds": [                      // one per bleeding body part
    { "slot": "left arm", "severity": "nasty",   // minor nasty bad severe fatal
      "type": "slashing", "desc": "a nasty bleeding wound" }
  ],
  "enemy":     "an orc warrior",   // legacy single-target
  "enemypct":  60,
  "enemies": [                     // multi-target — preferred
    { "name": "an orc warrior", "hp": 60, "shape": "severely hurt" },
    { "name": "an orc shaman",  "hp": 90, "shape": "slightly hurt" }
  ],
  "momentum":         "berserk",   // available momentum action, or ""
  "special_momentum": ""
}
```

The `enemies[*].hp` field is **bucketed to 12 tiers** (100 / 99 / 90 /
80 / 70 / 60 / 50 / 40 / 30 / 20 / 10 / 5) to match what `consider`
shows in text. Don't display finer precision than this — the data
isn't there.

## Char.EnemyDeath

Fired when an opponent the player is fighting dies.

```
{ "name": "an orc warrior" }
```

Used to remove rows from the enemy panel snappily, instead of waiting
for the next `Char.Status` to drop.

## Char.Base

Sent on character info changes (name, race, guild title).

```
{
  "name":  "Idles",
  "title": "Idles, the Wanderer",
  "race":  "human",
  "guild": "warrior"
}
```

## Char.Casting

Sent during spell casting and skill busy intervals.

```
{
  "spell":    "fireball",     // or skill name
  "duration": 3.5,            // seconds
  "elapsed":  0.0
}
```

## Char.Cooldowns

Sent on cooldown change.

```
{
  "cooldowns": [
    { "name": "shieldbash",  "remaining": 12 },
    { "name": "berserk",     "remaining": 45 }
  ]
}
```

`remaining` is in seconds; tick it down client-side.

## Char.ExpGain

Fired on EXP gain, useful for float-up notifications.

```
{ "amount": 1500 }
```

## Comm.Channel

Sent for every channel + say + tell + whisper sent to this player.

```
{
  "chan":   "newbie",
  "player": "Tester",
  "msg":    "anyone awake?"
}
```

`player` is empty for system messages on the channel.

## Room.Info

Sent on every move.

```
{
  "name":    "A frozen path",
  "area":    "Outworld",
  "id":      "outworld:142,77",
  "exits":   { "north": "...", "south": "...", "east": "..." },
  "terrain": "f",                // single char for outworld tiles
  "x":       142,
  "y":       77
}
```

## Party.Info

Sent on party changes (member join/leave, HP).

```
{
  "members": [
    { "name": "Idles",  "hp": 80, "hpmax": 100, "level": 42 },
    { "name": "Friend", "hp": 60, "hpmax":  90, "level": 39 }
  ]
}
```

## Client.Triggers, Client.Hotkeys

Server-side stored triggers and hotkey bindings, synced via GMCP. The
web client uses these for cross-session persistence; a future Mudlet
module can read+write them so triggers roam between clients.

```
// Client.Triggers
{
  "triggers": [ { "p": "you are hungry", "c": "eat food" }, … ],
  "raw":      "<original textarea form>"
}

// Client.Hotkeys
{
  "F1": "kill orc",
  "F2": "cast heal at me"
}
```

## World.Time, Server.Status

Game clock and server stats. The HUD shows `World.Time.hour_name` on
the location row; the server sends the packet at login and whenever the
hour or the day phase changes.

```
// World.Time
{
  "hour_name": "late evening", "hour_position": "middle",
  "day": 12, "month": "Frostmoon", "season": "winter",
  "is_night": 1, "phase": "night"
}
```
