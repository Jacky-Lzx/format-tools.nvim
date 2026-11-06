local M = {}
local ns = vim.api.nvim_create_namespace("format-tools-views")

-- Boundaries must be UTF-8 boundaries: a shared leading byte is not a shared
-- character (for example two different Chinese characters).
local function prefix(a, b)
  local n = 0
  while n < math.min(#a, #b) and a:byte(n + 1) == b:byte(n + 1) do
    n = n + 1
  end
  while n > 0 and a:byte(n + 1) and a:byte(n + 1) >= 128 and a:byte(n + 1) < 192 do
    n = n - 1
  end
  return n
end

local function suffix(a, b, limit)
  local n = 0
  while n < limit and a:byte(#a - n) == b:byte(#b - n) do
    n = n + 1
  end
  while n > 0 and a:byte(#a - n + 1) >= 128 and a:byte(#a - n + 1) < 192 do
    n = n - 1
  end
  return n
end

function M.run(ctx, lines, undojoin)
  local buf = ctx.bufnr
  local hunks = vim.diff(table.concat(ctx.lines, "\n") .. "\n", table.concat(lines, "\n") .. "\n", {
    result_type = "indices",
    algorithm = "histogram",
  })
  if #hunks == 0 then
    return false
  end
  local views = {}
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(win, function()
      local view = vim.fn.winsaveview()
      views[#views + 1] = {
        win = win,
        view = view,
        cursor = vim.api.nvim_buf_set_extmark(buf, ns, view.lnum - 1, view.col, { right_gravity = false }),
        top = vim.api.nvim_buf_set_extmark(buf, ns, view.topline - 1, 0, { right_gravity = false }),
      }
    end)
  end
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    -- Reassigning undolevels synchronizes the previous undo block without
    -- clearing history. Joining the preceding edit is an explicit caller choice.
    if not undojoin then
      local undo = vim.bo[buf].undolevels
      vim.bo[buf].undolevels = undo
    end
    local first = true
    for i = #hunks, 1, -1 do
      local a, ac, b, bc = unpack(hunks[i])
      if not first or undojoin then
        vim.cmd("silent! undojoin")
      end
      first = false
      local replacement = {}
      for j = b, b + bc - 1 do
        replacement[#replacement + 1] = lines[j]
      end
      if ac > 0 and bc > 0 then
        local p = prefix(ctx.lines[a], replacement[1])
        local last_old, last_new = ctx.lines[a + ac - 1], replacement[#replacement]
        local limit = math.min(#last_old, #last_new)
        if ac == 1 then
          limit = math.min(limit, #last_old - p)
        end
        if bc == 1 then
          limit = math.min(limit, #last_new - p)
        end
        local s = suffix(last_old, last_new, limit)
        replacement[#replacement] = last_new:sub(1, #last_new - s)
        replacement[1] = replacement[1]:sub(p + 1)
        vim.api.nvim_buf_set_text(buf, a - 1, p, a + ac - 2, #last_old - s, replacement)
      else
        -- In an insertion hunk xdiff reports the preceding line (zero at BOF).
        local start = ac == 0 and a or a - 1
        vim.api.nvim_buf_set_lines(buf, start, start + ac, false, replacement)
      end
    end
  end)
  for _, item in ipairs(views) do
    if vim.api.nvim_win_is_valid(item.win) and vim.api.nvim_win_get_buf(item.win) == buf then
      local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, item.cursor, {})
      local top = vim.api.nvim_buf_get_extmark_by_id(buf, ns, item.top, {})
      vim.api.nvim_win_call(item.win, function()
        item.view.lnum, item.view.col, item.view.topline = pos[1] + 1, pos[2], top[1] + 1
        vim.fn.winrestview(item.view)
      end)
    end
    vim.api.nvim_buf_del_extmark(buf, ns, item.cursor)
    vim.api.nvim_buf_del_extmark(buf, ns, item.top)
  end
  assert(ok, err)
  return true
end

return M
