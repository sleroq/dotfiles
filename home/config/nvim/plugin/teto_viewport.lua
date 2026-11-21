local id = vim.env.HC_TERMINAL_ID
if not id or not id:match '^t[a-z0-9]+$' or vim.env.SSH_CONNECTION or vim.env.SSH_CLIENT or vim.env.SSH_TTY then
  return
end

local uv = vim.uv or vim.loop
local directory = vim.fn.expand '~/.cache/teto98'
local path = directory .. '/nvim-' .. id .. '.json'
local pending, active, last, serial = false, false, nil, 0

local function text_span(row, left, right)
  local first, last_col
  for col = left, right do
    local cell = vim.fn.screenstring(row, col)
    if cell ~= '' and not cell:match '^%s+$' then
      first = first or col - 1
      last_col = math.min(right, col - 1 + vim.fn.strdisplaywidth(cell))
    end
  end
  return first, last_col
end

local function report()
  vim.cmd 'redraw'
  local ledges = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local config = vim.api.nvim_win_get_config(win)
    local buf = vim.api.nvim_win_get_buf(win)
    if config.relative == '' and vim.bo[buf].buftype == '' then
      local info = vim.fn.getwininfo(win)[1]
      local top = info.winrow + info.winbar
      local bottom = top + info.height - 1
      local left = info.wincol + info.textoff
      local right = info.wincol + info.width - 1
      vim.api.nvim_win_call(win, function()
        for line = info.topline, info.botline do
          if vim.fn.foldclosed(line) == -1 then
            local col = vim.fn.virtcol2col(win, line, info.leftcol + 1)
            local pos = vim.fn.screenpos(win, line, col)
            local row = pos.row
            if row >= top and row <= bottom and pos.col > 0 then
              local x1, x2 = text_span(row, left, right)
              if x1 and (row > top or line == 1) then
                local prev1, prev2
                if row > top then
                  prev1, prev2 = text_span(row - 1, left, right)
                end
                local prefix = ('%d:%d:%d:'):format(win, buf, line)
                local function add(side, a, b)
                  if a < b then
                    ledges[#ledges + 1] = { id = prefix .. side, row = row - 1, x1 = a, x2 = b, kind = 'text' }
                  end
                end
                if not prev1 then
                  add('left', x1, x2)
                else
                  add('left', x1, math.min(x2, prev1))
                  add('right', math.max(x1, prev2), x2)
                end
              end
            end
          end
        end
      end)
    end
  end
  local data = vim.json.encode { version = 1, cols = vim.o.columns, rows = vim.o.lines, ledges = ledges }
  if data == last then
    return
  end
  vim.fn.mkdir(directory, 'p', 448)
  serial = serial + 1
  local temporary = ('%s.%d.%d.tmp'):format(path, uv.os_getpid(), serial)
  local fd = uv.fs_open(temporary, 'wx', 384)
  if not fd then
    return
  end
  local written = uv.fs_write(fd, data, 0)
  uv.fs_close(fd)
  if written == #data and uv.fs_rename(temporary, path) then
    last = data
  else
    uv.fs_unlink(temporary)
  end
end

local function refresh()
  if not active or pending then
    return
  end
  pending = true
  vim.defer_fn(function()
    if active then
      report()
    end
    pending = false
  end, 30)
end

local function start()
  if active then
    return
  end
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.stdin_tty and ui.stdout_tty then
      active = true
      local group = vim.api.nvim_create_augroup('TetoViewport', { clear = true })
      vim.api.nvim_create_autocmd({
        'VimEnter',
        'WinScrolled',
        'WinResized',
        'VimResized',
        'WinEnter',
        'WinClosed',
        'BufWinEnter',
        'BufWinLeave',
        'TextChanged',
        'TextChangedI',
        'TextChangedP',
        'InsertLeave',
        'OptionSet',
        'ColorScheme',
      }, { group = group, callback = refresh })
      vim.api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
          active = false
          uv.fs_unlink(path)
        end,
      })
      refresh()
      return
    end
  end
end

vim.api.nvim_create_autocmd('UIEnter', { callback = start })
start()
