local C = {}

C.defaults = {
  -- outdir = "source" 表示输出到源码所在目录；也可设置为自定义目录
  outdir = "source",
  -- 用户可覆盖：为不同系统/工具链提供命令模板
  toolchain = {
    windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
    unix = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
  },
  -- compile_commands.json 相关配置
  compile_commands = {
    -- mode = 'generate' | 'use'
    mode = 'generate',
    -- 生成或复制的目标输出目录：'source' 表示放在当前源文件目录
    outdir = 'source',
    -- 当 mode = 'use' 时，从此路径复制 compile_commands.json
    use_path = nil,
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
  diagnostics = {
    quickfix = {
      enabled = true,      -- 是否收集编译输出到 quickfix
      open = 'error',      -- 'always' | 'error' | 'warning' | 'never'
      jump = 'error',      -- 'always' | 'error' | 'warning' | 'never'
      use_telescope = true,-- 打开列表时优先使用 Telescope quickfix（如已安装）
    },
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
    prefer = nil, -- 可为字符串或列表，例如 "make" | "mingw32-make" | { "make", "mingw32-make" }
    cwd = nil,    -- 默认使用当前文件所在目录
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    telescope = {
      prompt_title = "Quick-c Make Targets",
      preview = true,                 -- 是否启用预览
      max_preview_bytes = 200 * 1024, -- 预览最多读取的字节数
      max_preview_lines = 2000,       -- 预览最多显示的行数
      set_filetype = true,            -- 预览 buffer 是否设置 filetype = 'make'
      choose_terminal = 'auto',       -- 发送命令到终端时的选择行为: 'auto' | 'always' | 'never'
    },
    cache = {
      ttl = 10, -- 目标解析缓存（秒）。同一 cwd 且 Makefile 未变化时，在 TTL 内复用上次解析结果
    },
    targets = {
      prioritize_phony = true, -- 将 .PHONY 目标在列表中优先显示
    },
    args = {
      prompt = true,    -- 选择目标后是否弹出输入框追加参数（例如 -j4 VAR=1）
      default = "",     -- 默认参数
      remember = true,  -- 记住每个 cwd 最近一次输入，作为下次默认值
    },
  },
  keymaps = {
    enabled = true,
    build = "<leader>cqb",
    run = "<leader>cqr",
    build_and_run = "<leader>cqR",
    debug = "<leader>cqD",
    make = "<leader>cqM",
    sources = "<leader>cqS",
    quickfix = "<leader>cqf",
  },
}

return C
