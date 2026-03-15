-- Plugin para mejorar la gestión de imports en TypeScript/JavaScript
return {
  -- TypeScript Tools para mejor manejo de imports
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      settings = {
        -- Organizar imports automáticamente
        tsserver_file_preferences = {
          includeCompletionsForModuleExports = true,
          includeCompletionsWithInsertText = true,
          autoImportFileExcludePatterns = {
            "node_modules/*",
            ".git/*",
          },
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
        -- Comando para organizar imports y remover sin usar
        expose_as_code_action = "all",
        tsserver_format_options = {
          allowIncompleteCompletions = false,
          allowRenameOfImportPath = true,
        },
      },
      handlers = {
        -- Mejorar la velocidad de autocompletado
        ["textDocument/publishDiagnostics"] = function(...)
          vim.lsp.diagnostic.on_publish_diagnostics(...)
        end,
      },
    },
    config = function(_, opts)
      require("typescript-tools").setup(opts)
      
      -- Comandos adicionales
      vim.api.nvim_create_user_command("TSOrganizeImports", function()
        vim.cmd("TSToolsOrganizeImports")
      end, { desc = "Organize imports (TypeScript Tools)" })
      
      vim.api.nvim_create_user_command("TSRemoveUnused", function()
        vim.cmd("TSToolsRemoveUnused")
      end, { desc = "Remove unused imports (TypeScript Tools)" })
      
      vim.api.nvim_create_user_command("TSAddMissingImports", function()
        vim.cmd("TSToolsAddMissingImports")
      end, { desc = "Add missing imports (TypeScript Tools)" })
    end,
  },
  
  -- Treesitter para mejor sintaxis (si no está instalado)
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "typescript",
        "tsx",
        "javascript",
      })
    end,
  },
}
