local M = {}
local function definition(name, opts)
  assert(type(name) == "string" and name:match("^[%w_-]+$"), "Invalid formatter name")
  local path = "format_tools.formatters." .. name
  local base = {}
  if package.searchpath(path, package.path) then
    base = require(path)
  else
    local files = vim.api.nvim_get_runtime_file("lua/format_tools/formatters/" .. name .. ".lua", false)
    if #files > 0 then
      base = require(path)
    end
  end
  local override = opts.formatters[name] or {}
  assert(type(override) == "table", "Formatter definition must be a table: " .. name)
  return vim.tbl_deep_extend("force", {}, base, override)
end

function M.build(ctx, config, request)
  local list = request.formatters or config.formatters_by_ft[ctx.filetype] or config.formatters_by_ft._ or {}
  if type(list) == "function" then
    list = list(ctx.bufnr)
  end
  assert(type(list) == "table", "Formatter list must be a table")
  local opts = vim.tbl_extend("force", config.default_format_opts, list, request)
  require("format_tools.config").options(opts)
  local items, candidates, seen = {}, {}, {}
  local names = vim.deepcopy(list)
  if not request.formatters then
    local all = config.formatters_by_ft["*"] or {}
    if type(all) == "function" then
      all = all(ctx.bufnr)
    end
    for _, name in ipairs(all) do
      names[#names + 1] = name
    end
  end
  for _, name in ipairs(names) do
    if not seen[name] then
      seen[name] = true
      local def = definition(name, config)
      local item = { name = name, definition = def, available = false }
      if def.condition and not def.condition(ctx) then
        item.reason = "condition returned false"
      elseif def.transform then
        assert(type(def.transform) == "function", "transform must be a function")
        item.available = true
      else
        local command = type(def.command) == "function" and def.command(ctx) or def.command
        if type(command) == "string" and command ~= "" and vim.fn.executable(command) == 1 then
          item.available, item.command = true, vim.fn.exepath(command)
        else
          item.reason = command and ("executable not found: " .. tostring(command)) or "unknown formatter"
        end
      end
      if item.available and (not opts.stop_after_first or #items == 0) then
        item.selected = true
        items[#items + 1] = item
      elseif item.available then
        item.reason = "earlier candidate selected"
      end
      candidates[#candidates + 1] = item
    end
  end
  return { items = items, candidates = candidates, opts = opts }
end

return M
