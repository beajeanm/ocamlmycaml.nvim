local Job = require('plenary.job')
local log = require('ocamlmycaml.util').create_logger("ocamlmycaml.dune")

local fidget_available, fidget_progress_handle = pcall(require, "fidget.progress.handle")

-- TODOs:
-- * stop DuneJob when last buffer of project is closed
-- * log DuneJob output to buffer (?)
-- * investigate use of different build directories
--   (i.e. to be able to run `dune build` and `dune utop` simultaneous)
-- * get a list of dune defined dependencies (requires `sexp` to be installed):
--      `dune describe external-lib-deps | sexp query "smash (field external_deps) each (index 0)"`


--- @class DuneJob
local DuneJob = {
    --- @type string | nil
    root_path = nil,

    --- @type string[]
    command = {},

    --- @type ProgressHandle
    progress_handler = nil,

    --- @type vim.SystemObj
    process = nil,

    --- @type boolean
    running = false,

    -- --- @type table<string, DuneJob>
    --- @type DuneJob[]
    active_jobs = {}
}
DuneJob.__index = DuneJob

--- @param root string|nil
--- @param command string[]
function DuneJob:new(root, command)
    table.insert(command, 1, "dune")
    local new = {root_path = root, command = command}
    return setmetatable(new, self)
end


function DuneJob:start()
    if self.running then
        log.debug("Already running")
        return
    end

    -- register itself into the global job list
    table.insert(DuneJob.active_jobs, self)

    self.process = vim.system(self.command, {
        -- TODO: rethink how to do error handling/output logging
        stdout = function (error, data)
            if error then
                log.error("Error: " .. error)
                return
            end

            if fidget_available and self.progress_handler then
                self.progress_handler:report({message = data})
            end
        end,
        stderr = function (error, data)
            if error then
                log.error("Error: " .. error)
                return
            end
            if fidget_available and self.progress_handler then
                self.progress_handler:report({message = data})
            end
        end,

        cwd = self.root_path,

        -- When using `dune exec -w <target>`, two processes are created:
        --
        -- 1. the dune process which waits for file system changes to trigger a compilation
        -- 2. the <target> process
        --
        -- In Neovim we only know the PID of the dune process, not the <target> one. Hence, we can only send a SIGINT to
        -- the dune process. However, dune is currently not forwarding those signals the the child process
        -- (https://github.com/ocaml/dune/issues/11089), which will leave the <target> processes orphaned.
        --
        -- Due to this reason we're stopping the dune process by sending the SIGINT to its process group id (PGID)
        -- which is shared with the <target> process. Sending a signal to the process group will forward it
        -- to all processes in the group (see `man kill`).
        --
        -- By setting `detached = true` we ensure that the dune and <target> PGID is different from the Neovim one
        -- itself. Otherwise sending SIGINT to the group would stop Neovim itself.
        detach = true,
    },

    --- @param completed vim.SystemCompleted
    vim.schedule_wrap(function (completed)
        self.running = false

        -- TODO: do this better ...
        if completed.code ~= 0 then
            log.error("Error: " .. completed.stderr)
        end

        -- We clean up the job from DuneJobs.active_jobs here rather than in
        -- DuneJob:stop() in case of an unexpected exit

        -- ugly but meh
        local index = nil
        for i, job in ipairs(DuneJob.active_jobs) do
            if job == self then
                index = i
            end
        end

        if index ~= nil then
            table.remove(DuneJob.active_jobs, index)
        end

        -- remove the progress handler as well
        if self.progress_handler ~= nil then
            self.progress_handler:finish()
        end
    end))

    self.running = true
    if fidget_available then
        self.progress_handler = fidget_progress_handle.create({
            title = table.concat(self.command, " "),
            message = "msg",
            lsp_client = {name = "dune"},
        })
    end

end

function DuneJob:stop()
    if self.process ~= nil then
        -- The PID of the dune process is the PGID of all spawned subprocesses (hopefuly).
        -- We can send a signal to the process group by using the negative PGID (see `man kill`)
        local pid = self.process.pid
        local pgid = -pid
        vim.uv.kill(pgid, 2)
    end
end


function DuneJob:toTable()
    return {root_path = self.root_path, command = self.command}
end

local M = {
    DuneJob = DuneJob
}

--- @param dune_root string dune project root folder
--- @return DuneJob|nil
M.find_dune_job_for_project = function(dune_root)
    for _, job in ipairs(DuneJob.active_jobs) do
        if job.root_path == dune_root then
            return job
        end
    end
    return nil
end

local function stop_all_dune_jobs()
    for _, job in ipairs(DuneJob.active_jobs) do
        if job ~= nil then
            job:stop()
        end
    end
end


-- TODO: document opts
M.setup = function(opts)
    -- store settings for later access in other functions
    M.opts = opts

    local au_grp = vim.api.nvim_create_augroup("ocamlmycaml.dune", {})

    vim.api.nvim_create_autocmd({"LspDetach"}, {
        group = au_grp,
        once = false,
        pattern = {"*.ml", "*.mli"},
        callback = function(event)
            local file = event.file
            local dune_root = M.find_dune_project(file)
            if dune_root ~= nil then
                local dune_job = M.find_dune_job_for_project(dune_root)
                if dune_job ~= nil then
                    dune_job:stop()
                end
            end
        end
    })

    -- used for hot reload of plugin during development under Lazy
    vim.api.nvim_create_autocmd({"User"}, {
        group = au_grp,
        once = false,
        pattern = {"OcamlMyCamlStart", "OcamlMyCamlStop"},
        callback = function(event)
            if event.match == "OcamlMyCamlStart" then
                -- query all workspaces for the ocamllsp client and start those DuneJobs
                local dune_jobs = vim.g.ocamlmycaml_jobs
                for _, job in ipairs(dune_jobs) do
                    job:start()
                end
            elseif event.match == "OcamlMyCamlStop" then
                local jobs = vim.tbl_map(function(job) return job:toTable() end, DuneJob.active_jobs)
                jobs = vim.tbl_values(jobs)
                vim.g.ocamlmycaml_jobs = jobs
                stop_all_dune_jobs()
            end
        end
    })

    vim.api.nvim_create_autocmd({"VimLeavePre"}, {
        group = au_grp,
        once = false,
        pattern = {"*"},
        callback = function(event)
            -- close all remaining running dune jobs
            -- (LspDetach is not called on vim close)
            stop_all_dune_jobs()
        end
    })

    -- ensure we start a default build job once we enter an ocaml file in a dune project
    if opts.auto_start == true then
        vim.api.nvim_create_autocmd({"LspAttach"}, {
            group = au_grp,
            once = false,
            pattern = {"*.ml", "*.mli"},
            callback = function(event)
                local file = event.file
                local dune_root = M.find_dune_project(file)

                -- only start job if it's not yet running
                if dune_root ~= nil then
                    for _, job in ipairs(DuneJob.active_jobs) do
                        if job.root_path == dune_root then
                            return
                        end
                    end
                    -- we haven't found an active job for the current root dir
                    DuneJob:new(dune_root, {"build", "-w"}):start()
                end
            end
        })
        return
    end
end

--- check if folder is part of a dune project by searching up the file tree for a `dune-project` file
---@param file string
---@return string | nil
M.find_dune_project = function (file)
    local is_readable = vim.fn.filereadable(file) == 1
    if not is_readable then
        return nil
    end
    return vim.fs.root(file, "dune-project")
end


-- stop all running dune jobs
M.stop_all_dune_jobs = stop_all_dune_jobs


--- @class UserCommandInfo
--- @field name string Command name
--- @field args string The args passed to the command, if any
--- @field fargs table The args split by unescaped whitespace (when more than one argument is allowed), if any
--- @field nargs string Number of arguments `:command-nargs`
--- @field bang boolean "true" if the command was executed with a ! modifier
--- @field line1 number The starting line of the command range
--- @field line2 number The final line of the command range
--- @field range number The number of items in the command range: 0, 1, or 2
--- @field count number Any count supplied
--- @field reg string The optional register, if specified
--- @field mods string Command modifiers, if any
--- @field smods table Command modifiers in a structured format. Has the same structure as the "mods" key of `nvim_parse_cmd()`.


--- @param command UserCommandInfo
M.dune_command = function(command)
    local args = command.fargs
    if #args < 1 then
        return
    end

    local file = vim.api.nvim_buf_get_name(0)
    local root = M.find_dune_project(file)
    local cmd = vim.deepcopy(args)

    DuneJob:new(root, cmd):start()
end



-- TODO: this needs improvements, however with ocamllsp's diagnostics, it's not a high priority.
--       This can/should probably just be copied from ocaml/vim-ocaml
M.dune_efm = {
    '%AFile "%f"\\, line %l\\, characters %c-%k:',
    -- '%C%.%# | %.%#',
    '%C%.%# | %m', -- include the code line iself in the error message
    '%C %#^%#',
    '%C%trror%.%#: %m',
    '%C%tarning %m',
    '%C%m'
}

-- TODO: not a fan of the sync() call, but good enough for now.
--       would prefer a callback based design, but this seem not to be supported by
--       telescope at the moment.
M.dune_targets = function()
    local targets = {}
    local dune_job = Job:new({
        command = "dune",
        args = {"describe"},
    })

    -- pipe the results into sexp
    local sexp_job = Job:new({
        command = "sexp",
        args = {"query", "(cat (pipe (field executables) (field names) (index 0)) (pipe (field library) (test (field local) (equals true)) (field name)))"},
        writer = dune_job,
        on_exit = function (job)
            targets = job:result()
        end
    })
    dune_job:and_then(sexp_job)

    -- start the actual job
    sexp_job:sync()

    return targets
end


M.setup_make = function()
    vim.o.makeprg = "dune build $*"
    vim.opt.efm = M.dune_efm
end

return M
