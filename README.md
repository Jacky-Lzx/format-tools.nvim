# format-tools.nvim

Transactional buffer formatting for Neovim 0.11+.

```lua
require("format_tools").setup({
  formatters_by_ft = { ["_"] = { "trim_whitespace" } },
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

Custom definitions support `command`, argv-list `args`, `prepend_args`,
`append_args`, `cwd`, `env`, `stdin` (false for in-place tools), `exit_codes`,
and `condition(ctx)`. Arguments may contain `$FILENAME` and `$DIRNAME`.
`command`, argv lists, `cwd`, and `env` may be functions of the snapshot context.
`transform(ctx, text)` supplies an in-process text transformation instead.
Transforms must be fast and nonblocking. Definitions override built-in adapters.
Tools are installed separately, through your existing tool manager.

Public API: `setup(opts)`, `format(opts, callback)`, `cancel(bufnr)`,
`status(bufnr)`, `inspect(bufnr, opts)`, `info(bufnr)`, and `config()`.
`format` returns a request handle with `status`, `error`, and `did_edit`.
The callback `(error, did_edit, handle)` is delivered once on completion.
Options include `bufnr`, `async`, `timeout_ms`, `quiet`, `formatters`,
`stop_after_first`, `dry_run`, and `undojoin`.
`inspect` explains candidate availability and selection without starting tools.
`_` supplies the list for unconfigured filetypes; `*` appends to all filetypes.

Range formatting and embedded-language formatting are not implemented yet.
Explicit ranges are rejected rather than silently formatting the entire buffer.

Run `sh tests/run.sh` for regression checks.
