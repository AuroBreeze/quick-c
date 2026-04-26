local C = {}

C.defaults = {
  -- 是否启用插件内置的 Telescope 增强（目标选择器、源文件选择器、quickfix 增强等）
  -- 设为 false 可与 cmake-tools/overseer 等生态避免重叠
  telescope_enhance = true,
  -- outdir 用于决定可执行文件与临时产物的输出位置：
  -- - "source": 写入到“当前源文件所在目录”（默认）
  -- - 其他字符串：自定义目录
  --    · 相对路径：相对于当前工作目录(:pwd)；例如 "build"、"build/bin"
  --    · 绝对路径：如 "C:/proj/bin" 或 "/home/me/bin"
  --    · 目录不存在会自动创建（mkdir -p）
  -- 示例：
  --   outdir = "source"         -- a.c => ./a.exe 或 ./a.out
  --   outdir = "build"          -- a.c => ./build/a.exe
  --   outdir = "build/bin"      -- a.c => ./build/bin/a.exe
  --   outdir = "C:/tmp/bin"     -- Windows 绝对路径
  outdir = 'source',
  -- 用户可覆盖：为不同系统/工具链提供命令模板
  toolchain = {
    windows = { c = { 'gcc', 'cl' }, cpp = { 'g++', 'cl' } },
    unix = { c = { 'gcc', 'clang' }, cpp = { 'g++', 'clang++' } },
  },
  compile = {
    prefer = { c = nil, cpp = nil },
    prefer_force = false,
    -- 用户自定义编译命令：可通过模板或预设完全覆盖内置命令
    -- 当 enabled = true 时，构建流程会优先询问/选择自定义命令；未选择时回退到内置命令
    user_cmd = {
      enabled = true,
      -- 是否使用 Telescope 弹窗选择：包含 [Use built-in]、[Custom input...] 以及 presets
      telescope = {
        popup = false, -- 参考 make 的交互，默认不弹；开启后若未安装 telescope 将自动回退到 vim.ui
        prompt_title = 'Quick-c Compile',
      },
      -- 预设命令（推荐使用列表形式以避免 shell 解析问题）：
      -- 必须使用完整的编译命令，这不是追加参数
      -- 允许占位符：{sources} {out} {cc} {ft}
      -- 例如：{ 'gcc', '-g', '-O0', '{sources}', '-o', '{out}' }
      presets = {
        { name = "Debug", cmd = { "gcc", "-g", "-O0", "{sources}", "-o", "{out}" } },
        { name = "ASan",  cmd = { "gcc", "-g", "-O0", "-fsanitize=address", "{sources}", "-o", "{out}" } },
      },
      -- 自定义输入的默认模板（字符串或数组）。
      -- 这是弹窗后的追加命令
      default = nil,
      -- 记住每个项目最近一次输入（用于下次默认值）
      remember_last = true,
    },
  },
  -- compile_commands.json 相关配置
  compile_commands = {
    -- mode:
    --   'generate' : 按当前工具链/参数为单/多文件生成最小 compile_commands（适合非 CMake 项目）
    --   'use'      : 从 use_path 指定的文件复制到 outdir
    --   'cmake'    : 使用 CMake 导出（自动追加 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON），
    --                从 cmake.build_dir/compile_commands.json 复制到 outdir
    -- 说明：
    --   - 非 CMake 项目的一次性批量生成，建议使用命令：
    --       :QuickCCompileDBGenProject   （扫描 :pwd 全项目）
    --       :QuickCCompileDBGenDir [dir] （指定目录）
    --       :QuickCCompileDBGenSources   （Telescope 多选源文件）
    --   - 仅借用 CMake 导出（即使平时用 make）：
    --       :QuickCCompileDBGenCMake 或将 mode 设为 'cmake' 后 :QuickCCompileDB
    mode = 'generate',
    -- 可选：find_dir = ''，从此路径复制
    --
    -- outdir：生成/复制的目标位置
    --   'source'  : 写到“当前源文件目录”。当为多文件/项目生成时，内部会优先写到项目根（便于 clangd 发现）
    --   'cwd'     : 直接写到当前工作目录（项目根）
    --   相对路径 : 相对 :pwd
    --   绝对路径 : 例如 'C:/proj/compile_commands'
    outdir = 'source',
    ignore_dirs = { '.git', 'node_modules', '.cache' },
    include_hidden = true,
    progress_throttle_ms = 1200,
    max_depth = 4,
    -- 当 mode = 'use' 时，从此路径复制 compile_commands.json
    use_path = nil,
  },
  -- Build behavior
  build = {
    -- Timeout for single-file builds started via jobstart (ms). 0 = no timeout
    timeout_ms = 0,
    summary = {
      -- Show floating summary after build finishes. Default off to avoid covering terminal.
      enabled = false,
    },
  },
  diagnostics = {
    quickfix = {
      enabled = true, -- 是否收集编译输出到 quickfix
      open = 'warning', -- 'always' | 'error' | 'warning' | 'never'
      jump = 'warning', -- 'always' | 'error' | 'warning' | 'never'
      use_telescope = true, -- 打开列表时优先使用 Telescope quickfix（如已安装）
    },
  },
  autosave = {
    enabled = true,
    debounce_ms = 1000,
    events = { 'TextChanged', 'TextChangedI', 'InsertLeave' },
    filetypes = { 'c', 'cpp' },
    ignore_filetypes = { 'gitcommit', 'gitrebase' },
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
  debug = { -- 搜索可执行文件的配置
    search = {
      up = 2,
      down = 2,
      ignore_dirs = { '.git', 'node_modules', '.cache' },
      dirs = nil, -- 指定搜索目录，为空时使用当前文件所在目录
    },
    concurrency = 8, -- 并发工作者数
  },
  make = {
    enabled = true,
    prefer = nil, -- 可为字符串或列表，例如 "make" | "mingw32-make" | { "make", "mingw32-make" }
    cwd = nil, -- 默认使用当前文件所在目录
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    -- 并发工作者数：用于 Makefile 搜索等异步操作；可根据系统性能微调
    concurrency = 8,
    telescope = {
      prompt_title = 'Quick-c Make Targets',
      preview = true, -- 是否启用预览
      max_preview_bytes = 200 * 1024, -- 预览最多读取的字节数
      max_preview_lines = 2000, -- 预览最多显示的行数
      set_filetype = true, -- 预览 buffer 是否设置 filetype = 'make'
      choose_terminal = 'auto', -- 发送命令到终端时的选择行为: 'auto' | 'always' | 'never'
    },
    cache = {
      ttl = 10, -- 目标解析缓存（秒）。同一 cwd 且 Makefile 未变化时，在 TTL 内复用上次解析结果
    },
    targets = {
      prioritize_phony = true, -- 将 .PHONY 目标在列表中优先显示
    },
    args = {
      prompt = true, -- 选择目标后是否弹出输入框追加参数（例如 -j4 VAR=1）
      default = '', -- 默认参数
      remember = true, -- 记住每个 cwd 最近一次输入，作为下次默认值
    },
  },
  cmake = {
    enabled = true,
    prefer = nil, -- 指定 cmake 可执行程序路径或名称
    generator = nil, -- 例如 "Ninja" | "Unix Makefiles" | "MinGW Makefiles" | "NMake Makefiles"
    build_dir = 'build', -- 构建目录，默认在项目根目录下
    view = 'both', -- 构建输出视图：'quickfix' | 'terminal' | 'both'
    -- 并发工作者数：用于 CMake 根目录搜索等异步操作；可根据系统性能微调
    concurrency = 8,
    output = {
      open = true, -- both 模式下是否自动打开输出面板
      height = 12, -- 输出面板高度
    },
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    telescope = {
      prompt_title = 'Quick-c CMake Targets',
      preview = true,
      max_preview_bytes = 200 * 1024,
      max_preview_lines = 2000,
      set_filetype = false,
      choose_terminal = 'auto',
    },
    args = {
      prompt = true, -- 选择目标后是否弹出输入框追加构建参数（传递给构建工具，如 -j4）
      default = '',
      remember = true,
    },
    configure = {
      extra = {}, -- 额外传递给 cmake -S/-B 的参数，如 { "-DCMAKE_BUILD_TYPE=Debug" }
      toolchain = nil, -- 指定工具链文件路径
    },
  },
  keymaps = {
    enabled = true,
    unmap_defaults = true,
    build = '<leader>cqb',
    run = '<leader>cqr',
    build_and_run = '<leader>cqR',
    debug = '<leader>cqD',
    make = '<leader>cqM',
    cmake = '<leader>cqC',
    cmake_run = '<leader>cqB',
    cmake_configure = '<leader>cqc',
    sources = '<leader>cqS',
    quickfix = '<leader>cqf',
    logs = '<leader>cqL',
    stop = '<leader>cqx',
    retry = '<leader>cqt',
  },
}

return C
