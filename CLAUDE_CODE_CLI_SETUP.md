# Claude Code CLI 集成设置指南

本指南将帮助您将 Claude Code CLI 与 avante.nvim 集成，实现通过 CLI 工具进行 AI 代码生成和对话。

## 前提条件

1. **安装 Claude Code CLI**
   ```bash
   # 确保您已经安装了 claude 命令行工具
   which claude
   
   # 如果没有安装，请参考 Claude Code 官方文档进行安装
   ```

2. **验证 Claude CLI 可用性**
   ```bash
   # 测试 claude 命令是否可用
   claude --help
   
   # 确保已经登录到 Claude Code
   claude auth status
   ```

## 配置步骤

### 1. 使用内置提供商配置

将以下配置添加到您的 Neovim 配置中：

```lua
{
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- 重要：永远不要设置为 "*"
  build = function()
    if vim.fn.has("win32") == 1 then
      return "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
    else
      return "make"
    end
  end,
  opts = {
    provider = "claude_code_cli",
    providers = {
      claude_code_cli = {
        model = "claude-sonnet-4-20250514",
        timeout = 60000, -- CLI 操作可能需要更长时间
        extra_request_body = {
          temperature = 0.75,
          max_tokens = 20480,
        },
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
```

### 2. 高级配置选项

```lua
{
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- 重要：永远不要设置为 "*"
  build = "make",
  opts = {
    provider = "claude_code_cli",
    providers = {
      -- 主要的 CLI 提供商
      claude_code_cli = {
        model = "claude-sonnet-4-20250514",
        timeout = 60000,
        extra_request_body = {
          temperature = 0.75,
          max_tokens = 20480,
        },
      },
      
      -- 快速响应的配置
      claude_cli_fast = {
        __inherited_from = "claude_code_cli",
        model = "claude-haiku-3-5",
        extra_request_body = {
          temperature = 0.5,
          max_tokens = 8192,
        },
      },
      
      -- 保留 API 版本作为备选
      claude_api = {
        __inherited_from = "claude",
        endpoint = "https://api.anthropic.com",
        model = "claude-sonnet-4-20250514",
        api_key_name = "ANTHROPIC_API_KEY",
      },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = { file_types = { "markdown", "Avante" } },
      ft = { "markdown", "Avante" },
    },
  },
}
```

## 使用方法

### 基本使用

1. **开启对话**
   ```vim
   :AvanteAsk
   ```

2. **切换提供商**
   ```vim
   :AvanteSwitchProvider claude_code_cli
   :AvanteSwitchProvider claude_cli_fast
   ```

3. **检查健康状态**
   ```vim
   :checkhealth avante
   ```

### 支持的 Claude CLI 参数

CLI 提供商支持以下 Claude Code CLI 参数：

- `--model`: 指定模型（从配置中获取）
- `--temperature`: 控制响应随机性
- `--max-tokens`: 限制响应长度
- `--stream`: 启用流式响应（默认开启）
- `--file`: 输入文件（自动生成）

### 功能特性

- ✅ **流式响应**: 支持实时显示生成内容
- ✅ **模型切换**: 可以在不同模型间切换
- ✅ **错误处理**: 完整的错误处理和用户反馈
- ✅ **取消操作**: 支持中途取消生成
- ✅ **图片支持**: 支持图片路径输入
- ❌ **工具调用**: CLI 模式下不支持工具调用

## 故障排除

### 常见问题

1. **lazy.nvim semver 错误**
   ```
   Error: attempt to index local 'spec' (a boolean value)
   ```
   **解决方案**: 确保在配置中添加 `version = false`：
   ```lua
   {
     "yetone/avante.nvim",
     version = false, -- 这行很重要！
     -- ... 其他配置
   }
   ```

2. **"Claude Code CLI not found" 错误**
   ```bash
   # 确保 claude 在 PATH 中
   echo $PATH
   which claude
   
   # 重新安装 Claude Code CLI
   ```

3. **命令执行失败**
   ```bash
   # 检查 claude 权限
   claude auth status
   
   # 手动测试命令
   echo "Hello" | claude --stream
   ```

4. **构建错误：cargo 未找到命令**
   ```bash
   # 安装 Rust 工具链
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.bashrc
   
   # 或者手动下载预构建二进制文件
   cd ~/.local/share/nvim/lazy/avante.nvim
   mkdir -p build
   # Linux x86_64:
   curl -L "https://github.com/yetone/avante.nvim/releases/latest/download/avante_lib-linux-x86_64-luajit.tar.gz" | tar -zxv -C build/
   # Linux ARM64:
   curl -L "https://github.com/yetone/avante.nvim/releases/latest/download/avante_lib-linux-aarch64-luajit.tar.gz" | tar -zxv -C build/
   ```

5. **响应缓慢**
   - 增加 `timeout` 配置值
   - 使用更快的模型（如 claude-haiku）
   - 减少 `max_tokens` 设置

### 调试模式

启用调试模式获取更多信息：

```lua
{
  "yetone/avante.nvim",
  opts = {
    debug = true, -- 启用调试模式
    provider = "claude_code_cli",
    -- ... 其他配置
  },
}
```

调试信息将显示在 Neovim 的消息中：
```vim
:messages
```

## 性能优化

### CLI 优化建议

1. **模型选择**
   - 日常使用：`claude-haiku-3-5`（快速）
   - 复杂任务：`claude-sonnet-4-20250514`（高质量）

2. **参数调优**
   ```lua
   extra_request_body = {
     temperature = 0.5,  -- 更确定的输出
     max_tokens = 8192,  -- 适中的长度
   },
   ```

3. **超时设置**
   ```lua
   timeout = 30000, -- 30秒，适合大多数场景
   ```

## 与其他功能的集成

### 与 agentic 模式配合

CLI 提供商完全支持 agentic 模式下的代码生成：

```lua
{
  mode = "agentic", -- 启用 agentic 模式
  provider = "claude_code_cli",
}
```

### 与其他提供商混合使用

```lua
{
  provider = "claude_code_cli",           -- 主要提供商
  auto_suggestions_provider = "claude",   -- 自动建议使用 API
  memory_summary_provider = "claude",     -- 记忆总结使用 API
}
```

## 支持和贡献

如果您遇到问题或有改进建议：

1. 检查 [avante.nvim issues](https://github.com/yetone/avante.nvim/issues)
2. 提交新的 issue 描述问题
3. 参考 `CLAUDE.md` 了解开发指南

## 更新日志

- **v1.0**: 初始 Claude Code CLI 支持
- 支持基本对话和代码生成
- 支持流式响应和错误处理
- 支持模型切换和参数配置