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
  local cwd = (M.config.make and M.config.make.cwd) or vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
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
  local cwd = (M.config.make and M.config.make.cwd) or vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
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
  parse_make_targets_async(function(targets)
    if #targets == 0 then
      notify_warn("未解析到任何 make 目标")
      return
    end
    local title = (M.config.make.telescope and M.config.make.telescope.prompt_title) or "Make Targets"
    pickers.new({}, {
      prompt_title = title,
      finder = finders.new_table({ results = targets }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(_, map)
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')
        map('i', '<CR>', function(bufnr)
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          make_run_target(entry[1])
        end)
        map('n', '<CR>', function(bufnr)
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          make_run_target(entry[1])
        end)
        return true
      end,
    }):find()
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

