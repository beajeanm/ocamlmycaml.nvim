

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

return M
