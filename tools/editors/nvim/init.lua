-- Install packer first:
-- git clone --depth 1 https://github.com/wbthomason/packer.nvim\
-- ~/.local/share/nvim/site/pack/packer/start/packer.nvim

-- macOS specific settings
vim.opt.clipboard = 'unnamedplus'  -- Use system clipboard
vim.opt.backupdir = os.getenv("HOME") .. '/.local/share/nvim/backup'  -- macOS backup directory
vim.opt.undodir = os.getenv("HOME") .. '/.local/share/nvim/undo'      -- persistent undo directory
vim.opt.undofile = true

vim.cmd [[packadd packer.nvim]]

require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- Theme
  use 'folke/tokyonight.nvim'

  -- Fuzzy finder
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} }
  }

  -- Treesitter for better syntax highlighting
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate'
  }

  -- LSP Support
  use {
    'neovim/nvim-lspconfig',
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
  }

  -- Autocompletion
  use {
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'L3MON4D3/LuaSnip',
  }

  -- File explorer
  use {
    'nvim-tree/nvim-tree.lua',
    requires = {
      'nvim-tree/nvim-web-devicons',
    },
  }

  -- Status line
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'nvim-tree/nvim-web-devicons' }
  }

  -- Git integration
  use {
    'lewis6991/gitsigns.nvim',    -- Git signs in the gutter
    'tpope/vim-fugitive',         -- Git commands in nvim
    'sindrets/diffview.nvim',     -- Better diff viewing
  }

  -- Markdown support
  use {
    'iamcco/markdown-preview.nvim',
    run = function() vim.fn['mkdp#util#install']() end,
  }
  use 'preservim/vim-markdown'    -- Markdown syntax highlighting
  use 'godlygeek/tabular'        -- Needed for vim-markdown

  -- YAML support
  use 'cuducos/yaml.nvim'
  use {
    'someone-stole-my-name/yaml-companion.nvim',
    requires = {
      { 'neovim/nvim-lspconfig' },
      { 'nvim-lua/plenary.nvim' },
      { 'nvim-telescope/telescope.nvim' },
    },
  }

  -- Github Copilot
  use 'github/copilot.vim'

  -- IDE-like features
  use {
    'akinsho/bufferline.nvim',          -- VSCode-like tabs
    tag = "*",
    requires = 'nvim-tree/nvim-web-devicons'
  }
  use 'lukas-reineke/indent-blankline.nvim'  -- Indentation guides
  use 'folke/trouble.nvim'              -- Better error list
  use 'folke/which-key.nvim'            -- Command palette helper
  use {
    'numToStr/Comment.nvim',            -- Easy code commenting
    config = function() require('Comment').setup() end
  }
  use {
    "folke/todo-comments.nvim",         -- Highlight TODO comments
    requires = "nvim-lua/plenary.nvim",
  }
  use 'simrat39/symbols-outline.nvim'   -- Code outline/structure
  use {
    'folke/noice.nvim',                 -- Better UI for commands
    requires = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    }
  }
  use 'j-hui/fidget.nvim'               -- LSP progress UI
  use {
    'stevearc/aerial.nvim',             -- Code outline sidebar
    config = function() require('aerial').setup() end
  }
end)

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50

-- Set leader key to space
vim.g.mapleader = " "

-- Theme setup
vim.cmd[[colorscheme tokyonight-storm]]

-- Font settings (if using Neovide or other GUI)
vim.o.guifont = "MonaLisa:h13"

-- Basic keymaps
local keymap = vim.keymap.set
keymap('n', '<leader>ff', '<cmd>Telescope find_files<cr>')
keymap('n', '<leader>fg', '<cmd>Telescope live_grep<cr>')
keymap('n', '<leader>e', '<cmd>NvimTreeToggle<cr>')

-- LSP setup
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    "gopls",    -- Go
    "tsserver", -- TypeScript/JavaScript
  },
})

local lspconfig = require('lspconfig')
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Go LSP setup
lspconfig.gopls.setup{
  capabilities = capabilities,
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
}

-- TypeScript/JavaScript LSP setup
lspconfig.tsserver.setup{
  capabilities = capabilities,
}

-- Autocompletion setup
local cmp = require('cmp')
cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer' },
  })
})

-- Tree-sitter setup
require('nvim-treesitter.configs').setup{
  ensure_installed = { "go", "javascript", "typescript", "lua", "yaml", "markdown" },
  highlight = {
    enable = true,
  },
}

-- Nvim-tree setup
require("nvim-tree").setup()

-- Lualine setup
require('lualine').setup{
  options = {
    theme = 'tokyonight'
  }
}

-- Git signs configuration
require('gitsigns').setup{
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
  current_line_blame = true,  -- Toggle with :Gitsigns toggle_current_line_blame
}

-- Markdown configuration
vim.g.vim_markdown_folding_disabled = 1
vim.g.vim_markdown_frontmatter = 1
vim.g.vim_markdown_auto_insert_bullets = 1
vim.g.vim_markdown_new_list_item_indent = 2
vim.g.mkdp_auto_close = 0
vim.g.mkdp_open_to_the_world = 0

-- Additional keymaps for new plugins
keymap('n', '<leader>md', '<cmd>MarkdownPreview<CR>')        -- Preview markdown
keymap('n', '<leader>gd', '<cmd>DiffviewOpen<CR>')           -- Open git diff view
keymap('n', '<leader>gc', '<cmd>DiffviewClose<CR>')          -- Close git diff view
keymap('n', '<leader>gb', '<cmd>Gitsigns toggle_current_line_blame<CR>') -- Toggle git blame
keymap('n', '<leader>gh', '<cmd>Gitsigns preview_hunk<CR>')  -- Preview git hunk

-- YAML LSP setup
local yaml_companion = require("yaml-companion").setup({
  builtin_matchers = {
    kubernetes = { enabled = true },
  },
  lspconfig = {
    settings = {
      yaml = {
        schemas = {
          ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
          ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose.yml",
        },
      },
    },
  },
})

lspconfig.yamlls.setup(yaml_companion)

-- IDE feature configurations
-- Bufferline (tabs) setup
require("bufferline").setup{
  options = {
    numbers = "ordinal",
    diagnostics = "nvim_lsp",
    separator_style = "slant",
    show_buffer_close_icons = true,
    show_close_icon = true,
  }
}

-- Better error display
require("trouble").setup{
  position = "bottom",
  icons = true,
  mode = "workspace_diagnostics",
  auto_preview = true,
}

-- Command palette helper
require("which-key").setup{}

-- TODO comments
require("todo-comments").setup{}

-- Better UI
require("noice").setup{
  lsp = {
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
  },
}

-- LSP progress UI
require("fidget").setup{}

-- Indentation guides
require("indent_blankline").setup{
  show_current_context = true,
  show_current_context_start = true,
}

-- Code outline
require("aerial").setup{
  on_attach = function(bufnr)
    vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", {buffer = bufnr})
    vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", {buffer = bufnr})
  end
}

-- Copilot configuration
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true
vim.g.copilot_tab_fallback = ""
-- Use Alt-] to accept Copilot suggestion
vim.api.nvim_set_keymap('i', '<M-]>', 'copilot#Accept("\\<CR>")', { expr = true, silent = true })
-- Use Alt-[ to cycle to next suggestion
vim.api.nvim_set_keymap('i', '<M-[>', '<Plug>(copilot-next)', {})
-- Use Alt-\ to show Copilot suggestions
vim.api.nvim_set_keymap('i', '<M-\\>', '<Plug>(copilot-suggest)', {})

-- Additional IDE-like keymaps
keymap('n', '<leader>xx', '<cmd>TroubleToggle<cr>')                    -- Toggle diagnostics
keymap('n', '<leader>xw', '<cmd>TroubleToggle workspace_diagnostics<cr>') -- Toggle workspace diagnostics
keymap('n', '<leader>o', '<cmd>AerialToggle<cr>')                      -- Toggle code outline
keymap('n', 'gcc', '<cmd>Commentary<CR>')                              -- Toggle comment
keymap('n', '<leader>fb', '<cmd>Telescope buffers<cr>')                -- Show open buffers
keymap('n', '<leader>fs', '<cmd>Telescope lsp_document_symbols<cr>')    -- Search symbols
keymap('n', '<leader>fr', '<cmd>Telescope lsp_references<cr>')          -- Find references
keymap('n', '<leader>fd', '<cmd>Telescope lsp_definitions<cr>')         -- Find definitions
keymap('n', '<C-p>', '<cmd>Telescope commands<cr>')                     -- Command palette
keymap('n', '<C-b>', '<cmd>NvimTreeFocus<cr>')                         -- Focus file explorer
keymap('n', '<C-j>', '<cmd>Telescope jumplist<cr>')                     -- Jump list
keymap('n', '<leader>tt', '<cmd>Telescope<cr>')                         -- Open Telescope

-- Tab navigation like VSCode
keymap('n', '<C-Tab>', '<cmd>BufferLineCycleNext<cr>')
keymap('n', '<C-S-Tab>', '<cmd>BufferLineCyclePrev<cr>')

-- LSP additional keybindings (IDE-like)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local opts = {buffer = args.buf}

    -- GoLand/VSCode like keybindings
    keymap('n', 'gD', vim.lsp.buf.declaration, opts)
    keymap('n', 'gd', vim.lsp.buf.definition, opts)
    keymap('n', 'K', vim.lsp.buf.hover, opts)
    keymap('n', 'gi', vim.lsp.buf.implementation, opts)
    keymap('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    keymap('n', '<leader>rn', vim.lsp.buf.rename, opts)
    keymap('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    keymap('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)
  end,
})