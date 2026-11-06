local M = {}
local Context = require("format_tools.context")

function M.new(config)
  local self = { config = config, active = {}, states = {}, disabled = {}, enabled = config.enabled }

  function self:cancel(buf, reason)
    if not buf then
      local buffers = vim.tbl_keys(self.active)
      for _, b in ipairs(buffers) do
        self:cancel(b, reason)
      end
      return
    end
    local job = self.active[buf]
    if job then
      if job.stop then
        job.stop()
      end
      job.finish(reason or "cancelled", "cancelled")
    end
  end

  function self:run(buf, request, callback)
    self:cancel(buf, "superseded")
    local job = { started = vim.uv.hrtime(), status = "running", bufnr = buf, did_edit = false }
    local timer = assert(vim.uv.new_timer())
    self.active[buf], self.states[buf] = job, job
    function job.finish(err, status)
      if job.finished then
        return
      end
      job.finished, job.error, job.status = true, err, status or (err and "error" or "done")
      job.duration_ms = (vim.uv.hrtime() - job.started) / 1e6
      timer:stop()
      timer:close()
      if self.active[buf] == job then
        self.active[buf] = nil
      end
      if err and job.status == "error" and not (job.opts or request).quiet then
        vim.notify("format-tools: " .. tostring(err), vim.log.levels.WARN)
      end
      if callback then
        local ok, failure = pcall(callback, err, job.did_edit, job)
        if not ok then
          vim.schedule(function()
            vim.notify(tostring(failure), vim.log.levels.ERROR)
          end)
        end
      end
    end
    local function guard()
      if job.finished then
        return false
      end
      if not Context.valid(job.context) then
        job.finish("buffer changed", "stale")
        return false
      end
      if vim.uv.hrtime() >= job.deadline then
        if job.stop then
          job.stop()
        end
        job.finish("formatting timed out", "error")
        return false
      end
      return true
    end
    local function advance(index, input)
      if not guard() then
        return
      end
      local item = job.plan.items[index]
      if not item then
        local ok, result = pcall(function()
          local lines = Context.lines(input)
          if job.opts.dry_run then
            job.output = input
            return false
          end
          return require("format_tools.apply").run(job.context, lines, job.opts.undojoin)
        end)
        if ok then
          job.did_edit = result
          job.finish()
        else
          job.finish(tostring(result))
        end
        return
      end
      job.current = item.name
      local function completed(err, text, stderr, code)
        if not guard() then
          return
        end
        item.stderr, item.exit_code = stderr, code
        if err then
          job.finish(item.name .. ": " .. tostring(err))
          return
        end
        if type(text) ~= "string" or #text > config.max_output or text:find("%z") then
          job.finish(item.name .. ": invalid or oversized output")
          return
        end
        advance(index + 1, text)
      end
      if item.definition.transform then
        local ok, result = pcall(item.definition.transform, job.context, input)
        if ok then
          completed(nil, result)
        else
          completed(result)
        end
      else
        job.stop = require("format_tools.runner").start(item, job.context, input, config, completed)
      end
    end
    local ok, err = pcall(function()
      job.context = Context.capture(buf, config)
      job.plan = require("format_tools.plan").build(job.context, config, request)
      job.opts = job.plan.opts
      job.deadline = job.started + job.opts.timeout_ms * 1e6
      timer:start(
        job.opts.timeout_ms,
        0,
        vim.schedule_wrap(function()
          if not job.finished then
            if job.stop then
              job.stop()
            end
            job.finish("formatting timed out")
          end
        end)
      )
      if #job.plan.items == 0 then
        job.finish(nil, "skipped")
      else
        advance(1, job.context.input)
      end
    end)
    if not ok then
      job.finish(tostring(err))
    end
    if not (job.opts or request).async and not job.finished then
      vim.wait(math.max(1, math.ceil((job.deadline - vim.uv.hrtime()) / 1e6)) + 20, function()
        return job.finished
      end, 1)
      if not job.finished then
        self:cancel(buf, "formatting timed out")
      end
    end
    return job
  end
  return self
end

return M
