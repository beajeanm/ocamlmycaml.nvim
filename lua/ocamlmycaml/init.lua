local dune = require("ocamlmycaml.dune")
local lsp = require("ocamlmycaml.lsp")


local M = {}

M.setup = function(opts)

    -- setup dune options
    dune.setup(opts.dune)

    vim.api.nvim_create_user_command("Ocamllsp", function (command)
        local args = command.fargs
        if #args < 1 then
            return
        end

        local buffer = vim.api.nvim_get_current_buf()
        if args[1] == "switch" then
            lsp.switchImplIntf(buffer)
        elseif args[1] == "hole" then
            lsp.nextHole(buffer)
        end
    end, {nargs = '*'})

    -- setup dune releated commands
    vim.api.nvim_create_user_command("Dune", dune.dune_command, {nargs = '*'})
    vim.api.nvim_create_user_command("DuneStop", dune.stop_all_dune_jobs, {})

    -- TODO: does this need to return anything?
    return {}
end



return M
