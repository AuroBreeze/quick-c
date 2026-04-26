local K = {}

-- Setup keymaps according to config.keymaps
-- callbacks: { build, run, build_and_run, debug, make, cmake, cmake_run, cmake_configure }
function K.setup(config, callbacks)
  local km = config.keymaps or {}
  if km.enabled == false then
    return
  end

  -- Option: unmap previous default keys when changed/disabled (default: true)
  local do_unmap = true
  if km.unmap_defaults == false then
    do_unmap = false
  end

  local function disabled(v)
    return v == false or v == nil or (type(v) == 'string' and v == '')
  end

  -- Unmap helper
  local function try_unmap(lhs)
    if not lhs or lhs == '' then
      return
    end
    pcall(vim.keymap.del, 'n', lhs)
  end

  -- Compare with defaults and unmap if changed/disabled
  if do_unmap then
    local ok_cfg, CFG = pcall(require, 'quick-c.config')
    if ok_cfg and CFG and CFG.defaults and CFG.defaults.keymaps then
      local def = CFG.defaults.keymaps
      local pairs_to_check = {
        { def = def.build, cur = km.build },
        { def = def.run, cur = km.run },
        { def = def.build_and_run, cur = km.build_and_run },
        { def = def.debug, cur = km.debug },
        { def = def.make, cur = km.make },
        { def = def.cmake, cur = km.cmake },
        { def = def.cmake_run, cur = km.cmake_run },
        { def = def.cmake_configure, cur = km.cmake_configure },
        { def = def.sources, cur = km.sources },
        { def = def.quickfix, cur = km.quickfix },
        { def = def.logs, cur = km.logs },
        { def = def.stop, cur = km.stop },
        { def = def.retry, cur = km.retry },
      }
      for _, it in ipairs(pairs_to_check) do
        if disabled(it.cur) or (type(it.cur) == 'string' and it.cur ~= it.def) then
          try_unmap(it.def)
        end
      end
    end
  end

  local function map(lhs, rhs, desc)
    if type(lhs) == 'string' and lhs ~= '' and rhs then
      pcall(vim.keymap.set, 'n', lhs, rhs, { desc = desc, unique = true })
    end
  end

  if not disabled(km.build) then
    map(km.build, callbacks.build, 'Quick-c: Compile current C/C++ file')
  end
  if not disabled(km.run) then
    map(km.run, callbacks.run, 'Quick-c: Run current C/C++ exe')
  end
  if not disabled(km.build_and_run) then
    map(km.build_and_run, callbacks.build_and_run, 'Quick-c: Build & Run current C/C++')
  end
  if not disabled(km.debug) then
    map(km.debug, callbacks.debug, 'Quick-c: Debug current C/C++ exe')
  end
  if not disabled(km.make) then
    local function scheduled_make()
      vim.schedule(function()
        callbacks.make()
      end)
    end
    map(km.make, scheduled_make, 'Quick-c: Make targets (Telescope)')
  end
  if not disabled(km.cmake) and callbacks.cmake then
    map(km.cmake, callbacks.cmake, 'Quick-c: CMake targets (Telescope)')
  end
  if not disabled(km.cmake_run) and callbacks.cmake_run then
    map(km.cmake_run, callbacks.cmake_run, 'Quick-c: CMake build')
  end
  if not disabled(km.cmake_configure) and callbacks.cmake_configure then
    map(km.cmake_configure, callbacks.cmake_configure, 'Quick-c: CMake configure (-S/-B)')
  end
  if not disabled(km.sources) and km.sources then
    local function sources_picker()
      local ok, tel = pcall(require, 'quick-c.telescope')
      if not ok then
        return
      end
      tel.telescope_quickc_sources(config)
    end
    map(km.sources, sources_picker, 'Quick-c: Select sources (Telescope)')
  end
  if not disabled(km.quickfix) and km.quickfix then
    local function open_quickfix()
      local cfg = config.diagnostics and config.diagnostics.quickfix or {}
      if cfg.use_telescope then
        local ok, tel = pcall(require, 'quick-c.telescope')
        if ok and tel and tel.telescope_quickfix then
          tel.telescope_quickfix(config)
          return
        end
        local ok2, tb = pcall(require, 'telescope.builtin')
        if ok2 and tb and tb.quickfix then
          tb.quickfix()
          return
        end
      end
      vim.cmd 'copen'
    end
    map(km.quickfix, open_quickfix, 'Quick-c: Open quickfix list (Telescope)')
  end
  if not disabled(km.logs) and km.logs then
    local function open_logs()
      local ok, tel = pcall(require, 'quick-c.telescope')
      if ok and tel and tel.telescope_build_logs then
        tel.telescope_build_logs(config)
        return
      end
      local latest = vim.fn.stdpath('data') .. '/quick-c/logs/latest-build.log'
      if vim.fn.filereadable(latest) == 1 then
        vim.cmd('tabnew ' .. vim.fn.fnameescape(latest))
      else
        vim.notify('no build logs', vim.log.levels.WARN)
      end
    end
    map(km.logs, open_logs, 'Quick-c: Build logs (Telescope)')
  end
  -- Task control keymaps
  if not disabled(km.stop) and callbacks.stop then
    map(km.stop, callbacks.stop, 'Quick-c: Stop current task')
  end
  if not disabled(km.retry) and callbacks.retry then
    map(km.retry, callbacks.retry, 'Quick-c: Retry last task')
  end
end

return K
