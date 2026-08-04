return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    opts = {
      ensure_installed = {
        "angularls",
        "bashls",
        "cssls",
        "docker_language_server",
        "jsonls",
        "lua_ls",
        "csharp_ls",
        "pylsp",
        "tailwindcss",
        "ts_ls",
        "yamlls",
      },
      automatic_enable = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- LSP keymaps (set on attach). K, gra, gri, grr and grt are Neovim 0.11+
      -- defaults with identical behaviour, so only the deviations live here.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local opts = { buffer = ev.buf }

          -- Go to mappings — deliberately inverted from the defaults to match IdeaVim
          vim.keymap.set("n", "grD", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
          vim.keymap.set("n", "grd", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))

          -- Rename
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))

          -- Signature help
          vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "Signature help" }))
        end,
      })

      -- Diagnostic configuration
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = true,
        },
      })

      -- Pass blink.cmp capabilities to all LSP servers (Neovim 0.11+ wildcard)
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Server configurations using vim.lsp.config (Neovim 0.11+)
      vim.lsp.config("angularls", {})
      vim.lsp.config("bashls", {})
      vim.lsp.config("cssls", {})
      vim.lsp.config("docker_language_server", {})
      vim.lsp.config("jsonls", {})
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME },
            },
            completion = { callSnippet = "Replace" },
            diagnostics = { globals = { "vim" } },
          },
        },
      })
      vim.lsp.config("csharp_ls", {})
      vim.lsp.config("pylsp", {})
      vim.lsp.config("tailwindcss", {})
      vim.lsp.config("ts_ls", {})
      vim.lsp.config("yamlls", {})

      -- Servers are enabled by mason-lspconfig's automatic_enable, driven by the
      -- single ensure_installed list above — no second list to keep in sync.
    end,
  },
}
