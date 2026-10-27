package.path = arg_dir .. "/?.lua;" .. package.path
local function ev(v) return function() return v end end
package.preload["st.capabilities"] = function() return { motionSensor = { motion = { active = ev("active"), inactive = ev("inactive") } } } end
package.preload["st.matter.clusters"] = function() return {} end
package.preload["st.utils"] = function() return {} end
package.preload["sensor_utils.utils"] = function() return {} end
package.preload["sensor_utils.fields"] = function() return {} end
package.preload["sensor_utils.device_configuration"] = function() return {} end
package.preload["version"] = function() return { api = 99 } end
local h = require("sensor_handlers.attribute_handlers").occupancy_measured_value_handler

local P, clock = 7080, 1000
os.time = function() return clock end
local fields, emitted, timers = {}, {}, {}
local dev = { log = { info_with = function() end },
  get_field = function(_, k) return fields[k] end, set_field = function(_, k, v) fields[k] = v end,
  supports_capability = function() return true end,
  emit_event_for_endpoint = function(_, _, e) table.insert(emitted, e) end,
  thread = { call_with_delay = function(_, _, fn) table.insert(timers, fn) end } }
local function report(v, at) clock = at; h(nil, dev, { endpoint_id = 1, data = { value = v } }) end

report(1, 1000); report(0, 1030)                 -- real motion, room then idle
emitted = {}
report(1, 1000 + P)                               -- phantom tick: dropped
assert(#emitted == 0 and #timers == 1, "phantom dropped, check scheduled")
report(0, 1000 + P + 30); timers[1]()             -- cleared at 30s like every phantom
assert(emitted[1] == "inactive" and #emitted == 1, "normal phantom: nothing reported late")

emitted, timers = {}, {}
report(1, 1000 + 2 * P)                           -- next tick, someone walks in during the hold
assert(#emitted == 0, "dropped")
timers[1]()                                       -- 35s later still no inactive
assert(emitted[1] == "active", "held phantom: motion reported late")
report(0, 1000 + 2 * P + 300)
assert(emitted[2] == "inactive", "session ends normally")
print("neo held phantom checks passed")
