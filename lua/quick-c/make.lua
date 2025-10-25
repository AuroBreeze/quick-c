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

local function strip_quotes(s)
  if type(s) ~= 'string' then return s end
  local a = s:match('^%s*"(.*)"%s*$') or s:match("^%s*'(.*)'%s*$")
  return a or s
end

local function can_execute_prog(p)
  local prog = strip_quotes(p)
  if not prog or prog == '' then return false end
  if vim.fn.executable(prog) == 1 then return true end
  -- If it's a path, check file existence (may still fail to exec, but avoid jobstart crash)
  local is_path
  if U.is_windows() then
    is_path = prog:match('[\\/]') or prog:match('%.exe$')
  else
    is_path = prog:sub(1,1) == '/' or prog:match('[\\/]')
  end
  if is_path then
    local st = vim.loop.fs_stat(prog)
    return st and st.type == 'file'
  end
  return false
end

-- Choose a make program only for parsing targets (-q/-p), independent from prefer_force
local function choose_probe_make()
  local candidates = { 'make', 'mingw32-make', 'nmake' }
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then return name end
  end
  return nil
end

function M.choose_make(config)
  local pref = (config.make or {}).prefer
  local force = ((config.make or {}).prefer_force == true)
  local function is_exec(x) return x and vim.fn.executable(x) == 1 end
  local function is_path(x)
    if not x or type(x) ~= 'string' then return false end
    if U.is_windows() then return x:match('[\\/]') or x:match('%.exe$') end
    return x:sub(1,1) == '/' or x:match('[\\/]')
  end
  local function quote_if_needed(p)
    if not p then return p end
    if p:find('%s') then return string.format('%q', p) end
    return p
  end
  local function path_exists_file(p)
    local st = vim.loop.fs_stat(p)
    return st and st.type == 'file'
  end
  if type(pref) == 'string' then
    if is_path(pref) then
      if path_exists_file(pref) then return quote_if_needed(pref) end
      if force then return quote_if_needed(pref) end
      U.notify_warn("首选 make 程序路径不存在：" .. tostring(pref))
    elseif is_exec(pref) then
      return pref
    else
      if force then return pref end
      U.notify_warn("首选 make 程序不可执行：" .. tostring(pref) .. "（未在 PATH 中找到）")
    end
  elseif type(pref) == 'table' then
    if force and #pref > 0 then
      local name = pref[1]
      if is_path(name) then return quote_if_needed(name) else return name end
    else
      for _, name in ipairs(pref) do
        if is_path(name) then
          if path_exists_file(name) then return quote_if_needed(name) end
        elseif is_exec(name) then
          return name
        end
      end
    end
  end
  if is_exec('make') then return 'make' end
  if U.is_windows() and is_exec('mingw32-make') then return 'mingw32-make' end
  return nil
end

function M.parse_make_targets_in_cwd_async(config, cwd, cb)
  local pref_prog = M.choose_make(config)
  if not pref_prog then cb({}) return end
  local probe = pref_prog
  if not can_execute_prog(pref_prog) then
    local alt = choose_probe_make()
    if alt then
      U.notify_warn("Quick-c: 使用可用的 make (" .. alt .. ") 解析目标；运行仍使用 '" .. tostring(pref_prog) .. "'")
      probe = alt
    else
      local msg = "Quick-c: 未找到可用于解析目标的 make（make/mingw32-make/nmake），请检查环境或使用 QuickCMakeCmd"
      U.notify_warn(msg)
      cb({})
      return
    end
  end
  local cache_cfg = ((config.make or {}).cache) or {}
  local ttl = tonumber(cache_cfg.ttl) or 10
  local cur_mtime = stat_makefile(cwd)
  local entry = target_cache[cwd]
  if entry and entry.targets and entry.at and (os.time() - entry.at <= ttl) and entry.mtime == cur_mtime then
    cb({ targets = entry.targets, phony = entry.phony or {} })
    return
  end
  local function parse_lines(lines)
    local targets, seen = {}, {}
    local phony = {}
    for _, l in ipairs(lines) do
      local plist = l:match('^%.PHONY%s*:%s*(.+)')
      if plist then
        for name in plist:gmatch('%S+') do phony[name] = true end
      else
        local name = l:match('^([%w%._%-%+/\\][^:%$#=]*)%s*:')
        if name then
          name = name:gsub('%s+$', '')
          if not name:match('%%%') and not name:match('^%.')
             and name ~= 'Makefile' and name ~= 'makefile' and name ~= 'GNUmakefile' then
            if not seen[name] then seen[name] = true; table.insert(targets, name) end
          end
        end
      end
    end
    table.sort(targets)
    return targets, phony
  end
  local function run_and_collect(flags, done)
    local lines = {}
    local job = vim.fn.jobstart({ strip_quotes(probe), flags }, {
      cwd = cwd,
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then for _, l in ipairs(data) do table.insert(lines, l) end end
      end,
      on_exit = function()
        done(lines)
      end,
    })
    if job <= 0 then done({}) end
  end
  run_and_collect('-qp', function(lines_qp)
    local targets, phony = parse_lines(lines_qp)
    if #targets == 0 then
      -- Fallback to -pn for broader compatibility (e.g., some make variants)
      run_and_collect('-pn', function(lines_pn)
        local t2, p2 = parse_lines(lines_pn)
        target_cache[cwd] = { mtime = cur_mtime, at = os.time(), targets = t2, phony = p2 }
        cb({ targets = t2, phony = p2 })
      end)
    else
      target_cache[cwd] = { mtime = cur_mtime, at = os.time(), targets = targets, phony = phony }
      cb({ targets = targets, phony = phony })
    end
  end)
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
