local M = {}
local U = require('quick-c.util')
local LAST_ARGS = {}

-- Telescope picker for make: select cwd (resolved outside) -> list targets -> run
-- External dependencies are injected to avoid circular requires.
-- Args:
--   config: plugin config table
--   resolve_make_cwd_async(base, cb)
--   parse_make_targets_in_cwd_async(cwd, cb)
--   make_run_in_cwd(target, cwd)
--   choose_make(): string|nil
--   shell_quote_path(path): string
--   run_make_in_terminal(cmdline): nil
function M.telescope_make(config,
  resolve_make_cwd_async,
  parse_make_targets_in_cwd_async,
  make_run_in_cwd,
  choose_make,
  shell_quote_path,
  run_make_in_terminal)

  if not (config.make and config.make.enabled ~= false) then
    vim.notify('Make 功能未启用', vim.log.levels.WARN)
    return
  end
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('未找到 telescope.nvim', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values

  local base = (config.make and config.make.cwd) or vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
  resolve_make_cwd_async(base, function(cwd)
    parse_make_targets_in_cwd_async(cwd, function(res)
      local targets, phony_set = {}, {}
      if type(res) == 'table' and res.targets then
        targets = res.targets or {}
        phony_set = res.phony or {}
      else
        targets = res or {}
      end
      if #targets == 0 then
        vim.notify('未解析到任何 make 目标', vim.log.levels.WARN)
        return
      end
      local telcfg = (config.make and config.make.telescope) or {}
      local mktargets = (config.make and config.make.targets) or {}
      local mkargs = (config.make and config.make.args) or {}
      local phony_only = false

      local function build_entries()
        local entries = {}
        table.insert(entries, { display = '[自定义参数…]', kind = 'args' })
        local list = {}
        if mktargets.prioritize_phony ~= false then
          local a, b = {}, {}
          for _, t in ipairs(targets) do
            if phony_set[t] then table.insert(a, t) else table.insert(b, t) end
          end
          list = {}
          if phony_only then
            list = a
          else
            for _, t in ipairs(a) do table.insert(list, t) end
            for _, t in ipairs(b) do table.insert(list, t) end
          end
        else
          list = targets
        end
        for _, t in ipairs(list) do
          local disp = phony_set[t] and (t .. ' [PHONY]') or t
          table.insert(entries, { display = disp, value = t, kind = 'target', phony = phony_set[t] or false })
        end
        return entries
      end

      local entries = build_entries()
      local title = (config.make.telescope and config.make.telescope.prompt_title) or 'Make Targets'
      pickers.new({}, {
        prompt_title = title .. ' (' .. cwd .. ')',
        finder = finders.new_table({
          results = entries,
          entry_maker = function(e)
            return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
          end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = (function()
          if telcfg.preview == false then return nil end
          local previewers = require('telescope.previewers')
          local conf_t = require('telescope.config').values
          local uv = vim.loop
          local names = { 'Makefile', 'makefile', 'GNUmakefile' }
          local function find_makefile(dir)
            for _, n in ipairs(names) do
              local p = U.join(dir, n)
              local st = uv.fs_stat(p)
              if st and st.type == 'file' then return p end
            end
            return nil
          end
          local fixed_path = find_makefile(cwd)
          local loaded = false
          return previewers.new_buffer_previewer({
            define_preview = function(self)
              if loaded then return end
              if not fixed_path or fixed_path == '' then
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No Makefile found]' })
                loaded = true
                return
              end
              local st = uv.fs_stat(fixed_path) or {}
              local max_bytes = telcfg.max_preview_bytes or (200 * 1024)
              local max_lines = telcfg.max_preview_lines or 2000
              local set_ft = (telcfg.set_filetype ~= false)
              if st.size and st.size > max_bytes then
                local ok, lines = pcall(vim.fn.readfile, fixed_path, '', max_lines)
                if not ok then lines = { '[Preview truncated: failed to read file]' } end
                table.insert(lines, 1, string.format('[Preview truncated: %d bytes > %d bytes, showing first %d lines]', st.size or 0, max_bytes, max_lines))
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
              else
                conf_t.buffer_previewer_maker(fixed_path, self.state.bufnr, { bufname = self.state.bufname })
              end
              if set_ft then pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'make') end
              loaded = true
            end,
          })
        end)(),
        attach_mappings = function(bufnr, map)
          local actions = require('telescope.actions')
          local action_state = require('telescope.actions.state')
          local function run_with_args(target)
            local def = mkargs.default or ''
            if mkargs.remember ~= false then def = LAST_ARGS[cwd] or def end
            local ui = vim.ui or {}
            if not ui.input then make_run_in_cwd(target, cwd); return end
            ui.input({ prompt = 'make 参数: ', default = def }, function(arg)
              if arg and arg ~= '' then
                if mkargs.remember ~= false then LAST_ARGS[cwd] = arg end
                local prog = choose_make()
                if not prog then vim.notify('未找到 make 或 mingw32-make', vim.log.levels.ERROR); return end
                local cmd = string.format('%s -C %s %s %s', prog, shell_quote_path(cwd), target or '', arg)
                run_make_in_terminal(cmd)
              else
                make_run_in_cwd(target, cwd)
              end
            end)
          end

          local function choose(pbuf)
            local entry = action_state.get_selected_entry()
            actions.close(pbuf)
            if entry.kind == 'args' then
              local def = mkargs.default or ''
              if mkargs.remember ~= false then def = LAST_ARGS[cwd] or def end
              local ui = vim.ui or {}
              if not ui.input then return end
              ui.input({ prompt = 'make 参数: ', default = def }, function(arg)
                if not arg or arg == '' then return end
                if mkargs.remember ~= false then LAST_ARGS[cwd] = arg end
                local prog = choose_make()
                if not prog then vim.notify('未找到 make 或 mingw32-make', vim.log.levels.ERROR); return end
                local cmd = string.format('%s -C %s %s', prog, shell_quote_path(cwd), arg)
                run_make_in_terminal(cmd)
              end)
              return
            end
            if mkargs.prompt ~= false then
              run_with_args(entry.value)
            else
              make_run_in_cwd(entry.value, cwd)
            end
          end
          map('i', '<CR>', choose)
          map('n', '<CR>', choose)
          local function toggle_phony_only()
            phony_only = not phony_only
            local picker = action_state.get_current_picker(bufnr)
            local new_entries = build_entries()
            picker:refresh(finders.new_table({
              results = new_entries,
              entry_maker = function(e)
                return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
              end,
            }), { reset_prompt = false })
          end
          map('i', '<C-p>', toggle_phony_only)
          map('n', '<C-p>', toggle_phony_only)
          return true
        end,
      }):find()
    end)
  end)
end

-- Telescope picker for Quick-c: select multiple C/C++ sources, then choose action
function M.telescope_quickc_sources(config)
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('未找到 telescope.nvim', vim.log.levels.ERROR)
    return
  end
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local cwd = vim.fn.getcwd()
  local function list_sources()
    local results = {}
    local patterns = { '**/*.c', '**/*.cpp', '**/*.cc', '**/*.cxx' }
    local seen = {}
    for _, pat in ipairs(patterns) do
      local files = vim.fn.glob(pat, true, true)
      for _, f in ipairs(files) do
        local p = vim.fn.fnamemodify(f, ':p')
        if vim.fn.filereadable(p) == 1 and not seen[p] then
          table.insert(results, p)
          seen[p] = true
        end
      end
    end
    return results
  end
  local files = list_sources()
  if #files == 0 then
    vim.notify('未在当前工作目录找到 C/C++ 源文件', vim.log.levels.WARN)
    return
  end
  pickers.new({}, {
    prompt_title = 'Quick-c: Select sources (' .. cwd .. ')',
    finder = finders.new_table({ results = files }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr, map)
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')
      local function do_action()
        local picker = action_state.get_current_picker(bufnr)
        local multi = picker:get_multi_selection()
        local sel = action_state.get_selected_entry()
        local srcs = {}
        if multi and #multi > 0 then
          for _, e in ipairs(multi) do table.insert(srcs, e[1] or e.value or e.path or e) end
        elseif sel then
          table.insert(srcs, sel[1] or sel.value or sel.path)
        end
        actions.close(bufnr)
        if not srcs or #srcs == 0 then return end
        local ui = vim.ui or {}
        local items = {
          { name = 'Build', fn = function() require('quick-c.build').build(config, { err = U.notify_err, warn = U.notify_warn, info = U.notify_info }, { sources = srcs }) end },
          { name = 'Run', fn = function() require('quick-c.build').run(config, { err = U.notify_err, warn = U.notify_warn, info = U.notify_info }, { sources = srcs }) end },
          { name = 'Build & Run', fn = function() require('quick-c.build').build_and_run(config, { err = U.notify_err, warn = U.notify_warn, info = U.notify_info }, { sources = srcs }) end },
        }
        if ui.select then
          ui.select({ items[1].name, items[2].name, items[3].name }, { prompt = '选择操作' }, function(choice)
            if choice == items[1].name then items[1].fn() end
            if choice == items[2].name then items[2].fn() end
            if choice == items[3].name then items[3].fn() end
          end)
        else
          items[1].fn()
        end
      end
      map('i', '<CR>', do_action)
      map('n', '<CR>', do_action)
      return true
    end,
  }):find()
end

return M
