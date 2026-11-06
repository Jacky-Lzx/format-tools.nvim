return {
  command = "shfmt",
  args = function(ctx)
    local args = { "-filename", "$FILENAME" }
    if ctx.expandtab and not vim.fs.root(ctx.dirname, ".editorconfig") then
      vim.list_extend(args, { "-i", tostring(ctx.shiftwidth) })
    end
    return args
  end,
}
