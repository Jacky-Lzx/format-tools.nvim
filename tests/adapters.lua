local F = require("format_tools")
local util = require("format_tools.util")
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/src", "p")
local checks = 0
local function eq(a, b)
  checks = checks + 1
  assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b))
end
local ctx = { dirname = root .. "/src", filename = root .. "/src/main.rs", expandtab = true, shiftwidth = 4 }
vim.fn.writefile({ "[package]", 'edition = "2024"' }, root .. "/Cargo.toml")
eq(util.rust_edition(ctx), "2024")
vim.fn.writefile({ "[workspace.package]", 'edition = "2021"' }, root .. "/Cargo.toml")
vim.fn.writefile({ "[package]", "edition.workspace = true" }, root .. "/src/Cargo.toml")
eq(util.rust_edition(ctx), "2021")
vim.fn.writefile({ "[package]", 'name = "old"', "[dependencies]", 'edition = "2024"' }, root .. "/src/Cargo.toml")
eq(util.rust_edition(ctx), "2015")
local modules = vim.api.nvim_get_runtime_file("lua/format_tools/formatters/*.lua", true)
for _, path in ipairs(modules) do
  local name = vim.fs.basename(path):gsub("%.lua$", "")
  local def = require("format_tools.formatters." .. name)
  if def.transform then
    assert(type(def.transform(ctx, "x \n")) == "string")
  else
    local command = type(def.command) == "function" and def.command(ctx) or def.command
    assert(type(command) == "string" and command ~= "", name)
    local args = type(def.args) == "function" and def.args(ctx) or def.args or {}
    for _, arg in ipairs(args) do
      assert(type(arg) == "string", name)
    end
  end
  checks = checks + 1
end
assert(#modules == 22, "missing formatter adapters: " .. #modules)

-- The nearest project-local executable wins without depending on PATH.
vim.fn.mkdir(root .. "/node_modules/.bin", "p")
local local_tool = root .. "/node_modules/.bin/prettier"
vim.fn.writefile({ "#!/bin/sh", "cat" }, local_tool)
assert(vim.uv.fs_chmod(local_tool, 493))
eq(util.executable("prettier", "node_modules/.bin")(ctx), local_tool)
vim.fn.mkdir(root .. "/.venv/bin", "p")
vim.fn.writefile({ "#!/bin/sh", "cat" }, root .. "/.venv/bin/ruff")
assert(vim.uv.fs_chmod(root .. "/.venv/bin/ruff", 493))
eq(util.executable("ruff", ".venv/bin")(ctx), root .. "/.venv/bin/ruff")

-- Save is synchronous, repeated setup has one owner, toggles affect only autosave.
vim.cmd("enew!")
local file = root .. "/save.txt"
vim.api.nvim_buf_set_name(0, file)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "spaces   " })
local opts = { formatters_by_ft = { _ = { "trim_whitespace" } }, format_on_save = { timeout_ms = 500 } }
F.setup(opts)
F.setup(opts)
eq(#vim.api.nvim_get_autocmds({ group = "FormatTools", event = "BufWritePre" }), 1)
F.disable()
vim.cmd.write()
eq(vim.fn.readfile(file), { "spaces   " })
F.enable()
F.disable(0)
vim.cmd.write()
eq(vim.fn.readfile(file), { "spaces   " })
F.enable(0)
vim.cmd.write()
eq(vim.fn.readfile(file), { "spaces" })
eq(vim.bo.modified, false)
vim.cmd.undo()
eq(vim.api.nvim_get_current_line(), "spaces   ")
F.disable()
F.format()
eq(vim.api.nvim_get_current_line(), "spaces")
eq(vim.fn.exists(":FormatToolsInfo"), 2)
local invalid = true
F.setup({
  formatters_by_ft = { _ = { "trim_whitespace" } },
  format_on_save = function()
    return invalid and true or { timeout_ms = 500 }
  end,
})
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "again   " })
local notify = vim.notify
vim.notify = function() end
vim.cmd("silent write")
invalid = false
vim.cmd("silent write")
vim.notify = notify
eq(vim.fn.readfile(file), { "again" }, "invalid autosave options do not wedge subsequent saves")
vim.fn.delete(root, "rf")
print("Adapter and save checks passed: " .. checks)
