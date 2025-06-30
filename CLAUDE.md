# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

avante.nvim is a Neovim plugin that emulates Cursor AI IDE behavior, providing AI-driven code suggestions and the ability to apply recommendations directly to source files. It's a hybrid Lua/Rust project with Python components for RAG services.

## Development Commands

### Building
```bash
# Standard build (downloads prebuilt binaries or builds from source if needed)
make

# Force build from source
make BUILD_FROM_SOURCE=true

# Build specific components
make TARGET_LIBRARY=tokenizers
make TARGET_LIBRARY=templates  
make TARGET_LIBRARY=repo-map
make TARGET_LIBRARY=html2md

# Clean build artifacts
make clean
```

### Testing
```bash
# Run all tests
make luatest          # Lua tests via Plenary
make rusttest         # Rust tests
make lua-typecheck    # Lua type checking

# Run individual test files
nvim --headless -c "PlenaryBustedFile tests/specific_test.lua"
```

### Linting and Formatting
```bash
# Run all linting
make lint

# Individual tools
make luacheck         # Lua linting
make luastylecheck    # Lua style check (stylua)
make stylefix         # Auto-fix Lua style issues
make ruststylecheck   # Rust formatting check
make rustlint         # Rust clippy linting

# Python linting (for RAG service)
cd py/rag-service && ruff check
cd py/rag-service && ruff format
```

### RAG Service (Docker)
```bash
# Build RAG service image
make build-image

# Push image (maintainers only)
make push-image
```

## Architecture

### Core Components

1. **Lua Frontend** (`lua/avante/`):
   - `sidebar.lua` - Main UI component for AI chat interface
   - `config.lua` - Configuration management with extensive provider options
   - `api.lua` - Public API functions
   - `llm.lua` - LLM interaction orchestration
   - `providers/` - AI provider implementations (Claude, OpenAI, Gemini, etc.)
   - `llm_tools/` - Agentic tool implementations for code operations

2. **Rust Backend** (`crates/`):
   - `avante-tokenizers` - Token counting for various models
   - `avante-templates` - Jinja2 template rendering for prompts
   - `avante-repo-map` - Tree-sitter based code structure analysis
   - `avante-html2md` - HTML to Markdown conversion

3. **Python RAG Service** (`py/rag-service/`):
   - Optional containerized service for semantic code search
   - Supports multiple embedding providers (OpenAI, Ollama, etc.)

### Key Design Patterns

- **Hybrid Language Architecture**: Lua for Neovim integration, Rust for performance-critical operations, Python for ML/AI services
- **Provider Pattern**: Extensible AI provider system supporting 10+ LLM services
- **Agentic Mode**: Tool-based AI interactions for automated code operations (default)
- **Legacy Mode**: Traditional planning-based code generation
- **Cursor Planning Mode**: Alternative planning implementation for broader model compatibility

### Operating Modes

1. **Agentic Mode** (default): Uses LLM tools to automatically perform code operations
2. **Legacy Mode**: Traditional planning-based approach
3. **Cursor Planning Mode**: Alternative implementation for better model compatibility

### Template System

- Uses Jinja2 templates in `lua/avante/templates/` for AI prompts
- Project-specific prompts via `*.avanterules` files
- Template categories: `planning`, `editing`, `suggesting`, `agentic`

## Development Workflow

### Making Changes

1. **Lua Changes**: Direct editing, test with `:luafile %` 
2. **Rust Changes**: Requires rebuild (`make BUILD_FROM_SOURCE=true`)
3. **Python Changes**: Restart RAG service container
4. **Templates**: Immediate effect, no rebuild needed

### Testing Strategy

- Lua tests use Plenary framework
- Rust tests use standard `cargo test`
- Manual testing via `:AvanteAsk`, `:AvanteChat`, etc.
- Provider testing requires valid API keys

### Configuration Files

- `stylua.toml` - Lua formatting (2 spaces, 119 chars/line)
- `ruff.toml` - Python linting (180 chars/line, strict rules)
- `Cargo.toml` - Rust workspace with pedantic clippy settings
- `.luarc.json` - Lua language server configuration

### Environment Setup

Required environment variables for providers:
- `ANTHROPIC_API_KEY` or `AVANTE_ANTHROPIC_API_KEY`
- `OPENAI_API_KEY` or `AVANTE_OPENAI_API_KEY` 
- `AZURE_OPENAI_API_KEY` or `AVANTE_AZURE_OPENAI_API_KEY`
- And others per provider documentation

### Binary Dependencies

- **Rust toolchain** (1.80+) for building from source
- **Docker** for RAG service
- **curl/tar** for downloading prebuilt binaries
- **gh CLI** (optional) for faster downloads

## Common Tasks

### Adding New Providers
1. Create provider file in `lua/avante/providers/`
2. Update `providers/init.lua` with provider registration
3. Add configuration schema to `config.lua`
4. Test with sample prompts

### Adding New Tools
1. Create tool implementation in `lua/avante/llm_tools/`
2. Register in `llm_tools/init.lua`
3. Update tool documentation in relevant templates

### Debugging
- Enable debug mode: `require("avante.config").override({debug = true})`
- Check `:checkhealth avante` for configuration issues
- Lua errors appear in `:messages`
- Rust panics logged to stderr