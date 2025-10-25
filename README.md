# Quick-c

<div align="center"><p>
    <a href="https://github.com/AuroBreeze/quick-c/releases/latest">
      <img alt="Latest release" src="https://img.shields.io/github/v/release/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41&include_prerelease&sort=semver" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/pulse">
      <img alt="Last commit" src="https://img.shields.io/github/last-commit/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41"/>
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/blob/main/LICENSE">
      <img alt="License" src="https://img.shields.io/github/license/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/stargazers">
      <img alt="Stars" src="https://img.shields.io/github/stars/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/issues">
      <img alt="Issues" src="https://img.shields.io/github/issues/AuroBreeze/quick-c?style=for-the-badge&logo=bilibili&color=F5E0DC&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c">
      <img alt="Repo Size" src="https://img.shields.io/github/repo-size/AuroBreeze/quick-c?color=%23DDB6F2&label=SIZE&logo=codesandbox&style=for-the-badge&logoColor=D9E0EE&labelColor=302D41" />
    </a>
</p></div>

<p align="center">
  <b>中文</b> | <a href="README.en.md">English</a>
</p>

一个面向 C/C++ 的轻量 Neovim 插件：一键编译、运行与调试当前文件，支持 Windows、Linux、macOS，兼容 betterTerm 与内置终端。构建与运行全程异步，不会阻塞 Neovim 主线程。

<a href="https://dotfyle.com/plugins/AuroBreeze/quick-c">
  <img src="https://dotfyle.com/plugins/AuroBreeze/quick-c/shield" />
</a>

## ✨ 特性

 - 🚀 **一键构建/运行（异步）**：`QuickCBuild`、`QuickCRun`、`QuickCBR`（构建并运行）
 - 🐞 **调试集成**：`QuickCDebug` 使用 `nvim-dap` 与 `codelldb`
 - 🌐 **跨平台**：自动选择可用编译器（gcc/clang/cl）与合适运行方式（PowerShell/终端）
 - 📁 **灵活输出位置**：默认将可执行文件输出到源码所在目录；可通过配置修改
 - 🔌 **终端兼容**：优先将命令发送到 `betterTerm`（如已安装），否则使用 Neovim 内置终端
 
 - 🔧 **Make 集成（异步）**：自动解析 `make -qp` 目标，Telescope 选择执行（如 `clean`、`install`）
 - ⌨️ **便捷快捷键**：默认提供 `<leader>cqb`、`<leader>cqr`、`<leader>cqR`、`<leader>cqD`、`<leader>cqM`
 - 📚 **LSP 集成（compile_commands.json）**：一键为当前文件目录生成或使用指定 `compile_commands.json` 供 clangd 等 LSP 使用

## 📦 依赖

- Neovim 0.8+
- 至少一种 C/C++ 编译器（按平台自动探测）：
  - Windows: `gcc/g++`（MinGW）或 `cl`（MSVC）或 `clang/clang++`
  - Unix: `gcc/g++` 或 `clang/clang++`
- 可选：
  - [`betterTerm`](https://github.com/CRAG666/betterTerm.nvim)（若安装则优先使用）
  - 调试：[`nvim-dap`](https://github.com/mfussenegger/nvim-dap) 与 `codelldb`
  - Make 选择器：[`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) 与 [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)

## 🧩 安装

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
    { "<leader>cqb", desc = "Quick-c: Build" },
    { "<leader>cqr", desc = "Quick-c: Run" },
    { "<leader>cqR", desc = "Quick-c: Build & Run" },
    { "<leader>cqD", desc = "Quick-c: Debug" },
    { "<leader>cqM", desc = "Quick-c: Make targets (Telescope)" },
    { "<leader>cqS", desc = "Quick-c: Select sources (Telescope)" }, -- 使用tab进行多选
    { "<leader>cqf", desc = "Quick-c: Open quickfix (Telescope)" },
  },
  -- 3) 命令触发（调用命令时加载，等同“命令提前加载”）
  cmd = {
    "QuickCBuild", "QuickCRun", "QuickCBR", "QuickCDebug",
    "QuickCMake", "QuickCMakeRun",
    "QuickCCompileDB", "QuickCCompileDBGen", "QuickCCompileDBUse",
    "QuickCQuickfix",
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

## 🚀 快速开始

打开任意 `*.c` 或 `*.cpp` 文件：

- 构建当前文件：`:QuickCBuild` 或 `<leader>cqb`
- 运行可执行文件：`:QuickCRun` 或 `<leader>cqr`
- 构建并运行：`:QuickCBR` 或 `<leader>cqR`
- 调试运行：`:QuickCDebug` 或 `<leader>cqD`

多文件项目（传入多个源文件路径）：

- C: `:QuickCBuild main.c util.c`
- C++: `:QuickCBR src/main.cpp src/foo.cpp`
- 运行基于多文件编译生成的可执行文件：`:QuickCRun src/main.cpp src/foo.cpp`

使用 Telescope 选择多文件（推荐）：

- 按 `<leader>cqS` 打开源文件选择器。
- 在列表中按 `Tab` 多选（Shift+Tab 往回，多选不移动可用 Ctrl+Space）。
- 回车后选择操作：Build / Run / Build & Run。

说明：源文件列表显示为相对当前工作目录的路径，内部会使用绝对路径进行构建与运行。
 

默认输出名为当前文件名（Windows 会追加 `.exe`）；如需自定义输出名，构建时可在提示中输入。

输出名与缓存：

- 多文件构建：总是弹出“Output name”输入框；若你对“同一源集合”输入过名称，将自动带出为默认值。
- 单文件构建：直接使用默认名（同文件名）。

## ⌨️ 命令与快捷键

- 命令：
  - `QuickCBuild`/`QuickCRun`/`QuickCBR`/`QuickCDebug`
  - `QuickCMake`/`QuickCMakeRun [target]`
  - `QuickCCompileDB`/`QuickCCompileDBGen`/`QuickCCompileDBUse`
  - `QuickCQuickfix`（打开 quickfix，优先 Telescope）
  - `QuickCReload`（重新计算默认+用户+项目配置）
  - `QuickCConfig`（打印生效配置与项目配置路径）

- 默认键位（普通模式）：
  - `<leader>cqb` 构建
  - `<leader>cqr` 运行
  - `<leader>cqR` 构建并运行
  - `<leader>cqD` 调试
  - `<leader>cqM` Make 目标（Telescope）
  - `<leader>cqS` 源文件选择（Telescope）
  - `<leader>cqf` 打开 quickfix（Telescope）

## ⚙️ 配置

Quick-c 支持多级配置，优先级从高到低为：
1. 项目级配置（`.quick-c.json`） - 覆盖全局配置
2. 用户配置（`setup()` 参数） - 用户自定义配置
3. 默认配置 - 插件内置默认值

### 项目级配置文件

在项目根目录创建 `.quick-c.json` 文件，可以为特定项目定制配置，覆盖全局配置。当插件检测到项目配置文件时，会自动加载并应用配置。

**配置文件查找规则：**
- 仅在当前工作目录（`:pwd`，项目根）查找
- 文件名固定为 `.quick-c.json`
- 如切换目录（`DirChanged`），会自动重新载入（含 400ms 防抖）

**配置格式：**
- 使用 JSON 格式
- 配置结构与 Lua 配置相同
- 支持所有配置选项

示例 `.quick-c.json`：
```json
{
  "outdir": "build",
  "toolchain": {
    "windows": {
      "c": ["gcc", "cl"],
      "cpp": ["g++", "cl"]
    },
    "unix": {
      "c": ["gcc", "clang"],
      "cpp": ["g++", "clang++"]
    }
  },
  "compile_commands": {
    "mode": "generate",
    "outdir": "build"
  },
  "diagnostics": {
    "quickfix": {
      "open": "warning",
      "jump": "warning",
      "use_telescope": true
    }
  },
  "make": {
    "prefer": ["make", "mingw32-make"],
    "cwd": ".",
    "search": {
      "up": 2,
      "down": 3,
      "ignore_dirs": [".git", "node_modules", ".cache", "build"]
    },
    "telescope": {
      "prompt_title": "项目构建目标"
    },
    "cache": {
      "ttl": 10
    },
    "args": {
      "prompt": true,
      "default": "-j4",
      "remember": true
    }
  },
  "keymaps": {
    "build": "<leader>cb",
    "run": "<leader>cr",
    "build_and_run": "<leader>cR",
    "debug": "<leader>cD",
    "make": "<leader>cM",
    "sources": "<leader>cS",
    "quickfix": "<leader>cf"
  }
}
```

**项目配置文件示例场景：**

1. **构建输出目录定制**
```json
{
  "outdir": "build",
  "compile_commands": {
    "mode": "generate",
    "outdir": "build"
  }
}
```

2. **项目特定工具链**
```json
{
  "toolchain": {
    "windows": { "c": ["clang", "gcc"] },
    "unix": { "c": ["clang", "gcc"] }
  },
  "make": {
    "prefer": ["make", "mingw32-make"],
    "cwd": ".",
    "search": {
      "ignore_dirs": [".git", "node_modules", "build", "dist"]
    }
  }
}
```

3. **项目快捷键定制**
```json
{
  "keymaps": {
    "build": "<leader>cb",
    "run": "<leader>cr",
    "build_and_run": "<leader>cR",
    "debug": "<leader>cD",
    "make": "<leader>cM"
  }
}
```

**配置生效时机：**
- 插件初始化时自动检测并加载
- 切换不同项目（`:cd` 改变 `:pwd`）时自动应用（400ms 防抖）
- 使用命令 `:QuickCReload` 手动重载
- 使用命令 `:QuickCConfig` 查看“生效配置”和检测到的项目配置路径

### 用户配置

最小示例（仅常用项）：

```lua
require("quick-c").setup({
  outdir = "source", -- 或自定义路径，如 vim.fn.stdpath("data") .. "/quick-c-bin"
  toolchain = {
    windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
    unix    = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
  },
  make = {
    prefer = { "make", "mingw32-make" },
    cache = { ttl = 10 },
    telescope = { choose_terminal = "auto" },
  },
  diagnostics = {
    quickfix = { open = "warning", jump = "warning", use_telescope = true },
  },
  keymaps = {
    enabled = true,
    build = "<leader>cqb",
    run = "<leader>cqr",
    build_and_run = "<leader>cqR",
    debug = "<leader>cqD",
  },
})
```

默认配置（三重懒加载启用；完整配置与注释均保留）：

```lua
{
  "AuroBreeze/quick-c",
  -- 三重懒加载：任一触发即可加载
  ft = { "c", "cpp" },
  keys = {
    { "<leader>cqb", desc = "Quick-c: Build" },
    { "<leader>cqr", desc = "Quick-c: Run" },
    { "<leader>cqR", desc = "Quick-c: Build & Run" },
    { "<leader>cqD", desc = "Quick-c: Debug" },
    { "<leader>cqM", desc = "Quick-c: Make targets (Telescope)" },
    { "<leader>cqS", desc = "Quick-c: Select sources (Telescope)" },
    { "<leader>cqf", desc = "Quick-c: Open quickfix (Telescope)" },
  },
  cmd = {
    "QuickCBuild", "QuickCRun", "QuickCBR", "QuickCDebug",
    "QuickCMake", "QuickCMakeRun", "QuickCQuickfix",
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
      -- 为 LSP 生成/使用 compile_commands.json（clangd 等）
      compile_commands = {
        -- 'generate' 生成基于当前文件的简单编译数据库；'use' 从指定路径复制
        mode = 'generate',
        -- 输出位置：'source' 表示写入到当前源文件所在目录
        outdir = 'source',
        -- 当 mode = 'use' 时，从该路径复制 compile_commands.json 到 outdir
        -- 例如：vim.fn.getcwd().."/compile_commands.json"
        use_path = nil,
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
        -- 目标列表行为
        targets = {
          -- 将 .PHONY 目标在列表中优先显示（Telescope 内可用 <C-p> 切换“仅显示 .PHONY”）
          prioritize_phony = true,
        },
        -- 追加 make 参数（如 -j4、VAR=1），并记住每个 cwd 最近一次输入
        args = {
          prompt = true,   -- 选择目标后是否弹出输入框
          default = "",    -- 默认参数
          remember = true, -- 记忆最近一次输入，作为默认值
        },
      },
      diagnostics = {
        quickfix = {
          enabled = true,
          open = 'warning',   -- always | error | warning | never
          jump = 'warning',   -- always | error | warning | never
          use_telescope = true,
        },
      },
      keymaps = {
        -- 设为 false 可不注入任何默认键位（你可自行映射命令）
        enabled = true,
        -- 置为 nil 或 '' 可单独禁用某个映射
        build = '<leader>cqb',
        run = '<leader>cqr',
        build_and_run = '<leader>cqR',
        debug = '<leader>cqD',
        -- 注意：键位注入使用 unique=true，不会覆盖你已有的映射；冲突时跳过
        make = '<leader>cqM',
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

### 🧪 诊断与快速跳转（quickfix / Telescope）

- 构建时会解析 gcc/clang/MSVC 输出为 quickfix 项，支持错误与警告。
- 满足触发条件时自动打开列表并跳转到第一条；默认仅有错误时打开/跳转。
- 如已安装 Telescope，默认使用 `:Telescope quickfix` 打开（可在配置关闭）。

提示：若当前缓冲是“未命名且已修改”，为避免保存提示，自动跳转（`cc`）将被跳过，此时请在 quickfix 中手动选择条目即可。

配置示例：

```lua
require('quick-c').setup({
  diagnostics = {
    quickfix = {
      enabled = true,
      open = 'warning',   -- always | error | warning | never
      jump = 'warning',   -- always | error | warning | never
      use_telescope = true,
    },
  },
})
```

#### 支持的编译器输出

- gcc/g++
- clang/clang++
- MSVC cl

默认快捷键（普通模式）：

- `<leader>cqb` → 构建
- `<leader>cqr` → 运行
- `<leader>cqR` → 构建并运行
- `<leader>cqD` → 调试
- `<leader>cqM` → 打开 Make 目标选择器（Telescope）
- `<leader>cqS` → 打开源文件选择器（Telescope）
- `<leader>cqf` → 打开 quickfix 列表（Telescope）

提示：
- 以上键位均可通过 `setup({ keymaps = { ... } })` 自定义或禁用。
- 插件设置键位时使用 `unique=true`，不会覆盖你已有的映射；如键位已被占用会跳过注入。

### 📚 Telescope 预览说明

- 目录选择器与目标选择器均内置 Makefile 预览，Windows 路径兼容更好。
- 目标选择器阶段，预览固定显示已选目录中的 Makefile，不随光标移动刷新（避免卡顿）。
- 对大文件自动截断，受以下配置项控制：
  - `make.telescope.preview`：是否启用预览。
  - `make.telescope.max_preview_bytes`：超过该字节数则改为按行读取并截断。
  - `make.telescope.max_preview_lines`：截断时最多显示的行数。
  - `make.telescope.set_filetype`：是否设置预览 buffer 的 `filetype=make`。

### 🔌 终端选择行为

- 选择 make 目标后，可将命令发送到已打开的内置终端，或使用默认策略（betterTerm 优先，失败回退内置）。
- 通过 `make.telescope.choose_terminal` 控制行为：
  - `'auto'`：存在已打开终端时弹选择器，否则直接默认策略。
  - `'always'`：总是弹出选择器。
  - `'never'`：总是使用默认策略。

### 🔎 Makefile 搜索说明

- 若未设置 `make.cwd`，插件会在“当前文件所在目录”为起点：
  - 向上查找至多 `search.up` 层（默认 2 层）
  - 在每一层向下递归至多 `search.down` 层（默认 3 层）
  - 找到包含 `Makefile`/`makefile`/`GNUmakefile` 的首个目录作为工作目录
  - 会跳过 `ignore_dirs` 名单中的目录（默认：`.git`、`node_modules`、`.cache`）
  - 增强：对被忽略目录进行“第一层探测”（不递归），若该目录根下存在 Makefile，则也纳入候选

多结果时，Telescope 列表显示相对于 `:pwd` 的相对路径，便于识别（如 `./build`、`./sub/dir`）。

## 🛠️ 架构说明

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
  - `lua/quick-c/cc.lua` 生成或使用指定的 `compile_commands.json`
  
  - `lua/quick-c/keys.lua` 键位注入

- 行为保持不变：
  - 键位可配置/禁用；多 Makefile 时目录先选后执行；选择后自动关闭选择器并在终端执行；全程异步不阻塞。

## 💻 Windows 注意事项

- 如在 PowerShell 下运行，会自动使用 `& 'path\to\exe'` 语法；`cmd`/其它 shell 下会使用 `"path\to\exe"`
- 使用 MSVC `cl` 编译时，请确保已在“开发者命令提示符”或已正确设置 VS 环境变量的终端中启动 Neovim

## 🐞 调试

- 需要安装并配置 `nvim-dap` 与 `codelldb`
- `:QuickCDebug` 会以 `codelldb` 方案启动，`program` 指向最近一次构建输出

 

## 🔎 故障排查

- 找不到编译器：请确认 `gcc/g++`、`clang/clang++` 或 `cl` 在 `PATH` 中
- 构建失败但无输出：查看 Neovim `:messages` 或终端面板中的编译器警告/错误
- 终端无法发送命令：如安装了 `betterTerm` 但发送失败，插件会自动回退到内置终端
- 无法运行可执行文件：请先 `:QuickCBuild`；或检查输出目录与文件后缀（Windows 需要 `.exe`）
 - 未解析到 make 目标：确认项目存在 `Makefile`，以及 `make -qp` 在该目录下可运行；Windows 可改用 `mingw32-make`

## 📋 发布说明

参见 [Release.md](Release.md)




