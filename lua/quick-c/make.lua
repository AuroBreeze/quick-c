local U = require('quick-c.util')
local M = {}

function M.choose_make(config)
  if config.make and config.make.prefer then return config.make.prefer end
  if vim.fn.executable('make') == 1 then return 'make' end
  if U.is_windows() and vim.fn.executable('mingw32-make') == 1 then return 'mingw32-make' end
  return nil
end

function M.parse_make_targets_in_cwd_async(config, cwd, cb)
  local prog = M.choose_make(config)
  if not prog then cb({}) return end
  local lines = {}
  local job = vim.fn.jobstart({ prog, '-qp' }, {
    cwd = cwd,
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then for _, l in ipairs(data) do table.insert(lines, l) end end
    end,
    on_exit = function()
      local targets, seen = {}, {}
      for _, l in ipairs(lines) do
        local name = l:match('^([%w%._%-%+/][^:%$#=]*)%s*:')
        if name then
          name = name:gsub('%s+$', '')
          if not name:match('%%%') and not name:match('^%.') and name ~= 'Makefile' and name ~= 'makefile' then
            if not seen[name] then seen[name] = true; table.insert(targets, name) end
          end
        end
      end
      table.sort(targets)
      cb(targets)
    end,
  })
  if job <= 0 then cb({}) end
end

function M.make_run_in_cwd(config, cwd, target, run_fn)
  local prog = M.choose_make(config)
  if not prog then
    U.notify_err('未找到 make 或 mingw32-make')
    return
  end
  local cmd = string.format('%s -C %s %s', prog, U.shell_quote_path(cwd), target or '')
  run_fn(cmd)
end

return M
