package.path = arg_dir .. "/?.lua;" .. package.path
local function obj() return setmetatable({}, { __call = function(_, t) return t or {} end, __index = function(t, k) return obj() end }) end
local fc = { set_cluster_specific = function() end, set_disable_default_response = function() end }
local emitted = {}
local function ev(name) return function(v) return function() return { name = name, v = v } end end end
package.preload["st.capabilities"] = function() return setmetatable({ tamperAlert = { ID = "tamperAlert", tamper = { clear = function() return { name = "tamper", v = "clear" } end } } }, { __index = function(_, id) if id == "stse.sensitivityAdjustment" then return { sensitivityAdjustment = { High = function() return { name = "sens", v = "High" } end, Medium = function() return { name = "sens", v = "Medium" } end, Low = function() return { name = "sens", v = "Low" } end } } else return { keepTime = function(v) return { name = "keep", v = v } end } end end }) end
package.preload["st.driver"] = function() return { default_capability_match_driverSwitched_handler = function() end } end
package.preload["st.zigbee.device_management"] = function() return { configure = function(_, d) d.configured_calls = (d.configured_calls or 0) + 1 end } end
package.preload["st.zigbee.zcl.clusters"] = function() return { PowerConfiguration = { ID = 0x0001, attributes = { BatteryPercentageRemaining = { read = function() return "read" end } } } } end
package.preload["st.zigbee.messages"] = function() return { AddressHeader = function(...) return { ... } end, ZigbeeMessageTx = function(t) return t end } end
package.preload["st.zigbee.zcl"] = function() return { ZclHeader = function(t) t.frame_ctrl = fc; return t end, ZclMessageBody = function(t) return t end } end
package.preload["st.zigbee.data_types"] = function() return { ZCLCommandId = function(v) return { value = v } end } end
package.preload["st.zigbee.generic_body"] = function() return { GenericBody = function(p) return { body_bytes = p } end } end
package.preload["st.zigbee.constants"] = function() return { HUB = { ADDR = 0, ENDPOINT = 1 }, HA_PROFILE_ID = 0x0104 } end

local m = require "aoyan_reconfigure"
local fields, sent = {}, {}
-- Like the hub datastore: a persisted table comes back as a proxy that next() sees as empty.
local function proxy(t)
  local values = {}
  for k, v in pairs(t) do values[k] = v end
  return setmetatable({}, { __index = values, __pairs = function() return pairs(values) end })
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local log = { info_with = function() end, warn_with = function() end }
local dev = { preferences = { sensitivity = "2" }, log = log,
  get_model = function() return "AY-204Z" end, get_field = function(_, k) return fields[k] end,
  set_field = function(_, k, v, p) if p and p.persist and type(v) == "table" then for key in pairs(v) do if type(key) ~= "string" then error("persist: non-string key " .. tostring(key)) end end v = proxy(v) end fields[k] = v end, send = function(_, msg) table.insert(sent, msg) end, emit_event = function(_, e) table.insert(emitted, e) end,
  get_short_address = function() return 0x1234 end, get_endpoint = function() return 1 end }

-- 1) user picks settings in the app -> queued + UI updated, nothing sent yet
local h = m.capability_handlers
h["stse.sensitivityAdjustment"].setSensitivityAdjustment(nil, dev, { args = { sensitivity = "High" } })
h["earthpepper23300.motionKeepTime"].setKeepTime(nil, dev, { args = { value = "30" } })
h["earthpepper23300.motionKeepTime"].setKeepTime(nil, dev, { args = { value = "999" } })
assert(fields.aoyan_pending_dps["9"] == 2 and fields.aoyan_pending_dps["10"] == 1, "queued")
assert(#emitted == 2 and emitted[1].v == "High" and emitted[2].v == "30", "ui updated, invalid ignored")
assert(sent[1] == nil, "nothing sent yet")
assert(#sent == 0, "not sent while asleep")

-- 2) capture dispatcher hook via install
local hooked
local drv = { zigbee_message_dispatcher = { dispatch = function() end }, call_with_delay = function() end }
m.install(drv)
local function rx(cluster, cmd, bytes) return { address_header = { cluster = { value = cluster } }, body = { zcl_header = { cmd = { value = cmd } }, zcl_body = { body_bytes = bytes } } } end
fields.aoyan_configured = true -- configuration already done
drv.zigbee_message_dispatcher:dispatch(drv, dev, rx(0x0500, 0x00, ""))
assert(#sent == 2, "both dps sent on wake")
local p = sent[1].body.zcl_body.body_bytes
assert(#p == 7 and p:byte(4) == 4 and p:byte(6) == 1, "tuya enum frame")

-- 3) immediate second wake within 10s -> no duplicate
drv.zigbee_message_dispatcher:dispatch(drv, dev, rx(0x0500, 0x00, ""))
assert(#sent == 2, "rate limited")

-- 4) device echoes dp 9 -> only dp 10 remains
drv.zigbee_message_dispatcher:dispatch(drv, dev, rx(0xEF00, 0x02, string.pack(">I2BBI2B", 1, 9, 4, 1, 2)))
assert(fields.aoyan_pending_dps["9"] == nil and fields.aoyan_pending_dps["10"] == 1, "dp 9 acked")
drv.zigbee_message_dispatcher:dispatch(drv, dev, rx(0xEF00, 0x02, string.pack(">I2BBI2B", 2, 10, 4, 1, 1)))
assert(count(fields.aoyan_pending_dps) == 0 and fields.aoyan_dp_attempts == nil, "all acked")


-- 6) not configured yet: probe response triggers configure, later battery marks done
fields.aoyan_configured = nil
drv.zigbee_message_dispatcher:dispatch(drv, dev, rx(0x0001, 0x01, ""))
assert(dev.configured_calls == 1 and not fields.aoyan_configured, "first battery msg = awake -> configure")
drv.zigbee_message_dispatcher:dispatch(drv, dev, rx(0x0001, 0x01, ""))
assert(fields.aoyan_configured == true, "second battery msg = configured")
-- 7) newly added device: defaults shown in the app AND queued for the device (Low, 10s)
local function new_dev(states)
  local f, ev = {}, {}
  local d = { log = log, fields = f, emitted = ev,
    get_model = function() return "AY-204Z" end, get_field = function(_, k) return f[k] end,
    set_field = function(_, k, v) f[k] = v end, emit_event = function(_, e) table.insert(ev, e) end,
    supports_capability_by_id = function() return true end,
    get_latest_state = function(_, _, cap) return states[cap] end,
    thread = { call_with_delay = function(_, _, fn) fn() end } }
  return d
end
local fresh = new_dev({})
m.added(nil, fresh)
assert(fresh.fields.aoyan_pending_dps["9"] == 0 and fresh.fields.aoyan_pending_dps["10"] == 0, "defaults queued: Low, 10s")
local shown = {}
for _, e in ipairs(fresh.emitted) do shown[e.name] = e.v end
assert(shown.sens == "Low" and shown.keep == "10", "defaults shown in app")

-- 8) device that already has values keeps the user's choice
local used = new_dev({ ["stse.sensitivityAdjustment"] = "High", ["earthpepper23300.motionKeepTime"] = "60", tamperAlert = "clear" })
m.added(nil, used)
assert(used.fields.aoyan_pending_dps == nil and #used.emitted == 0, "existing settings untouched")
print("aoyan checks passed")
