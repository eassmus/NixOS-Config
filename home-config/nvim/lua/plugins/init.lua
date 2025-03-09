return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform"
  }, -- These are some examples, uncomment them if you want to see them work!
  {"neovim/nvim-lspconfig", config = function() require "configs.lspconfig" end},
  {
    'mrcjkb/rustaceanvim',
    version = '^5', -- Recommended
    lazy = false, -- This plugin is already lazy
    ft = "rust",
    config = function()
      local mason_registry = require('mason-registry')
      local codelldb = mason_registry.get_package("codelldb")
      local extension_path = codelldb:get_install_path() .. "/extension/"
      local codelldb_path = extension_path .. "adapter/codelldb"
      local liblldb_path = extension_path .. "lldb/lib/liblldb.so"
      local cfg = require('rustaceanvim.config')

      vim.g.rustaceanvim = {
        dap = {adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path)}
      }
    end
  }, {
    "Exafunction/codeium.nvim",
    lazy = false,
    dependencies = {"nvim-lua/plenary.nvim", "hrsh7th/nvim-cmp"},
    config = function()
      require("codeium").setup({
        -- Optionally disable cmp source if using virtual text only
        enable_cmp_source = false,
        virtual_text = {
          enabled = true,
          manual = false,
          filetypes = {python = true, cpp = false, rs = true},
          default_filetype_enabled = true,
          idle_delay = 75,
          virtual_text_priority = 65535,
          map_keys = true,
          -- The key to press when hitting the accept keybinding but no completion is showing.
          -- Defaults to \t normally or <c-n> when a popup is showing. 
          accept_fallback = "",
          -- Key bindings for managing completions in virtual text mode.
          key_bindings = {
            -- Accept the current completion.
            accept = "<C-a>",
            -- Accept the next word.
            accept_word = false,
            -- Accept the next line.
            accept_line = false,
            -- Clear the virtual text.
            clear = false,
            -- Cycle to the next completion.
            next = "<M-]>",
            -- Cycle to the previous completion.
            prev = "<M-[>"
          }
        }
      })
    end
  }, {
    'rust-lang/rust.vim',
    ft = "rust",
    init = function() vim.g.rustfmt_autosave = 1 end
  }, {
    'mfussenegger/nvim-dap',
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end
  }, {
    'rcarriga/nvim-dap-ui',
    dependencies = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"},
    config = function() require("dapui").setup() end
  }, {
    'saecki/crates.nvim',
    ft = {"toml"},
    config = function()
      require("crates").setup {completion = {cmp = {enabled = true}}}
      require('cmp').setup.buffer({sources = {{name = "crates"}}})
    end
  }, {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc", "html", "css", "python", "rust", "cpp",
        "javascript", "typescript", "yaml", "toml", "json", "bash", "glsl",
        "nix"
      },
      highlight = {enable = true}
    }
  }
}
