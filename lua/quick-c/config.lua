local C = {}

C.defaults = {
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
    open = true,
    height = 12,
  },
  betterterm = {
    enabled = true,
    index = 0,
    send_delay = 200,
    focus_on_run = true,
    open_if_closed = true,
  },
  make = {
    enabled = true,
    prefer = nil, -- e.g. "make" | "mingw32-make"
    cwd = nil,    -- 默认使用当前文件所在目录
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    telescope = {
      prompt_title = "Quick-c Make Targets",
      preview = true,                 -- 是否启用预览
      max_preview_bytes = 200 * 1024, -- 预览最多读取的字节数
      max_preview_lines = 2000,       -- 预览最多显示的行数
      set_filetype = true,            -- 预览 buffer 是否设置 filetype = 'make'
    },
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

return C
