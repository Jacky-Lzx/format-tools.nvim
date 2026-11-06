local M = {}
local method = "textDocument/formatting"

function M.select(ctx, opts)
  local clients = vim.lsp.get_clients({ bufnr = ctx.bufnr, method = method, id = opts.id, name = opts.name })
  clients = vim.tbl_filter(function(client)
    return (not opts.id or client.id == opts.id)
      and (not opts.name or client.name == opts.name)
      and (not opts.filter or opts.filter(client))
  end, clients)
  if #clients > 1 then
    error("Multiple LSP formatters match; select one with id, name or filter")
  end
  return clients[1]
end

function M.start(item, ctx, opts, config, done)
  local client, cancelled, request_id, delivered = item.client, false, nil, false
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(ctx.bufnr) },
    options = vim.tbl_extend(
      "force",
      { tabSize = ctx.shiftwidth, insertSpaces = ctx.expandtab },
      opts.formatting_options or {}
    ),
  }
  local ok, sent, id = pcall(client.request, client, method, params, function(err, edits)
    vim.schedule(function()
      if cancelled or delivered then
        return
      end
      delivered = true
      if err then
        done(type(err) == "table" and (err.message or vim.inspect(err)) or tostring(err))
        return
      end
      local scratch
      local valid, output = pcall(function()
        assert(edits == nil or (type(edits) == "table" and vim.islist(edits)), "Invalid LSP text edits")
        local size = 0
        for _, edit in ipairs(edits or {}) do
          assert(type(edit.newText) == "string", "Invalid LSP edit text")
          size = size + #edit.newText
          assert(size <= config.max_output, "LSP output exceeds max_output")
        end
        scratch = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(scratch, 0, -1, false, ctx.lines)
        vim.lsp.util.apply_text_edits(edits or {}, scratch, client.offset_encoding or "utf-16")
        return table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n") .. "\n"
      end)
      if scratch and vim.api.nvim_buf_is_valid(scratch) then
        vim.api.nvim_buf_delete(scratch, { force = true })
      end
      if valid then
        done(nil, output)
      else
        done(tostring(output))
      end
    end)
  end, ctx.bufnr)
  if not ok or not sent then
    vim.schedule(function()
      if not cancelled then
        done(not ok and tostring(sent) or "LSP request was rejected")
      end
    end)
  else
    request_id = id
  end
  return function()
    cancelled = true
    if request_id then
      pcall(client.cancel_request, client, request_id)
    end
  end
end

return M
