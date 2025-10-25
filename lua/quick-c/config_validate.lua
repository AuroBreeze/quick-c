local V = {}

local U = require('quick-c.util')
local MK = require('quick-c.make')
local PROJECT_CONFIG = require('quick-c.project_config')

local function add(report, level, msg)
  table.insert(report.messages, { level = level, text = msg })
  if level == 'error' then report.ok = false end
end

local function is_str(x) return type(x) == 'string' end
local function is_tbl(x) return type(x) == 'table' end
local function is_bool(x) return type(x) == 'boolean' end
local function is_num(x) return type(x) == 'number' end

local function resolve_cwd(config)
  local cwd = config.make and config.make.cwd or nil
  if not cwd or cwd == '' then return nil end
  local is_abs
  if U.is_windows() then
    is_abs = cwd:match('^%a:[\\/]') or cwd:match('^[\/]') or cwd:match('^\\\\')
  else
    is_abs = cwd:sub(1,1) == '/'
  end
  if not is_abs then
    local base = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
    cwd = vim.fn.fnamemodify(U.join(base, cwd), ':p')
  end
  return cwd
end

function V.validate(config)
  local report = { ok = true, messages = {}, details = {} }
  if not is_tbl(config) then
    add(report, 'error', 'Config is not a table')
    return report
  end

  -- Project config path
  local pwd = vim.fn.getcwd()
  local project_path = PROJECT_CONFIG.find_project_config(pwd)
  if project_path then
    add(report, 'info', 'Project config detected: ' .. project_path)
  else
    add(report, 'info', 'No project config (.quick-c.json) found under :pwd')
  end

  -- outdir
  if config.outdir ~= nil and not is_str(config.outdir) then
    add(report, 'warn', 'outdir should be a string ("source" or path)')
  end

  -- toolchain
  if config.toolchain and not is_tbl(config.toolchain) then
    add(report, 'warn', 'toolchain should be a table')
  end

  -- make section
  local mk = config.make or {}
  if mk.enabled == false then
    add(report, 'info', 'make is disabled (make.enabled = false)')
  end
  if mk.prefer ~= nil then
    if is_str(mk.prefer) then
      -- ok
    elseif is_tbl(mk.prefer) then
      for i, v in ipairs(mk.prefer) do if type(v) ~= 'string' then add(report, 'warn', 'make.prefer['..i..'] should be string') end end
    else
      add(report, 'warn', 'make.prefer should be string or list of strings')
    end
  end
  if mk.prefer_force ~= nil and not is_bool(mk.prefer_force) then
    add(report, 'warn', 'make.prefer_force should be boolean')
  end
  if mk.search ~= nil then
    if not is_tbl(mk.search) then
      add(report, 'warn', 'make.search should be a table')
    else
      if mk.search.up ~= nil and not is_num(mk.search.up) then add(report, 'warn', 'make.search.up should be a number') end
      if mk.search.down ~= nil and not is_num(mk.search.down) then add(report, 'warn', 'make.search.down should be a number') end
      if mk.search.ignore_dirs ~= nil then
        if not is_tbl(mk.search.ignore_dirs) then
          add(report, 'warn', 'make.search.ignore_dirs should be a list of strings')
        else
          for i, v in ipairs(mk.search.ignore_dirs) do if type(v) ~= 'string' then add(report, 'warn', 'make.search.ignore_dirs['..i..'] should be string') end end
        end
      end
    end
  end

  -- cwd checks
  local cwd = resolve_cwd(config)
  if cwd then
    if vim.fn.isdirectory(cwd) ~= 1 then
      add(report, 'error', 'make.cwd does not exist: ' .. cwd)
    else
      add(report, 'info', 'Resolved make.cwd: ' .. cwd)
      -- Check for Makefile existence or note fallback search
      local uv = vim.loop
      local names = { 'Makefile', 'makefile', 'GNUmakefile' }
      local found = false
      for _, n in ipairs(names) do
        local st = uv.fs_stat(U.join(cwd, n))
        if st and st.type == 'file' then found = true; break end
      end
      if not found then
        local down = (mk.search and mk.search.down) or 3
        add(report, 'warn', 'No Makefile in make.cwd; will search downward within cwd (depth = ' .. tostring(down) .. ')')
      end
    end
  else
    add(report, 'info', 'make.cwd not set; resolver will search near current file with up/down rules')
  end

  -- choose make / executables
  local chosen = MK.choose_make(config)
  if chosen then
    add(report, 'info', 'Chosen make program: ' .. tostring(chosen))
  else
    add(report, 'error', 'No usable make program found (make, mingw32-make). Check make.prefer or PATH')
  end

  report.details.project_config_path = project_path
  report.details.resolved_cwd = cwd
  report.details.chosen_make = chosen
  return report
end

local function format_report(report)
  local lines = { 'Quick-c: Configuration Check' }
  for _, m in ipairs(report.messages) do
    local prefix = (m.level == 'error' and '[ERROR] ') or (m.level == 'warn' and '[WARN]  ') or '[INFO]  '
    table.insert(lines, prefix .. m.text)
  end
  return table.concat(lines, '\n')
end

function V.run_and_notify(config)
  local rpt = V.validate(config)
  local msg = format_report(rpt)
  local lvl = rpt.ok and vim.log.levels.INFO or vim.log.levels.WARN
  vim.notify(msg, lvl)
  return rpt
end

return V
