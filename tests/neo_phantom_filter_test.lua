package.path = arg_dir .. "/?.lua;" .. package.path
local f = require "phantom_filter"
local P = 7080

-- chain start: exactly +P after the previous active (room idle)
local ph, s = f.check({ last_active = 1000 }, 1000 + P)
assert(ph and s.chain == 1000 + P, "chain start +P")
assert(f.check({ last_active = 1000 }, 1000 + P + 3), "+P+3")
assert(f.check({ last_active = 1000 }, 1000 + P - 3), "+P-3")
assert(not f.check({ last_active = 1000 }, 1000 + P + 4), "+P+4 outside")
assert(not f.check({}, 5000), "empty state")

-- chain keeps ticking even with real motion in between; real motion passes
local t = s.chain
ph, s = f.check(s, t + 600)
assert(not ph and s.chain == t, "real motion 10 min later passes, chain kept")
ph, s = f.check(s, t + P + 1)
assert(ph and s.chain == t + P + 1, "tick despite real motion in between")
ph = f.check(s, s.chain + 2 * P)
assert(ph, "missing tick (2P)")
assert(not f.check({ chain = 1000, last_active = 50000 }, 1000 + 13 * P), "beyond 12 ticks")

-- old flaw: a real active on a multiple of some older *real* active must pass
assert(not f.check({ last_active = 1000 + 5 * P - 300 }, 1000 + 5 * P), "no all-history matching")

-- input state not modified
local before = { last_active = 1, chain = nil }
f.check(before, 1 + P)
assert(before.last_active == 1 and before.chain == nil, "input not mutated")

-- Tuya set-data payload: seq(2) dp(1) type(1) len(2) value(1)
local p = string.pack(">I2BBI2B", 0x1234, 9, 4, 1, 2)
assert(#p == 7 and p:byte(3) == 9 and p:byte(4) == 4 and p:byte(6) == 1 and p:byte(7) == 2, "tuya payload")
print("all checks passed")
