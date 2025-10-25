local U = require('quick-c.util')
local M = {}

local target_cache = {
  -- [cwd] = { mtime = <number|nil>, at = <os.time>, targets = {...} }
}

local function stat_makefile(cwd)
  local names = { 'Makefile', 'makefile', 'GNUmakefile' }
  for _, n in ipairs(names) do
    local p = U.join(cwd, n)
    local st = vim.loop.fs_stat(p)
    if st and st.type == 'file' then
      return st.mtime and st.mtime.sec or st.mtime or 0
    end
  end
  return nil
end

function M.choose_make(config)
  local pref = (config.make or {}).prefer
  local function is_exec(x) return x and vim.fn.executable(x) == 1 end
  if type(pref) == 'string' then
    if is_exec(pref) then return pref end
  elseif type(pref) == 'table' then
    for _, name in ipairs(pref) do
      if is_exec(name) then return name end
    end
  end
  if is_exec('make') then return 'make' end
  if U.is_windows() and is_exec('mingw32-make') then return 'mingw32-make' end
  return nil
end

function M.parse_make_targets_in_cwd_async(config, cwd, cb)
  local prog = M.choose_make(config)
  if not prog then cb({}) return end
  local cache_cfg = ((config.make or {}).cache) or {}
  local ttl = tonumber(cache_cfg.ttl) or 10
  local cur_mtime = stat_makefile(cwd)
  local entry = target_cache[cwd]
  if entry and entry.targets and entry.at and (os.time() - entry.at <= ttl) and entry.mtime == cur_mtime then
    cb({ targets = entry.targets, phony = entry.phony or {} })
    return
  end
  local lines = {}
  local job = vim.fn.jobstart({ prog, '-qp' }, {
    cwd = cwd,
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then for _, l in ipairs(data) do table.insert(lines, l) end end
    end,
    on_exit = function()
      local targets, seen = {}, {}
      local phony = {}
      for _, l in ipairs(lines) do
        -- collect .PHONY
        local plist = l:match('^%.PHONY%s*:%s*(.+)')
        if plist then
          for name in plist:gmatch('%S+') do phony[name] = true end
        else
          local name = l:match('^([%w%._%-%+/][^:%$#=]*)%s*:')
          if name then
            name = name:gsub('%s+$', '')
            if not name:match('%%%') and not name:match('^%.') and name ~= 'Makefile' and name ~= 'makefile' then
              if not seen[name] then seen[name] = true; table.insert(targets, name) end
            end
          end
        end
      end
      table.sort(targets)
      target_cache[cwd] = { mtime = cur_mtime, at = os.time(), targets = targets, phony = phony }
      cb({ targets = targets, phony = phony })
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
