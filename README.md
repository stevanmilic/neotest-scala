# neotest-scala

[Neotest](https://github.com/rcarriga/neotest) adapter for scala. Supports [utest](https://github.com/com-lihaoyi/utest), [munit](https://scalameta.org/munit/docs/getting-started.html) and [ScalaTest](https://www.scalatest.org/) test frameworks, by either running it with [bloop](https://scalacenter.github.io/bloop/) or sbt. Note that for ScalaTest the only supported style is FunSuite for now.

It also supports debugging tests with [nvim-dap](https://github.com/rcarriga/nvim-dap) (requires [nvim-metals](https://github.com/scalameta/nvim-metals)), at the moment you can only debug a specific test file (hint: use breakpoints on test functions to breakdown execution). Once [passing arguments to test framework](https://github.com/scalameta/metals-feature-requests/issues/216) is completed in metals, debugging specific test case could be done.

Requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and the parser for scala.

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "nvim-neotest/neotest",
  requires = {
    ...,
    "stevanmilic/neotest-scala",
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
        -- Possibly values bloop|sbt.
        runner = "bloop",
        -- Test framework to use. Will use utest by default.
        -- Can be a function to return dynamic value.
        -- Possibly values utest|munit|scalatest.
        framework = "utest",
    })
  }
})
```

## Roadmap

To be implemented:

- Displaying errors in diagnostics
