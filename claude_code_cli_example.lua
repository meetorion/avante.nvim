-- Claude Code CLI integration example for avante.nvim
-- This file demonstrates how to configure avante.nvim to use Claude Code CLI

return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- Never set this value to "*"! Never!
  build = function()
    if vim.fn.has("win32") == 1 then
      return "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
    else
      -- Try to use prebuilt first, fallback to make if needed
      return "bash ./install_prebuilt.sh || make"
    end
  end,
  opts = {
    -- Set Claude Code CLI as the default provider
    provider = "claude_code_cli",
    
    providers = {
      claude_code_cli = {
        -- Model to use with Claude Code CLI
        model = "claude-sonnet-4-20250514",
        timeout = 60000, -- Increased timeout for CLI operations
        extra_request_body = {
          temperature = 0.75,
          max_tokens = 20480,
        },
      },
      
      -- You can also create multiple CLI configurations
      claude_code_fast = {
        __inherited_from = "claude_code_cli",
        model = "claude-haiku-3-5",
        extra_request_body = {
          temperature = 0.5,
          max_tokens = 8192,
        },
      },
      
      -- Keep other providers for fallback
      claude = {
        endpoint = "https://api.anthropic.com",
        model = "claude-sonnet-4-20250514",
        timeout = 30000,
        extra_request_body = {
          temperature = 0.75,
          max_tokens = 20480,
        },
      },
    },
    
    behaviour = {
      auto_suggestions = false,
      auto_set_highlight_group = true,
      auto_set_keymaps = true,
      auto_apply_diff_after_generation = false,
      support_paste_from_clipboard = false,
    },
    
    -- You might want to disable tools that don't work well with CLI
    disabled_tools = {},
    
    -- Configure windows for better CLI experience
    windows = {
      position = "right",
      width = 35,
      sidebar_header = {
        enabled = true,
        align = "center",
        rounded = true,
      },
    },
  },
  
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}