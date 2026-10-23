-- NEO NAS-PD07W10 phantom motion filter.
--
-- The device firmware (2.1.1) re-reports occupancy=1 exactly 118 minutes (7080s, +-1s)
-- after a previous occupancy=1, chaining every 118 minutes while the room is empty.
-- An "active" that lands on k * 7080s (+-TOLERANCE) after any recent active is dropped.
-- Verified against 4 days of history: all known phantoms caught, remaining drops
-- fell inside real activity where the light was already on.

local PERIOD_SEC = 7080
local TOLERANCE_SEC = 3
local MAX_MULTIPLE = 12 -- covers chains with missing links, ~24h back
local HISTORY_SEC = PERIOD_SEC * MAX_MULTIPLE + TOLERANCE_SEC

local M = {}

-- history: array of epoch seconds of previous active reports (oldest first)
function M.is_phantom(history, now)
  for _, t in ipairs(history) do
    local elapsed = now - t
    local k = math.floor(elapsed / PERIOD_SEC + 0.5)
    if k >= 1 and k <= MAX_MULTIPLE and math.abs(elapsed - k * PERIOD_SEC) <= TOLERANCE_SEC then
      return true
    end
  end
  return false
end

-- Returns a new history with `now` appended and entries older than HISTORY_SEC dropped.
-- Phantoms are recorded too, so the chain keeps being recognized.
function M.record(history, now)
  local next_history = {}
  for _, t in ipairs(history) do
    if now - t <= HISTORY_SEC then
      table.insert(next_history, t)
    end
  end
  table.insert(next_history, now)
  return next_history
end

return M
