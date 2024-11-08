local make_entry = require("telescope.make_entry")


local M = {}

--- @class Logger
--- @field trace function<string>
--- @field debug function<string>
--- @field info function<string>
--- @field warn function<string>
--- @field error function<string>

--- @param namespace string
--- @return Logger
M.create_logger = function(namespace)
    local opts = {namespace = namespace}
    local logging_func_for = function(level)
        return function(msg)
            vim.notify(msg, level, opts)
        end
    end

    return {
        trace = logging_func_for(vim.log.levels.TRACE),
        debug = logging_func_for(vim.log.levels.DEBUG),
        info = logging_func_for(vim.log.levels.INFO),
        warn = logging_func_for(vim.log.levels.WARN),
        error = logging_func_for(vim.log.levels.ERROR),
    }
end


local _callable_obj = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, ...)
    return t:_find(...)
  end

  obj.close = function() end

  return obj
end

local CallbackDynamicFinder = _callable_obj()

function CallbackDynamicFinder:new(opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")
  assert(not opts.static, "`static` should be used with finder.new_oneshot_job")

  local obj = setmetatable({
    curr_buf = opts.curr_buf,
    fn = opts.fn,
    entry_maker = opts.entry_maker or make_entry.gen_from_string(opts),
  }, self)

  return obj
end

function CallbackDynamicFinder:_find(prompt, process_result, process_complete)
  self.fn(prompt, function(results)
      local result_num = 0
      for _, result in ipairs(results) do
        result_num = result_num + 1
        local entry = self.entry_maker(result)
        if entry then
          entry.index = result_num
        end
        if process_result(entry) then
          return
        end
      end

      process_complete()
    end)
end

M.new_callback_finder = function(opts)
    return CallbackDynamicFinder:new(opts)
end

return M
