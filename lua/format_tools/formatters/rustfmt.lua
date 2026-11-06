return {
  command = "rustfmt",
  args = function(ctx)
    return { "--emit=stdout", "--edition=" .. require("format_tools.util").rust_edition(ctx) }
  end,
  cwd = require("format_tools.util").root({ "rustfmt.toml", ".rustfmt.toml", "Cargo.toml" }),
}
