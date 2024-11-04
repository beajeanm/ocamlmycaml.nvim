local lsp_api = require("ocamlmycaml.lsp.api")

local M = {
    switchImplIntf = function(buffer)
        lsp_api.custom_methods.switchImplIntf(buffer, function (err, result)
            if #result == 0 then
                return
            end
            local file_uri = result[1]
            local related_file = vim.split(file_uri, "file://")[2]

            -- if called on a .mli file, just go to the corresponding .ml file
            if vim.endswith(related_file, ".ml") then
                vim.cmd(":e " .. related_file)
                return
            end

            -- check if the .mli file already exists. if so just go to it
            if vim.fn.filereadable(related_file) == 1 then
                vim.cmd(":e " .. related_file)
                return
            end

            lsp_api.custom_methods.inferIntf(buffer, function(err2, result2)
                local lines = vim.split(result2, "\n")
                local new_buf = vim.api.nvim_create_buf(true, false)
                vim.api.nvim_set_option_value("ft", "ocaml", {buf = new_buf})
                vim.api.nvim_buf_set_name(new_buf, related_file)
                vim.api.nvim_buf_set_lines(new_buf, 0, 0, true, lines)
                vim.api.nvim_win_set_buf(0, new_buf)
            end)

        end)
    end,

    nextHole = function(buffer)
        lsp_api.custom_methods.typedHoles(buffer, function(err, result)
            table.sort(result, function(a, b)
                return a.start.line < b.start.line
            end)

            local first_hole = result[1]
            vim.api.nvim_win_set_cursor(0, { first_hole.start.line + 1, first_hole.start.character })
        end)
    end
}

return M
