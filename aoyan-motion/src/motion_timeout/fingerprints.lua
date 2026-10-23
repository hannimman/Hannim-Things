-- Copyright 2025 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local ZIGBEE_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "ORVIBO", model = "895a2d80097f4ae2b2d40500d5e03dcc", timeout = 20 },
  { mfr = "Megaman", model = "PS601/z1", timeout = 20 },
  { mfr = "HEIMAN", model = "PIRSensor-N", timeout = 20 },
  -- AY-204Z may not send a "clear" zone status; manufacturer is reported with trailing spaces
  { mfr = "AOYAN", model = "AY-204Z", timeout = 20 },
  { mfr = "AOYAN ", model = "AY-204Z", timeout = 20 },
  { mfr = "AOYAN  ", model = "AY-204Z", timeout = 20 }
}

return ZIGBEE_MOTION_SENSOR_FINGERPRINTS
