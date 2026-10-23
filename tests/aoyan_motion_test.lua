package.path = arg_dir .. "/?.lua;" .. arg_dir .. "/?/init.lua;" .. package.path
local function ev(name, v) return function() return { name = name, v = v } end end
package.preload["st.capabilities"] = function() return {
  motionSensor = { motion = { active = ev("motion", "active"), inactive = ev("motion", "inactive") } },
  tamperAlert = { ID = "tamperAlert", tamper = { detected = ev("tamper", "detected"), clear = ev("tamper", "clear") } },
} end
package.preload["st.zigbee.zcl.clusters"] = function() return { IASZone = { ID = 0x0500,
  client = { commands = { ZoneStatusChangeNotification = { ID = 0x00 } } },
  attributes = { ZoneStatus = { ID = 0x0002 } } } } end

local handler = require "motion_timeout"
local notify = handler.zigbee_handlers.cluster[0x0500][0x00]

local function new_device(mfr, model)
  local d = { emitted = {}, timers = {}, fields = {} }
  d.get_manufacturer = function() return mfr end
  d.get_model = function() return model end
  d.supports_capability_by_id = function() return true end
  d.emit_event = function(_, e) table.insert(d.emitted, e) end
  d.get_field = function(_, k) return d.fields[k] end
  d.set_field = function(_, k, v) d.fields[k] = v end
  d.thread = { call_with_delay = function(_, sec, fn) table.insert(d.timers, { sec = sec, fn = fn }); return #d.timers end,
    cancel_timer = function() end }
  return d
end
local function zone(alarm)
  return { body = { zcl_body = { zone_status = {
    is_alarm1_set = function() return alarm end, is_alarm2_set = function() return false end,
    is_tamper_set = function() return false end } } } }
end
local function last_motion(d)
  for i = #d.emitted, 1, -1 do if d.emitted[i].name == "motion" then return d.emitted[i].v end end
end

-- 1) AOYAN: motion stays active until the device itself reports clear (no auto-clear timer)
local aoyan = new_device("AOYAN ", "AY-204Z")
notify(nil, aoyan, zone(true))
assert(last_motion(aoyan) == "active", "aoyan active")
assert(#aoyan.timers == 0, "aoyan: no auto-clear timer")
notify(nil, aoyan, zone(false))
assert(last_motion(aoyan) == "inactive", "aoyan clear from device")
assert(#aoyan.timers == 0, "aoyan: still no timer")

-- 2) other fingerprints keep the official 20s auto-clear
local heiman = new_device("HEIMAN", "PIRSensor-N")
notify(nil, heiman, zone(true))
assert(#heiman.timers == 1 and heiman.timers[1].sec == 20, "heiman timer")
heiman.timers[1].fn()
assert(last_motion(heiman) == "inactive", "heiman auto-clear")
print("aoyan motion checks passed")
