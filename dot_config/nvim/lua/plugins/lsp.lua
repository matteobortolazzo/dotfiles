return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
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
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    opts = {
      ensure_installed = {
        "angularls",
        "bashls",
        "cssls",
        "docker_language_server",
        "jsonls",
        "lua_ls",
        "omnisharp",
        "pylsp",
        "tailwindcss",
        "ts_ls",
        "yamlls",
      },
      automatic_installation = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
    },
    config = function()
      -- LSP keymaps (set on attach)
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local opts = { buffer = ev.buf }

          -- Go to mappings (matching IdeaVim)
          vim.keymap.set("n", "grD", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
          vim.keymap.set("n", "grd", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
          vim.keymap.set("n", "gri", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "Go to implementation" }))
          vim.keymap.set("n", "grr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Find references" }))
          vim.keymap.set("n", "grt", vim.lsp.buf.type_definition, vim.tbl_extend("force", opts, { desc = "Go to type definition" }))

          -- Code actions
          vim.keymap.set({ "n", "v" }, "gra", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))

          -- Rename
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))

          -- Hover and signature
          vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover documentation" }))
          vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "Signature help" }))

          -- Format
          vim.keymap.set("n", "<leader>f", function()
            vim.lsp.buf.format({ async = true })
          end, vim.tbl_extend("force", opts, { desc = "Format buffer" }))
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
      vim.lsp.config("omnisharp", {})
      vim.lsp.config("pylsp", {})
      vim.lsp.config("tailwindcss", {})
      vim.lsp.config("ts_ls", {})
      vim.lsp.config("yamlls", {})

      -- Enable all configured servers
      vim.lsp.enable({
        "angularls",
        "bashls",
        "cssls",
        "docker_language_server",
        "jsonls",
        "lua_ls",
        "omnisharp",
        "pylsp",
        "tailwindcss",
        "ts_ls",
        "yamlls",
      })
    end,
  },
}
