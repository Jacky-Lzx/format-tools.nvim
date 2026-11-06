local F = require("format_tools")
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.api.nvim_buf_set_name(0, root .. "/session.fixture")
vim.bo.filetype = "fixture"
local original = { "中😀bad", "keep" }
vim.api.nvim_buf_set_lines(0, 0, -1, false, original)
local id = assert(vim.lsp.start({
  name = "format-tools-fixture",
  cmd = { "python3", vim.fn.getcwd() .. "/tests/lsp_server.py" },
  root_dir = root,
  flags = { debounce_text_changes = 0 },
}))
local client = assert(vim.lsp.get_client_by_id(id))
assert(
  vim.wait(3000, function()
    return client.initialized
  end, 1),
  "LSP initialize timed out"
)
assert(client.offset_encoding == "utf-16")
F.setup({ default_format_opts = { lsp_format = "fallback" } })
assert(F.inspect().lsp.id == id)
local job = F.format()
assert(job.status == "done", tostring(job.error))
assert(vim.api.nvim_get_current_line() == "中😀good")
vim.cmd("silent undo")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), original))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "next bad edit", "keep" })
job = F.format()
assert(job.status == "done", tostring(job.error))
assert(vim.api.nvim_get_current_line() == "next good edit", "LSP didChange was not flushed before formatting")
client:stop(true)
assert(vim.wait(3000, function()
  return vim.lsp.get_client_by_id(id) == nil
end, 1))
vim.fn.delete(root, "rf")
print("Real LSP session passed: initialize, UTF-16, fallback, full-file edits, undo and didChange synchronization")
