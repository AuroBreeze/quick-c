--generate_from_cmake: Line 203

local U = require 'quick-c.util'
local CM = require 'quick-c.cmake'

local CC = {}

local function is_win()
  return U.is_windows()
end

local function gather_current_source()
  return vim.fn.expand '%:p'
end

local function choose_compiler(config, ft)
  local domain = is_win() and config.toolchain.windows or config.toolchain.unix
  local candidates = (ft == 'c') and domain.c or domain.cpp
  for _, name in ipairs(candidates) do
    if name == 'gcc' or name == 'g++' then
      if vim.fn.executable(name) == 1 then
        return name, 'gcc'
      end
    elseif name == 'clang' or name == 'clang++' then
      if vim.fn.executable(name) == 1 then
        return name, 'clang'
      end
    elseif name == 'cl' then
      if vim.fn.executable 'cl' == 1 then
        return 'cl', 'cl'
      end
    end
  end
  return nil, nil
end

local function build_compile_command(config, ft, source, out)
  local _, family = choose_compiler(config, ft)
  if not family then
    return nil
  end
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
  if outdir == 'cwd' then
    local cwd = vim.fn.getcwd()
    return cwd .. '/' .. filename
  end
  vim.fn.mkdir(outdir, 'p')
  return outdir .. '/' .. filename
end

local function copy_file(src, dst)
  local data = vim.fn.readfile(src)
  if not data or #data == 0 then
    return false
  end
  return vim.fn.writefile(data, dst) == 0
end

local function collect_sources_recursive(root, ignore_set)
  local uv = vim.loop
  local results = {}
  local function scan(dir)
    local fs = uv.fs_scandir(dir)
    if not fs then return end
    while true do
      local name, t = uv.fs_scandir_next(fs)
      if not name then break end
      local path = dir .. '/' .. name
      if t == 'directory' then
        if not ignore_set[name] then
          scan(path)
        end
      else
        local ext = (name:match('%.([%w]+)$') or ''):lower()
        if ext == 'c' or ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
          table.insert(results, path)
        end
      end
    end
  end
  scan(root)
  return results
end

local function collect_sources_async(root, ignore_set, include_hidden, max_depth, on_progress, on_done)
  local uv = vim.loop
  local queue = { { root, 0 } }
  local results = {}
  local scanners = {}
  local dir_count, file_count = 0, 0
  local function step()
    local budget = 600
    while budget > 0 do
      local item = queue[#queue]
      local current, depth = nil, 0
      if item then current, depth = item[1], item[2] or 0 end
      if not current then
        on_done(results)
        return
      end
      local fs = scanners[current]
      if not fs then
        fs = uv.fs_scandir(current)
        scanners[current] = fs or false
        if not fs then
          queue[#queue] = nil
        end
      else
        local name, t = uv.fs_scandir_next(fs)
        if not name then
          queue[#queue] = nil
        else
          local path = current .. '/' .. name
          if t == 'directory' then
            if not ignore_set[name] then
              if include_hidden or not name:match('^%.') then
                if (not max_depth) or (depth + 1 <= max_depth) then
                  queue[#queue + 1] = { path, depth + 1 }
                  dir_count = dir_count + 1
                end
              end
            end
          else
            local ext = (name:match('%.([%w]+)$') or ''):lower()
            if ext == 'c' or ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
              results[#results + 1] = path
              file_count = file_count + 1
            end
          end
          budget = budget - 1
        end
      end
      if budget <= 0 then break end
    end
    if on_progress then on_progress(file_count, dir_count) end
    vim.defer_fn(step, 1)
  end
  step()
end

function CC.generate(config, notify)
  local ft = vim.bo.filetype
  if ft ~= 'c' and ft ~= 'cpp' then
    notify.warn 'Only c/cpp files supported'
    return
  end
  local source = gather_current_source()
  if source == nil or source == '' then
    notify.warn 'No source file found'
    return
  end
  local source_dir = vim.fn.fnamemodify(source, ':p:h')
  local exe = resolve_out_path(config, source)
  local cmdline = build_compile_command(config, ft, source, exe)
  if not cmdline then
    notify.err 'No available compiler found'
    return
  end
  local entry = {
    directory = source_dir,
    file = source,
    command = cmdline,
  }
  local path = resolve_target_path(config.compile_commands, source_dir)
  local ok = vim.fn.writefile({ vim.json.encode { entry } }, path) == 0
  if ok then
    notify.info('Generated: ' .. path)
  else
    notify.err('Generation failed: ' .. path)
  end
end

-- Generate compile_commands.json from a CMake project
function CC.generate_from_cmake(config, notify)
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  CM.resolve_root_async(config, base, function(root)
    if not root then
      notify.warn 'CMake project root not found'
      return
    end
    -- Make a shallow copy and ensure export flag
    local cfg = vim.tbl_deep_extend('force', {}, config)
    cfg.cmake = cfg.cmake or {}
    cfg.cmake.configure = cfg.cmake.configure or {}
    local extra = {}
    for _, v in ipairs(cfg.cmake.configure.extra or {}) do table.insert(extra, v) end
    local has_flag = false
    for _, v in ipairs(extra) do
      if tostring(v):match('CMAKE_EXPORT_COMPILE_COMMANDS=ON') then has_flag = true break end
    end
    if not has_flag then
      table.insert(extra, '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON')
    end
    cfg.cmake.configure.extra = extra
    CM.ensure_configured_async(cfg, root, function(ok, bdir)
      if not ok then
        notify.err 'CMake configuration failed (cannot export compile_commands)'
        return
      end
      --WINOE: If user configed the compile_commands.find_dir
      local compile_command_dir = bdir
      if cfg.compile_commands.find_dir ~= nil then
          compile_command_dir = cfg.compile_commands.find_dir
          --vim.notify(cfg.compile_commands.find_dir)
      end

      local src = (compile_command_dir .. '/compile_commands.json')
      if vim.fn.filereadable(src) ~= 1 then
        notify.err('Not found: ' .. src)
        return
      end
      local ccfg = config.compile_commands or {}
      local dst = resolve_target_path(ccfg, root)
      if copy_file(src, dst) then
        notify.info('Copied: ' .. src .. ' -> ' .. dst)
      else
        notify.err('Copy failed: ' .. dst)
      end
    end)
  end)
end

function CC.use_external(config, notify)
  local ccfg = config.compile_commands or {}
  local src = ccfg.use_path
  if not src or src == '' then
    notify.warn 'compile_commands path not set'
    return
  end
  if vim.fn.filereadable(src) ~= 1 then
    notify.err('File not found: ' .. src)
    return
  end
  local source = gather_current_source()
  local source_dir = vim.fn.fnamemodify(source, ':p:h')
  local dst = resolve_target_path(ccfg, source_dir)
  if copy_file(src, dst) then
    notify.info('Copied to: ' .. dst)
  else
    notify.err('Copy failed: ' .. dst)
  end
end

function CC.apply(config, notify)
  local ccfg = config.compile_commands or {}
  if ccfg.mode == 'use' then
    CC.use_external(config, notify)
  elseif ccfg.mode == 'cmake' then
    CC.generate_from_cmake(config, notify)
  else
    CC.generate(config, notify)
  end
end

-- Helper: detect ft from filename
local function ft_from_file(path)
  local ext = (path:match('%.([%w]+)$') or ''):lower()
  if ext == 'c' then return 'c' end
  if ext == 'cpp' or ext == 'cc' or ext == 'cxx' then return 'cpp' end
  return 'c'
end

-- Non-CMake: generate for a given list of sources (multi-file)
function CC.generate_for_sources(config, notify, sources)
  sources = sources or {}
  if type(sources) ~= 'table' or #sources == 0 then
    notify.warn 'No sources selected'
    return
  end
  local entries = {}
  for _, src in ipairs(sources) do
    local abs = vim.fn.fnamemodify(src, ':p')
    if vim.fn.filereadable(abs) == 1 then
      local ft = ft_from_file(abs)
      local out = resolve_out_path(config, abs)
      local cmd = build_compile_command(config, ft, abs, out)
      if cmd then
        table.insert(entries, {
          directory = vim.fn.fnamemodify(abs, ':p:h'),
          file = abs,
          command = cmd,
        })
      end
    end
  end
  if #entries == 0 then
    notify.warn 'No valid sources to generate compile_commands'
    return
  end
  local ccfg = config.compile_commands or {}
  -- For multi-file/project, when outdir = 'source', prefer project root (cwd)
  local dst = resolve_target_path({ outdir = (ccfg.outdir == 'source') and vim.fn.getcwd() or ccfg.outdir }, vim.fn.getcwd())
  local ok = vim.fn.writefile({ vim.json.encode(entries) }, dst) == 0
  if ok then
    notify.info('Generated: ' .. dst .. ' (' .. tostring(#entries) .. ' entries)')
  else
    notify.err('Generation failed: ' .. dst)
  end
end

-- Non-CMake: scan project for sources and generate
function CC.generate_for_project(config, notify)
  local cwd = vim.fn.getcwd()
  local ccfg = config.compile_commands or {}
  local ignores = {}
  for _, v in ipairs(ccfg.ignore_dirs or { '.git', 'node_modules', '.cache' }) do ignores[v] = true end
  local include_hidden = ccfg.include_hidden ~= false
  local max_depth = ccfg.max_depth
  local throttle = tonumber(ccfg.progress_throttle_ms) or 600
  local last = 0
  collect_sources_async(cwd, ignores, include_hidden, max_depth, function(files, dirs)
    local uv = vim.loop
    if uv and uv.now then
      local now = uv.now()
      if now - (last or 0) >= throttle then
        notify.info(string.format('Scanning project: %d files, %d dirs', files or 0, dirs or 0))
        last = now
      end
    end
  end, function(list)
    local seen, sources = {}, {}
    for _, p in ipairs(list) do
      local abs = vim.fn.fnamemodify(p, ':p')
      if vim.fn.filereadable(abs) == 1 and not seen[abs] then
        seen[abs] = true
        sources[#sources + 1] = abs
      end
    end
    if #sources == 0 then
      notify.warn 'No C/C++ sources found under project root'
      return
    end
    CC.generate_for_sources(config, notify, sources)
  end)
end

-- Non-CMake: generate for all sources under a specified directory
function CC.generate_for_dir(config, notify, dir)
  dir = dir or vim.fn.getcwd()
  -- Normalize directory path for Windows and remove trailing separators
  dir = vim.fn.fnamemodify(dir, ':p')
  dir = (dir:gsub('\\', '/'):gsub('/+$', ''))
  local uv = vim.loop
  local st = uv.fs_stat(dir)
  if not st or st.type ~= 'directory' then
    notify.err('Not a directory: ' .. tostring(dir))
    return
  end
  local ccfg = config.compile_commands or {}
  local ignores = {}
  for _, v in ipairs(ccfg.ignore_dirs or { '.git', 'node_modules', '.cache' }) do ignores[v] = true end
  local include_hidden = ccfg.include_hidden ~= false
  local max_depth = ccfg.max_depth
  local throttle = tonumber(ccfg.progress_throttle_ms) or 600
  local last = 0
  collect_sources_async(dir, ignores, include_hidden, max_depth, function(files, dirs)
    local uvn = vim.loop
    if uvn and uvn.now then
      local now = uvn.now()
      if now - (last or 0) >= throttle then
        notify.info(string.format('Scanning dir: %d files, %d dirs', files or 0, dirs or 0))
        last = now
      end
    end
  end, function(list)
    local seen, sources = {}, {}
    for _, p in ipairs(list) do
      local abs = vim.fn.fnamemodify(p, ':p')
      if vim.fn.filereadable(abs) == 1 and not seen[abs] then
        seen[abs] = true
        sources[#sources + 1] = abs
      end
    end
    if #sources == 0 then
      notify.warn('No C/C++ sources found under: ' .. dir)
      return
    end
    local cfg = vim.tbl_deep_extend('force', {}, config)
    cfg.compile_commands = cfg.compile_commands or {}
    if cfg.compile_commands.outdir == 'source' then
      cfg.compile_commands.outdir = dir
    end
    CC.generate_for_sources(cfg, notify, sources)
  end)
end

return CC
