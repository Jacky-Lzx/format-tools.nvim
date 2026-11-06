local M = {}

function M.capture(buf, opts)
  assert(vim.api.nvim_buf_is_loaded(buf), "Buffer is not loaded")
  assert(vim.bo[buf].buftype == "" and vim.bo[buf].modifiable, "Buffer is not a modifiable file buffer")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local input = table.concat(lines, "\n")
  assert(#input <= opts.max_file_size, "Buffer exceeds max_file_size")
  local name = vim.api.nvim_buf_get_name(buf)
  local directory = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  return {
    bufnr = buf,
    name = name,
    filename = name ~= "" and name
      or (directory .. "/untitled." .. (vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "txt")),
    dirname = directory,
    filetype = vim.bo[buf].filetype,
    changedtick = vim.api.nvim_buf_get_changedtick(buf),
    endofline = vim.bo[buf].endofline,
    fixendofline = vim.bo[buf].fixendofline,
    fileformat = vim.bo[buf].fileformat,
    binary = vim.bo[buf].binary,
    shiftwidth = vim.api.nvim_buf_call(buf, vim.fn.shiftwidth),
    tabstop = vim.bo[buf].tabstop,
    expandtab = vim.bo[buf].expandtab,
    lines = lines,
    -- Keep the final terminator separate from the buffer's EOL policy, so an
    -- empty final line remains unambiguous throughout the formatter chain.
    input = input .. "\n",
  }
end

function M.valid(ctx)
  local buf = ctx.bufnr
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.api.nvim_buf_get_changedtick(buf) == ctx.changedtick
    and vim.api.nvim_buf_get_name(buf) == ctx.name
    and vim.bo[buf].filetype == ctx.filetype
    and vim.bo[buf].buftype == ""
    and vim.bo[buf].modifiable
    and vim.bo[buf].endofline == ctx.endofline
    and vim.bo[buf].fileformat == ctx.fileformat
    and vim.bo[buf].fixendofline == ctx.fixendofline
    and vim.bo[buf].binary == ctx.binary
    and vim.bo[buf].expandtab == ctx.expandtab
    and vim.bo[buf].tabstop == ctx.tabstop
    and vim.api.nvim_buf_call(buf, vim.fn.shiftwidth) == ctx.shiftwidth
end

function M.lines(text)
  assert(type(text) == "string" and not text:find("%z"), "Formatter returned invalid text")
  text = text:gsub("\r\n", "\n")
  if text:sub(-1) == "\n" then
    text = text:sub(1, -2)
  end
  return vim.split(text, "\n", { plain = true })
end

return M
