# format-tools.nvim

Transactional buffer formatting for Neovim 0.11+.

```lua
require("format_tools").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_fix", "ruff_organize_imports", "ruff_format" },
    markdown = { "prettierd", "prettier", stop_after_first = true },
    ["_"] = { "trim_whitespace" },
  },
  default_format_opts = { lsp_format = "fallback" },
  format_on_save = { timeout_ms = 500 },
})
require("format_tools").format()
```

Formatters transform an in-memory snapshot sequentially. The completed chain is
applied once using small edits. Failure, timeout, cancellation, and stale inputs
leave the buffer untouched. The entire chain shares one deadline (1000 ms by
default), including asynchronous calls. A new request cancels the older one.
Output is bounded while reading. In-place tools receive a private temporary
copy beside the original; the actual source file is never passed for mutation.
Temporary copies are removed after the process exits, including cancellation.

The buffer's fileformat and endofline options are preserved. A format creates
one undo entry; `undojoin = true` explicitly joins the preceding edit. No-op
formatting creates no undo entry. Views and cursor anchors are tracked across
small edits in every window displaying the buffer.
Formatter input uses LF line endings and a final newline as a canonical text
representation, independent of the buffer's disk EOL policy.

Custom definitions support `command`, argv-list `args`, `prepend_args`,
`append_args`, `cwd`, `env`, `stdin` (false for in-place tools), `exit_codes`,
and `condition(ctx)`. Arguments may contain `$FILENAME` and `$DIRNAME`.
`command`, argv lists, `cwd`, and `env` may be functions of the snapshot context.
`transform(ctx, text)` supplies an in-process text transformation instead.
Transforms must be fast and nonblocking. Definitions override built-in adapters.
Tools are installed separately, through your existing tool manager.

Public API: `setup(opts)`, `format(opts, callback)`, `cancel(bufnr)`,
`status(bufnr)`, `inspect(bufnr, opts)`, `info(bufnr)`, `config()`,
`enable(bufnr?)`, `disable(bufnr?)`, and `is_enabled(bufnr)`.
`format` returns a request handle with `status`, `error`, and `did_edit`.
The callback `(error, did_edit, handle)` is delivered once on completion.
Options include `bufnr`, `async`, `timeout_ms`, `quiet`, `formatters`,
`stop_after_first`, `dry_run`, and `undojoin`.
`inspect` explains candidate availability and selection without starting tools.
`_` supplies the list for unconfigured filetypes; `*` appends to all filetypes.

`:FormatToolsFormat`, `:FormatToolsCancel`, and `:FormatToolsInfo` operate on
the current buffer. `:FormatToolsDisable` / `:FormatToolsEnable` control global
autoformat; a bang controls only the current buffer. Manual format stays usable
when autoformat is disabled. `format_on_save` may be a function of bufnr returning
options or nil to skip. Saving always formats synchronously before the disk write.
Repeated setup cancels existing requests and replaces its autocommands.
`:checkhealth format_tools` checks configured tools without running them.

LSP modes are `never`, `fallback` (no external formatter is available), and
`prefer` (use LSP when available). An external formatter error does not trigger
LSP fallback. Multiple matching LSP clients require explicit `id`, `name`, or
`filter` selection. LSP edits are decoded using the client's encoding on a
scratch copy, then applied through the same minimal-diff path. A detached client
cancels its request. `formatting_options` overrides tabSize/insertSpaces.

Built-in adapters: stylua, ruff_fix, ruff_organize_imports, ruff_format, prettier,
prettierd, tex-fmt, typstyle, rustfmt, clang-format, nixfmt, jq, taplo, shfmt,
fish_indent, cmake_format, html_beautify, gdscript-formatter,
verible-verilog-format, mh_style, swift, and trim_whitespace. Node-based tools
prefer the nearest node_modules/.bin; Ruff prefers a project .venv/bin.
Rustfmt reads package/workspace edition metadata from Cargo.toml.

Range formatting and embedded-language formatting are not implemented yet.
Explicit ranges are rejected rather than silently formatting the entire buffer.
LSP `first`/`last` composition and asynchronous post-save rewrites are also
outside the initial API. This plugin has no dependency on Conform or other tools
plugins, and does not install executables or set mappings/formatexpr.

Run `sh tests/run.sh` for regression checks, available real formatter tests and
rendered PTY interaction. A local stdio LSP fixture also exercises Neovim's real
client transport, document synchronization, encoding and edit handling.
`FORMAT_TOOLS_BIN` adds executable directories for real
tests; `FORMAT_TOOLS_REQUIRE_REAL=19` requires all nineteen real tool scenarios.
