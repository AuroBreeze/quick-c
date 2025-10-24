local A = {}

function A.setup(config, build_and_run)
  local group = vim.api.nvim_create_augroup('QuickC_AutoRun', { clear = true })
  local function ft_enabled(ft)
    for _, f in ipairs(config.autorun.filetypes or {}) do
      if f == ft then return true end
    end
    return false
  end
  local function setup_autorun()
    if not config.autorun.enabled then return end
    for _, ev in ipairs(config.autorun.events or { 'BufWritePost' }) do
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
  vim.api.nvim_create_user_command('QuickCAutoRunToggle', function()
    config.autorun.enabled = not config.autorun.enabled
    vim.api.nvim_clear_autocmds({ group = group })
    setup_autorun()
    vim.notify('Quick-c: autorun ' .. (config.autorun.enabled and 'enabled' or 'disabled'))
  end, {})
end

return A
