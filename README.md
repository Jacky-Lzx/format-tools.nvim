# format-tools.nvim

Transactional buffer formatting with external tools and native LSP.

## Features

- Run formatter chains against an isolated text snapshot.
- Apply small edits only when the complete request succeeds.
- Inspect tool selection and control formatting on save.

## Requirements

Neovim **0.11+**. Install formatter executables separately. LSP formatting requires a capable attached server.

## Installation

With lazy.nvim:

```lua
{
  "Jacky-Lzx/format-tools.nvim",
  main = "format_tools",
  opts = { formatters_by_ft = { lua = { "stylua" } } },
}
```

Or put this repository and its required dependencies on `runtimepath`, then call:

```lua
require("format_tools").setup({ formatters_by_ft = { lua = { "stylua" } } })
```

## Usage

```vim
:FormatToolsFormat
:FormatToolsInfo
```

## Documentation

- [Complete reference](doc/format-tools.txt) — `:help format-tools`.
- Diagnose availability with `:checkhealth format_tools`.

## Development

Run from the repository root:

```sh
python3 tests/run.py unit --filter docs
python3 tests/run.py default
```

See [the test workflow](tests/README.md) for dependencies, optional suites and
retained failure evidence. Local development overrides belong in your package
manager configuration; public installation uses the repository above.

[License](LICENSE).
