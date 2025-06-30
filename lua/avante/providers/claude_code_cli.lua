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
  -- Simple streaming implementation for CLI output
  if data_stream and data_stream ~= "" then
    -- Process each line from CLI output
    for line in data_stream:gmatch("[^\n]+") do
      if line:match("^data: ") then
        local json_str = line:sub(7) -- Remove "data: " prefix
        if json_str == "[DONE]" then
          opts.on_stop({ reason = "complete" })
          return
        end
        
        local ok, json_data = pcall(vim.json.decode, json_str)
        if ok and json_data and json_data.content then
          if opts.on_chunk then
            opts.on_chunk(json_data.content)
          end
          
          if opts.on_messages_add then
            local msg = HistoryMessage:new({
              role = "assistant",
              content = json_data.content,
            }, {
              state = "generating",
              turn_id = ctx.turn_id,
            })
            opts.on_messages_add({ msg })
          end
        end
      else
        -- Direct text output from CLI
        if opts.on_chunk then
          opts.on_chunk(line .. "\n")
        end
        
        if opts.on_messages_add then
          local msg = HistoryMessage:new({
            role = "assistant",
            content = line,
          }, {
            state = "generating",
            turn_id = ctx.turn_id,
          })
          opts.on_messages_add({ msg })
        end
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
  
  -- Create a temporary file with the conversation
  local temp_file = os.tmpname()
  local conversation = {}
  
  -- Add system prompt if available
  if prompt_opts.system_prompt and prompt_opts.system_prompt ~= "" then
    table.insert(conversation, "System: " .. prompt_opts.system_prompt)
    table.insert(conversation, "")
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
    
    table.insert(conversation, role .. ": " .. content)
    table.insert(conversation, "")
  end
  
  -- Write conversation to temp file
  local file = io.open(temp_file, "w")
  if file then
    file:write(table.concat(conversation, "\n"))
    file:close()
  end
  
  -- Build claude command arguments
  local cmd_args = { "claude" }
  
  -- Add model if specified
  if provider_conf.model then
    table.insert(cmd_args, "--model")
    table.insert(cmd_args, provider_conf.model)
  end
  
  -- Add streaming flag
  table.insert(cmd_args, "--stream")
  
  -- Add temperature if specified
  if provider_conf.extra_request_body and provider_conf.extra_request_body.temperature then
    table.insert(cmd_args, "--temperature")
    table.insert(cmd_args, tostring(provider_conf.extra_request_body.temperature))
  end
  
  -- Add max tokens if specified
  if provider_conf.extra_request_body and provider_conf.extra_request_body.max_tokens then
    table.insert(cmd_args, "--max-tokens")
    table.insert(cmd_args, tostring(provider_conf.extra_request_body.max_tokens))
  end
  
  -- Add input file
  table.insert(cmd_args, "--file")
  table.insert(cmd_args, temp_file)
  
  return {
    command = table.concat(cmd_args, " "),
    temp_file = temp_file,
    is_cli = true, -- Special flag to indicate CLI execution
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
  local ctx = { turn_id = opts.turn_id or Utils.uuid() }
  
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
          Utils.warn("Claude CLI stderr: " .. data)
        end
      end,
    }, function(result)
      -- Clean up temp file
      if args.temp_file then
        pcall(os.remove, args.temp_file)
      end
      
      vim.schedule(function()
        if result.code == 0 then
          opts.on_stop({ reason = "complete" })
        else
          opts.on_stop({ 
            reason = "error", 
            error = "Claude command failed with exit code: " .. result.code 
          })
        end
      end)
    end)
  else
    -- Fallback for older Neovim versions
    vim.defer_fn(function()
      local handle = io.popen(args.command .. " 2>&1")
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
      if args.temp_file then
        pcall(os.remove, args.temp_file)
      end
      
      vim.schedule(function()
        if success then
          opts.on_stop({ reason = "complete" })
        else
          opts.on_stop({ reason = "error", error = "Claude command execution failed" })
        end
      end)
    end, 0)
  end
end

return M