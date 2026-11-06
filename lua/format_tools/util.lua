local M = {}

function M.root(markers)
  return function(ctx)
    return vim.fs.root(ctx.dirname, markers) or ctx.dirname
  end
end

function M.executable(name, directory)
  return function(ctx)
    if directory then
      local dir = ctx.dirname
      while dir do
        local path = dir .. "/" .. directory .. "/" .. name
        if vim.fn.executable(path) == 1 then
          return path
        end
        dir = vim.fs.dirname(dir) ~= dir and vim.fs.dirname(dir) or nil
      end
    end
    return name
  end
end

local function section(path, wanted)
  local file = io.open(path, "r")
  if not file then
    return ""
  end
  local active, lines = false, {}
  for line in file:lines() do
    local name = line:match("^%s*%[([^%]]+)%]%s*")
    if name then
      active = name == wanted
    elseif active then
      lines[#lines + 1] = line
    end
  end
  file:close()
  return table.concat(lines, "\n")
end

function M.rust_edition(ctx)
  local root = vim.fs.root(ctx.dirname, "Cargo.toml")
  if not root then
    return "2021"
  end
  local package = section(root .. "/Cargo.toml", "package")
  local function edition(text)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      local value = line:match("^%s*edition%s*=%s*['\"](%d+)['\"]")
      if value then
        return value
      end
    end
  end
  local value = edition(package)
  if value then
    return value
  end
  if
    package:match("edition%s*%.%s*workspace%s*=%s*true") or package:match("edition%s*=%s*{%s*workspace%s*=%s*true")
  then
    local dir = root
    while dir do
      value = edition(section(dir .. "/Cargo.toml", "workspace.package"))
      if value then
        return value
      end
      dir = vim.fs.dirname(dir) ~= dir and vim.fs.dirname(dir) or nil
    end
  end
  -- An existing Cargo package without an edition uses Rust 2015.
  return package ~= "" and "2015" or "2021"
end

return M
