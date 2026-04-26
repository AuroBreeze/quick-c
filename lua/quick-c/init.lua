-- Setup: Line 236
-- QuickCCompileDBGenCCMake: Line 309

local M = {}
local T = require 'quick-c.terminal'
local AS = require 'quick-c.autosave'
local U = require 'quick-c.util'
local MS = require 'quick-c.make_search'
local MK = require 'quick-c.make'
local CFG = require 'quick-c.config'
local PROJECT_CONFIG = require 'quick-c.project_config'
local CM = require 'quick-c.cmake'
local STATUS = require 'quick-c.status'
local TASK = require 'quick-c.task'

M.config = CFG.defaults
M.user_opts = {}
M._last_project_config_path = nil
M._reload_timer = nil
M._suppress_notice_until = 0 -- uv.now() deadline in ms
M._autosave_timer = nil
M._inited = false

local function is_windows()
  return U.is_windows()
end

-- notify helpers must be defined before any function that captures them
local function notify_err(msg)
  U.notify_err(msg)
end
local function notify_info(msg)
  U.notify_info(msg)
end
local function notify_warn(msg)
  U.notify_warn(msg)
end

-- CMake helpers
local function cmake_run_target(target)
  return CM.run_build_from_current(M.config, target, function(cmd)
    return T.select_or_run_in_terminal(M.config, is_windows, cmd, notify_warn, notify_err)
  end)
end

local function cmake_configure()
  return CM.configure_from_current(M.config, { err = notify_err, warn = notify_warn, info = notify_info })
end

-- 异步非阻塞 Makefile 搜索：分批扫描目录，避免卡主线程
local function find_make_root_async(start_dir, cb)
  return MS.find_make_root_async(M.config, start_dir, cb)
end

local function choose_make()
  return MK.choose_make(M.config)
end

local function is_powershell()
  return U.is_powershell()
end

-- quick-py like terminal helpers
local function run_in_native_terminal(cmd)
  return T.run_in_native_terminal(M.config, is_windows, cmd)
end

local function run_in_betterterm(cmd)
  return T.run_in_betterterm(M.config, is_windows, cmd, notify_warn, notify_err)
end

-- Make/Telescope helpers
local function run_make_in_terminal(cmdline)
  return T.select_or_run_in_terminal(M.config, is_windows, cmdline, notify_warn, notify_err)
end

local function shell_quote_path(p)
  return U.shell_quote_path(p)
end

local function resolve_make_cwd_async(base, cb)
  return MS.resolve_make_cwd_async(M.config, base, cb)
end

local function parse_make_targets_in_cwd_async(cwd, cb)
  return MK.parse_make_targets_in_cwd_async(M.config, cwd, cb)
end

local function make_run_target(target)
  local prog = choose_make()
  if not prog then
    notify_err 'cannot find make or mingw32-make'
    return
  end
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  resolve_make_cwd_async(base, function(cwd)
    local mkargs = (M.config.make and M.config.make.args) or {}
    local no_dash_C = (M.config.make and M.config.make.no_dash_C) == true
    if mkargs.prompt ~= false then
      local def = mkargs.default or ''
      local key = cwd or '' -- simple remember per-cwd in vim.g
      vim.g.quick_c_make_last_args = vim.g.quick_c_make_last_args or {}
      if mkargs.remember ~= false then
        def = vim.g.quick_c_make_last_args[key] or def
      end
      local ui = vim.ui or {}
      if ui.input then
        ui.input({ prompt = 'make args: ', default = def }, function(arg)
          if mkargs.remember ~= false and arg and arg ~= '' then
            vim.g.quick_c_make_last_args[key] = arg
          end
          local extra = (arg and arg ~= '') and (' ' .. arg) or ''
          local cmd
          if no_dash_C then
            cmd = string.format('%s %s%s', prog, target or '', extra)
          else
            cmd = string.format('%s -C %s %s%s', prog, shell_quote_path(cwd), target or '', extra)
          end
          run_make_in_terminal(cmd)
        end)
        return
      end
    end
    local cmd
    if no_dash_C then
      cmd = string.format('%s %s', prog, target or '')
    else
      cmd = string.format('%s -C %s %s', prog, shell_quote_path(cwd), target or '')
    end
    run_make_in_terminal(cmd)
  end)
end

-- 已知 cwd 时，直接运行目标，避免再次弹出目录选择
local function make_run_in_cwd(target, cwd)
  return MK.make_run_in_cwd(M.config, cwd, target, function(cmd)
    run_make_in_terminal(cmd)
  end)
end

-- Custom make command: resolve cwd, then prompt a full command line for user to edit
local function make_run_custom_cmd()
  local prog = choose_make() or 'make'
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  resolve_make_cwd_async(base, function(cwd)
    local no_dash_C = (M.config.make and M.config.make.no_dash_C) == true
    local def
    if no_dash_C then
      def = string.format('%s ', prog)
    else
      def = string.format('%s -C %s ', prog, shell_quote_path(cwd))
    end
    local ui = vim.ui or {}
    if not ui.input then
      run_make_in_terminal(def)
      return
    end
    ui.input({ prompt = 'make command: ', default = def }, function(cmd)
      if not cmd or cmd == '' then
        return
      end
      run_make_in_terminal(cmd)
    end)
  end)
end

local function telescope_make()
  local ok, mod = pcall(require, 'quick-c.telescope')
  if not ok then
    notify_err 'cannot load quick-c.telescope module'
    return
  end
  mod.telescope_make(
    M.config,
    resolve_make_cwd_async,
    parse_make_targets_in_cwd_async,
    make_run_in_cwd,
    choose_make,
    shell_quote_path,
    run_make_in_terminal
  )
end

local function build(...)
  require('quick-c.build').build(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...)
end
local function run(...)
  require('quick-c.build').run(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...)
end
local function build_and_run(...)
  require('quick-c.build').build_and_run(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...)
end
local function debug_run(...)
  require('quick-c.build').debug_run(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...)
end
local function cc_apply()
  require('quick-c.cc').apply(M.config, { err = notify_err, warn = notify_warn, info = notify_info })
end
local function cc_generate()
  local cfg = M.config
  cfg.compile_commands = cfg.compile_commands or {}
  cfg.compile_commands.mode = 'generate'
  require('quick-c.cc').generate(cfg, { err = notify_err, warn = notify_warn, info = notify_info })
end
local function cc_use()
  local cfg = M.config
  cfg.compile_commands = cfg.compile_commands or {}
  cfg.compile_commands.mode = 'use'
  require('quick-c.cc').use_external(cfg, { err = notify_err, warn = notify_warn, info = notify_info })
end

local function recompute_config()
  M.config = vim.tbl_deep_extend('force', CFG.defaults, M.user_opts or {})
  local merged_config = PROJECT_CONFIG.setup(M.config)
  if merged_config then
    M.config = merged_config
    local root = vim.fn.getcwd()
    local p = PROJECT_CONFIG.find_project_config(root)
    local now = (vim.loop and vim.loop.now and vim.loop.now()) or 0
    if p and p ~= M._last_project_config_path then
      if now >= (M._suppress_notice_until or 0) then
        U.notify_info 'project config loaded (.quick-c.json)'
      end
      M._last_project_config_path = p
    end
  else
    M._last_project_config_path = nil
  end
  -- Normalize toggles: when telescope_enhance is false, turn off telescope-based quickfix
  if M.config.telescope_enhance == false then
    M.config.diagnostics = M.config.diagnostics or {}
    M.config.diagnostics.quickfix = M.config.diagnostics.quickfix or {}
    M.config.diagnostics.quickfix.use_telescope = false
  end
end

function M.setup(opts)
  M.user_opts = opts or {}
  recompute_config()
  -- mark setup done for auto-setup guard
  pcall(function() vim.g.quick_c_auto_setup_done = true end)
  if not M._inited then
  vim.api.nvim_create_user_command('QuickCBuild', function(opts)
    local sources = opts.fargs and #opts.fargs > 0 and opts.fargs or nil
    if sources then
      build { sources = sources }
    else
      build()
    end
  end, { nargs = '*', complete = 'file' })
  vim.api.nvim_create_user_command('QuickCRun', function(opts)
    local sources = opts.fargs and #opts.fargs > 0 and opts.fargs or nil
    if sources then
      run { sources = sources }
    else
      run()
    end
  end, { nargs = '*', complete = 'file' })
  vim.api.nvim_create_user_command('QuickCBR', function(opts)
    local sources = opts.fargs and #opts.fargs > 0 and opts.fargs or nil
    if sources then
      build_and_run { sources = sources }
    else
      build_and_run()
    end
  end, { nargs = '*', complete = 'file' })
  vim.api.nvim_create_user_command('QuickCDebug', function()
    debug_run()
  end, {})
  vim.api.nvim_create_user_command('QuickCCompileDB', function()
    cc_apply()
  end, {})
  vim.api.nvim_create_user_command('QuickCCompileDBGen', function()
    cc_generate()
  end, {})
  vim.api.nvim_create_user_command('QuickCCompileDBUse', function()
    cc_use()
  end, {})
  -- compile_commands helpers
  vim.api.nvim_create_user_command('QuickCCompileDBGenProject', function()
    local CC = require 'quick-c.cc'
    CC.generate_for_project(M.config, { err = notify_err, warn = notify_warn, info = notify_info })
  end, {})
  vim.api.nvim_create_user_command('QuickCCompileDBGenDir', function(opts)
    local CC = require 'quick-c.cc'
    local dir = (opts.args or '')
    if dir == '' then
      local ui = vim.ui or {}
      if ui.input then
        ui.input({ prompt = 'Directory: ', default = vim.fn.getcwd() }, function(input)
          if not input or input == '' then return end
          CC.generate_for_dir(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, input)
        end)
      else
        CC.generate_for_dir(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, vim.fn.getcwd())
      end
    else
      CC.generate_for_dir(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, dir)
    end
  end, { nargs = '?', complete = 'dir' })
  vim.api.nvim_create_user_command('QuickCCompileDBGenSources', function()
    local ok_t, tel = pcall(require, 'quick-c.telescope')
    if ok_t and tel and tel.telescope_quickc_sources then
      tel.telescope_quickc_sources(M.config, { mode = 'generate_compile_commands' })
      return
    end
    notify_warn 'Telescope not available; please use QuickCCompileDBGenDir/Project instead'
  end, {})
  vim.api.nvim_create_user_command('QuickCCompileDBGenCMake', function()
    local CC = require 'quick-c.cc'
    CC.generate_from_cmake(M.config, { err = notify_err, warn = notify_warn, info = notify_info })
  end, {})
  vim.api.nvim_create_user_command('QuickCQuickfix', function()
    local cfg = M.config.diagnostics and M.config.diagnostics.quickfix or {}
    if cfg.use_telescope then
      local ok, tb = pcall(require, 'telescope.builtin')
      if ok then
        tb.quickfix()
        return
      end
    end
    vim.cmd 'copen'
  end, {})
  -- Validate configuration (global + project)
  vim.api.nvim_create_user_command('QuickCCheck', function()
    local ok_v, V = pcall(require, 'quick-c.config_validate')
    if not ok_v then
      vim.notify('Quick-c: config_validate module not found', vim.log.levels.ERROR)
      return
    end
    V.run_and_notify(M.config)
  end, {})
  -- Health report
  vim.api.nvim_create_user_command('QuickCHealth', function()
    local ok_h, H = pcall(require, 'quick-c.health')
    if not ok_h then
      vim.notify('Quick-c: health module not found', vim.log.levels.ERROR)
      return
    end
    local ok, lines = H.run(M.config)
    local lvl = ok and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(table.concat(lines, '\n'), lvl)
  end, {})
  -- Make commands (respect make.enabled and telescope_enhance)
  if not (M.config.make and M.config.make.enabled == false) then
    if M.config.telescope_enhance ~= false then
      vim.api.nvim_create_user_command('QuickCMake', function()
        telescope_make()
      end, {})
    end
    vim.api.nvim_create_user_command('QuickCMakeRun', function(opts)
      local target = table.concat(opts.fargs or {}, ' ')
      make_run_target(target)
    end, { nargs = '*' })
    vim.api.nvim_create_user_command('QuickCMakeCmd', function()
      make_run_custom_cmd()
    end, {})
  end

  -- CMake commands (respect cmake.enabled and telescope_enhance)
  if not (M.config.cmake and M.config.cmake.enabled == false) then
    if M.config.telescope_enhance ~= false then
      vim.api.nvim_create_user_command('QuickCCMake', function()
        require('quick-c.telescope').telescope_cmake(M.config)
      end, {})
    end
    vim.api.nvim_create_user_command('QuickCCMakeRun', function(opts)
      local target = table.concat(opts.fargs or {}, ' ')
      cmake_run_target(target ~= '' and target or nil)
    end, { nargs = '*' })
    vim.api.nvim_create_user_command('QuickCCMakeConfigure', function()
      cmake_configure()
    end, {})
  end

  vim.api.nvim_create_user_command('QuickCReload', function()
    local uv = vim.loop
    if uv and uv.now then
      M._suppress_notice_until = uv.now() + 1000
    end
    recompute_config()
    vim.notify('Quick-c: Config reloaded', vim.log.levels.INFO)
  end, {})

  -- Task control commands
  vim.api.nvim_create_user_command('QuickCStop', function()
    if TASK.cancel_current() then
      notify_info 'Requested to cancel current task'
    else
      notify_warn 'No task currently running'
    end
  end, {})
  vim.api.nvim_create_user_command('QuickCRetry', function()
    if TASK.retry_last() then
      notify_info 'Retry task added to queue'
    else
      notify_warn 'No task to retry'
    end
  end, {})

  -- Unified entry: :QuickC
  vim.api.nvim_create_user_command('QuickC', function()
    local items = {}
    local function add(label, fn)
      table.insert(items, { label = label, fn = fn })
    end
    add('Build', function() build() end)
    add('Run', function() run() end)
    add('Build & Run', function() build_and_run() end)
    add('Debug', function() debug_run() end)
    if not (M.config.make and M.config.make.enabled == false) then
      add('Make Targets', function()
        if M.config.telescope_enhance ~= false then
          telescope_make()
        else
          notify_warn('Telescope UI disabled; use :QuickCMakeRun or :QuickCMakeCmd')
        end
      end)
    end
    if not (M.config.cmake and M.config.cmake.enabled == false) then
      add('CMake Targets', function()
        if M.config.telescope_enhance ~= false then
          local ok, tel = pcall(require, 'quick-c.telescope')
          if ok and tel and tel.telescope_cmake then
            tel.telescope_cmake(M.config)
          else
            notify_err('quick-c.telescope not available')
          end
        else
          cmake_run_target(nil)
        end
      end)
    end
    if M.config.telescope_enhance ~= false then
      add('Select Sources (Telescope)', function()
        local ok, tel = pcall(require, 'quick-c.telescope')
        if ok and tel and tel.telescope_quickc_sources then
          tel.telescope_quickc_sources(M.config)
        else
          notify_err('quick-c.telescope not available')
        end
      end)
    end
    add('Open Quickfix', function()
      pcall(vim.cmd, 'QuickCQuickfix')
    end)
    -- Compile DB shortcuts
    add('Compile DB (CMake export)', function()
      local CC = require 'quick-c.cc'
      CC.generate_from_cmake(M.config, { err = notify_err, warn = notify_warn, info = notify_info })
    end)
    add('Compile DB (Project scan)', function()
      local CC = require 'quick-c.cc'
      CC.generate_for_project(M.config, { err = notify_err, warn = notify_warn, info = notify_info })
    end)
    if M.config.telescope_enhance ~= false then
      add('Compile DB (Select sources)', function()
        local ok_t, tel = pcall(require, 'quick-c.telescope')
        if ok_t and tel and tel.telescope_quickc_sources then
          tel.telescope_quickc_sources(M.config, { mode = 'generate_compile_commands' })
        else
          notify_warn 'Telescope not available'
        end
      end)
    end

    local use_telescope = (M.config.telescope_enhance ~= false) and pcall(require, 'telescope')
    if use_telescope then
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local conf = require('telescope.config').values
      local entries = {}
      for _, it in ipairs(items) do table.insert(entries, it) end
      pickers
        .new({}, {
          prompt_title = 'Quick-c',
          finder = finders.new_table {
            results = entries,
            entry_maker = function(e)
              return { value = e, display = e.label, ordinal = e.label }
            end,
          },
          sorter = conf.generic_sorter {},
          attach_mappings = function(bufnr, map)
            local actions = require 'telescope.actions'
            local action_state = require 'telescope.actions.state'
            local function choose(pbuf)
              local entry = action_state.get_selected_entry()
              actions.close(pbuf)
              local v = entry and entry.value
              if v and v.fn then v.fn() end
            end
            map('i', '<CR>', choose)
            map('n', '<CR>', choose)
            return true
          end,
        })
        :find()
      return
    end
    local ui = vim.ui or {}
    if ui.select then
      local labels = {}
      for _, it in ipairs(items) do table.insert(labels, it.label) end
      ui.select(labels, { prompt = 'Quick-c' }, function(choice)
        if not choice then return end
        for _, it in ipairs(items) do if it.label == choice then it.fn(); return end end
      end)
      return
    end
    -- Fallback: run build directly
    build()
    end, {})

    -- Debug: show effective config and detected project config path
    vim.api.nvim_create_user_command('QuickCConfig', function()
      local cfg = M.config
      local ok, inspect = pcall(vim.inspect, cfg)
      local lines = {}
      table.insert(lines, 'Quick-c: Effective Config')
      table.insert(lines, ok and inspect or '<inspect failed>')
      local root = vim.fn.getcwd()
      local p = PROJECT_CONFIG.find_project_config(root)
      table.insert(lines, 'Project root: ' .. root)
      table.insert(lines, 'Project config: ' .. (p or '<not found>'))
      vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, {})

  local function schedule_recompute(ms)
    local uv = vim.loop
    if not M._reload_timer or M._reload_timer:is_closing() then
      M._reload_timer = uv.new_timer()
    end
    local t = M._reload_timer
    t:stop()
    t:start(ms or 400, 0, function()
      vim.schedule(function()
        pcall(recompute_config)
      end)
    end)
  end

  local ok_grp, grp = pcall(vim.api.nvim_create_augroup, 'QuickC_Autocmds', { clear = true })
  if not ok_grp then
    grp = nil
  end
  pcall(vim.api.nvim_create_autocmd, 'DirChanged', {
    group = grp,
    callback = function()
      schedule_recompute(400)
    end,
  })

    -- Autosave
    pcall(function()
      AS.setup(M.config)
    end)
    M._inited = true
  end

  -- Auto-reload when saving project config in current root
  pcall(vim.api.nvim_create_autocmd, 'BufWritePost', {
    group = grp,
    pattern = '.quick-c.json',
    callback = function(args)
      local saved = vim.fn.fnamemodify(args.file or '', ':p')
      local expect = vim.fn.fnamemodify(U.join(vim.fn.getcwd(), '.quick-c.json'), ':p')
      if saved == expect then
        local uv = vim.loop
        if uv and uv.now then
          M._suppress_notice_until = uv.now() + 1000
        end
        schedule_recompute(100)
        vim.schedule(function()
          vim.notify('Quick-c: project config reloaded', vim.log.levels.INFO)
        end)
      end
    end,
  })

  -- Prepare callbacks for keymaps respecting toggles
  local callbacks = {
    build = build,
    run = run,
    build_and_run = build_and_run,
    debug = debug_run,
    make = nil,
    cmake = nil,
    cmake_run = nil,
    cmake_configure = nil,
    stop = function()
      if TASK.cancel_current() then
        notify_info 'Requested to cancel current task'
      else
        notify_warn 'No task currently running'
      end
    end,
    retry = function()
      if TASK.retry_last() then
        notify_info 'Retry task added to queue'
      else
        notify_warn 'No task to retry'
      end
    end,
  }
  -- Enable Telescope-based callbacks only when allowed
  if not (M.config.make and M.config.make.enabled == false) and M.config.telescope_enhance ~= false then
    callbacks.make = telescope_make
  end
  if not (M.config.cmake and M.config.cmake.enabled == false) then
    if M.config.telescope_enhance ~= false then
      callbacks.cmake = function()
        require('quick-c.telescope').telescope_cmake(M.config)
      end
    end
    callbacks.cmake_run = function()
      cmake_run_target(nil)
    end
    callbacks.cmake_configure = function()
      cmake_configure()
    end
  end
  require('quick-c.keys').setup(M.config, callbacks)
end

function M.status()
  return STATUS.get()
end

return M
