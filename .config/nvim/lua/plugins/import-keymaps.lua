return {
  {
    "LazyVim/LazyVim",
    opts = {
      -- Configurar keymaps para imports
      keys = {
        -- Organizar imports con <leader>co (code organize)
        {
          "<leader>co",
          function()
            vim.lsp.buf.code_action({
              context = {
                only = { "source.organizeImports" },
                diagnostics = {},
              },
              apply = true,
            })
          end,
          desc = "Organize Imports",
        },
        
        -- Agregar import faltante con <leader>ci (code import)
        {
          "<leader>ci",
          function()
            vim.lsp.buf.code_action({
              context = {
                only = { "source.addMissingImports" },
                diagnostics = {},
              },
              apply = true,
            })
          end,
          desc = "Add Missing Imports",
        },
        
        -- Remover imports sin usar con <leader>cu (code unused)
        {
          "<leader>cu",
          function()
            vim.lsp.buf.code_action({
              context = {
                only = { "source.removeUnused" },
                diagnostics = {},
              },
              apply = true,
            })
          end,
          desc = "Remove Unused Imports",
        },
        
        -- Fix all con <leader>cF (code fix all)
        {
          "<leader>cF",
          function()
            vim.lsp.buf.code_action({
              context = {
                only = { "source.fixAll" },
                diagnostics = {},
              },
              apply = true,
            })
          end,
          desc = "Fix All Issues",
        },
      },
    },
  },
}
