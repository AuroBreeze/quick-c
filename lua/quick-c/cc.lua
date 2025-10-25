local U = require('quick-c.util')

local CC = {}

local function is_win()
  return U.is_windows()
end

local function gather_current_source()
  return vim.fn.expand('%:p')
end

local function choose_compiler(config, ft)
  local domain = is_win() and config.toolchain.windows or config.toolchain.unix
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

local function build_compile_command(config, ft, source, out)
  local _, family = choose_compiler(config, ft)
  if not family then return nil end
  if family == 'cl' then
    local args = { 'cl', '/Zi', '/Od', source, '/Fe:' .. out }
    return table.concat(args, ' ')
  elseif family == 'gcc' then
    local cc = (ft == 'c') and 'gcc' or 'g++'
    local args = { cc, '-g', '-O0', '-Wall', '-Wextra', source, '-o', out }
    return table.concat(args, ' ')
  else
    local cc = (ft == 'c') and 'clang' or 'clang++'
    local args = { cc, '-g', '-O0', '-Wall', '-Wextra', source, '-o', out }
    return table.concat(args, ' ')
  end
end

local function resolve_out_path(config, source)
  local base = vim.fn.fnamemodify(source, ':p:h')
  if config.outdir == 'source' then
    return base .. '/' .. vim.fn.fnamemodify(source, ':t:r') .. (is_win() and '.exe' or '')
  else
    vim.fn.mkdir(config.outdir, 'p')
    return config.outdir .. '/' .. vim.fn.fnamemodify(source, ':t:r') .. (is_win() and '.exe' or '')
  end
end

local function resolve_target_path(ccfg, source_dir)
  local filename = 'compile_commands.json'
  local outdir = ccfg.outdir
  if not outdir or outdir == 'source' then
    return source_dir .. '/' .. filename
  end
  vim.fn.mkdir(outdir, 'p')
  return outdir .. '/' .. filename
end

local function copy_file(src, dst)
  local data = vim.fn.readfile(src)
  if not data or #data == 0 then return false end
  return vim.fn.writefile(data, dst) == 0
end

function CC.generate(config, notify)
  local ft = vim.bo.filetype
  if ft ~= 'c' and ft ~= 'cpp' then
    notify.warn('仅支持 c/cpp 文件')
    return
  end
  local source = gather_current_source()
  if source == nil or source == '' then
    notify.warn('未找到源码文件')
    return
  end
  local source_dir = vim.fn.fnamemodify(source, ':p:h')
  local exe = resolve_out_path(config, source)
  local cmdline = build_compile_command(config, ft, source, exe)
  if not cmdline then
    notify.err('未找到可用编译器')
    return
  end
  local entry = {
    directory = source_dir,
    file = source,
    command = cmdline,
  }
  local path = resolve_target_path(config.compile_commands, source_dir)
  local ok = vim.fn.writefile({ vim.json.encode({ entry }) }, path) == 0
  if ok then
    notify.info('已生成 ' .. path)
  else
    notify.err('生成失败: ' .. path)
  end
end

function CC.use_external(config, notify)
  local ccfg = config.compile_commands or {}
  local src = ccfg.use_path
  if not src or src == '' then
    notify.warn('未设置 compile_commands 路径')
    return
  end
  if vim.fn.filereadable(src) ~= 1 then
    notify.err('文件不存在: ' .. src)
    return
  end
  local source = gather_current_source()
  local source_dir = vim.fn.fnamemodify(source, ':p:h')
  local dst = resolve_target_path(ccfg, source_dir)
  if copy_file(src, dst) then
    notify.info('已复制到 ' .. dst)
  else
    notify.err('复制失败: ' .. dst)
  end
end

function CC.apply(config, notify)
  local ccfg = config.compile_commands or {}
  if ccfg.mode == 'use' then
    CC.use_external(config, notify)
  else
    CC.generate(config, notify)
  end
end

return CC
