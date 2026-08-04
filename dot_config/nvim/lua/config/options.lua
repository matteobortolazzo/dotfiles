local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Scrolling
opt.scrolloff = 5

-- Clipboard
opt.clipboard = "unnamedplus"

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- UI (termguicolors is auto-detected since 0.10)
opt.signcolumn = "yes"
opt.cursorline = true
opt.splitright = true
opt.splitbelow = true

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300

-- Undo
opt.undofile = true

-- Folding (treesitter-based; global so every window folds, not just the one
-- that happened to trigger FileType. foldlevel keeps everything open on load.)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
