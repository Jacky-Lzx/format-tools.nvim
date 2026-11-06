local F = require("format_tools")
local original = vim.lsp.get_clients
local checks, handler, params, cancelled, requests = 0, nil, nil, 0, 0
local client = { id = 12, name = "fixture", offset_encoding = "utf-16" }
function client:request(method, options, callback, buf)
  assert(method == "textDocument/formatting" and buf == vim.api.nvim_get_current_buf())
  handler, params, requests = callback, options, requests + 1
  return true, 101
end
function client:cancel_request(id)
  assert(id == 101)
  cancelled = cancelled + 1
end
local clients = { client }
vim.lsp.get_clients = function(opts)
  assert(opts.method == "textDocument/formatting")
  return clients
end
local function eq(a, b)
  checks = checks + 1
  assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b))
end
local function setup(opts)
  vim.cmd("enew!")
  vim.bo.filetype, vim.bo.shiftwidth, vim.bo.expandtab = "fixture", 2, true
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "中😀bad", "keep" })
  F.setup(vim.tbl_extend("force", { default_format_opts = { lsp_format = "fallback", quiet = true } }, opts or {}))
end
local function wait(job)
  assert(vim.wait(2000, function()
    return job.finished
  end, 1))
end
local function line()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
end
local function edit(text)
  return { { range = { start = { line = 0, character = 3 }, ["end"] = { line = 0, character = 6 } }, newText = text } }
end

setup()
eq(F.inspect().lsp, { id = 12, name = "fixture" })
local callbacks = 0
local job = F.format({ async = true }, function()
  callbacks = callbacks + 1
end)
eq(params.options, { tabSize = 2, insertSpaces = true })
eq(params.textDocument.uri, vim.uri_from_bufnr(0))
handler(nil, edit("good"))
wait(job)
eq(line(), "中😀good")
eq(callbacks, 1)
vim.cmd.undo()
eq(line(), "中😀bad")

-- Full-document replacement takes the same minimal-diff application path.
setup()
local ns = vim.api.nvim_create_namespace("lsp-test")
local mark = vim.api.nvim_buf_set_extmark(0, ns, 1, 2, {})
job = F.format({ async = true })
local full_document = {
  {
    range = { start = { line = 0, character = 0 }, ["end"] = { line = 2, character = 0 } },
    newText = "中😀good\nkeep\n",
  },
}
handler(nil, full_document)
wait(job)
eq(vim.api.nvim_buf_get_extmark_by_id(0, ns, mark, {}), { 1, 2 })
eq(line(), "中😀good")

setup()
job = F.format({ async = true })
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "new edit" })
handler(nil, edit("old result"))
wait(job)
eq(job.status, "stale")
eq(line(), "new edit")
setup()
job = F.format({ async = true, timeout_ms = 30 })
wait(job)
eq(job.status, "error")
eq(cancelled, 1)
handler(nil, edit("late result"))
vim.wait(10, function()
  return false
end, 1)
eq(line(), "中😀bad")

setup()
job = F.format({ async = true })
vim.api.nvim_exec_autocmds("LspDetach", { buffer = 0, data = { client_id = client.id } })
eq(job.status, "cancelled")
eq(cancelled, 2)
handler(nil, edit("late result"))

setup({ formatters_by_ft = { fixture = { "trim_whitespace" } } })
local before = requests
eq(F.format().status, "done")
eq(requests, before, "available external formatter prevents LSP fallback")
setup({
  formatters_by_ft = { fixture = { "failing" } },
  formatters = {
    failing = {
      transform = function()
        error("failure")
      end,
    },
  },
})
eq(F.format().status, "error")
eq(requests, before)
setup({ formatters_by_ft = { fixture = { "trim_whitespace" } } })
eq(F.inspect(0, { lsp_format = "prefer" }).formatters[1].selected, false)

setup()
clients = { client, { id = 13, name = "another" } }
eq(F.format().status, "error")
job = F.format({
  async = true,
  filter = function(c)
    return c.id == 12
  end,
})
handler(nil, nil)
wait(job)
eq(job.status, "done")
eq(job.did_edit, false)
clients = {}
eq(F.format().status, "skipped")
vim.lsp.get_clients = original
print("LSP formatting checks passed: " .. checks)
