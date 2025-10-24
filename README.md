# Quick-c

<a href="https://dotfyle.com/plugins/AuroBreeze/quick-py">
	<img src="https://dotfyle.com/plugins/AuroBreeze/quick-py/shield?style=for-the-badge" />
</a>

一个面向 C/C++ 的轻量 Neovim 插件：一键编译、运行与调试当前文件，支持 Windows、Linux、macOS，兼容 betterTerm 与内置终端，并可选自动保存后构建运行。构建与运行全程异步，不会阻塞 Neovim 主线程。

## 特性

- **一键构建/运行（异步）**：`QuickCBuild`、`QuickCRun`、`QuickCBR`（构建并运行）
- **调试集成**：`QuickCDebug` 使用 `nvim-dap` 与 `codelldb`
- **跨平台**：自动选择可用编译器（gcc/clang/cl）与合适运行方式（PowerShell/终端）
- **灵活输出位置**：默认将可执行文件输出到源码所在目录；可通过配置修改
- **终端兼容**：优先将命令发送到 `betterTerm`（如已安装），否则使用 Neovim 内置终端
- **自动运行**：可选保存后自动构建并运行（按文件类型过滤）
- **Make 集成（异步）**：自动解析 `make -qp` 目标，Telescope 选择执行（如 `clean`、`install`）
- **便捷快捷键**：默认提供 `<leader>cb`、`<leader>cr`、`<leader>cR`、`<leader>cD`、`<leader>cm`

### v1.1.0 更新摘要

- Telescope 选择器内置 Makefile 预览（目录选择与目标选择均可见，目标选择阶段固定预览所选目录的 Makefile）。
- 大文件与编码兼容：预览支持字节/行数截断，避免卡顿。
- 终端发送可配置：`make.telescope.choose_terminal = 'auto'|'always'|'never'`。
- 选择已有内置终端发送时，会自动打开/聚焦该终端窗口；默认策略仍为 betterTerm 优先、失败回退内置终端。
- 键位注入采用 `unique=true`，不再覆盖用户已有映射。
- Windows 路径处理更稳健（预览器使用安全拼接）。

## 依赖

- Neovim 0.8+
- 至少一种 C/C++ 编译器（按平台自动探测）：
  - Windows: `gcc/g++`（MinGW）或 `cl`（MSVC）或 `clang/clang++`
  - Unix: `gcc/g++` 或 `clang/clang++`
- 可选：
  - [`betterTerm`](https://github.com/CRAG666/betterTerm.nvim)（若安装则优先使用）
  - 调试：[`nvim-dap`](https://github.com/mfussenegger/nvim-dap) 与 `codelldb`
  - Make 选择器：[`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) 与 [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)

## 安装

使用 lazy.nvim（三重懒加载：按文件类型/按快捷键/按命令 任一触发即加载）：

```lua
{
  "AuroBreeze/quick-c",

  lazy = true,
  event = "VeryLazy",

  -- 1) 文件类型触发（打开 C/C++ 文件时加载）
  ft = { "c", "cpp" },
  -- 2) 快捷键触发（首次按键时加载，映射由插件在 setup 时注入）
  keys = {
    { "<leader>cb", desc = "Quick-c: Build" },
    { "<leader>cr", desc = "Quick-c: Run" },
    { "<leader>cR", desc = "Quick-c: Build & Run" },
    { "<leader>cD", desc = "Quick-c: Debug" },
    { "<leader>cM", desc = "Quick-c: Make targets (Telescope)" },
  },
  -- 3) 命令触发（调用命令时加载，等同“命令提前加载”）
  cmd = {
    "QuickCBuild", "QuickCRun", "QuickCBR", "QuickCDebug",
    "QuickCMake", "QuickCMakeRun", "QuickCAutoRunToggle",
  },
  config = function()
    require("quick-c").setup()
  end,
}
```

使用 packer.nvim：

```lua
use({
  "AuroBreeze/quick-c",
  config = function()
    require("quick-c").setup()
  end,
})
```

插件会通过 `plugin/quick-c.lua` 在加载时自动调用 `require('quick-c').setup()`，你也可以在自己的配置中传入自定义项覆盖默认行为。

## 快速开始

打开任意 `*.c` 或 `*.cpp` 文件：

- 构建当前文件：`:QuickCBuild` 或 `<leader>cb`
- 运行可执行文件：`:QuickCRun` 或 `<leader>cr`
- 构建并运行：`:QuickCBR` 或 `<leader>cR`
- 调试运行：`:QuickCDebug` 或 `<leader>cD`
- 切换保存即运行：`:QuickCAutoRunToggle`

默认输出名为当前文件名（Windows 会追加 `.exe`）；如需自定义输出名，构建时可在提示中输入。

## 配置

默认配置（三重懒加载启用；完整配置与注释均保留）：

```lua
{
  "AuroBreeze/quick-c",
  -- 三重懒加载：任一触发即可加载
  ft = { "c", "cpp" },
  keys = {
    { "<leader>cb", desc = "Quick-c: Build" },
    { "<leader>cr", desc = "Quick-c: Run" },
    { "<leader>cR", desc = "Quick-c: Build & Run" },
    { "<leader>cD", desc = "Quick-c: Debug" },
    { "<leader>cM", desc = "Quick-c: Make targets (Telescope)" },
  },
  cmd = {
    "QuickCBuild", "QuickCRun", "QuickCBR", "QuickCDebug",
    "QuickCMake", "QuickCMakeRun", "QuickCAutoRunToggle",
  },
  config = function()
    require("quick-c").setup({
      -- 可执行文件输出目录：
      --  - "source": 输出在源码同目录
      --  - 自定义路径：如 vim.fn.stdpath("data") .. "/quick-c-bin"
      outdir = "source",
      toolchain = {
        -- 编译器探测优先级（按平台与语言）
        windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
        unix    = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
      },
      autorun = {
        -- 保存即运行功能（默认关闭）
        enabled = false,
        -- 触发自动运行的事件
        events = { "BufWritePost" },
        -- 仅对这些文件类型生效
        filetypes = { "c", "cpp" },
      },
      terminal = {
        -- 运行时是否自动打开内置终端窗口
        open = true,
        -- 终端窗口高度
        height = 12,
      },
      betterterm = {
        -- 安装了 betterTerm 时优先使用
        enabled = true,
        -- 发送到的终端索引（0 为第一个）
        index = 0,
        -- 发送命令的延时（毫秒）
        send_delay = 200,
        -- 发送命令后是否聚焦终端
        focus_on_run = true,
        -- 终端未打开时是否先打开
        open_if_closed = true,
      },
      make = {
        -- 启用/禁用 make 集成
        enabled = true,
        -- 指定优先使用的 make 程序：
        --   - 可为字符串或列表；按顺序探测可执行：
        --     prefer = 'make' 或 prefer = { 'make', 'mingw32-make' }
        --   - Windows 常见：{ 'make', 'mingw32-make' }
        prefer = nil,
        -- 固定工作目录（不设置则由插件根据当前文件自动搜索）
        cwd = nil,
        -- Makefile 搜索策略（未显式设置 cwd 时生效）：
        --   以当前文件所在目录为起点，向上 up 层、向下每层 down 层，跳过 ignore_dirs
        search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
        telescope = {
          -- Telescope 选择器标题
          prompt_title = "Quick-c Make Targets",
          -- 是否启用预览（目录选择与目标选择均支持）
          preview = true,
          -- 大文件截断策略（按字节与行数）
          max_preview_bytes = 200 * 1024,
          max_preview_lines = 2000,
          -- 是否为预览 buffer 设置 filetype=make（语法高亮）
          set_filetype = true,
          -- 发送命令到终端时的选择行为：
          --   'auto'  有已打开终端则弹选择器，否则走默认策略
          --   'always'总是弹选择器
          --   'never' 始终走默认策略（betterTerm 优先，失败回退内置）
          choose_terminal = 'auto',
        },
        -- 目标解析缓存：同一 cwd 且 Makefile 未变化时，TTL 内复用结果
        cache = {
          ttl = 10,
        },
      },
      keymaps = {
        -- 设为 false 可不注入任何默认键位（你可自行映射命令）
        enabled = true,
        -- 置为 nil 或 '' 可单独禁用某个映射
        build = '<leader>cb',
        run = '<leader>cr',
        build_and_run = '<leader>cR',
        debug = '<leader>cD',
        -- 注意：键位注入使用 unique=true，不会覆盖你已有的映射；冲突时跳过
        make = '<leader>cM',
      },
    })
  end,
}
```

自定义示例：指定固定输出目录，并优先使用 `clang/clang++`：

```lua
require("quick-c").setup({
  outdir = vim.fn.stdpath("data") .. "/quick-c-bin",
  toolchain = {
    windows = { c = { "clang", "gcc", "cl" }, cpp = { "clang++", "g++", "cl" } },
    unix = { c = { "clang", "gcc" }, cpp = { "clang++", "g++" } },
  },
  make = {
    -- 在 Windows 优先尝试 make，不存在时退回到 mingw32-make
    prefer = { 'make', 'mingw32-make' },
    cache = { ttl = 15 },
  },
})
```

## 命令与快捷键

- `:QuickCBuild` 构建当前 C/C++ 文件
- `:QuickCRun` 运行当前文件对应的可执行文件
- `:QuickCBR` 构建并运行
- `:QuickCDebug` 使用 `nvim-dap` 以 `codelldb` 调试可执行文件
- `:QuickCAutoRunToggle` 切换保存即运行（受 `autorun.filetypes` 限制）
- `:QuickCMake` 打开 Telescope 选择器列出可用 make 目标
- `:QuickCMakeRun [target]` 直接运行指定 make 目标

默认快捷键（普通模式）：

- `<leader>cb` → 构建
- `<leader>cr` → 运行
- `<leader>cR` → 构建并运行
- `<leader>cD` → 调试
- `<leader>cm` → 打开 Make 目标选择器（Telescope）

提示：
- 以上键位均可通过 `setup({ keymaps = { ... } })` 自定义或禁用。
- 插件设置键位时使用 `unique=true`，不会覆盖你已有的映射；如键位已被占用会跳过注入。

### Telescope 预览说明

- 目录选择器与目标选择器均内置 Makefile 预览。
- 目标选择器阶段，预览固定显示已选目录中的 Makefile，不随光标移动刷新（避免卡顿）。
- 对大文件自动截断，受以下配置项控制：
  - `make.telescope.preview`：是否启用预览。
  - `make.telescope.max_preview_bytes`：超过该字节数则改为按行读取并截断。
  - `make.telescope.max_preview_lines`：截断时最多显示的行数。
  - `make.telescope.set_filetype`：是否设置预览 buffer 的 `filetype=make`。

### 终端选择行为

- 选择 make 目标后，可将命令发送到已打开的内置终端，或使用默认策略（betterTerm 优先，失败回退内置）。
- 通过 `make.telescope.choose_terminal` 控制行为：
  - `'auto'`：存在已打开终端时弹选择器，否则直接默认策略。
  - `'always'`：总是弹出选择器。
  - `'never'`：总是使用默认策略。

### Makefile 搜索说明

- 若未设置 `make.cwd`，插件会在“当前文件所在目录”为起点：
  - 向上查找至多 `search.up` 层（默认 2 层）
  - 在每一层向下递归至多 `search.down` 层（默认 3 层）
  - 找到包含 `Makefile`/`makefile`/`GNUmakefile` 的首个目录作为工作目录
  - 会跳过 `ignore_dirs` 名单中的目录（默认：`.git`、`node_modules`、`.cache`）

## 架构说明

内部已模块化重构，但对外 API 不变：

- 模块划分
  - `lua/quick-c/init.lua` 装配、命令与键位注入
  - `lua/quick-c/config.lua` 默认配置
  - `lua/quick-c/util.lua` 工具函数（平台/路径/消息）
  - `lua/quick-c/terminal.lua` 终端封装（betterTerm/内置）
  - `lua/quick-c/make_search.lua` 异步 Makefile 搜索与目录选择
  - `lua/quick-c/make.lua` 选择 make/解析目标/在 cwd 执行
  - `lua/quick-c/telescope.lua` Telescope 交互（目录与目标、自定义参数）
  - `lua/quick-c/build.lua` 构建/运行/调试
  - `lua/quick-c/autorun.lua` 保存即运行
  - `lua/quick-c/keys.lua` 键位注入

- 行为保持不变：
  - 键位可配置/禁用；多 Makefile 时目录先选后执行；选择后自动关闭选择器并在终端执行；全程异步不阻塞。

## Windows 注意事项

- 如在 PowerShell 下运行，会自动使用 `& 'path\to\exe'` 语法；`cmd`/其它 shell 下会使用 `"path\to\exe"`
- 使用 MSVC `cl` 编译时，请确保已在“开发者命令提示符”或已正确设置 VS 环境变量的终端中启动 Neovim

## 调试

- 需要安装并配置 `nvim-dap` 与 `codelldb`
- `:QuickCDebug` 会以 `codelldb` 方案启动，`program` 指向最近一次构建输出

## 自动运行（Autorun）

- 通过 `setup({ autorun = { enabled = true, ... } })` 开启
- 默认事件：`BufWritePost`，默认文件类型：`c`、`cpp`
- 也可在运行中用 `:QuickCAutoRunToggle` 动态开关

## 故障排查

- 找不到编译器：请确认 `gcc/g++`、`clang/clang++` 或 `cl` 在 `PATH` 中
- 构建失败但无输出：查看 Neovim `:messages` 或终端面板中的编译器警告/错误
- 终端无法发送命令：如安装了 `betterTerm` 但发送失败，插件会自动回退到内置终端
- 无法运行可执行文件：请先 `:QuickCBuild`；或检查输出目录与文件后缀（Windows 需要 `.exe`）
 - 未解析到 make 目标：确认项目存在 `Makefile`，以及 `make -qp` 在该目录下可运行；Windows 可改用 `mingw32-make`

## 目录结构

- `plugin/quick-c.lua` 自动调用 `require('quick-c').setup()`
- `lua/quick-c/init.lua` 插件主体、配置与命令实现

