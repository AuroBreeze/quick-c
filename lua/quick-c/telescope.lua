local M = {}

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
    parse_make_targets_in_cwd_async(cwd, function(targets)
      if #targets == 0 then
        vim.notify('未解析到任何 make 目标', vim.log.levels.WARN)
        return
      end
      local results = vim.list_extend({ '[自定义参数…]' }, targets)
      local title = (config.make.telescope and config.make.telescope.prompt_title) or 'Make Targets'
      pickers.new({}, {
        prompt_title = title .. ' (' .. cwd .. ')',
        finder = finders.new_table({ results = results }),
        sorter = conf.generic_sorter({}),
        previewer = (function()
          local previewers = require('telescope.previewers')
          local uv = vim.loop
          local names = { 'Makefile', 'makefile', 'GNUmakefile' }
          local function find_makefile(dir)
            for _, n in ipairs(names) do
              local p = dir .. '/' .. n
              local st = uv.fs_stat(p)
              if st and st.type == 'file' then return p end
            end
            return nil
          end
          return previewers.vim_buffer_cat.new({
            get_path = function()
              local p = find_makefile(cwd)
              return p or ''
            end,
          })
        end)(),
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
                  if not prog then vim.notify('未找到 make 或 mingw32-make', vim.log.levels.ERROR); return end
                  local cmd = string.format('%s -C %s %s', prog, shell_quote_path(cwd), args)
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

return M
