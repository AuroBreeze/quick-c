local M = {}
local T = require('quick-c.terminal')
local U = require('quick-c.util')
local MS = require('quick-c.make_search')
local MK = require('quick-c.make')
local CFG = require('quick-c.config')
local PROJECT_CONFIG = require('quick-c.project_config')

M.config = CFG.defaults
M.user_opts = {}

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
    local base = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
    resolve_make_cwd_async(base, function(cwd)
        local mkargs = (M.config.make and M.config.make.args) or {}
        if mkargs.prompt ~= false then
            local def = mkargs.default or ""
            local key = cwd or "" -- simple remember per-cwd in vim.g
            vim.g.quick_c_make_last_args = vim.g.quick_c_make_last_args or {}
            if mkargs.remember ~= false then
                def = vim.g.quick_c_make_last_args[key] or def
            end
            local ui = vim.ui or {}
            if ui.input then
                ui.input({ prompt = 'make 参数: ', default = def }, function(arg)
                    if mkargs.remember ~= false and arg and arg ~= '' then
                        vim.g.quick_c_make_last_args[key] = arg
                    end
                    local extra = (arg and arg ~= '') and (' ' .. arg) or ''
                    local cmd = string.format("%s -C %s %s%s", prog, shell_quote_path(cwd), target or '', extra)
                    run_make_in_terminal(cmd)
                end)
                return
            end
        end
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

local function build(...) require('quick-c.build').build(M.config,
        { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
local function run(...) require('quick-c.build').run(M.config,
        { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
local function build_and_run(...) require('quick-c.build').build_and_run(M.config,
        { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
local function debug_run(...) require('quick-c.build').debug_run(M.config,
        { err = notify_err, warn = notify_warn, info = notify_info }, ...) end
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
    M.config = vim.tbl_deep_extend("force", CFG.defaults, M.user_opts or {})
    local merged_config = PROJECT_CONFIG.setup(M.config)
    if merged_config then M.config = merged_config U.notify_info("已加载项目配置文件 (.quick-c.json)") end
end

function M.setup(opts)
    M.user_opts = opts or {}
    recompute_config()
    vim.api.nvim_create_user_command("QuickCBuild", function(opts)
        local sources = opts.fargs and #opts.fargs > 0 and opts.fargs or nil
        if sources then
            build({ sources = sources })
        else
            build()
        end
    end, { nargs = "*", complete = "file" })
    vim.api.nvim_create_user_command("QuickCRun", function(opts)
        local sources = opts.fargs and #opts.fargs > 0 and opts.fargs or nil
        if sources then
            run({ sources = sources })
        else
            run()
        end
    end, { nargs = "*", complete = "file" })
    vim.api.nvim_create_user_command("QuickCBR", function(opts)
        local sources = opts.fargs and #opts.fargs > 0 and opts.fargs or nil
        if sources then
            build_and_run({ sources = sources })
        else
            build_and_run()
        end
    end, { nargs = "*", complete = "file" })
    vim.api.nvim_create_user_command("QuickCDebug", function()
        debug_run()
    end, {})
    vim.api.nvim_create_user_command("QuickCCompileDB", function()
        cc_apply()
    end, {})
    vim.api.nvim_create_user_command("QuickCCompileDBGen", function()
        cc_generate()
    end, {})
    vim.api.nvim_create_user_command("QuickCCompileDBUse", function()
        cc_use()
    end, {})
    vim.api.nvim_create_user_command("QuickCQuickfix", function()
        local cfg = M.config.diagnostics and M.config.diagnostics.quickfix or {}
        if cfg.use_telescope then
            local ok, tb = pcall(require, 'telescope.builtin')
            if ok then
                tb.quickfix(); return
            end
        end
        vim.cmd('copen')
    end, {})
    vim.api.nvim_create_user_command("QuickCMake", function()
        telescope_make()
    end, {})
    vim.api.nvim_create_user_command("QuickCMakeRun", function(opts)
        local target = table.concat(opts.fargs or {}, " ")
        make_run_target(target)
    end, { nargs = "*" })

    vim.api.nvim_create_user_command("QuickCReload", function()
        recompute_config()
        vim.notify("Quick-c: Config reloaded", vim.log.levels.INFO)
    end, {})

    -- Debug: show effective config and detected project config path
    vim.api.nvim_create_user_command("QuickCConfig", function()
        local cfg = M.config
        local ok, inspect = pcall(vim.inspect, cfg)
        local lines = {}
        table.insert(lines, "Quick-c: Effective Config")
        table.insert(lines, ok and inspect or "<inspect failed>")
        local root = vim.fn.getcwd()
        local p = PROJECT_CONFIG.find_project_config(root)
        table.insert(lines, "Project root: " .. root)
        table.insert(lines, "Project config: " .. (p or "<not found>"))
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end, {})

    pcall(vim.api.nvim_create_autocmd, 'DirChanged', { callback = function() pcall(recompute_config) end })

    require('quick-c.keys').setup(M.config, {
        build = build,
        run = run,
        build_and_run = build_and_run,
        debug = debug_run,
        make = telescope_make,
    })
end

return M
