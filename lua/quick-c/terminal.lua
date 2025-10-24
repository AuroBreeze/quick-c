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

return T
