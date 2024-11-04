# OCaml plugin for Neovim

:warning: This is heavily under development and should be considered in alpha state :warning:

At this point the API and commands will most likely change until I can find a good setup. Expect force pushes to main,
so use at your own risk. You have been warned.

## Currently supported functions

Functionality related to `dune`:
- `:Dune ...`: will invoke the corresponding `dune` command. If `-w` is provided and `fidget.nvim` is is installed, a
  progress indicator is show
- `:DuneStop`: stop all active `dune` jobs (especially `-w` ones). 

In general this plugins stops any running `dune` process when Neovim exits (`VimLeavePre`) or when `LspDetach` is
received for the first buffer of the dune project.

Functionality related to `ocamllsp` (:warning: experimental):
- `:Ocamllsp switch`: switch between .ml and .mli files (if no .mli file exists it will create a new buffer with the
inferred signatures)
- `:Ocamllsp hole`: switches to the next typed hole


## Configuration

```lua
require("ocamlmycaml").setup({
    dune = {
        auto_start = true    -- will execute `dune build -w` when opening the first file in a dune project
    }
})
```

or with Lazy

```lua
{
    "MoritzHamann/ocamlmycaml.nvim",
    opts = {
        dune = {
            auto_start = true    -- will execute `dune build -w` when opening the first file in a dune project
        }
    }
}

```

## API
Unstable, but feel free to checkout out the `lua` subfolder. All exported functions are in the `M` module of each file.

