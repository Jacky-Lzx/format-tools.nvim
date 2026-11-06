local M = {}
M.defaults = {
  enabled = true,
  formatters_by_ft = {},
  formatters = {},
  default_format_opts = { timeout_ms = 1000, lsp_format = "never" },
  format_on_save = false,
  max_file_size = 4 * 1024 * 1024,
  max_output = 8 * 1024 * 1024,
}
local option_types = {
  timeout_ms = "number",
  lsp_format = "string",
  bufnr = "number",
  async = "boolean",
  quiet = "boolean",
  stop_after_first = "boolean",
  dry_run = "boolean",
  undojoin = "boolean",
  formatters = "table",
  id = "number",
  name = "string",
  filter = "function",
  formatting_options = "table",
}

function M.list(list)
  assert(type(list) == "table", "Formatter list must be a table")
  local count, last, options = 0, 0, {}
  for key, value in pairs(list) do
    if type(key) == "number" then
      assert(key >= 1 and key % 1 == 0, "Formatter indices must be positive integers")
      assert(type(value) == "string" and value:match("^[%w_-]+$"), "Invalid formatter name")
      count, last = count + 1, math.max(last, key)
    else
      options[key] = value
    end
  end
  assert(count == last, "Formatter list must have contiguous indices")
  return options
end

function M.options(opts)
  assert(type(opts) == "table", "format options must be a table")
  assert(not opts.range, "Range formatting is not supported yet")
  for key, value in pairs(opts) do
    assert(option_types[key], "Unknown format option: " .. tostring(key))
    assert(type(value) == option_types[key], "Invalid format option type: " .. key)
  end
  assert(
    type(opts.timeout_ms) == "number" and opts.timeout_ms > 0 and opts.timeout_ms % 1 == 0,
    "timeout_ms must be a positive integer"
  )
  assert(vim.list_contains({ "never", "fallback", "prefer" }, opts.lsp_format), "Invalid lsp_format")
  for _, key in ipairs({ "async", "quiet", "stop_after_first", "dry_run", "undojoin" }) do
    assert(opts[key] == nil or type(opts[key]) == "boolean", key .. " must be boolean")
  end
  if opts.formatters then
    assert(next(M.list(opts.formatters)) == nil, "Explicit formatters must be a name list")
  end
  return opts
end

function M.normalize(opts)
  local result = vim.deepcopy(M.defaults)
  for key, value in pairs(opts or {}) do
    assert(M.defaults[key] ~= nil, "Unknown format-tools option: " .. key)
    result[key] = vim.deepcopy(value)
  end
  assert(type(result.enabled) == "boolean", "enabled must be boolean")
  for _, key in ipairs({ "max_file_size", "max_output" }) do
    assert(
      type(result[key]) == "number" and result[key] > 0 and result[key] % 1 == 0,
      key .. " must be a positive integer"
    )
  end
  assert(type(result.formatters_by_ft) == "table", "formatters_by_ft must be a table")
  assert(type(result.formatters) == "table", "formatters must be a table")
  assert(
    result.format_on_save == false
      or type(result.format_on_save) == "table"
      or type(result.format_on_save) == "function",
    "Invalid format_on_save"
  )
  result.default_format_opts = vim.tbl_extend("force", M.defaults.default_format_opts, result.default_format_opts)
  M.options(result.default_format_opts)
  for ft, list in pairs(result.formatters_by_ft) do
    assert(
      type(ft) == "string" and (type(list) == "table" or type(list) == "function"),
      "Invalid filetype formatter list"
    )
    if type(list) == "table" then
      M.options(vim.tbl_extend("force", result.default_format_opts, M.list(list)))
    end
  end
  local types = {
    command = { "string", "function" },
    args = { "table", "function" },
    prepend_args = { "table", "function" },
    append_args = { "table", "function" },
    cwd = { "string", "function" },
    env = { "table", "function" },
    stdin = { "boolean" },
    exit_codes = { "table" },
    condition = { "function" },
    transform = { "function" },
  }
  for name, def in pairs(result.formatters) do
    M.list({ name })
    assert(type(def) == "table", "Formatter definition must be a table")
    for key, value in pairs(def) do
      assert(types[key] and vim.list_contains(types[key], type(value)), "Invalid formatter field: " .. tostring(key))
    end
  end
  if type(result.format_on_save) == "table" then
    M.options(vim.tbl_extend("force", result.default_format_opts, result.format_on_save))
  end
  return result
end

return M
