-- Copyright 2022 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0


local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local IASZone = zcl_clusters.IASZone



-- AOYAN keep time selected in the app, in seconds ("10"|"30"|"60"|"120")
local KEEP_TIME_CAP_ID = "earthpepper23300.motionKeepTime"
local TIMEOUT_TIMER = "motion_timeout_timer"

local generate_event_from_zone_status = function(driver, device, zone_status, zigbee_message)
  local FINGERPRINTS = require("motion_timeout.fingerprints")
  device:emit_event(
      (zone_status:is_alarm1_set() or zone_status:is_alarm2_set()) and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
  if device:supports_capability_by_id(capabilities.tamperAlert.ID) then
    device:emit_event(zone_status:is_tamper_set() and capabilities.tamperAlert.tamper.detected() or capabilities.tamperAlert.tamper.clear())
  end
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      -- Never clear before the device's own keep time; restart the timer on every report
      -- so continuous motion is not cut off by an earlier timer.
      local keep = tonumber(device:get_latest_state("main", KEEP_TIME_CAP_ID, "keepTime") or "") or 0
      local timeout = math.max(fingerprint.timeout, keep)
      local previous = device:get_field(TIMEOUT_TIMER)
      if previous ~= nil then
        device.thread:cancel_timer(previous)
      end
      device:set_field(TIMEOUT_TIMER, device.thread:call_with_delay(timeout, function(d)
          device:set_field(TIMEOUT_TIMER, nil)
          device:emit_event(capabilities.motionSensor.motion.inactive())
        end))
      break
    end
  end
end

local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

local function ias_zone_status_change_handler(driver, device, zb_rx)
  generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

local motion_timeout_handler = {
  NAME = "Motion Timeout Handler",
  zigbee_handlers = {
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    }
  },
  can_handle = require("motion_timeout.can_handle"),
}

return motion_timeout_handler
