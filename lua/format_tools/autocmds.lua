local M = {}

function M.setup(api, engine)
  local group = vim.api.nvim_create_augroup("FormatTools", { clear = true })
  local saving = {}
  if engine.config.format_on_save ~= false then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = group,
      callback = function(ev)
        if saving[ev.buf] or not engine.enabled or engine.disabled[ev.buf] then
          return
        end
        if vim.bo[ev.buf].buftype ~= "" or not vim.bo[ev.buf].modifiable then
          return
        end
        local opts = engine.config.format_on_save
        if type(opts) == "function" then
          local ok, value = pcall(opts, ev.buf)
          if not ok then
            vim.notify("format-tools: " .. tostring(value), vim.log.levels.WARN)
            return
          end
          opts = value
        end
        if not opts then
          return
        end
        saving[ev.buf] = true
        local ok, err = pcall(function()
          api.format(vim.tbl_extend("force", opts, { bufnr = ev.buf, async = false }))
        end)
        saving[ev.buf] = nil
        if not ok then
          vim.notify("format-tools: " .. tostring(err), vim.log.levels.WARN)
        end
      end,
    })
  end
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      engine:cancel(ev.buf, "buffer unloaded")
      engine.states[ev.buf], engine.disabled[ev.buf] = nil, nil
    end,
  })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    callback = function(ev)
      local job = engine.active[ev.buf]
      if job and job.plan and job.plan.client and ev.data and job.plan.client.id == ev.data.client_id then
        engine:cancel(ev.buf, "LSP detached")
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      engine:cancel(nil, "editor exit")
    end,
  })
  local commands = {
    FormatToolsFormat = function()
      api.format()
    end,
    FormatToolsCancel = function()
      api.cancel()
    end,
    FormatToolsInfo = function()
      api.info()
    end,
    FormatToolsEnable = function(args)
      api.enable(args.bang and 0 or nil)
    end,
    FormatToolsDisable = function(args)
      api.disable(args.bang and 0 or nil)
    end,
  }
  for name, callback in pairs(commands) do
    vim.api.nvim_create_user_command(name, callback, { bang = true, force = true, desc = name })
  end
end

return M
