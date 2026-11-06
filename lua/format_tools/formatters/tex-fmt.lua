return {
  command = "tex-fmt",
  args = function(ctx)
    local args = { "--stdin", "--tabsize", tostring(ctx.expandtab and ctx.shiftwidth or 1) }
    if not ctx.expandtab then
      args[#args + 1] = "--usetabs"
    end
    return args
  end,
}
