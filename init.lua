vim.opt.clipboard:append("unnamedplus")

-- Line numbers
vim.opt.nu = true
vim.opt.relativenumber = true

-- Set leader key to space
vim.g.mapleader = " "

-- Bootstrap lazy.nvim package manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup plugins
require("lazy").setup({
  -- Mason for LSP/formatter/linter management
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  
  -- Mason LSP config integration
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "ts_ls" },
      })
    end,
  },
  
  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- Setup LSP servers with completion capabilities
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.pyright.setup({ capabilities = capabilities })
      lspconfig.ts_ls.setup({ capabilities = capabilities })
    end,
  },
  
  -- Completion plugin
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },
  
  -- Debug Adapter Protocol
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      
      -- Setup DAP UI
      dapui.setup()
      
      -- Setup Python debugging
      require("dap-python").setup("python")
      
      -- Auto-load project-specific DAP configs
      local function load_project_dap_config()
        local project_dap_file = vim.fn.getcwd() .. "/.nvim/dap.lua"
        if vim.fn.filereadable(project_dap_file) == 1 then
          dofile(project_dap_file)
        end
      end
      
      -- Load project config on startup and when changing directories
      load_project_dap_config()
      vim.api.nvim_create_autocmd("DirChanged", {
        callback = load_project_dap_config,
      })
      
      -- Auto open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
      
      -- Keybindings
      vim.keymap.set("n", "<F5>", dap.continue)
      vim.keymap.set("n", "<F10>", dap.step_over)
      vim.keymap.set("n", "<F11>", dap.step_into)
      vim.keymap.set("n", "<F12>", dap.step_out)
      vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint)
      vim.keymap.set("n", "<leader>B", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end)
      vim.keymap.set("n", "<leader>dr", dap.repl.open)
      vim.keymap.set("n", "<leader>dl", dap.run_last)
      vim.keymap.set("n", "<leader>du", dapui.toggle)
    end,
  },
  
  -- Telescope fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")
      
      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<C-h>"] = "which_key"
            }
          }
        }
      })
      
      -- Keybindings
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
      vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
      vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
      vim.keymap.set("n", "<leader>fw", builtin.lsp_workspace_symbols, { desc = "Workspace symbols" })
    end,
  },
  
  -- Telescope FZF extension (optional but recommended)
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
  },
  
  -- LazyGit integration
  {
    "kdheepak/lazygit.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "Open LazyGit" })
    end,
  },
  
  -- Tokyo Night colorscheme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd("colorscheme tokyonight")
    end,
  },
  
  -- Multi-cursor support
  {
    "mg979/vim-visual-multi",
    config = function()
      -- Optional: Configure vim-visual-multi settings
      vim.g.VM_maps = {
        ["Find Under"] = "<C-n>",
        ["Find Subword Under"] = "<C-n>",
        ["Select All"] = "<C-A>",
        ["Start Regex Search"] = "<C-/>",
        ["Add Cursor Down"] = "<C-Down>",
        ["Add Cursor Up"] = "<C-Up>",
      }
    end,
  },
})

-- Custom help keybindings command
vim.api.nvim_create_user_command('HK', function()
  local help_content = {
    "═══════════════════════════════════════════════════════════════",
    "                      NVIM KEYBINDINGS HELP",
    "═══════════════════════════════════════════════════════════════",
    "",
    "🔧 BASIC NVIM",
    "  Ctrl+r              - Redo", 
    "  Ctrl+o              - Jump back",
    "  Ctrl+i              - Jump forward",
    "",
    "💡 SEARCH & REPLACE",
    "  *                   - Search word under cursor",
    "  /pattern            - Search for pattern",
    "  :noh                - Clear search highlighting",
    "  :%s/old/new/g       - Replace all occurrences",
    "  cgn                 - Change next search match",
    "",
    "📁 BUFFERS & NAVIGATION",
    "  :ls                 - List buffers",
    "  :b1, :b2            - Switch to buffer number",
    "  :bn                 - Next buffer",
    "  :bp                 - Previous buffer",
    "  Ctrl+^              - Toggle last buffer",
    "",
    "🔍 TELESCOPE (Leader = Space)",
    "  <leader>ff          - Find files",
    "  <leader>fg          - Live grep",
    "  <leader>fb          - Find buffers",
    "  <leader>fh          - Help tags",
    "  <leader>fr          - Recent files",
    "  <leader>fs          - Document symbols",
    "  <leader>fw          - Workspace symbols",
    "",
    "🎯 VIM-VISUAL-MULTI",
    "  Ctrl+n              - Select word under cursor",
    "  Ctrl+A              - Select all instances",
    "  Ctrl+Down/Up        - Add cursor above/below",
    "  q                   - Skip current selection",
    "  Q                   - Remove current cursor",
    "  Esc                 - Exit multi-cursor mode",
    "",
    "🐛 DAP DEBUGGING",
    "  <leader>db          - Toggle breakpoint",
    "  <leader>dc          - Continue",
    "  <leader>ds          - Step over",
    "  <leader>di          - Step into",
    "  <leader>do          - Step out",
    "  <leader>dr          - Open repl",
    "  <leader>du          - Toggle UI",
    "",
    "📝 LSP",
    "  gd                  - Go to definition",
    "  K                   - Hover documentation",
    "  <leader>rn          - Rename",
    "  <leader>ca          - Code actions",
    "  [d                  - Previous diagnostic",
    "  ]d                  - Next diagnostic",
    "",
    "🔧 TERMINAL MODE",
    "  Ctrl+\\ Ctrl+n      - Exit terminal mode",
    "",
    "💡 SEARCH & REPLACE",
    "  *                   - Search word under cursor",
    "  /pattern            - Search for pattern",
    "  :noh                - Clear search highlighting",
    "  :%s/old/new/g       - Replace all occurrences",
    "  cgn                 - Change next search match",
    "",
    "═══════════════════════════════════════════════════════════════",
    "Press 'q' to close this help buffer",
    "═══════════════════════════════════════════════════════════════",
  }
  
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer content first while it's modifiable
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_content)
  
  -- Then set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  
  -- Open in a split window
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Set window height
  vim.api.nvim_win_set_height(0, math.min(#help_content + 2, vim.o.lines - 5))
  
  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'Keybindings Help')
  
  -- Map 'q' to close the buffer
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
  
  -- Set cursor to top
  vim.api.nvim_win_set_cursor(0, {1, 0})
end, {})

-- Also create a shorter alias
vim.api.nvim_create_user_command('Help', 'HK', {})
