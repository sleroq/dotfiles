local uv = vim.uv
local function append_reference(range)
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' or vim.bo.buftype ~= '' then
    vim.notify('Pi draft needs a file buffer', vim.log.levels.WARN)
    return
  end

  local state = vim.env.XDG_STATE_HOME
  local directory = ((state and state ~= '') and state or vim.fn.expand '~/.local/state') .. '/pi-draft'
  local fd = uv.fs_open(directory .. '/last', 'r', 0)
  local id = fd and uv.fs_read(fd, 13, 0)
  if fd then
    uv.fs_close(fd)
  end
  if not id or #id ~= 12 or not id:match '^[0-9a-f]+$' then
    vim.notify('No active Pi draft; focus or type in a terminal Pi session first', vim.log.levels.WARN)
    return
  end

  local socket = uv.new_pipe(false)
  local function finish(message, level)
    if socket:is_closing() then
      return
    end
    socket:close()
    vim.schedule(function()
      vim.notify(message, level)
    end)
  end

  local request = vim.json.encode { path = path, first = range.line1, last = range.line2 } .. '\n'
  socket:connect(directory .. '/' .. id .. '.sock', function(err)
    if err then
      finish('Last active Pi session is unavailable; focus or type in a running session', vim.log.levels.WARN)
      return
    end
    socket:write(request)
    local reply = ''
    socket:read_start(function(read_err, chunk)
      if read_err then
        finish("Could not read Pi's reply: " .. read_err, vim.log.levels.WARN)
      elseif chunk then
        reply = reply .. chunk
      elseif reply == 'ok\n' then
        finish('Added reference to Pi draft', vim.log.levels.INFO)
      else
        finish(reply ~= '' and vim.trim(reply) or 'Pi closed the draft connection', vim.log.levels.WARN)
      end
    end)
  end)
  vim.defer_fn(function()
    finish('Timed out waiting for Pi to update its draft', vim.log.levels.WARN)
  end, 1500)
end

vim.api.nvim_create_user_command('PiDraftReference', append_reference, { range = true, desc = 'Append file and line range to the last active Pi draft' })
vim.keymap.set('x', '<leader>pm', ':PiDraftReference<CR>', { desc = 'Append selection reference to Pi draft' })
