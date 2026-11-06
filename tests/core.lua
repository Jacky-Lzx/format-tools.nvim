local F = require("format_tools")
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local checks = 0
local function eq(a, b, label)
  checks = checks + 1
  assert(vim.deep_equal(a, b), (label or "mismatch") .. ": " .. vim.inspect(a) .. " ~= " .. vim.inspect(b))
end
local function wait(fn)
  assert(vim.wait(3000, fn, 2), "condition timed out")
end
local function set(lines, opts)
  vim.cmd("enew!")
  vim.bo.filetype = "fixture"
  vim.bo.expandtab, vim.bo.shiftwidth = true, 2
  vim.api.nvim_buf_set_name(0, directory .. "/fixture " .. checks .. ".txt")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  local config = {
    formatters_by_ft = { fixture = { "test" } },
    formatters = {
      test = {
        transform = function(_, text)
          return (text:gsub("bad", "good"))
        end,
      },
    },
    default_format_opts = { quiet = true },
  }
  F.setup(vim.tbl_extend("force", config, opts or {}))
  return vim.api.nvim_get_current_buf()
end
local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
local function definition(mode, extra)
  return { command = "python3", args = vim.list_extend({ vim.fn.getcwd() .. "/tests/process.py", mode }, extra or {}) }
end
local function process(mode, extra)
  return { formatters = { test = definition(mode, extra) } }
end

-- Minimal changes preserve unrelated extmarks, folds, multiple windows and UTF-8.
local buf = set({ "bad 中文", "keep this", "bad end", "tail" })
local ns = vim.api.nvim_create_namespace("fixture")
local mark = vim.api.nvim_buf_set_extmark(buf, ns, 1, 2, {})
vim.api.nvim_win_set_cursor(0, { 2, 2 })
vim.cmd("vsplit")
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(win, { 4, 1 })
local job = F.format()
eq(job.status, "done")
eq(lines(), { "good 中文", "keep this", "good end", "tail" })
eq(vim.api.nvim_buf_get_extmark_by_id(buf, ns, mark, {}), { 1, 2 })
eq(vim.api.nvim_win_get_cursor(win), { 4, 1 })
local undo = vim.fn.undotree().seq_cur
eq(F.format().did_edit, false)
eq(vim.fn.undotree().seq_cur, undo, "no-op undo")
vim.cmd.undo()
eq(lines(), { "bad 中文", "keep this", "bad end", "tail" }, "whole format undoes once")
vim.cmd.redo()
eq(lines()[1], "good 中文")
vim.cmd.only()
local chinese_options = {
  formatters = {
    test = {
      transform = function(_, text)
        return (text:gsub("中", "文"):gsub("bad", "good"))
      end,
    },
  },
}
set({ "中abc", "bad" }, chinese_options)
F.format()
eq(lines(), { "文abc", "good" })

-- Insertion/deletion hunks, empty output and EOL policy.
for _, pair in ipairs({
  { { "a", "b" }, { "x", "a", "b" } },
  { { "a", "b" }, { "a", "b", "x" } },
  { { "a", "b", "c" }, { "b", "c" } },
  { { "a", "b", "c" }, { "a", "b" } },
  { { "a", "b", "c" }, { "a", "c" } },
  { { "a" }, { "" } },
  { { "" }, { "a", "b" } },
}) do
  local function render()
    return table.concat(pair[2], "\n") .. "\n"
  end
  local hunk_options = { formatters = { test = { transform = render } } }
  set(pair[1], hunk_options)
  F.format()
  eq(lines(), pair[2], "hunk")
  vim.cmd.undo()
  eq(lines(), pair[1], "hunk undo")
end
set({ "bad", "" })
vim.bo.endofline, vim.bo.fixendofline, vim.bo.fileformat = false, false, "dos"
F.format()
eq(lines(), { "good", "" })
eq(vim.bo.endofline, false)
eq(vim.bo.fileformat, "dos")

-- An entire chain commits once, and a later error does not apply earlier output.
set({ "bad" }, {
  formatters_by_ft = { fixture = { "first", "second" } },
  formatters = {
    first = {
      transform = function(_, text)
        return text:upper()
      end,
    },
    second = {
      transform = function(_, text)
        eq(text, "BAD\n")
        return "done\n"
      end,
    },
  },
})
F.format()
eq(lines(), { "done" })
vim.cmd.undo()
eq(lines(), { "bad" })
set({ "bad" }, {
  formatters_by_ft = { fixture = { "first", "second" } },
  formatters = {
    first = {
      transform = function(_, text)
        return text:upper()
      end,
    },
    second = definition("fail"),
  },
})
job = F.format()
eq(job.status, "error")
eq(lines(), { "bad" }, "failed transaction")

-- Availability selection and shell-free argv expansion.
set({ "bad" }, {
  formatters_by_ft = { fixture = { "absent", "test", "later", stop_after_first = true } },
  formatters = {
    absent = { command = "format-tools-nonexistent" },
    test = definition("upper"),
    later = definition("fail"),
  },
})
eq(F.inspect().formatters[3].selected, false)
eq(F.format().status, "done")
eq(lines(), { "BAD" })
set({ "bad" }, process("argv", { "$FILENAME" }))
F.format()
eq(lines(), { vim.api.nvim_buf_get_name(0) })
set({ "bad" }, process("empty"))
F.format()
eq(lines(), { "" }, "empty stdout is valid formatting")

-- In-place tools touch only their private copy, even with a filename with spaces.
buf = set({ "bad" }, process("inplace", { "$FILENAME" }))
local config = F.config()
config.formatters.test.stdin = false
F.setup(config)
local name = vim.api.nvim_buf_get_name(buf)
vim.fn.writefile({ "disk original" }, name)
eq(F.format().status, "done")
eq(lines(), { "BAD" })
eq(vim.fn.readfile(name), { "disk original" })
eq(vim.fn.glob(directory .. "/.format-tools-*", false, true), {}, "temporary cleanup")

-- One deadline covers all stages; bounded output cannot partially edit a buffer.
set({ "bad" }, {
  formatters_by_ft = { fixture = { "a", "b" } },
  formatters = {
    a = definition("delay", { "0.09" }),
    b = definition("delay", { "0.2" }),
  },
})
job = F.format({ timeout_ms = 220 })
eq(job.status, "error")
assert(job.duration_ms < 400)
eq(lines(), { "bad" })
set({ "bad" }, vim.tbl_extend("force", process("flood"), { max_output = 1024 }))
job = F.format()
eq(job.status, "error")
assert(job.error:find("max_output", 1, true), job.error)
eq(lines(), { "bad" })

-- Synchronize asynchronous races with the child process, not an arbitrary sleep.
local function gated()
  local ready, release = directory .. "/ready", directory .. "/release"
  vim.fn.delete(ready)
  vim.fn.delete(release)
  buf = set({ "bad" }, process("gate", { ready, release }))
  local callbacks = 0
  local j = F.format({ async = true }, function()
    callbacks = callbacks + 1
  end)
  wait(function()
    return vim.uv.fs_stat(ready) ~= nil
  end)
  return j, function()
    vim.fn.writefile({}, release)
  end, function()
    return callbacks
  end
end
local release, count
job, release, count = gated()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "new edit" })
release()
wait(function()
  return job.finished
end)
eq(job.status, "stale")
eq(count(), 1)
eq(lines(), { "new edit" })
job, release, count = gated()
F.cancel()
release()
eq(job.status, "cancelled")
eq(count(), 1)
eq(lines(), { "bad" })
job, release, count = gated()
local replacement = F.format({ formatters = { "trim_whitespace" } })
release()
eq(job.status, "cancelled")
eq(replacement.status, "done")
eq(count(), 1)
job, release, count = gated()
F.setup({})
release()
eq(job.status, "cancelled")
eq(count(), 1)
job, release = gated()
vim.api.nvim_buf_set_name(buf, directory .. "/renamed.txt")
release()
wait(function()
  return job.finished
end)
eq(job.status, "stale")
job, release = gated()
vim.api.nvim_buf_delete(buf, { force = true })
release()
wait(function()
  return job.finished
end)
eq(job.status, "cancelled")
set({ "bad" })
eq(F.format({ dry_run = true }).output, "good\n")
eq(lines(), { "bad" })
eq(F.format({ range = {} }).status, "error")
eq(lines(), { "bad" })
local defaults = process("upper")
defaults.formatters.test.cwd = function()
  return nil
end
defaults.formatters.test.env = function()
  return nil
end
set({ "bad" }, defaults)
eq(F.format().status, "done", "nil dynamic cwd/env use defaults")
eq(lines(), { "BAD" })
set({ "bad" }, process("argv", { "$FILENAME" }))
vim.api.nvim_buf_set_name(0, directory .. "/literal-$DIRNAME.txt")
F.format()
eq(lines(), { vim.api.nvim_buf_get_name(0) }, "placeholder values are not recursively expanded")
-- Cancel an in-place process only after it has opened its isolated copy.
local ready, released = directory .. "/inplace-ready", directory .. "/inplace-release"
set({ "bad" }, process("inplace_gate", { "$FILENAME", ready, released }))
local isolated_config = F.config()
isolated_config.formatters.test.stdin = false
F.setup(isolated_config)
job = F.format({ async = true })
wait(function()
  return vim.uv.fs_stat(ready) ~= nil
end)
local private_file = vim.fn.readfile(ready)[1]
assert(private_file ~= vim.api.nvim_buf_get_name(0))
F.cancel()
wait(function()
  return not vim.uv.fs_stat(vim.fs.dirname(private_file))
end)
eq(job.status, "cancelled")
eq(lines(), { "bad" })

-- Reproducible mixed UTF-8 insert/delete/replace cases exercise diff coordinates.
math.randomseed(271828)
local alphabet = { "a", "中", "文", "😀", "", "xx" }
for _ = 1, 80 do
  local before, after = {}, {}
  for _ = 1, math.random(1, 8) do
    before[#before + 1] = alphabet[math.random(#alphabet)]
  end
  for _ = 1, math.random(1, 8) do
    after[#after + 1] = alphabet[math.random(#alphabet)]
  end
  local function render()
    return table.concat(after, "\n") .. "\n"
  end
  set(before, { formatters = { test = { transform = render } } })
  job = F.format()
  eq(job.status, "done")
  eq(lines(), after)
  if job.did_edit then
    vim.cmd("silent undo")
    eq(lines(), before)
  end
end
set({ "bad", "keep", "keep", "bad" })
vim.wo.foldmethod = "manual"
vim.cmd("2,3fold")
F.format()
eq(vim.fn.foldclosed(2), 2, "unrelated manual fold stays closed")
for _, invalid in ipairs({
  { formatters_by_ft = { fixture = { [2] = "trim_whitespace" } } },
  { default_format_opts = { timeout_ms = 0 } },
  { formatters = { broken = { args = "shell string" } } },
  { default_format_opts = { lsp_format = "first" } },
}) do
  eq(pcall(F.setup, invalid), false, "configuration validation")
end
vim.fn.delete(directory, "rf")
print("Core formatting checks passed: " .. checks)
