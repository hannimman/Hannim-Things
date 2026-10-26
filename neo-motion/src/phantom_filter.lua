-- NEO NAS-PD07W10 phantom motion filter.
--
-- The device firmware (2.1.1) has a free-running 118-minute clock (7080s, drifting ~+1s
-- every few cycles). Once started by an "active", it re-reports occupancy=1 on every tick,
-- even while real motion happens in between; real motion does not reset it.
--
-- So only one clock is tracked:
--   * chain start: an "active" exactly 7080s (+-TOLERANCE) after the previous "active"
--   * chain tick: an "active" on k * 7080s (+-TOLERANCE, k <= 12) after the last phantom
-- Checked against a week of history: all 25 chain phantoms caught, and 7 real reports that
-- the earlier all-history filter dropped now pass. Blocked time went from 3-6% to <0.1% a day.

local PERIOD_SEC = 7080
local TOLERANCE_SEC = 3
local MAX_MULTIPLE = 12 -- missing ticks happen; ~24h back

local M = {}

local function on_tick(elapsed)
  local k = math.floor(elapsed / PERIOD_SEC + 0.5)
  return k >= 1 and k <= MAX_MULTIPLE and math.abs(elapsed - k * PERIOD_SEC) <= TOLERANCE_SEC
end

-- state: { last_active = epoch seconds or nil, chain = epoch of last phantom or nil }
-- Returns is_phantom and the next state (input is not modified).
function M.check(state, now)
  local is_phantom = (state.chain ~= nil and on_tick(now - state.chain))
    or (state.last_active ~= nil and math.abs(now - state.last_active - PERIOD_SEC) <= TOLERANCE_SEC)
  return is_phantom, { last_active = now, chain = is_phantom and now or state.chain }
end

return M
