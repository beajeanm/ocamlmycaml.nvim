local lsp_api = require("ocamlmycaml.lsp.api")
local util = require("ocamlmycaml.util")
local log = util.create_logger("ocamlmycaml.lsp")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")


local M = {
    switchImplIntf = function(buffer)
        lsp_api.custom_methods.switchImplIntf(buffer, function(err, result)
            if result == nil or #result == 0 then
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
                vim.api.nvim_set_option_value("ft", "ocaml", { buf = new_buf })
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
    end,

    merlin = {
        find_by_type = function()
            local buffer = vim.api.nvim_get_current_buf()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local position = cursor[1] .. ":" .. cursor[2]

            local merlin_finder = util.new_callback_finder({
                entry_maker = function(entry)
                    local name = string.gsub(entry.name, "\n", "")
                    local type = string.gsub(entry.type, "\n", "")
                    return {
                        value = entry,
                        display = name .. " : " .. type,
                        ordinal = entry.cost

                    }
                end,
                fn = function(prompt, cb)

                    --- @type MerlinCommand
                    local merlin_options = {
                        command = "search-by-type",
                        args = {
                            "-position", position,
                            "-query", prompt,
                            -- "-limit", "20",
                            -- "-with-doc true"
                        },
                        asSexp = false
                    }
                    lsp_api.custom_methods.merlinCallCompatible(
                        buffer, merlin_options,
                        function(error, result)
                            if error ~= nil then
                                log.error(vim.inspect(error))
                                cb({})
                            end
                            local suggestions = vim.json.decode(result.result)
                            cb(suggestions.value)
                        end
                    )
                end
            })

            local picker = pickers.new({
                prompt_title = "Search by type",
                finder = merlin_finder,
                -- sorter = conf.generic_sorter()
                attach_mappings = function(prompt_bufnr, map)
                    actions.select_default:replace(function()
                        actions.close(prompt_bufnr)
                        local selection = actions_state.get_selected_entry()
                        vim.api.nvim_paste(selection.value.constructible, false, -1)
                    end)
                    return true
                end
            }, {})

            picker:find()
        end
    }


}

return M
