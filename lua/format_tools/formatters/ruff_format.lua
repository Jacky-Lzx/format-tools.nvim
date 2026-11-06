local util = require("format_tools.util")
return {
  command = util.executable("ruff", ".venv/bin"),
  args = { "format", "--force-exclude", "--stdin-filename", "$FILENAME", "-" },
  cwd = util.root({ "pyproject.toml", "ruff.toml", ".ruff.toml" }),
}
