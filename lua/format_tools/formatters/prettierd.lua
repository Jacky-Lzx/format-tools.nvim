local util = require("format_tools.util")
return {
  command = util.executable("prettierd", "node_modules/.bin"),
  args = { "$FILENAME" },
  cwd = util.root({ ".prettierrc", ".prettierrc.json", ".prettierrc.yaml", "prettier.config.js", "package.json" }),
}
