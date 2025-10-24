local U = require('quick-c.util')
local M = {}

-- 异步非阻塞 Makefile 搜索：分批扫描目录，避免卡主线程
function M.find_make_root_async(config, start_dir, cb)
  local cfg = config.make or {}
  local up = (cfg.search and cfg.search.up) or 2
  local down = (cfg.search and cfg.search.down) or 3
  local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }
  local names = { 'Makefile', 'makefile', 'GNUmakefile' }
  local uv = vim.loop

  local function is_ignored(name)
    for _, n in ipairs(ignore) do if name == n then return true end end
    return false
  end
  local function has_makefile(dir)
    for _, n in ipairs(names) do
      local st = uv.fs_stat(U.join(dir, n))
      if st and st.type == 'file' then return true end
    end
    return false
  end
  local function parent(dir)
    local p = vim.fn.fnamemodify(dir, ':h')
    if p == nil or p == '' then return dir end
    return p
  end

  local cwd_root = U.norm(vim.fn.getcwd())

  -- 预生成向上各层起点（受工作目录边界限制）
  local bases = {}
  do
    local cur = start_dir
    for _ = 0, up do
      local cur_norm = U.norm(cur)
      if not cur_norm:find(cwd_root, 1, true) then break end
      table.insert(bases, cur)
      local nextp = parent(cur)
      if nextp == cur then break end
      local next_norm = U.norm(nextp)
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
              table.insert(queue, { dir = U.join(dir, name), depth = depth + 1 })
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

-- 收集多个 Makefile 目录（异步，非阻塞）
function M.find_make_roots_async(config, start_dir, cb)
  local results, seen = {}, {}
  M.find_make_root_async(config, start_dir, function()
    local cfg = config.make or {}
    local up = (cfg.search and cfg.search.up) or 2
    local down = (cfg.search and cfg.search.down) or 3
    local names = { 'Makefile', 'makefile', 'GNUmakefile' }
    local uv = vim.loop
    local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }

    local function is_ignored(name)
      for _, n in ipairs(ignore) do if name == n then return true end end
      return false
    end

    local cwd_root = U.norm(vim.fn.getcwd())
    local bases = {}
    do
      local cur = start_dir
      for _ = 0, up do
        local cur_norm = U.norm(cur)
        if not cur_norm:find(cwd_root, 1, true) then break end
        table.insert(bases, cur)
        local nextp = vim.fn.fnamemodify(cur, ':h')
        if nextp == cur then break end
        local next_norm = U.norm(nextp)
        if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then break end
        cur = nextp
      end
    end

    local function has_makefile(dir)
      for _, n in ipairs(names) do
        local st = uv.fs_stat(U.join(dir, n))
        if st and st.type == 'file' then return true end
      end
      return false
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
              if t == 'directory' and not is_ignored(name) then
                table.insert(queue, { dir = U.join(dir, name), depth = depth + 1 })
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

function M.resolve_make_cwd_async(config, start_dir, cb)
  if config.make and config.make.cwd then cb(config.make.cwd) return end
  local ok_t = pcall(require, 'telescope')
  M.find_make_roots_async(config, start_dir, function(roots)
    if #roots == 0 then cb(start_dir) return end
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
    local telcfg = (config.make and config.make.telescope) or {}
    pickers.new({}, {
      prompt_title = 'Select Makefile Directory',
      finder = finders.new_table({
        results = entries,
        entry_maker = function(e)
          return { value = e.path, display = e.display, ordinal = e.display }
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
        local max_bytes = telcfg.max_preview_bytes or (200 * 1024)
        local max_lines = telcfg.max_preview_lines or 2000
        local set_ft = (telcfg.set_filetype ~= false)
        return previewers.new_buffer_previewer({
          get_buffer_by_name = function(_, entry)
            return find_makefile(entry.value) or ('[makefile-preview] ' .. entry.value)
          end,
          define_preview = function(self, entry)
            local path = find_makefile(entry.value)
            if not path then
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No Makefile found]' })
              return
            end
            local st = uv.fs_stat(path) or {}
            if st.size and st.size > max_bytes then
              local ok, lines = pcall(vim.fn.readfile, path, '', max_lines)
              if not ok then lines = { '[Preview truncated: failed to read file]' } end
              table.insert(lines, 1, string.format('[Preview truncated: %d bytes > %d bytes, showing first %d lines]', st.size or 0, max_bytes, max_lines))
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            else
              conf_t.buffer_previewer_maker(path, self.state.bufnr, { bufname = self.state.bufname })
            end
            if set_ft then pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'make') end
          end,
        })
      end)(),
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

return M
