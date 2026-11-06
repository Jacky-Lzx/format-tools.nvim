local M = {}
function M.check()
  vim.health.start("format-tools")
  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim 0.11+")
  else
    vim.health.error("Requires Neovim 0.11+")
  end
  local ok, config = pcall(require("format_tools").config)
  if not ok then
    vim.health.warn("setup() has not run")
    return
  end
  local seen = {}
  for ft, list in pairs(config.formatters_by_ft) do
    if type(list) == "function" then
      vim.health.info(ft .. ": dynamic formatter list (inspect in its buffer)")
    else
      for _, name in ipairs(list) do
        if not seen[name] then
          seen[name] = true
          -- :checkhealth itself uses a nofile buffer. Availability probes need
          -- a context, but must not require a modifiable source buffer.
          local ctx = {
            bufnr = vim.api.nvim_get_current_buf(),
            dirname = vim.fn.getcwd(),
            filename = vim.fn.getcwd() .. "/untitled",
            filetype = "",
            expandtab = true,
            shiftwidth = 2,
          }
          local valid, plan =
            pcall(require("format_tools.plan").build, ctx, config, { formatters = { name }, lsp_format = "never" })
          local item = valid and plan.candidates[1]
          if item and item.available then
            vim.health.ok(name .. ": " .. (item.command or "Lua transform"))
          else
            vim.health.warn(name .. ": " .. (item and item.reason or tostring(plan)))
          end
        end
      end
    end
  end
end
return M
