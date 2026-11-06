return {
  command = "stylua",
  args = { "--search-parent-directories", "--respect-ignores", "--stdin-filepath", "$FILENAME", "-" },
  cwd = require("format_tools.util").root({ ".stylua.toml", "stylua.toml" }),
}
