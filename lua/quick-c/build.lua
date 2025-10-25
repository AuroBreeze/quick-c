local U = require('quick-c.util')
local T = require('quick-c.terminal')
local B = {}
local NAME_CACHE = {}

local function ensure_outdir(dir)
  vim.fn.mkdir(dir, 'p')
end

local function sources_key(sources)
  local list = {}
  for _, s in ipairs(sources or {}) do table.insert(list, vim.fn.fnamemodify(s, ':p')) end
  table.sort(list)
  return table.concat(list, ';')
end

local function gather_sources()
  return { vim.fn.expand('%:p') }
end

local function norm_abs(p)
  if not p or p == '' then return nil end
  return vim.fn.fnamemodify(p, ':p')
end

local function from_opts_sources(opts)
  if not opts or type(opts) ~= 'table' or not opts.sources then return nil end
  local list = {}
  for _, s in ipairs(opts.sources) do
    local abs = norm_abs(s)
    if abs and vim.fn.filereadable(abs) == 1 then table.insert(list, abs) end
  end
  if #list > 0 then return list end
  return nil
end

local function detect_ft_from_sources(sources)
  -- if any cpp-like file, treat as cpp; else c
  for _, s in ipairs(sources or {}) do
    local ext = (s:match('%.(%w+)$') or ''):lower()
    if ext == 'cpp' or ext == 'cc' or ext == 'cxx' or ext == 'hpp' then return 'cpp' end
  end
  return 'c'
end

local function default_out_name(is_win, sources)
  local ext = is_win and '.exe' or ''
  if #sources == 1 then
    local base = vim.fn.fnamemodify(sources[1], ':t:r')
    return base .. ext
  else
    local name = 'a.out'
    if is_win and not name:match('%.exe$') then name = name .. '.exe' end
    return name
  end
end

local function choose_compiler(config, is_win, ft)
  local domain = is_win and config.toolchain.windows or config.toolchain.unix
  local candidates = (ft == 'c') and domain.c or domain.cpp
  for _, name in ipairs(candidates) do
    if name == 'gcc' or name == 'g++' then
      if vim.fn.executable(name) == 1 then return name, 'gcc' end
    elseif name == 'clang' or name == 'clang++' then
      if vim.fn.executable(name) == 1 then return name, 'clang' end
    elseif name == 'cl' then
      if vim.fn.executable('cl') == 1 then return 'cl', 'cl' end
    end
  end
  return nil, nil
end

local function build_cmd(config, is_win, ft, sources, out)
  local _, family = choose_compiler(config, is_win, ft)
  if not family then return nil end
  if family == 'cl' then
    local args = { 'cl', '/Zi', '/Od' }
    for _, s in ipairs(sources) do table.insert(args, s) end
    table.insert(args, '/Fe:' .. out)
    return args
  elseif family == 'gcc' then
    local cc = (ft == 'c') and 'gcc' or 'g++'
    local cmd = { cc, '-g', '-O0', '-Wall', '-Wextra' }
    for _, s in ipairs(sources) do table.insert(cmd, s) end
    table.insert(cmd, '-o')
    table.insert(cmd, out)
    return cmd
  else
    local cc = (ft == 'c') and 'clang' or 'clang++'
    local cmd = { cc, '-g', '-O0', '-Wall', '-Wextra' }
    for _, s in ipairs(sources) do table.insert(cmd, s) end
    table.insert(cmd, '-o')
    table.insert(cmd, out)
    return cmd
  end
end

local function resolve_out_path(config, sources, name)
  local outdir = config.outdir
  if outdir == 'source' then
    local dir = vim.fn.fnamemodify(sources[1], ':p:h')
    return dir .. '/' .. name
  else
    ensure_outdir(outdir)
    return outdir .. '/' .. name
  end
end

-- Parse compiler diagnostics (gcc/clang/msvc) into quickfix items
local function parse_diagnostics(lines)
  local items = {}
  local has_error = false
  local has_warning = false
  local function clean_path(p)
    if not p or p == '' then return p end
    -- trim spaces and surrounding quotes
    p = p:gsub('^%s+', ''):gsub('%s+$', '')
    p = p:gsub('^"(.+)"$', '%1'):gsub("^'(.-)'$", '%1')
    return p
  end
  for _, l in ipairs(lines or {}) do
    if type(l) ~= 'string' or l == '' then goto continue end
    -- gcc/clang with column: file:line:col: type: message
    -- allow Windows drive letters and colons in paths by making filename greedy
    local f, ln, col, typ, msg = l:match("^(.+):(%d+):(%d+):%s*(%w+)%s*:%s*(.+)$")
    if f then
      local it = { filename = clean_path(f), lnum = tonumber(ln), col = tonumber(col), text = msg, type = (typ == 'error' and 'E' or 'W') }
      if it.type == 'E' then has_error = true else has_warning = true end
      table.insert(items, it)
      goto continue
    end
    -- gcc/clang without column: file:line: type: message
    local f2, ln2, typ2, msg2 = l:match("^(.+):(%d+):%s*(%w+)%s*:%s*(.+)$")
    if f2 then
      local it = { filename = clean_path(f2), lnum = tonumber(ln2), col = 1, text = msg2, type = (typ2 == 'error' and 'E' or 'W') }
      if it.type == 'E' then has_error = true else has_warning = true end
      table.insert(items, it)
      goto continue
    end
    -- MSVC cl: file(line) : type Cxxxx: message
    local fm, lnm, typm, msgm = l:match("^%s*(.-)%((%d+)%)%s*:%s*(%w+)[^:]*:%s*(.+)$")
    if fm then
      local it = { filename = clean_path(fm), lnum = tonumber(lnm), col = 1, text = msgm, type = (typm:lower() == 'error' and 'E' or 'W') }
      if it.type == 'E' then has_error = true else has_warning = true end
      table.insert(items, it)
      goto continue
    end
    ::continue::
  end
  return items, has_error, has_warning
end

function B.get_output_name_async(config, sources, preset_name, cb, default_override)
  local is_win = U.is_windows()
  if preset_name and preset_name ~= '' then cb(preset_name) return end
  if #sources == 1 then cb(default_out_name(is_win, sources)) return end
  local def = 'a.out'
  if is_win and not def:match('%.exe$') then def = def .. '.exe' end
  if default_override and default_override ~= '' then def = default_override end
  local ui = vim.ui or {}
  if ui.input then
    ui.input({ prompt = 'Output name: ', default = def }, function(input)
      local name = input
      if not name or name == '' then name = def end
      if is_win and not name:match('%.exe$') then name = name .. '.exe' end
      cb(name)
    end)
  else
    cb(def)
  end
end

function B.build(config, notify, opts)
  local cli_sources = from_opts_sources(opts)
  local sources = cli_sources or gather_sources()
  if not sources or #sources == 0 then
    notify.warn('未找到源码文件')
    return
  end
  local ft = vim.bo.filetype
  if ft ~= 'c' and ft ~= 'cpp' then
    ft = detect_ft_from_sources(sources)
  end
  opts = opts or {}
  local key = sources_key(sources)
  local cached = NAME_CACHE[key]
  -- 对多文件：即使有缓存也弹出输入框，但默认值使用缓存
  local preset = nil
  local default_override = cached
  B.get_output_name_async(config, sources, preset, function(name)
    if not cached and name and name ~= '' then NAME_CACHE[key] = name end
    local is_win = U.is_windows()
    local exe = resolve_out_path(config, sources, name)
    local cmd = build_cmd(config, is_win, ft, sources, exe)
    if not cmd then
      notify.err('未找到可用编译器，请检查 PATH 或在 setup 中自定义 compile 命令')
      if opts.on_exit then pcall(opts.on_exit, 1, nil) end
      return
    end
    local all_stdout, all_stderr = {}, {}
    local ok = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      detach = false,
      on_stdout = function(_, d)
        if d and #d > 0 then
          for _, line in ipairs(d) do table.insert(all_stdout, line) end
        end
      end,
      on_stderr = function(_, d)
        if d and #d > 0 then
          for _, line in ipairs(d) do table.insert(all_stderr, line) end
        end
      end,
      on_exit = function(_, code)
        local diagcfg = (config.diagnostics and config.diagnostics.quickfix) or {}
        local qf_enabled = (diagcfg.enabled ~= false)
        local lines = {}
        for _, s in ipairs(all_stdout) do table.insert(lines, s) end
        for _, s in ipairs(all_stderr) do table.insert(lines, s) end
        if qf_enabled and #lines > 0 then
          local items, has_error, has_warning = parse_diagnostics(lines)
          if #items > 0 then
            vim.fn.setqflist({}, ' ', { title = 'Quick-c Build', items = items })
            local function should_open()
              if diagcfg.open == 'always' then return true end
              if diagcfg.open == 'error' and has_error then return true end
              if diagcfg.open == 'warning' and (has_error or has_warning) then return true end
              return false
            end
            local function should_jump()
              if diagcfg.jump == 'always' then return true end
              if diagcfg.jump == 'error' and has_error then return true end
              if diagcfg.jump == 'warning' and (has_error or has_warning) then return true end
              return false
            end
            if should_open() then
              if diagcfg.use_telescope then
                local ok_tb, tb = pcall(require, 'telescope.builtin')
                if ok_tb then tb.quickfix() else vim.cmd('copen') end
              else
                vim.cmd('copen')
              end
            end
            if should_jump() then
              local cur = vim.api.nvim_get_current_buf()
              local name = vim.api.nvim_buf_get_name(cur)
              local modified = false
              pcall(function() modified = vim.api.nvim_buf_get_option(cur, 'modified') end)
              -- 避免在“未命名且已修改”的缓冲上自动跳转，防止保存提示
              if not (name == '' and modified) then
                pcall(vim.cmd, 'silent! keepalt keepjumps cc')
              end
            end
          else
            -- clear quickfix on successful build without diagnostics
            if code == 0 then vim.fn.setqflist({}) end
          end
        end
        if code == 0 then notify.info('Build OK -> ' .. exe) else notify.err('Build failed (' .. code .. ')') end
        if opts.on_exit then pcall(opts.on_exit, code, exe) end
      end,
    })
    if ok <= 0 then notify.err('启动编译进程失败') end
  end, default_override)
end

function B.run(config, notify, exe_or_opts)
  local opts
  local exe
  if type(exe_or_opts) == 'table' then
    opts = exe_or_opts
  else
    exe = exe_or_opts
  end
  local cli_sources = from_opts_sources(opts)
  local cur = cli_sources or { vim.fn.expand('%:p') }
  local is_win = U.is_windows()
  exe = exe or resolve_out_path(config, cur, default_out_name(is_win, cur))
  if vim.fn.filereadable(exe) ~= 1 then
    notify.warn('未找到可执行文件，请先构建')
    return
  end
  local cmd
  if is_win then
    if U.is_powershell() then cmd = string.format("& '%s'", exe) else cmd = string.format('"%s"', exe) end
  else
    cmd = string.format("'%s'", exe)
  end
  if not T.run_in_betterterm(config, U.is_windows, cmd, notify.warn, notify.err) then
    if not T.run_in_native_terminal(config, U.is_windows, cmd) then
      notify.err('无法运行命令：无法打开终端')
    end
  end
end

function B.build_and_run(config, notify, opts)
  opts = opts or {}
  local user_on_exit = opts.on_exit
  opts.on_exit = function(code, exe)
    if user_on_exit then pcall(user_on_exit, code, exe) end
    if code == 0 then
      -- 关键修复：直接使用构建时得到的 exe 路径运行，避免名称不一致
      B.run(config, notify, exe)
    end
  end
  B.build(config, notify, opts)
end

function B.debug_run(config, notify, exe)
  local cur = { vim.fn.expand('%:p') }
  local is_win = U.is_windows()
  exe = exe or resolve_out_path(config, cur, default_out_name(is_win, cur))
  if vim.fn.filereadable(exe) ~= 1 then
    notify.warn('未找到可执行文件，请先构建')
    return
  end
  local ok, dap = pcall(require, 'dap')
  if not ok then
    notify.err('未找到 nvim-dap')
    return
  end
  dap.run({
    type = 'codelldb',
    request = 'launch',
    name = 'Quick-c Debug',
    program = exe,
    cwd = vim.fn.getcwd(),
    stopOnEntry = false,
    runInTerminal = true,
    initCommands = { 'settings set target.process.thread.step-avoid-libraries true' },
  })
end

return B
