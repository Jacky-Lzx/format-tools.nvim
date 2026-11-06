local util = require("format_tools.util")
return {
  command = util.executable("prettier", "node_modules/.bin"),
  args = { "--stdin-filepath", "$FILENAME" },
  cwd = util.root({ ".prettierrc", ".prettierrc.json", ".prettierrc.yaml", "prettier.config.js", "package.json" }),
}
