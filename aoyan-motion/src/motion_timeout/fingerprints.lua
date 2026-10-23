-- Copyright 2025 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local ZIGBEE_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "ORVIBO", model = "895a2d80097f4ae2b2d40500d5e03dcc", timeout = 20 },
  { mfr = "Megaman", model = "PS601/z1", timeout = 20 },
  { mfr = "HEIMAN", model = "PIRSensor-N", timeout = 20 },
  -- AY-204Z sends its own "clear" zone status once nobody is there, so no timeout:
  -- an early auto-clear hides motion while the device still holds "occupied" and stays silent.
  -- Manufacturer is reported with trailing spaces.
  { mfr = "AOYAN", model = "AY-204Z" },
  { mfr = "AOYAN ", model = "AY-204Z" },
  { mfr = "AOYAN  ", model = "AY-204Z" }
}

return ZIGBEE_MOTION_SENSOR_FINGERPRINTS
