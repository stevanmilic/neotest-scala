# neotest-scala

[Neotest](https://github.com/rcarriga/neotest) adapter for scala. Supports only [utest](https://github.com/com-lihaoyi/utest) test framework (for now), by either running it with [bloop](https://scalacenter.github.io/bloop/) or sbt.

Requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and the parser for scala.

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "nvim-neotest/neotest",
  requires = {
    ...,
    "nvim-neotest/neotest-scala",
  }
  config = function()
    require("neotest").setup({
      ...,
      adapters = {
        require("neotest-scala"),
      }
    })
  end
})
```

## Configuration

You can set optional arguments to the setup function:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-scala")({
        -- Command line arguments for runner
        -- Can also be a function to return dynamic values
        args = {"--no-color"},
        -- Runner to use. Will use bloop by default.
        -- Can be a function to return dynamic value.
        -- For backwards compatibility, it also tries to read the vim-test scala config.
        runner = "bloop",
    })
  }
})
```

## Roadmap

To be implemented:

- Support for ScalaTest
- Support for nvim-dap
- Displaying errors in diagnostics
