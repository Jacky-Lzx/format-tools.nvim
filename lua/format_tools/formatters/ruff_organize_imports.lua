local util = require("format_tools.util")
return {
  command = util.executable("ruff", ".venv/bin"),
  args = {
    "check",
    "--fix",
    "--force-exclude",
    "--select=I001",
    "--exit-zero",
    "--no-cache",
    "--stdin-filename",
    "$FILENAME",
    "-",
  },
  cwd = util.root({ "pyproject.toml", "ruff.toml", ".ruff.toml" }),
}
