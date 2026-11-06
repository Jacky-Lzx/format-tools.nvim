return {
  command = require("format_tools.util").executable("html-beautify", "node_modules/.bin"),
  args = { "--editorconfig", "--file", "-" },
  cwd = require("format_tools.util").root({ ".jsbeautifyrc" }),
}
