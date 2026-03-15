return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- TypeScript/JavaScript/Angular
        ts_ls = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
              suggest = {
                autoImports = true, -- Habilitar sugerencias de auto-import
              },
              updateImportsOnFileMove = {
                enabled = "always", -- Actualizar imports al mover archivos
              },
            },
            javascript = {
              suggest = {
                autoImports = true,
              },
              updateImportsOnFileMove = {
                enabled = "always",
              },
            },
          },
          -- Configurar code actions para organizar imports
          init_options = {
            preferences = {
              includeCompletionsForModuleExports = true,
              includeCompletionsWithInsertText = true,
              importModuleSpecifierPreference = "relative",
              jsxAttributeCompletionStyle = "auto",
            },
          },
        },
        
        -- Angular Language Service
        angularls = {
          settings = {
            angular = {
              suggest = {
                autoImports = true,
              },
            },
          },
        },
      },
      -- Configurar keymaps para organizar imports
      setup = {
        ts_ls = function(_, opts)
          -- Organizar imports automáticamente
          vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
            callback = function()
              vim.lsp.buf.code_action({
                context = {
                  only = { "source.organizeImports" },
                  diagnostics = {},
                },
                apply = true,
              })
            end,
          })
        end,
      },
    },
  },
  
  -- Configuración adicional para blink.cmp (autocompletado)
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = {
            name = "LSP",
            module = "blink.cmp.sources.lsp",
            score_offset = 1000, -- Priorizar sugerencias del LSP
          },
        },
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        menu = {
          draw = {
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
        },
      },
    },
  },
}
