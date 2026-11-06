return {
  command = "jq",
  args = function(ctx)
    return ctx.expandtab and { "--indent", tostring(math.min(7, ctx.shiftwidth)), "." } or { "--tab", "." }
  end,
}
