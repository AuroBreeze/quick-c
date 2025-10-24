local M = {}
local T = require('quick-c.terminal')
local U = require('quick-c.util')
local MS = require('quick-c.make_search')
local MK = require('quick-c.make')
local CFG = require('quick-c.config')

M.config = CFG.defaults

local function is_windows() return U.is_windows() end

-- 异步非阻塞 Makefile 搜索：分批扫描目录，避免卡主线程
local function find_make_root_async(start_dir, cb)
  return MS.find_make_root_async(M.config, start_dir, cb)
end

local function choose_make()
  return MK.choose_make(M.config)
end

local function is_powershell() return U.is_powershell() end


local function notify_err(msg) U.notify_err(msg) end
local function notify_info(msg) U.notify_info(msg) end
local function notify_warn(msg) U.notify_warn(msg) end

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
  return MK.make_run_in_cwd(M.config, cwd, target, function(cmd)
    run_make_in_terminal(cmd)
  end)
end

local function telescope_make()
  local ok, mod = pcall(require, 'quick-c.telescope')
  if not ok then
    notify_err('无法加载 quick-c.telescope 模块')
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

local function build(...) require('quick-c.build').build(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
local function run(...) require('quick-c.build').run(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
local function build_and_run(...) require('quick-c.build').build_and_run(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
local function debug_run(...) require('quick-c.build').debug_run(M.config, { err = notify_err, warn = notify_warn, info = notify_info }, ...) end

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

  require('quick-c.keys').setup(M.config, {
    build = build,
    run = run,
    build_and_run = build_and_run,
    debug = debug_run,
    make = telescope_make,
  })
end

return M

