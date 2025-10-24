local M = {}

M.config = {
  -- outdir = "source" 表示输出到源码所在目录；也可设置为自定义目录
  outdir = "source",
  -- 用户可覆盖：为不同系统/工具链提供命令模板
  toolchain = {
    windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
    unix = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
  },
  compile_cmds = {
    gcc = function(ft, sources, out)
      local cc = (ft == "c") and "gcc" or "g++"
      return { cc, "-g", "-O0", "-Wall", "-Wextra", unpack(sources), "-o", out }
    end,
    clang = function(ft, sources, out)
      local cc = (ft == "c") and "clang" or "clang++"
      return { cc, "-g", "-O0", "-Wall", "-Wextra", unpack(sources), "-o", out }
    end,
    cl = function(ft, sources, out)
      -- cl 不同语法：/Fe:指定输出
      return vim.list_extend({ "cl", "/Zi", "/Od" }, sources, 1, #sources), { [0] = out }
    end,
  },
  runtime = {
    windows = { command = "powershell", args = function(exe) return { "-NoExit", "-Command", string.format("& '%s'", exe) } end },
    unix = { command = nil, args = function(exe) return { exe } end },
  },
  autorun = {
    enabled = false,
    events = { "BufWritePost" },
    filetypes = { "c", "cpp" },
  },
  terminal = {
    open = true,     -- 使用内置终端时自动打开
    height = 12,     -- 内置终端高度
  },
  betterterm = {
    enabled = true,      -- 优先使用 betterTerm（若已安装）
    index = 0,
    send_delay = 200,
    focus_on_run = true,
    open_if_closed = true,
  },
  make = {
    enabled = true,
    prefer = nil, -- e.g. "make" | "mingw32-make"
    cwd = nil,    -- 默认使用当前文件所在目录
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    telescope = { prompt_title = "Quick-c Make Targets" },
  },
  keymaps = {
    enabled = true,
    build = "<leader>cb",
    run = "<leader>cr",
    build_and_run = "<leader>cR",
    debug = "<leader>cD",
    make = "<leader>cm",
  },
}

local function is_windows()
  return vim.fn.has("win32") == 1
end

-- 异步非阻塞 Makefile 搜索：分批扫描目录，避免卡主线程
local function find_make_root_async(start_dir, cb)
  local cfg = M.config.make or {}
  local up = (cfg.search and cfg.search.up) or 2
  local down = (cfg.search and cfg.search.down) or 3
  local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }
  local names = { 'Makefile', 'makefile', 'GNUmakefile' }
  local uv = vim.loop

  local function join(a, b)
    if a:sub(-1) == '/' or a:sub(-1) == '\\' then return a .. b end
    local sep = is_windows() and '\\' or '/'
    return a .. sep .. b
  end
  local function norm(p)
    p = vim.fn.fnamemodify(p, ':p')
    if is_windows() then p = p:gsub('\\', '/'):lower() else p = p:gsub('//+', '/') end
    if p:sub(-1) == '/' then p = p:sub(1, -2) end
    return p
  end
  local function is_ignored(name)
    for _, n in ipairs(ignore) do if name == n then return true end end
    return false
  end
  local function has_makefile(dir)
    for _, n in ipairs(names) do
      local st = uv.fs_stat(join(dir, n))
      if st and st.type == 'file' then return true end
    end
    return false
  end
  local function parent(dir)
    local p = vim.fn.fnamemodify(dir, ':h')
    if p == nil or p == '' then return dir end
    return p
  end

  local cwd_root = norm(vim.fn.getcwd())

  -- 预生成向上各层起点（受工作目录边界限制）
  local bases = {}
  do
    local cur = start_dir
    for _ = 0, up do
      local cur_norm = norm(cur)
      if not cur_norm:find(cwd_root, 1, true) then break end
      table.insert(bases, cur)
      local nextp = parent(cur)
      if nextp == cur then break end
      local next_norm = norm(nextp)
      if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then break end
      cur = nextp
    end
  end

  -- BFS 队列：每个元素为 { dir, depth }
  local queue = {}
  for _, b in ipairs(bases) do table.insert(queue, { dir = b, depth = 0 }) end

  local scanning = false
  local found = false
  local batch_size = 40 -- 每 tick 处理的目录数

  local function step()
    if scanning then return end
    if found then return end
    scanning = true
    local processed = 0
    while processed < batch_size and #queue > 0 do
      local item = table.remove(queue, 1)
      local dir, depth = item.dir, item.depth
      -- 命中判断
      if has_makefile(dir) then
        found = true
        scanning = false
        cb(dir)
        return
      end
      if depth < down then
        local req = uv.fs_scandir(dir)
        if req then
          while true do
            local name, t = uv.fs_scandir_next(req)
            if not name then break end
            if t == 'directory' and not is_ignored(name) then
              table.insert(queue, { dir = join(dir, name), depth = depth + 1 })
            end
          end
        end
      end
      processed = processed + 1
    end
    scanning = false
    if not found then
      if #queue == 0 then
        -- 未找到，回退为 start_dir
        cb(start_dir)
      else
        vim.defer_fn(step, 1) -- 让出主线程，下一个 tick 继续
      end
    end
  end

  step()
end

-- Makefile 搜索：向上 up 层，向下 down 层，返回含有 Makefile 的目录
-- 同步版本（保留备用，不再直接在热路径使用）
local function find_make_root(start_dir)
  local cfg = M.config.make or {}
  local up = (cfg.search and cfg.search.up) or 2
  local down = (cfg.search and cfg.search.down) or 3
  local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }
  local names = { 'Makefile', 'makefile', 'GNUmakefile' }
  local uv = vim.loop

  local function join(a, b)
    if a:sub(-1) == '/' or a:sub(-1) == '\\' then return a .. b end
    local sep = is_windows() and '\\' or '/'
    return a .. sep .. b
  end

  local function norm(p)
    p = vim.fn.fnamemodify(p, ':p')
    if is_windows() then
      p = p:gsub('\\', '/'):lower()
    else
      p = p:gsub('//+', '/')
    end
    if p:sub(-1) == '/' then p = p:sub(1, -2) end
    return p
  end

  local function is_ignored(name)
    for _, n in ipairs(ignore) do if name == n then return true end end
    return false
  end

  local function has_makefile(dir)
    for _, n in ipairs(names) do
      local p = join(dir, n)
      local st = uv.fs_stat(p)
      if st and st.type == 'file' then return dir end
    end
    return nil
  end

  local function scan_down(dir, depth)
    local found = has_makefile(dir)
    if found then return found end
    if depth <= 0 then return nil end
    local req, iter = uv.fs_scandir(dir)
    if not req then return nil end
    while true do
      local name, t = uv.fs_scandir_next(req)
      if not name then break end
      if t == 'directory' and not is_ignored(name) then
        local sub = join(dir, name)
        local r = scan_down(sub, depth - 1)
        if r then return r end
      end
    end
    return nil
  end

  local function parent(dir)
    local p = vim.fn.fnamemodify(dir, ':h')
    if p == nil or p == '' then return dir end
    return p
  end

  local cur = start_dir
  local cwd_root = norm(vim.fn.getcwd())
  for i = 0, up do
    local cur_norm = norm(cur)
    if not cur_norm:find(cwd_root, 1, true) then break end
    local base = cur
    local r = scan_down(base, down)
    if r then return r end
    local nextp = parent(cur)
    if nextp == cur then break end
    local next_norm = norm(nextp)
    if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then break end
    cur = nextp
  end
  return start_dir
end

local function choose_make()
  if M.config.make and M.config.make.prefer then return M.config.make.prefer end
  if vim.fn.executable("make") == 1 then return "make" end
  if is_windows() and vim.fn.executable("mingw32-make") == 1 then return "mingw32-make" end
  return nil
end

local function is_powershell()
  local sh = (vim.o.shell or ""):lower()
  return sh:find("powershell") or sh:find("pwsh")
end

local function ensure_outdir(dir)
  vim.fn.mkdir(dir, "p")
end

local function default_out_name(sources)
  local ext = is_windows() and ".exe" or ""
  if #sources == 1 then
    local base = vim.fn.fnamemodify(sources[1], ":t:r")
    return base .. ext
  else
    -- 在异步流程中不再同步阻塞输入，这里仅返回默认值
    local name = "a.out"
    if is_windows() and not name:match("%.exe$") then name = name .. ".exe" end
    return name
  end
end

-- 异步获取输出名：当多源文件时使用 vim.ui.input（不会阻塞主线程）
local function get_output_name_async(sources, preset_name, cb)
  if preset_name and preset_name ~= "" then
    cb(preset_name)
    return
  end
  if #sources == 1 then
    cb(default_out_name(sources))
    return
  end
  local def = "a.out"
  if is_windows() and not def:match("%.exe$") then def = def .. ".exe" end
  local ui = vim.ui or {}
  if ui.input then
    ui.input({ prompt = "Output name: ", default = def }, function(input)
      local name = input
      if not name or name == "" then name = def end
      if is_windows() and not name:match("%.exe$") then name = name .. ".exe" end
      cb(name)
    end)
  else
    -- 回退：若无 ui.input 则使用默认，不进行同步阻塞
    cb(def)
  end
end

local function gather_sources()
  -- 默认：只编译当前缓冲文件
  return { vim.fn.expand("%:p") }
end

local function choose_compiler(ft)
  -- 用户可覆盖 compile_cmds 和 toolchain
  local c = M.config
  local domain = is_windows() and c.toolchain.windows or c.toolchain.unix
  local candidates = (ft == "c") and domain.c or domain.cpp
  for _, name in ipairs(candidates) do
    -- 允许 gcc/g++、clang/clang++、cl
    if name == "gcc" or name == "g++" then
      if vim.fn.executable(name) == 1 then return name, "gcc" end
    elseif name == "clang" or name == "clang++" then
      if vim.fn.executable(name) == 1 then return name, "clang" end
    elseif name == "cl" then
      if vim.fn.executable("cl") == 1 then return "cl", "cl" end
    end
  end
  return nil, nil
end

local function build_cmd(ft, sources, out)
  local _, family = choose_compiler(ft)
  if not family then return nil end
  if family == "cl" then
    local args = { "cl", "/Zi", "/Od" }
    for _, s in ipairs(sources) do table.insert(args, s) end
    table.insert(args, "/Fe:" .. out)
    return args
  elseif family == "gcc" then
    local cc = (ft == "c") and "gcc" or "g++"
    local cmd = { cc, "-g", "-O0", "-Wall", "-Wextra" }
    for _, s in ipairs(sources) do table.insert(cmd, s) end
    table.insert(cmd, "-o")
    table.insert(cmd, out)
    return cmd
  else -- clang family
    local cc = (ft == "c") and "clang" or "clang++"
    local cmd = { cc, "-g", "-O0", "-Wall", "-Wextra" }
    for _, s in ipairs(sources) do table.insert(cmd, s) end
    table.insert(cmd, "-o")
    table.insert(cmd, out)
    return cmd
  end
end

local function resolve_out_path(sources, name)
  local outdir = M.config.outdir
  if outdir == "source" then
    local dir = vim.fn.fnamemodify(sources[1], ":p:h")
    return dir .. "/" .. name
  else
    ensure_outdir(outdir)
    return outdir .. "/" .. name
  end
end

local function notify_err(msg) vim.notify("Quick-c: " .. msg, vim.log.levels.ERROR) end
local function notify_info(msg) vim.notify("Quick-c: " .. msg, vim.log.levels.INFO) end
local function notify_warn(msg) vim.notify("Quick-c: " .. msg, vim.log.levels.WARN) end

-- quick-py like terminal helpers
local function run_in_native_terminal(cmd)
  if M.config.terminal.open then
    vim.cmd("botright split | terminal")
    vim.cmd(string.format("resize %d", M.config.terminal.height or 12))
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

local function run_in_betterterm(cmd)
  local ok, betterTerm = pcall(require, 'betterTerm')
  if not ok or M.config.betterterm.enabled == false then return false end
  local cfg = M.config.betterterm or {}
  local idx = cfg.index or 0
  local delay = cfg.send_delay or 200
  local focus = (cfg.focus_on_run ~= false)
  local open_first = (cfg.open_if_closed ~= false)
  if open_first or focus then pcall(betterTerm.open, idx) end
  vim.defer_fn(function()
    local ok_send, err = pcall(betterTerm.send, cmd .. (is_windows() and '\r' or '\n'), idx)
    if not ok_send then
      notify_warn('发送到 betterTerm 失败，改用内置终端: ' .. tostring(err))
      if not run_in_native_terminal(cmd) then
        notify_err('内置终端打开失败')
      end
      return
    end
  end, delay)
  return true
end

-- Make/Telescope helpers
local function run_make_in_terminal(cmdline)
  if not run_in_betterterm(cmdline) then
    if not run_in_native_terminal(cmdline) then
      notify_err("无法运行 make：无法打开终端")
    end
  end
end

local function shell_quote_path(p)
  if is_windows() then
    if is_powershell() then
      return string.format("'%s'", p)
    else
      return string.format('"%s"', p)
    end
  else
    return string.format("'%s'", p)
  end
end

local function parse_make_targets_async(cb)
  local prog = choose_make()
  if not prog then cb({}) return end
  local base = (M.config.make and M.config.make.cwd) or vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
  if M.config.make and M.config.make.cwd then
    local cwd = base
    local lines = {}
    local job = vim.fn.jobstart({ prog, "-qp" }, {
      cwd = cwd,
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then for _, l in ipairs(data) do table.insert(lines, l) end end
      end,
      on_exit = function()
        local targets, seen = {}, {}
        for _, l in ipairs(lines) do
          local name = l:match("^([%w%._%-%+/][^:%$#=]*)%s*:")
          if name then
            name = name:gsub("%s+$", "")
            if not name:match("%%%") and not name:match("^%.") and name ~= "Makefile" and name ~= "makefile" then
              if not seen[name] then seen[name] = true; table.insert(targets, name) end
            end
          end
        end
        table.sort(targets)
        cb(targets)
      end,
    })
    if job <= 0 then cb({}) end
  else
    find_make_root_async(base, function(cwd)
      local lines = {}
      local job = vim.fn.jobstart({ prog, "-qp" }, {
        cwd = cwd,
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data then for _, l in ipairs(data) do table.insert(lines, l) end end
        end,
        on_exit = function()
          local targets, seen = {}, {}
          for _, l in ipairs(lines) do
            local name = l:match("^([%w%._%-%+/][^:%$#=]*)%s*:")
            if name then
              name = name:gsub("%s+$", "")
              if not name:match("%%%") and not name:match("^%.") and name ~= "Makefile" and name ~= "makefile" then
                if not seen[name] then seen[name] = true; table.insert(targets, name) end
              end
            end
          end
          table.sort(targets)
          cb(targets, cwd)
        end,
      })
      if job <= 0 then cb({}, cwd) end
    end)
  end
end

-- 收集多个 Makefile 目录（异步，非阻塞）
local function find_make_roots_async(start_dir, cb)
  local results, seen = {}, {}
  find_make_root_async(start_dir, function(first)
    -- 先把首个结果加入，再继续全量扫描（基于同一 BFS 逻辑：这里简单复用 find_make_root_async 的扫描实现不便，改为轻量级重扫）
    -- 为简化与避免复制大量代码，这里直接在同一策略下进行再次扫描，累计所有命中。
    local cfg = M.config.make or {}
    local up = (cfg.search and cfg.search.up) or 2
    local down = (cfg.search and cfg.search.down) or 3
    local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }
    local names = { 'Makefile', 'makefile', 'GNUmakefile' }
    local uv = vim.loop
    local function join(a, b)
      if a:sub(-1) == '/' or a:sub(-1) == '\\' then return a .. b end
      local sep = is_windows() and '\\' or '/'
      return a .. sep .. b
    end
    local function has_makefile(dir)
      for _, n in ipairs(names) do
        local st = uv.fs_stat(join(dir, n))
        if st and st.type == 'file' then return true end
      end
      return false
    end
    local function parent(dir)
      local p = vim.fn.fnamemodify(dir, ':h')
      if p == nil or p == '' then return dir end
      return p
    end
    local function norm(p)
      p = vim.fn.fnamemodify(p, ':p')
      if is_windows() then p = p:gsub('\\', '/'):lower() else p = p:gsub('//+', '/') end
      if p:sub(-1) == '/' then p = p:sub(1, -2) end
      return p
    end
    local cwd_root = norm(vim.fn.getcwd())
    local bases = {}
    do
      local cur = start_dir
      for _ = 0, up do
        local cur_norm = norm(cur)
        if not cur_norm:find(cwd_root, 1, true) then break end
        table.insert(bases, cur)
        local nextp = parent(cur)
        if nextp == cur then break end
        local next_norm = norm(nextp)
        if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then break end
        cur = nextp
      end
    end
    local queue = {}
    for _, b in ipairs(bases) do table.insert(queue, { dir = b, depth = 0 }) end
    local batch_size = 50
    local function step()
      local processed = 0
      while processed < batch_size and #queue > 0 do
        local item = table.remove(queue, 1)
        local dir, depth = item.dir, item.depth
        if has_makefile(dir) and not seen[dir] then
          seen[dir] = true
          table.insert(results, dir)
        end
        if depth < down then
          local req = uv.fs_scandir(dir)
          if req then
            while true do
              local name, t = uv.fs_scandir_next(req)
              if not name then break end
              if t == 'directory' and name ~= '.git' and name ~= 'node_modules' and name ~= '.cache' then
                table.insert(queue, { dir = join(dir, name), depth = depth + 1 })
              end
            end
          end
        end
        processed = processed + 1
      end
      if #queue > 0 then
        vim.defer_fn(step, 1)
      else
        table.sort(results)
        cb(results)
      end
    end
    step()
  end)
end

local function resolve_make_cwd_async(base, cb)
  if M.config.make and M.config.make.cwd then cb(M.config.make.cwd) return end
  local ok_t = pcall(require, 'telescope')
  find_make_roots_async(base, function(roots)
    if #roots == 0 then cb(base) return end
    if #roots == 1 or not ok_t then cb(roots[1]) return end
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local cwd = vim.fn.getcwd()
    local entries = {}
    for _, d in ipairs(roots) do
      local rel = vim.fn.fnamemodify(d, ':p')
      if rel:sub(1, #cwd) == cwd then
        rel = '.' .. rel:sub(#cwd + 1)
      end
      table.insert(entries, { display = rel, path = d })
    end
    pickers.new({}, {
      prompt_title = 'Select Makefile Directory',
      finder = finders.new_table({
        results = entries,
        entry_maker = function(e)
          return { value = e.path, display = e.display, ordinal = e.display }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(_, map)
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')
        local function choose(bufnr)
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          cb(entry.value)
        end
        map('i', '<CR>', choose)
        map('n', '<CR>', choose)
        return true
      end,
    }):find()
  end)
end

local function parse_make_targets_in_cwd_async(cwd, cb)
  local prog = choose_make()
  if not prog then cb({}) return end
  local lines = {}
  local job = vim.fn.jobstart({ prog, "-qp" }, {
    cwd = cwd,
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then for _, l in ipairs(data) do table.insert(lines, l) end end
    end,
    on_exit = function()
      local targets, seen = {}, {}
      for _, l in ipairs(lines) do
        local name = l:match("^([%w%._%-%+/][^:%$#=]*)%s*:")
        if name then
          name = name:gsub("%s+$", "")
          if not name:match("%%%") and not name:match("^%.") and name ~= "Makefile" and name ~= "makefile" then
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

local function make_run_target(target)
  local prog = choose_make()
  if not prog then
    notify_err("未找到 make 或 mingw32-make")
    return
  end
  local base = (M.config.make and M.config.make.cwd) or vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
  resolve_make_cwd_async(base, function(cwd)
    local cmd = string.format("%s -C %s %s", prog, shell_quote_path(cwd), target or "")
    run_make_in_terminal(cmd)
  end)
end

-- 已知 cwd 时，直接运行目标，避免再次弹出目录选择
local function make_run_in_cwd(target, cwd)
  local prog = choose_make()
  if not prog then
    notify_err("未找到 make 或 mingw32-make")
    return
  end
  local cmd = string.format("%s -C %s %s", prog, shell_quote_path(cwd), target or "")
  run_make_in_terminal(cmd)
end

local function telescope_make()
  if not (M.config.make and M.config.make.enabled ~= false) then
    notify_warn("Make 功能未启用")
    return
  end
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    notify_err("未找到 telescope.nvim")
    return
  end
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local base = (M.config.make and M.config.make.cwd) or vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
  resolve_make_cwd_async(base, function(cwd)
    parse_make_targets_in_cwd_async(cwd, function(targets)
      if #targets == 0 then
        notify_warn("未解析到任何 make 目标")
        return
      end
      -- 附加自定义参数入口
      local results = vim.list_extend({ '[自定义参数…]' }, targets)
      local title = (M.config.make.telescope and M.config.make.telescope.prompt_title) or "Make Targets"
      pickers.new({}, {
        prompt_title = title .. ' (' .. cwd .. ')',
        finder = finders.new_table({ results = results }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(_, map)
          local actions = require('telescope.actions')
          local action_state = require('telescope.actions.state')
          local function choose(bufnr)
            local entry = action_state.get_selected_entry()
            actions.close(bufnr)
            local val = entry[1]
            if val == '[自定义参数…]' then
              local ui = vim.ui or {}
              if ui.input then
                ui.input({ prompt = 'make 参数: ' }, function(args)
                  if not args or args == '' then return end
                  local prog = choose_make()
                  if not prog then notify_err('未找到 make 或 mingw32-make'); return end
                  local cmd = string.format("%s -C %s %s", prog, shell_quote_path(cwd), args)
                  run_make_in_terminal(cmd)
                end)
              end
            else
              make_run_in_cwd(val, cwd)
            end
          end
          map('i', '<CR>', choose)
          map('n', '<CR>', choose)
          return true
        end,
      }):find()
    end)
  end)
end

local function build(sources, target_name, opts)
  local ft = vim.bo.filetype
  if ft ~= "c" and ft ~= "cpp" then
    notify_warn("仅支持 c/cpp 文件")
    return
  end
  sources = sources or gather_sources()
  if not sources or #sources == 0 then
    notify_warn("未找到源码文件")
    return
  end
  opts = opts or {}
  get_output_name_async(sources, target_name, function(name)
    local exe = resolve_out_path(sources, name)
    local cmd = build_cmd(ft, sources, exe)
    if not cmd then
      notify_err("未找到可用编译器，请检查 PATH 或在 setup 中自定义 compile 命令")
      if opts.on_exit then pcall(opts.on_exit, 1, nil) end
      return
    end
    local ok = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      detach = false,
      on_stderr = function(_, d)
        if d and #d > 0 then notify_warn(table.concat(d, "\n")) end
      end,
      on_exit = function(_, code)
        if code == 0 then
          notify_info("Build OK -> " .. exe)
        else
          notify_err("Build failed (" .. code .. ")")
        end
        if opts.on_exit then pcall(opts.on_exit, code, exe) end
      end,
    })
    if ok <= 0 then notify_err("启动编译进程失败") end
  end)
end

local function run(exe)
  local cur = { vim.fn.expand("%:p") }
  exe = exe or resolve_out_path(cur, default_out_name(cur))
  if vim.fn.filereadable(exe) ~= 1 then
    notify_warn("未找到可执行文件，请先构建")
    return
  end
  local cmd
  if is_windows() then
    if is_powershell() then
      cmd = string.format("& '%s'", exe)
    else
      cmd = string.format('"%s"', exe)
    end
  else
    cmd = string.format("'%s'", exe)
  end
  if not run_in_betterterm(cmd) then
    if not run_in_native_terminal(cmd) then
      notify_err("无法运行命令：无法打开终端")
    end
  end
end

local function build_and_run()
  build(nil, nil, {
    on_exit = function(code, exe)
      if code == 0 then
        -- 构建成功后再运行，避免竞态
        run(exe)
      end
    end,
  })
end

local function debug_run(exe)
  local cur = { vim.fn.expand("%:p") }
  exe = exe or resolve_out_path(cur, default_out_name(cur))
  if vim.fn.filereadable(exe) ~= 1 then
    notify_warn("未找到可执行文件，请先构建")
    return
  end
  local ok, dap = pcall(require, "dap")
  if not ok then
    notify_err("未找到 nvim-dap")
    return
  end
  dap.run({
    type = "codelldb",
    request = "launch",
    name = "Quick-c Debug",
    program = exe,
    cwd = vim.fn.getcwd(),
    stopOnEntry = false,
    runInTerminal = true,
    initCommands = { "settings set target.process.thread.step-avoid-libraries true" },
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.api.nvim_create_user_command("QuickCBuild", function()
    build()
  end, {})
  vim.api.nvim_create_user_command("QuickCRun", function()
    run()
  end, {})
  vim.api.nvim_create_user_command("QuickCBR", function()
    build_and_run()
  end, {})
  vim.api.nvim_create_user_command("QuickCDebug", function()
    debug_run()
  end, {})
  vim.api.nvim_create_user_command("QuickCMake", function()
    telescope_make()
  end, {})
  vim.api.nvim_create_user_command("QuickCMakeRun", function(opts)
    local target = table.concat(opts.fargs or {}, " ")
    make_run_target(target)
  end, { nargs = "*" })

  -- autorun (build & run on save)
  local group = vim.api.nvim_create_augroup("QuickC_AutoRun", { clear = true })
  local function ft_enabled(ft)
    for _, f in ipairs(M.config.autorun.filetypes or {}) do
      if f == ft then return true end
    end
    return false
  end
  local function setup_autorun()
    if not M.config.autorun.enabled then return end
    for _, ev in ipairs(M.config.autorun.events or { "BufWritePost" }) do
      vim.api.nvim_create_autocmd(ev, {
        group = group,
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          if not ft_enabled(ft) then return end
          build_and_run()
        end,
      })
    end
  end
  setup_autorun()
  vim.api.nvim_create_user_command("QuickCAutoRunToggle", function()
    M.config.autorun.enabled = not M.config.autorun.enabled
    vim.api.nvim_clear_autocmds({ group = group })
    setup_autorun()
    vim.notify("Quick-c: autorun " .. (M.config.autorun.enabled and "enabled" or "disabled"))
  end, {})

  local function setup_keymaps()
    local km = M.config.keymaps or {}
    if km.enabled == false then return end
    local function map(lhs, rhs, desc)
      if type(lhs) == 'string' and lhs ~= '' and rhs then
        vim.keymap.set('n', lhs, rhs, { desc = desc })
      end
    end
    map(km.build, build, "Quick-c: Compile current C/C++ file")
    map(km.run, run, "Quick-c: Run current C/C++ exe")
    map(km.build_and_run, build_and_run, "Quick-c: Build & Run current C/C++")
    map(km.debug, debug_run, "Quick-c: Debug current C/C++ exe")
    map(km.make, telescope_make, "Quick-c: Make targets (Telescope)")
  end

  setup_keymaps()
end

return M

