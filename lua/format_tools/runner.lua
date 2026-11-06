local M = {}

function M.start(item, ctx, input, opts, done)
  local def, process, directory = item.definition
  local output, size, failure = { stdout = {}, stderr = {} }, 0
  local function evaluate(value)
    if type(value) == "function" then
      return value(ctx)
    end
    return value
  end
  local function cleanup()
    if directory then
      vim.fn.delete(directory, "rf")
    end
  end
  local function read(stream)
    return function(err, data)
      if err then
        failure = failure or tostring(err)
      end
      if not data or failure then
        return
      end
      size = size + #data
      if size > opts.max_output then
        failure = "Formatter output exceeds max_output"
        vim.schedule(function()
          if process then
            pcall(process.kill, process, 9)
          end
        end)
      else
        output[stream][#output[stream] + 1] = data
      end
    end
  end
  local ok, err = pcall(function()
    local filename = ctx.filename
    if def.stdin == false then
      directory = assert(vim.uv.fs_mkdtemp(ctx.dirname .. "/.format-tools-XXXXXX"))
      filename = directory .. "/" .. vim.fs.basename(ctx.filename)
      local file = assert(io.open(filename, "wb"))
      assert(file:write(input))
      assert(file:close())
    end
    local function arguments(value)
      if type(value) == "function" then
        value = value(ctx)
      end
      assert(value == nil or (type(value) == "table" and vim.islist(value)), "Formatter args must be an argv list")
      local values = {}
      for _, arg in ipairs(value or {}) do
        assert(type(arg) == "string" or type(arg) == "number", "Invalid formatter argument")
        arg = tostring(arg):gsub("%$([A-Z]+)", function(key)
          return ({ FILENAME = filename, DIRNAME = ctx.dirname })[key]
        end)
        values[#values + 1] = arg
      end
      return values
    end
    local argv = { item.command }
    for _, key in ipairs({ "prepend_args", "args", "append_args" }) do
      vim.list_extend(argv, arguments(def[key]))
    end
    item.argv = argv
    item.cwd = evaluate(def.cwd) or ctx.dirname
    process = vim.system(argv, {
      cwd = item.cwd,
      env = evaluate(def.env),
      stdin = def.stdin ~= false and input or nil,
      stdout = read("stdout"),
      stderr = read("stderr"),
    }, function(exit)
      vim.schedule(function()
        local text, stderr = table.concat(output.stdout), table.concat(output.stderr)
        local success = exit.signal == 0 and vim.list_contains(def.exit_codes or { 0 }, exit.code)
        if not failure and success and def.stdin == false then
          local stat = vim.uv.fs_stat(filename)
          if not stat or stat.size > opts.max_output then
            failure = "Invalid or oversized temporary formatter output"
          else
            local file = io.open(filename, "rb")
            if file then
              text = file:read("*a")
              file:close()
            else
              failure = "Cannot read formatter output"
            end
          end
        end
        cleanup()
        done(
          failure or (not success and ("exit " .. exit.code .. ": " .. stderr:sub(1, 2000)) or nil),
          text,
          stderr,
          exit.code
        )
      end)
    end)
  end)
  if not ok then
    cleanup()
    vim.schedule(function()
      done(tostring(err))
    end)
  end
  return function()
    if process then
      pcall(process.kill, process, 9)
    end
  end
end

return M
