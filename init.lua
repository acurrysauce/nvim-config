vim.opt.clipboard:append("unnamedplus")

-- Line numbers
vim.opt.nu = true
vim.opt.relativenumber = true

-- Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 2

-- Auto-reload files when changed externally
vim.opt.autoread = true
vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "CursorHold", "CursorHoldI"}, {
  callback = function()
    if vim.fn.mode() ~= 'c' then
      vim.cmd("checktime")
    end
  end,
})

-- Set updatetime for CursorHold events
vim.opt.updatetime = 100

-- Split borders and styling
vim.opt.fillchars:append({ vert = '│', horiz = '─', vertleft = '┤', vertright = '├', verthoriz = '┼' })
vim.opt.laststatus = 3  -- Global statusline

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
      
      -- LSP keybindings
      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, silent = true }
        
        -- Navigation
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        
        -- Actions
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        
        -- Diagnostics
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
        vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
      end
      
      -- Setup LSP servers with completion capabilities and keybindings
      lspconfig.lua_ls.setup({ 
        capabilities = capabilities,
        on_attach = on_attach 
      })
      lspconfig.pyright.setup({ 
        capabilities = capabilities,
        on_attach = on_attach 
      })
      lspconfig.ts_ls.setup({ 
        capabilities = capabilities,
        on_attach = on_attach 
      })
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
      
      -- Override default Python DAP config to use project root as working directory
      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch file',
          program = '${file}',
          cwd = '${workspaceFolder}',  -- Use project root as working directory
          pythonPath = function()
            -- Try to find virtual environment, fallback to system python
            local venv_path = vim.fn.getcwd() .. '/.venv/bin/python'
            if vim.fn.executable(venv_path) == 1 then
              return venv_path
            end
            return 'python'
          end,
        },
      }
      
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
      vim.keymap.set("n", "<leader>dz", function() dapui.open({reset=true}) end)
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
              ["<C-h>"] = "which_key",
              ["<C-x>"] = require("telescope.actions").select_horizontal,
              ["<C-v>"] = require("telescope.actions").select_vertical
            },
            n = {
              ["<C-x>"] = require("telescope.actions").select_horizontal,
              ["<C-v>"] = require("telescope.actions").select_vertical
            }
          }
        },
        pickers = {
          buffers = {
            mappings = {
              i = {
                ["<C-d>"] = require("telescope.actions").delete_buffer
              },
              n = {
                ["<C-d>"] = require("telescope.actions").delete_buffer
              }
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
      vim.keymap.set("n", "<leader>/", builtin.current_buffer_fuzzy_find, { desc = "Search in current buffer" })
      
      -- Visual mode: search for selected text in current buffer
      vim.keymap.set("v", "<leader>ft", function()
        -- Get selected text using a more reliable method
        vim.cmd('normal! "zy')  -- Yank selected text to register z
        local selected_text = vim.fn.getreg('z')
        
        -- Clean up the selected text (remove newlines, trim whitespace)
        selected_text = selected_text:gsub('\n.*', '')  -- Take only first line if multi-line
        selected_text = selected_text:match('^%s*(.-)%s*$')  -- Trim whitespace
        
        -- Exit visual mode
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
        
        -- Run telescope with the selected text as default (only if not empty)
        if selected_text and selected_text ~= "" then
          builtin.current_buffer_fuzzy_find({ default_text = selected_text })
        else
          builtin.current_buffer_fuzzy_find()
        end
      end, { desc = "Search selected text in current buffer" })
    end,
  },
  
  -- Telescope FZF extension (optional but recommended)
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
  },
  
  -- File operations (delete, rename, etc.)
  {
    "tpope/vim-eunuch",
  },
  
  -- Treesitter for better syntax highlighting and folding
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "python", "lua", "javascript", "typescript" },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
        fold = { enable = true },
      })
    end,
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
      -- Set split separators after colorscheme loads
      vim.api.nvim_set_hl(0, 'WinSeparator', { fg = '#7aa2f7', bg = 'NONE' })  -- Tokyo Night blue
      vim.api.nvim_set_hl(0, 'VertSplit', { fg = '#7aa2f7', bg = 'NONE' })  -- Fallback
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
    "═══════════════════════════════════════════════════════════════════════════════════════════════════════",
    "                                        NVIM KEYBINDINGS HELP",
    "═══════════════════════════════════════════════════════════════════════════════════════════════════════",
    "",
    "🔧 BASIC NVIM                      📁 BUFFERS & NAVIGATION          🔍 TELESCOPE (Leader = Space)",
    "  u           - Undo                 :ls         - List buffers        <leader>ff  - Find files",
    "  Ctrl+r      - Redo                 :b1, :b2    - Switch to buffer    <leader>fg  - Live grep", 
    "  Ctrl+o      - Jump back            :bn         - Next buffer         <leader>fb  - Find buffers",
    "  Ctrl+i      - Jump forward         :bp         - Previous buffer     <leader>fh  - Help tags",
    "  Ctrl+u      - Scroll up half page  Ctrl+^      - Toggle last buffer  <leader>fr  - Recent files",
    "  Ctrl+d      - Scroll down half page                                  <leader>fs  - Document symbols",
    "  {           - Jump to prev paragraph                                 <leader>fw  - Workspace symbols",
    "  }           - Jump to next paragraph",
    "",
    "🪟 VIM SPLITS                      🪟 VIM SPLIT NAVIGATION           🪟 VIM SPLIT SIZING",
    "  :split      - Horizontal split     Ctrl+w h    - Move to left split   Ctrl+w +    - Increase height",
    "  :vsplit     - Vertical split       Ctrl+w j    - Move to split below  Ctrl+w -    - Decrease height",
    "  :sp         - Horizontal split     Ctrl+w k    - Move to split above  Ctrl+w >    - Increase width", 
    "  :vsp        - Vertical split       Ctrl+w l    - Move to right split  Ctrl+w <    - Decrease width",
    "  Ctrl+w s    - Horizontal split     Ctrl+w w    - Cycle through splits  Ctrl+w =    - Equalize sizes",
    "  Ctrl+w v    - Vertical split       Ctrl+w p    - Previous split       Ctrl+w |    - Max width",
    "  Ctrl+w q    - Close split          Ctrl+w o    - Close other splits   Ctrl+w _    - Max height",
    "  Ctrl+w c    - Close split          :resize 20  - Set height to 20     :vertical resize 50 - Set width",
    "",
    "📝 LSP                             🎯 VIM-VISUAL-MULTI              🐛 DAP DEBUGGING",
    "  gd          - Go to definition     Ctrl+n      - Select word         <leader>db  - Toggle breakpoint",
    "  K           - Hover documentation  Ctrl+A      - Select all instances <leader>dc  - Continue",
    "  gi          - Go to implementation Ctrl+↑/↓    - Add cursor above/below <leader>ds - Step over",
    "  gr          - Go to references     q           - Skip current selection <leader>di - Step into",
    "  <leader>rn  - Rename symbol        Q           - Remove current cursor <leader>do  - Step out",
    "  <leader>ca  - Code actions         c           - Change selected text <leader>dr  - Open repl",
    "  [d          - Previous diagnostic  i           - Insert at beginning  <leader>du  - Toggle UI",
    "  ]d          - Next diagnostic      a           - Insert at end",
    "  <leader>e   - Show diagnostic float I           - Insert at line start",
    "                                     A           - Insert at line end",
    "                                     Esc         - Exit multi-cursor",
    "",
    "💡 SEARCH & REPLACE                🌳 LAZYGIT                       🔧 TERMINAL MODE",
    "  *           - Search word under cursor  <leader>gg  - Open LazyGit       Ctrl+\\ Ctrl+n - Exit terminal mode",
    "  /pattern    - Search for pattern",
    "  :noh        - Clear search highlighting",
    "  :%s/old/new/g - Replace all occurrences",
    "  cgn         - Change next search match",
    "",
    "📁 FILE OPERATIONS (vim-eunuch)",
    "  :Delete     - Delete current file and close buffer",
    "  :Remove     - Alias for :Delete",
    "  :Rename     - Rename current file",
    "  :Move       - Move/rename file to new path",
    "  :Copy       - Copy current file",
    "  :Mkdir      - Create directory",
    "",
    "📺 TMUX LAYOUTS                    📺 TMUX LAYOUT SHORTCUTS",
    "  :select-layout even-horizontal    Alt+1  - Even horizontal (vertical panes)",
    "  :select-layout even-vertical      Alt+2  - Even vertical (horizontal panes)",  
    "  :select-layout main-horizontal    Alt+3  - Main horizontal (large top pane)",
    "  :select-layout main-vertical      Alt+4  - Main vertical (large left pane)",
    "  :select-layout tiled              Alt+5  - Tiled (all panes same size)",
    "",
    "═══════════════════════════════════════════════════════════════════════════════════════════════════════",
    "Press 'q' to close this help buffer",
    "═══════════════════════════════════════════════════════════════════════════════════════════════════════",
  }
  
  -- Check if help buffer already exists and close it
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    if buf_name:match('Keybindings Help') then
      vim.api.nvim_buf_delete(buf_id, { force = true })
    end
  end
  
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer content first while it's modifiable
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_content)
  
  -- Then set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  
  -- Open in a new tab
  vim.cmd('tabnew')
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

-- Make x in visual mode delete to black hole register (preserve main register)
vim.keymap.set('v', 'x', '"_x', { desc = "Delete selection to black hole register" })

-- Comment toggle mapping for Ctrl+/
-- Function to toggle line comments
local function toggle_comment()
  local line = vim.api.nvim_get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  
  -- Get the comment string for the current filetype
  local commentstring = vim.bo.commentstring
  if commentstring == "" then
    -- Default to # for Python-like comments
    commentstring = "# %s"
  end
  
  -- Extract the comment prefix (remove %s part)
  local comment_prefix = commentstring:gsub("%%s", ""):gsub("%s+$", "")
  
  -- Check if line is already commented
  local trimmed_line = line:match("^%s*(.-)%s*$")
  if trimmed_line:match("^" .. vim.pesc(comment_prefix)) then
    -- Uncomment: remove comment prefix
    local new_line = line:gsub("^(%s*)" .. vim.pesc(comment_prefix) .. "%s?", "%1")
    vim.api.nvim_set_current_line(new_line)
  else
    -- Comment: add comment prefix
    local indent = line:match("^%s*")
    local content = line:match("^%s*(.*)$")
    if content == "" then
      -- Empty line, just add comment
      vim.api.nvim_set_current_line(indent .. comment_prefix)
    else
      -- Non-empty line, add comment prefix
      vim.api.nvim_set_current_line(indent .. comment_prefix .. " " .. content)
    end
  end
end

-- Function to toggle comments in visual line mode
local function toggle_visual_comment()
  -- Check if we're in visual line mode
  local mode = vim.fn.mode()
  if mode ~= 'V' then
    return  -- Only work in visual line mode
  end
  
  -- Get current visual selection bounds directly
  local start_line = vim.fn.line('v')
  local end_line = vim.fn.line('.')
  
  -- Ensure start_line is actually the start
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  
  -- Get the comment string for the current filetype
  local commentstring = vim.bo.commentstring
  if commentstring == "" then
    commentstring = "# %s"  -- Default to Python-style comments
  end
  
  -- Extract the comment prefix (remove %s part and trailing spaces)
  local comment_prefix = commentstring:gsub("%%s", ""):gsub("%s+$", "")
  
  -- Check if all selected lines are commented
  local all_commented = true
  for line_num = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
    if line then
      local trimmed_line = line:match("^%s*(.-)%s*$")
      -- Skip empty lines when checking if all are commented
      if trimmed_line and trimmed_line ~= "" then
        if not trimmed_line:match("^" .. vim.pesc(comment_prefix)) then
          all_commented = false
          break
        end
      end
    end
  end
  
  -- Toggle comments for each line
  for line_num = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
    if line then
      local new_line
      
      if all_commented then
        -- Uncomment: remove comment prefix and optional space
        new_line = line:gsub("^(%s*)" .. vim.pesc(comment_prefix) .. "%s?", "%1")
      else
        -- Comment: add comment prefix after any leading whitespace
        local indent = line:match("^%s*") or ""
        local content = line:match("^%s*(.*)$") or ""
        new_line = indent .. comment_prefix .. " " .. content
      end
      
      vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, {new_line})
    end
  end
end

-- Map Ctrl+/ to toggle comments in normal, insert, and visual modes
vim.keymap.set('n', '<C-_>', toggle_comment, { desc = "Toggle line comment" })
vim.keymap.set('i', '<C-_>', function()
  toggle_comment()
end, { desc = "Toggle line comment" })
-- Only map in visual line mode, not regular visual mode
vim.keymap.set('x', '<C-_>', function()
  toggle_visual_comment()
end, { desc = "Toggle comment on selected lines" })
