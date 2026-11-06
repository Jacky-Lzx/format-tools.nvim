local M = {}
local engine
local function current()
  assert(engine, "Call require('format_tools').setup() first")
  return engine
end
local function buffer(buf)
  return (not buf or buf == 0) and vim.api.nvim_get_current_buf() or buf
end

function M.setup(opts)
  local config = require("format_tools.config").normalize(opts)
  if engine then
    engine:cancel(nil, "setup replaced")
  end
  engine = require("format_tools.engine").new(config)
end

function M.format(opts, callback)
  opts = opts or {}
  return current():run(buffer(opts.bufnr), opts, callback)
end

function M.cancel(buf)
  current():cancel(buffer(buf))
end
function M.status(buf)
  local job = current().states[buffer(buf)]
  if not job then
    return nil
  end
  return {
    status = job.status,
    error = job.error,
    did_edit = job.did_edit,
    duration_ms = job.duration_ms,
    current = job.current,
  }
end
function M.config()
  return vim.deepcopy(current().config)
end
function M.inspect(buf, opts)
  local ctx = require("format_tools.context").capture(buffer(buf), current().config)
  local plan = require("format_tools.plan").build(ctx, current().config, opts or {})
  local items = {}
  for _, item in ipairs(plan.candidates) do
    items[#items + 1] = {
      name = item.name,
      command = item.command,
      selected = item.selected or false,
      available = item.available,
      reason = item.reason,
    }
  end
  return { formatters = items, options = plan.opts, last = M.status(buf) }
end
function M.info(buf)
  local info = M.inspect(buf)
  vim.notify(vim.inspect(info), vim.log.levels.INFO, { title = "FormatToolsInfo" })
  return info
end

return M
