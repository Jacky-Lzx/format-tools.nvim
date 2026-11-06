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
  assert(opts == nil or type(opts) == "table", "format-tools.nvim: setup expects a table")
  opts = vim.deepcopy(opts or {})
  local config = require("format_tools.config").normalize(opts)
  if engine then
    engine:cancel(nil, "setup replaced")
  end
  engine = require("format_tools.engine").new(config)
  require("format_tools.autocmds").setup(M, engine)
end

function M.dispose()
  if engine then
    engine:cancel(nil, "disposed")
  end
  engine = nil
  pcall(vim.api.nvim_del_augroup_by_name, "FormatTools")
  for _, name in ipairs({
    "FormatToolsFormat",
    "FormatToolsCancel",
    "FormatToolsInfo",
    "FormatToolsEnable",
    "FormatToolsDisable",
  }) do
    require("format_tools.user_command").delete(name)
  end
end

function M.format(opts, callback)
  opts = opts or {}
  return current():run(buffer(opts.bufnr), opts, callback)
end

function M.cancel(buf)
  if engine then
    engine:cancel(buffer(buf))
  end
end
function M.enable(buf)
  if not engine then
    M.setup()
  end
  if buf then
    current().disabled[buffer(buf)] = nil
  else
    current().enabled = true
  end
end
function M.disable(buf)
  if not engine then
    return
  end
  if buf then
    buf = buffer(buf)
    current().disabled[buf] = true
  else
    current().enabled = false
  end
  current():cancel(buf, "autoformat disabled")
end
function M.is_enabled(buf)
  return engine ~= nil and engine.enabled and not engine.disabled[buffer(buf)]
end
function M.status(buf)
  if not engine then
    return nil
  end
  local job = current().states[buffer(buf)]
  if not job then
    return nil
  end
  local steps = {}
  for _, item in ipairs(job.plan and job.plan.items or {}) do
    steps[#steps + 1] = {
      name = item.name,
      argv = vim.deepcopy(item.argv),
      cwd = item.cwd,
      exit_code = item.exit_code,
      stderr = item.stderr,
    }
  end
  return {
    status = job.status,
    error = job.error,
    did_edit = job.did_edit,
    duration_ms = job.duration_ms,
    current = job.current,
    steps = steps,
  }
end
function M.config()
  return engine and vim.deepcopy(engine.config) or nil
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
  return {
    formatters = items,
    options = plan.opts,
    last = M.status(buf),
    enabled = M.is_enabled(buf),
    lsp = plan.client and { id = plan.client.id, name = plan.client.name } or nil,
  }
end
function M.info(buf)
  local ok, info = pcall(M.inspect, buf)
  if not ok then
    info = { error = tostring(info), last = M.status(buf) }
  end
  vim.notify(vim.inspect(info), vim.log.levels.INFO, { title = "FormatToolsInfo" })
  return info
end

return M
