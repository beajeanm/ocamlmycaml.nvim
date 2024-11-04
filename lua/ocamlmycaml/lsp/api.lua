-- TODO: this all assumes one active ocamllsp server and one opam switch.
--       at some point this probably should respect multi project setups
--       with different local switches

local dune = require("ocamlmycaml.dune")
local log = require('ocamlmycaml.util').create_logger('ocamlmycaml.lsp')

--- @class OcamllspCapabilities
--- @field diagnostic_promotions boolean
--- @field hoverExtended boolean
--- @field inferIntf boolean
--- @field switchImplIntf boolean
--- @field typedHoles boolean
--- @field wrappingAstNode boolean
--- @field interfaceSpecificLangId boolean
--- @field construct boolean

--- @alias OcamllspCallback function<lsp.ResponseError|nil, any>

--- @class MerlinCommand
--- @field command string
--- @field args string[]
--- @field asSexp boolean


--- @param buffer integer buffer number
--- @return vim.lsp.Client | nil
local get_client_for_buffer = function(buffer)
    local clients = vim.lsp.get_clients({ bufnr = buffer, name = "ocamllsp" })
    if #clients == 0 or #clients > 1 then
        return nil
    end
    return clients[1]
end


--- @return OcamllspCapabilities
local get_available = function()
    local client = get_client_for_buffer(0)
    if client == nil then
        log.info("No active ocamllsp")
        return {}
    end

    -- all ocamllsp specific requests are stored under server_capabilities.experimental.ocamllsp
    local cap = client.server_capabilities.experimental.ocamllsp

    --- @type OcamllspCapabilities
    return {
        diagnostic_promotions = cap.diagnostic_promotions or false,
        getDocumentation = cap.handleGetDocumentation or false,
        hoverExtended = cap.handleHoverExtended or false,
        inferIntf = cap.handleInferIntf or false,
        merlinCallCompatible = cap.handleMerlinCallCompatible or false,
        switchImplIntf = cap.handleSwitchImplIntf or false,
        typeEnclosing = cap.handleTypeEnclosing or false,
        typedHoles = cap.handleTypedHoles or false,
        wrappingAstNode = cap.handleWrappingAstNode or false,
        interfaceSpecificLangId = cap.interfaceSpecificLangId or false,
        construct = cap.handleConstruct or false
    }
end

-- TODO: should we actually accept the official name of the capability?
--- @param name string name of the server capability
local check_available = function(name)
    local capabilities = get_available()
    return capabilities[name] == true
end

-- TODO: probably should handle relative/absolute/non-normalized paths ...
--- @param file_path string
--- @return string
local get_document_uri = function(file_path)
    return "file://" .. file_path
end



local custom_methods = {

    --- @param buffer integer buffer number
    --- @param callback OcamllspCallback
    getDocumentation = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        local cursor = vim.api.nvim_win_get_cursor(0)

        local params = {
            textDocument = {
                uri = document_uri
            },
            position = {
                line = cursor[1] - 1,
                character = cursor[2]
            }
        }
        client.request("ocamllsp/getDocumentation", params, callback)
    end,


    --- @param buffer integer buffer number
    --- @param callback OcamllspCallback Callback for results, see :h lsp-handler
    hoverExtended = function(buffer, callback)
        local client = get_client_for_buffer(buffer)
        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end


        local cursor = vim.api.nvim_win_get_cursor(0)
        local params = {
            textDocument = "",
            position = {
                line = cursor[1] - 1,
                character = cursor[2]
            },
        }

        client.request("ocamllsp/hoverExtended", params, callback)
    end,



    --- @param buffer integer buffer number
    --- @param callback OcamllspCallback
    inferIntf = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        client.request("ocamllsp/inferIntf", { document_uri }, callback)
    end,


    --- @param buffer integer buffer number
    --- @param options MerlinCommand
    --- @param callback OcamllspCallback
    merlinCallCompatible = function(buffer, options, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        local params = {
            uri = document_uri,
            command = options.command,
            args = options.args,
            resultAsSexp = options.asSexp
        }

        client.request("ocamllsp/merlinCallCompatible", params, callback)
    end,



    --- @param buffer integer buffer number
    --- @param callback function invoked with the result
    switchImplIntf = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        client.request("ocamllsp/switchImplIntf", { document_uri }, callback)
    end,


    --- @param buffer integer buffer number
    --- @param callback function invoked with the result
    typeEnclosing = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        local params = {
            uri = document_uri,
            at = {
                line = cursor[1] - 1,
                character = cursor[2]
            },
            index = 1
        }

        client.request("ocamllsp/typeEnclosing", params, callback)
    end,


    --- @param buffer integer buffer number
    --- @param callback OcamllspCallback
    typedHoles = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        client.request("ocamllsp/typedHoles", { uri = document_uri }, callback)
    end,

    --- @param buffer integer buffer number
    --- @param callback OcamllspCallback
    wrappingAstNode = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        local params = {
            uri = document_uri,
            position = {
                line = cursor[1] - 1,
                character = cursor[2]
            }
        }

        client.request("ocamllsp/wrappingAstNode", params, callback)
    end,

    --- @param buffer integer buffer number
    --- @param callback OcamllspCallback
    construct = function(buffer, callback)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = get_document_uri(file)
        local client = get_client_for_buffer(buffer)

        if client == nil then
            local err = {
                code = 1,
                message = "No active ocamllsp instance",
            }
            log.info(err.message)
            callback(err, nil)
            return
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        local params = {
            uri = document_uri,
            position = {
                line = cursor[1] - 1,
                character = cursor[2]
            },
            -- TODO: make those options for the function
            depth = 1,
            withValues = "local"
        }

        client.request("ocamllsp/construct", params, callback)
    end,
}


local workspace_commands = {
    -- Internal command to see metrics for ocamllsp
    ["ocamllsp/view-metrics"] = function()
        vim.lsp.buf.execute_command({
            command = "ocamllsp/view-metrics",
        })
    end,

    -- This is a command normally executed via code actions. It takes a DocumentUri as a parameter,
    -- however it's the URI of the document to be opened directly. I.e. it will not open a .mli wenn
    -- a .ml URI is provided.
    ["ocamllsp/open-related-source"] = function(buffer)
        local file = vim.api.nvim_buf_get_name(buffer)
        local document_uri = "file://" .. file
        vim.lsp.buf.execute_command({
            command = "ocamllsp/open-related-source",
            arguments = { document_uri }
        })
    end,
    -- this just reads the provided URI and displays it in a buffer?
    ["ocamllsp/show-document-text"] = function(buffer)
        local file_path = vim.api.nvim_buf_get_name(buffer)
        local uri = get_document_uri(file_path)

        vim.lsp.buf.execute_command({
            command = "ocamllsp/show-document-text",
            arguments = {uri}
        })
    end,
    ["ocamllsp/show-merlin-config"] = function()
        vim.lsp.buf.execute_command({
            command = "ocamllsp/show-merlin-config",
        })
    end,
    ["dune/promote"] = function(buffer)
        local file = vim.api.nvim_buf_get_name(buffer)
        local dune_root = dune.find_dune_project(file)
        if dune_root == nil then
            vim.notify("not a dune folder", vim.log.levels.INFO)
            return
        end

        local args = {
            -- root folder of the project?
            dune = dune_root,
            -- `in_source` is the file we want to promote?
            in_source = file
        }
        vim.lsp.buf.execute_command({
            command = "dune/promote",
            arguments = { args }
        })
    end
}

--- @param diff string `git diff` output
--- @return any
function parse_git_diff(diff)
    local lines = vim.split(diff, "\n")
end

local wrap_diagnostics = function ()
    local original_handler = vim.lsp.handlers['textDocument/publishDiagnostics']
    vim.lsp.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, config)
        local diagnostics = result.diagnostics

        for _, d in ipairs(diagnostics) do
            log.info(vim.inspect(d))
            if d.source == "dune" and vim.startswith(d.message, 'diff') then
                -- TODO: remove
                -- log.info(d.message)
                
                -- local rgx = vim.regex([[@@ -(?<s>[0-9]+),(?<soffset>[0-9]+) \+(?<e>[0-9]+),(?<eoffset>[0-9]+) @@]])
                -- local test = "
                local message = vim.split(d.message, '\n')
                local positions = vim.tbl_filter(function(line)
                    return rgx:match_str(line)
                end, message)

                if #positions > 0 then
                    log.info(vim.inspect(positions))
                end

            end
        end

        original_handler(err, result, ctx, config)
    end
end


return {
    -- helpers
    get_available = get_available,
    check_available = check_available,
    wrap = wrap_diagnostics,

    -- ocamllsp specific requests
    custom_methods = custom_methods,
    workspace_commands = workspace_commands
}
