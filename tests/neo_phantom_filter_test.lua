package.path = arg_dir .. "/?.lua;" .. package.path
local f = require "phantom_filter"
local P = 7080
-- chain: real at t0, phantoms at +P, +2P; real motion in between not filtered
local h = f.record({}, 1000)
assert(f.is_phantom(h, 1000 + P) == true, "exact +P")
assert(f.is_phantom(h, 1000 + P + 3) == true, "+P+3")
assert(f.is_phantom(h, 1000 + P - 3) == true, "+P-3")
assert(f.is_phantom(h, 1000 + P + 4) == false, "+P+4 outside")
assert(f.is_phantom(h, 1000 + 60) == false, "real motion 1min later")
assert(f.is_phantom(h, 1000 + 2 * P) == true, "missing link 2P")
assert(f.is_phantom(h, 1000 + 13 * P) == false, "beyond 12 multiples")
assert(f.is_phantom({}, 5000) == false, "empty history")
-- record prunes old entries and does not mutate input
local old = { 1, 2 }
local h2 = f.record(old, 1 + 12 * P + 10)
assert(#old == 2, "input not mutated")
assert(#h2 == 1, "old entries pruned")
-- Tuya set-data payload: seq(2) dp(1) type(1) len(2) value(1)
local p = string.pack(">I2BBI2B", 0x1234, 9, 4, 1, 2)
assert(#p == 7 and p:byte(3) == 9 and p:byte(4) == 4 and p:byte(6) == 1 and p:byte(7) == 2, "tuya payload")
print("all checks passed")
