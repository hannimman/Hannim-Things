-- AY-204Z: re-send configuration when the sleepy device wakes up.
--
-- SmartThings does not run doConfigure when a device is switched to this driver
-- (the default driverSwitched handler only checks capabilities). A sleepy end device
-- also misses anything sent while it is asleep. So whenever the device talks to us,
-- it is awake: send bind/reporting/IAS enroll + refresh until a battery
-- (PowerConfiguration) message proves the configuration took effect.
--
-- The same wake-up hook delivers the Tuya-only settings (sensitivity, keep time),
-- which the device only accepts while awake.

local Driver = require "st.driver"
local capabilities = require "st.capabilities"
local device_management = require "st.zigbee.device_management"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local messages = require "st.zigbee.messages"
local zcl_messages = require "st.zigbee.zcl"
local data_types = require "st.zigbee.data_types"
local generic_body = require "st.zigbee.generic_body"
local zb_const = require "st.zigbee.constants"

local CONFIGURED = "aoyan_configured"
local LAST_ATTEMPT = "aoyan_last_configure_attempt"
local PENDING_DPS = "aoyan_pending_dps"
local LAST_DP_SEND = "aoyan_last_dp_send"
local RETRY_INTERVAL_SEC = 60
local DP_RESEND_INTERVAL_SEC = 10
local DP_ATTEMPTS = "aoyan_dp_attempts"
local MAX_DP_ATTEMPTS = 5

local PROFILE = "aoyan-motion"
local PROFILE_SETTLE_SEC = 5
local TUYA_CLUSTER = 0xEF00
local TUYA_SET_DATA = 0x00
local TUYA_RESPONSE = 0x01
local TUYA_REPORT = 0x02
local TUYA_TYPE_ENUM = 0x04
-- Tuya datapoints and enum values (zigbee2mqtt AY-204Z definition)
local SENSITIVITY_DP = 9
local KEEP_TIME_DP = 10
local SENSITIVITY_VALUES = { Low = 0, Medium = 1, High = 2 }
local KEEP_TIME_VALUES = { ["10"] = 0, ["30"] = 1, ["60"] = 2, ["120"] = 3 }

-- UI controls: SmartThings' own sensitivity capability + our keep time capability
local SENSITIVITY_CAP_ID = "stse.sensitivityAdjustment"
local KEEP_TIME_CAP_ID = "earthpepper23300.motionKeepTime"
local DEFAULT_SENSITIVITY = "Medium"
local DEFAULT_KEEP_TIME = "10"

local function is_aoyan(device)
  return device:get_model() == "AY-204Z"
end

-- Tuya "set data": seq(2) dp(1) type(1) len(2) value(1)
local function tuya_enum_command(device, dp, value)
  local payload = string.pack(">I2BBI2B", math.random(0, 0xFFFF), dp, TUYA_TYPE_ENUM, 1, value)
  local header = zcl_messages.ZclHeader({ cmd = data_types.ZCLCommandId(TUYA_SET_DATA) })
  header.frame_ctrl:set_cluster_specific()
  header.frame_ctrl:set_disable_default_response()
  local address = messages.AddressHeader(
    zb_const.HUB.ADDR, zb_const.HUB.ENDPOINT,
    device:get_short_address(), device:get_endpoint(TUYA_CLUSTER),
    zb_const.HA_PROFILE_ID, TUYA_CLUSTER)
  local body = zcl_messages.ZclMessageBody({ zcl_header = header, zcl_body = generic_body.GenericBody(payload) })
  return messages.ZigbeeMessageTx({ address_header = address, body = body })
end

local function send_pending_dps(device)
  local pending = device:get_field(PENDING_DPS) or {}
  if next(pending) == nil then
    return
  end
  local now = os.time()
  local last = device:get_field(LAST_DP_SEND)
  if last ~= nil and now - last < DP_RESEND_INTERVAL_SEC then
    return
  end
  device:set_field(LAST_DP_SEND, now)
  -- Not every firmware echoes the datapoint back; stop after a few tries.
  local attempts = (device:get_field(DP_ATTEMPTS) or 0) + 1
  if attempts > MAX_DP_ATTEMPTS then
    device:set_field(PENDING_DPS, {}, { persist = true })
    device:set_field(DP_ATTEMPTS, nil)
    device.log.warn_with({ hub_logs = true }, "AOYAN: no acknowledgement for settings, giving up")
    return
  end
  device:set_field(DP_ATTEMPTS, attempts)
  for key, value in pairs(pending) do
    local dp = tonumber(key)
    device.log.info_with({ hub_logs = true }, string.format("AOYAN: sending dp %d = %d", dp, value))
    device:send(tuya_enum_command(device, dp, value))
  end
end

-- The device echoes a datapoint after accepting it; stop resending that one.
local function clear_acknowledged_dp(device, zb_rx)
  local bytes = zb_rx.body.zcl_body.body_bytes
  if bytes == nil or #bytes < 3 then
    return
  end
  local dp = bytes:byte(3)
  local key = tostring(dp)
  local pending = device:get_field(PENDING_DPS) or {}
  if pending[key] ~= nil then
    local next_pending = {}
    for k, v in pairs(pending) do
      if k ~= key then next_pending[k] = v end
    end
    device:set_field(PENDING_DPS, next_pending, { persist = true })
    if next(next_pending) == nil then
      device:set_field(DP_ATTEMPTS, nil)
    end
    device.log.info_with({ hub_logs = true }, string.format("AOYAN: dp %d acknowledged", dp))
  end
end

local function on_message(driver, device, zb_rx)
  if not is_aoyan(device) then
    return
  end

  local cluster = zb_rx.address_header.cluster.value
  if cluster == TUYA_CLUSTER then
    local cmd = zb_rx.body.zcl_header.cmd.value
    if cmd == TUYA_RESPONSE or cmd == TUYA_REPORT then
      clear_acknowledged_dp(device, zb_rx)
    end
  end
  send_pending_dps(device)

  if device:get_field(CONFIGURED) then
    return
  end

  -- A battery message only proves success if configuration was already sent;
  -- otherwise it is just a probe response, meaning "awake now" -> configure below.
  local last = device:get_field(LAST_ATTEMPT)
  if last ~= nil and cluster == zcl_clusters.PowerConfiguration.ID then
    device:set_field(CONFIGURED, true, { persist = true })
    device.log.info_with({ hub_logs = true }, "AOYAN: battery report received, configuration complete")
    return
  end

  local now = os.time()
  if last ~= nil and now - last < RETRY_INTERVAL_SEC then
    return
  end
  device:set_field(LAST_ATTEMPT, now)
  device.log.info_with({ hub_logs = true }, "AOYAN: device is awake, sending configuration")
  device_management.configure(driver, device)
end

-- Queue a Tuya setting until the device wakes up (see send_pending_dps).
-- Keys are strings ("9"): the hub's persistent store rejects sparse integer-keyed tables.
local function queue_dp(device, dp, value)
  local next_pending = {}
  for k, v in pairs(device:get_field(PENDING_DPS) or {}) do next_pending[k] = v end
  next_pending[tostring(dp)] = value
  device:set_field(PENDING_DPS, next_pending, { persist = true })
  device:set_field(LAST_DP_SEND, nil)
  device:set_field(DP_ATTEMPTS, nil)
  device.log.info_with({ hub_logs = true }, string.format("AOYAN: dp %d = %d queued until the device wakes up", dp, value))
end

-- App command: stse.sensitivityAdjustment.setSensitivityAdjustment("High"|"Medium"|"Low")
local function set_sensitivity(driver, device, command)
  local level = command.args.sensitivity
  local value = SENSITIVITY_VALUES[level]
  if value == nil then
    return
  end
  -- Update the UI first so the app spinner always resolves.
  device:emit_event(capabilities[SENSITIVITY_CAP_ID].sensitivityAdjustment[level]())
  queue_dp(device, SENSITIVITY_DP, value)
end

-- App command: earthpepper23300.motionKeepTime.setKeepTime("10"|"30"|"60"|"120")
local function set_keep_time(driver, device, command)
  local seconds = command.args.value
  local value = KEEP_TIME_VALUES[seconds]
  if value == nil then
    return
  end
  device:emit_event(capabilities[KEEP_TIME_CAP_ID].keepTime(seconds))
  queue_dp(device, KEEP_TIME_DP, value)
end

-- Give every UI attribute a value so the app stops showing
-- "this device hasn't updated all of its status information yet".
-- The device never reports these settings, so the defaults are what it was last set to.
local function fill_missing_states(device)
  -- The auto-clear timer (motion_timeout) does not survive a driver restart,
  -- so a leftover "active" would otherwise stay until the next motion.
  if device:get_latest_state("main", capabilities.motionSensor.ID, "motion") == "active" then
    device:emit_event(capabilities.motionSensor.motion.inactive())
  end
  if device:supports_capability_by_id(capabilities.tamperAlert.ID)
      and device:get_latest_state("main", capabilities.tamperAlert.ID, "tamper") == nil then
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end
  if device:supports_capability_by_id(SENSITIVITY_CAP_ID)
      and device:get_latest_state("main", SENSITIVITY_CAP_ID, "sensitivityAdjustment") == nil then
    device:emit_event(capabilities[SENSITIVITY_CAP_ID].sensitivityAdjustment[DEFAULT_SENSITIVITY]())
  end
  if device:supports_capability_by_id(KEEP_TIME_CAP_ID)
      and device:get_latest_state("main", KEEP_TIME_CAP_ID, "keepTime") == nil then
    device:emit_event(capabilities[KEEP_TIME_CAP_ID].keepTime(DEFAULT_KEEP_TIME))
  end
end

local capability_handlers = {
  [SENSITIVITY_CAP_ID] = { setSensitivityAdjustment = set_sensitivity },
  [KEEP_TIME_CAP_ID] = { setKeepTime = set_keep_time },
}

-- Poke the device with a tiny battery read until it answers. Hubs/parents hold messages
-- for a sleepy device ~7s, so a 5s interval catches any wake-up poll. The answer runs
-- through on_message, which then sends the full configuration.
-- ponytail: gives up after PROBE_DURATION_SEC; if the device polls less often, wake it by hand.
local PROBE_INTERVAL_SEC = 5
local PROBE_DURATION_SEC = 30 * 60

local function start_probe(device)
  local started = os.time()
  local timer
  timer = device.thread:call_on_schedule(PROBE_INTERVAL_SEC, function()
    if device:get_field(CONFIGURED) or os.time() - started > PROBE_DURATION_SEC then
      device.thread:cancel_timer(timer)
      return
    end
    device:send(zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
  end, "aoyan_probe")
  device.log.info_with({ hub_logs = true }, "AOYAN: probing sleepy device for up to 30 minutes")
end

-- Wrap the driver's dispatcher so every incoming Zigbee message passes through on_message first.
local function install(driver)
  local dispatcher = driver.zigbee_message_dispatcher
  local original_dispatch = dispatcher.dispatch
  dispatcher.dispatch = function(self, drv, device, zb_rx, ...)
    on_message(drv, device, zb_rx)
    return original_dispatch(self, drv, device, zb_rx, ...)
  end

  driver:call_with_delay(1, function()
    for _, device in ipairs(driver:get_devices()) do
      if is_aoyan(device) then
        -- Devices joined before the aoyan-motion profile existed keep the old one, and
        -- devices switched from another driver are left NONFUNCTIONAL by the default handler.
        device:try_update_metadata({ profile = PROFILE, provisioning_state = "PROVISIONED" })
        if not device:get_field(CONFIGURED) then
          start_probe(device)
        end
        -- wait for a possible profile change to land before emitting into new capabilities
        device.thread:call_with_delay(PROFILE_SETTLE_SEC, function() fill_missing_states(device) end)
      end
    end
  end)
end

-- driverSwitched: the default handler only compares capabilities and marks the device
-- NONFUNCTIONAL; it never configures. Apply our profile and configure on next wake instead.
local function driver_switched(driver, device)
  if not is_aoyan(device) then
    return Driver.default_capability_match_driverSwitched_handler(driver, device)
  end
  device:try_update_metadata({ profile = PROFILE, provisioning_state = "PROVISIONED" })
  device:set_field(CONFIGURED, nil, { persist = true })
  device:set_field(LAST_ATTEMPT, nil)
  start_probe(device)
  device.thread:call_with_delay(PROFILE_SETTLE_SEC, function() fill_missing_states(device) end)
end

return { install = install, driver_switched = driver_switched, capability_handlers = capability_handlers }
