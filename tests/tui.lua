local F = require("format_tools")
local directory = assert(vim.env.FORMAT_TUI_DIR)
local filename = directory .. "/sample.lua"
local original = { "local value={a=1}", "return value" }
local formatted = { "local value = { a = 1 }", "return value" }
vim.o.swapfile, vim.o.shadafile, vim.o.laststatus = false, "NONE", 0
vim.o.showmode = true
vim.g.mapleader = " "
F.setup({ formatters_by_ft = { lua = { "stylua" } }, format_on_save = { timeout_ms = 500 } })
vim.keymap.set("n", "<leader>gf", function()
  F.format()
end)
vim.keymap.set("n", "<leader>tf", function()
  if F.is_enabled() then
    F.disable()
  else
    F.enable()
  end
end)
vim.fn.writefile(original, filename)
vim.cmd.edit(filename)
vim.bo.filetype = "lua"
vim.api.nvim_win_set_cursor(0, { 2, 7 })
local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
local function frame()
  vim.cmd.redraw()
  local rows = {}
  for row = 1, vim.o.lines do
    local cells = {}
    for col = 1, vim.o.columns do
      cells[#cells + 1] = vim.fn.screenstring(row, col)
    end
    rows[#rows + 1] = table.concat(cells)
  end
  return table.concat(rows, "\n")
end
local function capture(name)
  vim.fn.writefile(vim.split(frame(), "\n"), directory .. "/" .. name)
end
local function stage(name)
  vim.fn.writefile({ name }, directory .. "/stage")
end
local function lines()
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end
local steps = {}
steps[1] = function()
  if not frame():find(original[1], 1, true) then
    return
  end
  capture("original-frame")
  stage("optout_save")
  return true
end
steps[2] = function()
  if F.is_enabled() or vim.bo.modified then
    return
  end
  assert(vim.deep_equal(vim.fn.readfile(filename), original))
  capture("disabled-frame")
  stage("enable_save")
  return true
end
steps[3] = function()
  if not vim.deep_equal(lines(), formatted) or vim.bo.modified then
    return
  end
  assert(vim.deep_equal(vim.fn.readfile(filename), formatted))
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(win), { 2, 7 }))
  if not frame():find(formatted[1], 1, true) then
    return
  end
  capture("formatted-frame")
  stage("undo")
  return true
end
steps[4] = function()
  if not vim.deep_equal(lines(), original) then
    return
  end
  assert(vim.deep_equal(vim.fn.readfile(filename), formatted))
  capture("undo-frame")
  stage("manual")
  return true
end
steps[5] = function()
  if not vim.deep_equal(lines(), formatted) then
    return
  end
  capture("manual-frame")
  stage("burst")
  return true
end
steps[6] = function()
  local expected = { "local value = { a = 2 }", "return value" }
  if not vim.deep_equal(lines(), expected) or vim.bo.modified then
    return
  end
  if vim.api.nvim_get_mode().mode ~= "n" then
    return
  end
  assert(vim.deep_equal(vim.fn.readfile(filename), expected))
  assert(vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_current_win() == win)
  if not frame():find(expected[1], 1, true) then
    return
  end
  capture("burst-frame")
  return true
end
local index, started = 1, vim.uv.hrtime()
local function poll()
  local ok, complete = pcall(steps[index])
  if not ok or (vim.uv.hrtime() - started) / 1e9 > 10 then
    vim.fn.writefile({ "stage " .. index .. ": " .. tostring(complete), frame() }, directory .. "/failure")
    vim.cmd("cquit 1")
    return
  end
  if complete then
    index, started = index + 1, vim.uv.hrtime()
  end
  if index > #steps then
    vim.fn.writefile(
      { "PTY: rendered opt-out, save, undo, manual format, burst saves, cursor, focus and mode passed" },
      directory .. "/result"
    )
    vim.cmd("qa!")
    return
  end
  vim.defer_fn(poll, 10)
end
vim.defer_fn(poll, 10)
