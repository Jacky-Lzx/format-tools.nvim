local M = {}

function M.check()
  vim.health.start("format-tools.nvim")
  if vim.fn.has("nvim-0.11") == 0 then
    vim.health.error("Neovim 0.11+ is required", { "Upgrade Neovim" })
    return
  end
  local issues = {}
  local function problem(level, message, advice)
    issues[#issues + 1] = { level = level, message = message, advice = advice }
  end
  local plugin = package.loaded.format_tools
  local config = plugin and plugin.config()
  if not config or not config.enabled then
    vim.health.info("Not configured; formatter checks skipped.")
    return
  end
  local seen, deferred = {}, false
  for _, list in pairs(config.formatters_by_ft) do
    if type(list) == "function" then
      deferred = true
    else
      for _, name in ipairs(list) do
        seen[name] = true
      end
    end
  end
  for name in pairs(seen) do
    local ok, builtin = pcall(require, "format_tools.formatters." .. name)
    local definition = vim.tbl_extend("force", ok and builtin or {}, config.formatters[name] or {})
    local cmd = definition.command
    if type(cmd) == "string" and not definition.condition then
      if vim.fn.executable(cmd) == 0 then
        problem(
          "warn",
          name .. ": executable unavailable: " .. cmd .. "; formatting may be unavailable.",
          { "Install/configure the formatter; inspect :FormatToolsInfo in its source buffer" }
        )
      end
    elseif type(cmd) == "function" or definition.condition then
      deferred = true
    elseif not definition.transform then
      problem(
        "warn",
        name .. ": formatter definition unavailable; formatting cannot run.",
        { "Configure a command or transform; inspect :FormatToolsInfo" }
      )
    end
  end
  if deferred and #issues == 0 then
    vim.health.info(
      "Static formatter checks passed; project-dependent commands require a source buffer. Details: :FormatToolsInfo"
    )
    return
  end

  table.sort(issues, function(a, b)
    if a.level ~= b.level then
      return a.level == "error"
    end
    return a.message < b.message
  end)
  for _, issue in ipairs(issues) do
    vim.health[issue.level](issue.message, issue.advice)
  end
  if #issues == 0 then
    vim.health.ok("Configured static formatter commands are available.")
  end
  vim.health.info("Details: :FormatToolsInfo")
end

return M
