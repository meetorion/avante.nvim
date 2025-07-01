local Utils = require("avante.utils")
local P = require("avante.providers")
local Config = require("avante.config")
local HistoryMessage = require("avante.history_message")

---@class AvanteProviderFunctor
local M = {}

M.api_key_name = nil -- Claude Code CLI doesn't need API key
M.support_prompt_caching = false

M.role_map = {
  user = "user",
  assistant = "assistant",
}

---@return boolean
function M.is_env_set()
  -- Check if claude command is available
  local handle = io.popen("which claude 2>/dev/null")
  if not handle then return false end
  local result = handle:read("*a")
  handle:close()
  return result and result:match("%S") ~= nil
end

function M.setup()
  if not M.is_env_set() then
    Utils.warn("Claude Code CLI not found. Please install claude-ai/claude-code CLI tool.", { once = true })
  end
end

function M.parse_api_key()
  return "" -- No API key needed for CLI
end

---@return boolean
function M:is_disable_stream() 
  return false -- We'll implement streaming
end

---@return AvanteClaudeMessage[]
function M:parse_messages(opts)
  ---@type AvanteClaudeMessage[]
  local messages = {}
  
  for _, message in ipairs(opts.messages) do
    local content_items = message.content
    local message_content = {}
    
    if type(content_items) == "string" then
      if message.role == "assistant" then 
        content_items = content_items:gsub("%s+$", "") 
      end
      if content_items ~= "" then
        table.insert(message_content, {
          type = "text",
          text = content_items,
        })
      end
    elseif type(content_items) == "table" then
      ---@cast content_items AvanteLLMMessageContentItem[]
      for _, item in ipairs(content_items) do
        if type(item) == "string" then
          if message.role == "assistant" then 
            item = item:gsub("%s+$", "") 
          end
          table.insert(message_content, { type = "text", text = item })
        elseif type(item) == "table" and item.type == "text" then
          table.insert(message_content, { type = "text", text = item.text })
        elseif type(item) == "table" and item.type == "image" then
          -- Claude Code CLI supports image paths
          table.insert(message_content, { type = "image", source = item.source })
        end
      end
    end
    
    if #message_content > 0 then
      table.insert(messages, {
        role = self.role_map[message.role],
        content = message_content,
      })
    end
  end
  
  return messages
end

---@param ctx table
---@param data_stream string
---@param event_state string|nil
---@param opts AvanteHandlerOptions
function M:parse_response(ctx, data_stream, event_state, opts)
  -- Simple text processing for CLI output
  if data_stream and data_stream ~= "" then
    -- Clean up the data
    local clean_data = data_stream:gsub("[\r\n]+$", "")
    
    if clean_data ~= "" then
      if opts.on_chunk then
        opts.on_chunk(clean_data .. "\n")
      end
      
      if opts.on_messages_add then
        -- Update the existing message or create a new one
        if not ctx.current_message then
          ctx.current_message = HistoryMessage:new({
            role = "assistant",
            content = clean_data,
          }, {
            state = "generating",
            turn_id = ctx.turn_id,
          })
        else
          -- Append to existing message
          local existing_content = ctx.current_message.message.content
          if type(existing_content) == "string" then
            existing_content = existing_content .. clean_data
          else
            existing_content = clean_data
          end
          
          ctx.current_message = HistoryMessage:new({
            role = "assistant",
            content = existing_content,
          }, {
            state = "generating",
            turn_id = ctx.turn_id,
            uuid = ctx.current_message.uuid,
          })
        end
        
        opts.on_messages_add({ ctx.current_message })
      end
    end
  end
end

---@param prompt_opts AvantePromptOptions
---@return table
function M:parse_curl_args(prompt_opts)
  local provider_conf, _ = P.parse_config(self)
  
  -- Build the claude command
  local messages = self:parse_messages(prompt_opts)
  
  -- Prepare the input text
  local input_parts = {}
  
  -- Add system prompt if available
  if prompt_opts.system_prompt and prompt_opts.system_prompt ~= "" then
    table.insert(input_parts, "System: " .. prompt_opts.system_prompt .. "\n")
  end
  
  -- Add messages
  for _, message in ipairs(messages) do
    local role = message.role == "user" and "Human" or "Assistant"
    local content = ""
    
    if type(message.content) == "table" then
      for _, item in ipairs(message.content) do
        if item.type == "text" then
          content = content .. item.text
        end
      end
    else
      content = tostring(message.content)
    end
    
    if content and content ~= "" then
      table.insert(input_parts, role .. ": " .. content .. "\n")
    end
  end
  
  local input_text = table.concat(input_parts, "\n")
  
  -- Build claude command arguments
  local cmd_args = { "claude", "--print" }
  
  -- Add model if specified
  if provider_conf.model then
    table.insert(cmd_args, "--model")
    table.insert(cmd_args, provider_conf.model)
  end
  
  local command = table.concat(cmd_args, " ")
  Utils.debug("Claude CLI command: " .. command)
  Utils.debug("Input text: " .. input_text)
  
  return {
    command = command,
    input_text = input_text,
    is_cli = true,
  }
end

---@param result table
function M.on_error(result)
  if result.exit_code and result.exit_code ~= 0 then
    local error_msg = "Claude Code CLI failed with exit code: " .. result.exit_code
    if result.stderr then
      error_msg = error_msg .. "\nError: " .. result.stderr
    end
    Utils.error(error_msg, { once = true, title = "Avante" })
  end
end

-- Custom execution function for CLI
---@param args table
---@param opts AvanteHandlerOptions
function M:execute_cli(args, opts)
  local ctx = { 
    turn_id = opts.turn_id or Utils.uuid(),
    current_message = nil,
  }
  
  -- Start response generation
  if opts.on_start then
    opts.on_start()
  end
  
  -- Use vim.system for better process handling (Neovim 0.10+)
  if vim.system then
    local cmd_parts = vim.split(args.command, " ")
    local cmd = table.remove(cmd_parts, 1)
    
    vim.system(vim.list_extend({cmd}, cmd_parts), {
      text = true,
      stdin = args.input_text,
      stdout = function(err, data)
        if err then
          opts.on_stop({ reason = "error", error = err })
          return
        end
        
        if data then
          vim.schedule(function()
            self:parse_response(ctx, data, nil, opts)
          end)
        end
      end,
      stderr = function(err, data)
        if data and data ~= "" then
          Utils.debug("Claude CLI stderr: " .. data)
        end
      end,
    }, function(result)
      vim.schedule(function()
        if result.code == 0 then
          -- Finalize the message
          if ctx.current_message then
            ctx.current_message = HistoryMessage:new({
              role = "assistant",
              content = ctx.current_message.message.content,
            }, {
              state = "generated",
              turn_id = ctx.turn_id,
              uuid = ctx.current_message.uuid,
            })
            if opts.on_messages_add then
              opts.on_messages_add({ ctx.current_message })
            end
          end
          opts.on_stop({ reason = "complete" })
        else
          opts.on_stop({ 
            reason = "error", 
            error = "Claude command failed with exit code: " .. result.code .. (result.stderr and ("\nStderr: " .. result.stderr) or "")
          })
        end
      end)
    end)
  else
    -- Fallback for older Neovim versions
    vim.defer_fn(function()
      local temp_file = os.tmpname()
      local file = io.open(temp_file, "w")
      if file then
        file:write(args.input_text)
        file:close()
      end
      
      local handle = io.popen(args.command .. " < " .. temp_file .. " 2>&1")
      if not handle then
        opts.on_stop({ reason = "error", error = "Failed to execute claude command" })
        return
      end
      
      local full_response = ""
      while true do
        local chunk = handle:read("*l")
        if not chunk then break end
        
        full_response = full_response .. chunk .. "\n"
        vim.schedule(function()
          self:parse_response(ctx, chunk, nil, opts)
        end)
      end
      
      local success = handle:close()
      
      -- Clean up temp file
      pcall(os.remove, temp_file)
      
      vim.schedule(function()
        if success then
          if ctx.current_message then
            ctx.current_message = HistoryMessage:new({
              role = "assistant",
              content = ctx.current_message.message.content,
            }, {
              state = "generated",
              turn_id = ctx.turn_id,
              uuid = ctx.current_message.uuid,
            })
            if opts.on_messages_add then
              opts.on_messages_add({ ctx.current_message })
            end
          end
          opts.on_stop({ reason = "complete" })
        else
          opts.on_stop({ reason = "error", error = "Claude command execution failed" })
        end
      end)
    end, 0)
  end
end

return M