local T = {}

function T.run_in_native_terminal(config, is_windows, cmd)
  if config.terminal.open then
    vim.cmd("botright split | terminal")
    vim.cmd(string.format("resize %d", config.terminal.height or 12))
  else
    vim.cmd("terminal")
  end
  local chan = vim.b.terminal_job_id
  if not chan then return false end
  vim.defer_fn(function()
    vim.fn.chansend(chan, cmd .. (is_windows() and "\r" or "\n"))
  end, 100)
  return true
end

function T.run_in_betterterm(config, is_windows, cmd, notify_warn, notify_err)
  local ok, betterTerm = pcall(require, 'betterTerm')
  if not ok or config.betterterm.enabled == false then return false end
  local cfg = config.betterterm or {}
  local idx = cfg.index or 0
  local delay = cfg.send_delay or 200
  local focus = (cfg.focus_on_run ~= false)
  local open_first = (cfg.open_if_closed ~= false)
  if open_first or focus then pcall(betterTerm.open, idx) end
  vim.defer_fn(function()
    local ok_send, err = pcall(betterTerm.send, cmd .. (is_windows() and '\r' or '\n'), idx)
    if not ok_send then
      notify_warn('发送到 betterTerm 失败，改用内置终端: ' .. tostring(err))
      if not T.run_in_native_terminal(config, is_windows, cmd) then
        notify_err('内置终端打开失败')
      end
      return
    end
  end, delay)
  return true
end

function T.run_make_in_terminal(config, is_windows, cmdline, notify_warn, notify_err)
  if not T.run_in_betterterm(config, is_windows, cmdline, notify_warn, notify_err) then
    if not T.run_in_native_terminal(config, is_windows, cmdline) then
      notify_err("无法运行 make：无法打开终端")
    end
  end
end

-- List open builtin terminal buffers
function T.list_open_builtin_terminals()
  local bufs = vim.api.nvim_list_bufs()
  local items = {}
  for _, b in ipairs(bufs) do
    local ok_bt, bt = pcall(vim.api.nvim_buf_get_option, b, 'buftype')
    if ok_bt and bt == 'terminal' then
      local ok_job, job = pcall(vim.api.nvim_buf_get_var, b, 'terminal_job_id')
      if ok_job and job and job > 0 then
        local name = vim.api.nvim_buf_get_name(b)
        table.insert(items, { bufnr = b, job = job, name = name })
      end
    end
  end
  return items
end

-- Send command to a specific builtin terminal job
local function open_builtin_terminal_window(config, bufnr)
  -- Try to focus existing window showing the buffer; otherwise open a split and show it
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      pcall(vim.api.nvim_set_current_win, win)
      return true
    end
  end
  local height = (config.terminal and config.terminal.height) or 12
  vim.cmd("botright split")
  vim.cmd(string.format("resize %d", height))
  pcall(vim.api.nvim_win_set_buf, 0, bufnr)
  return true
end

function T.send_to_builtin_terminal(is_windows, job, cmd, opts)
  opts = opts or {}
  if opts.bufnr and vim.api.nvim_buf_is_valid(opts.bufnr) then
    pcall(open_builtin_terminal_window, opts.config or {}, opts.bufnr)
  end
  local nl = is_windows() and '\r' or '\n'
  return pcall(vim.fn.chansend, job, cmd .. nl)
end

-- Select an open terminal (builtin) to send, or fallback to default run
function T.select_or_run_in_terminal(config, is_windows, cmdline, notify_warn, notify_err)
  local mode = (((config.make or {}).telescope or {}).choose_terminal) or 'auto'
  local open_terms = T.list_open_builtin_terminals()
  local ok_t = pcall(require, 'telescope')
  if mode == 'never' or not ok_t or (mode == 'auto' and #open_terms == 0) then
    return T.run_make_in_terminal(config, is_windows, cmdline, notify_warn, notify_err)
  end
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local entries = {}
  local prog = (cmdline:match('^%S+') or 'cmd')
  table.insert(entries, { display = string.format('[默认终端策略] → %s', prog), kind = 'default' })
  for _, it in ipairs(open_terms) do
    local disp = string.format('buf #%d | %s', it.bufnr, (it.name ~= '' and it.name or 'terminal'))
    table.insert(entries, { display = disp, kind = 'builtin', job = it.job, bufnr = it.bufnr })
  end
  pickers.new({}, {
    prompt_title = '选择终端以发送命令',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(e)
        return { value = e, display = e.display, ordinal = e.display }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(_, map)
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')
      local function choose(bufnr)
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        local v = entry.value
        if v.kind == 'default' then
          T.run_make_in_terminal(config, is_windows, cmdline, notify_warn, notify_err)
        else
          local ok = T.send_to_builtin_terminal(is_windows, v.job, cmdline, { bufnr = v.bufnr, config = config })
          if not ok then
            notify_warn('发送到选定终端失败，改用默认策略')
            T.run_make_in_terminal(config, is_windows, cmdline, notify_warn, notify_err)
          end
        end
      end
      map('i', '<CR>', choose)
      map('n', '<CR>', choose)
      return true
    end,
  }):find()
end

return T
