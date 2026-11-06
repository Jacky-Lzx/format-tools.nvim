local F = require("format_tools")
-- Use installed toolchain binaries when available; never install during tests.
local tools = vim.env.FORMAT_TOOLS_BIN
if tools then
  vim.env.PATH = tools .. ":" .. vim.env.PATH
end
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local count, skipped = 0, {}
local cases = {
  { "lua", "stylua", { "local x={a=1,b=2}", "return x" }, "local x = { a = 1, b = 2 }" },
  {
    "python",
    { "ruff_fix", "ruff_organize_imports", "ruff_format" },
    { "import sys", "import os", "value=  1+2", "print(os.name,sys.version,value)" },
    "value = 1 + 2",
  },
  { "javascript", "prettier", { "const value={a:1,b:2}" }, "const value = { a: 1, b: 2 };" },
  { "javascript", "prettierd", { "const value={a:1,b:2}" }, "const value = { a: 1, b: 2 };" },
  { "tex", "tex-fmt", { "\\begin{equation}", "x=1", "\\end{equation}" }, "  x=1" },
  { "json", "jq", { '{"a":1}' }, '  "a": 1' },
  { "rust", "rustfmt", { 'fn main(){println!("hi");}' }, '    println!("hi");' },
  { "swift", "swift", { 'func hello(){print("hi")}' }, 'func hello() { print("hi") }' },
  { "sh", "shfmt", { "if true;then", "echo hi", "fi" }, "  echo hi" },
  { "toml", "taplo", { "x=1" }, "x = 1" },
  { "nix", "nixfmt", { "{a=1;}" }, "a = 1;" },
  { "typst", "typstyle", { "#let x=(a:1,b:2)" }, "#let x = (a: 1, b: 2)" },
  { "cpp", "clang-format", { "int main(){return 0;}" }, "int main() { return 0; }" },
  { "fish", "fish_indent", { "if true", "echo hi", "end" }, "    echo hi" },
  { "html", "html_beautify", { "<div>", "<span>hi</span>", "</div>" }, "<span>hi</span>" },
  { "cmake", "cmake_format", { "set(x  1)" }, "set(x 1)" },
  { "gdscript", "gdscript-formatter", { "extends Node", "var x=1" }, "var x = 1" },
  { "verilog", "verible-verilog-format", { "module m;wire x;endmodule" }, "wire x;" },
  { "matlab", "mh_style", { "x=1;" }, "x = 1;" },
}
local suffixes = { python = "py", javascript = "js", rust = "rs", sh = "sh", typst = "typ" }
for index, case in ipairs(cases) do
  local ft, names, input, expected = unpack(case)
  if type(names) == "string" then
    names = { names }
  end
  vim.cmd("enew!")
  vim.api.nvim_buf_set_name(0, root .. "/case" .. index .. "." .. (suffixes[ft] or ft))
  vim.bo.filetype, vim.bo.expandtab, vim.bo.shiftwidth = ft, true, (ft == "rust" and 4 or 2)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, input)
  F.setup({ formatters_by_ft = { [ft] = names } })
  local plan = F.inspect()
  if not plan.formatters[1].available then
    skipped[#skipped + 1] = names[1]
  else
    local job = F.format({ timeout_ms = 10000 })
    assert(job.status == "done", names[1] .. ": " .. tostring(job.error))
    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert(text:find(expected, 1, true), names[1] .. ": " .. text)
    assert(not F.format({ timeout_ms = 10000 }).did_edit, names[1] .. " not idempotent")
    vim.cmd.undo()
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), input), names[1] .. " undo")
    count = count + 1
  end
end
assert(count >= tonumber(vim.env.FORMAT_TOOLS_REQUIRE_REAL or "1"), "Insufficient real formatter coverage")
vim.fn.delete(root, "rf")
print("Real formatters passed: " .. count .. "; unavailable: " .. table.concat(skipped, ", "))
