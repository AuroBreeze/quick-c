local K = {}

-- Setup keymaps according to config.keymaps
-- callbacks: { build, run, build_and_run, debug, make }
function K.setup(config, callbacks)
  local km = config.keymaps or {}
  if km.enabled == false then return end
  local function map(lhs, rhs, desc)
    if type(lhs) == 'string' and lhs ~= '' and rhs then
      pcall(vim.keymap.set, 'n', lhs, rhs, { desc = desc, unique = true })
    end
  end
  map(km.build, callbacks.build, "Quick-c: Compile current C/C++ file")
  map(km.run, callbacks.run, "Quick-c: Run current C/C++ exe")
  map(km.build_and_run, callbacks.build_and_run, "Quick-c: Build & Run current C/C++")
  map(km.debug, callbacks.debug, "Quick-c: Debug current C/C++ exe")
  map(km.make, callbacks.make, "Quick-c: Make targets (Telescope)")
end

return K
