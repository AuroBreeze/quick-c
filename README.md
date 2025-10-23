# Quick-c

一个面向 C/C++ 的轻量 Neovim 插件：一键编译、运行与调试当前文件，支持 Windows、Linux、macOS，兼容 betterTerm 与内置终端，并可选自动保存后构建运行。

## 特性

- **一键构建/运行**：`QuickCBuild`、`QuickCRun`、`QuickCBR`（构建并运行）
- **调试集成**：`QuickCDebug` 使用 `nvim-dap` 与 `codelldb`
- **跨平台**：自动选择可用编译器（gcc/clang/cl）与合适运行方式（PowerShell/终端）
- **灵活输出位置**：默认将可执行文件输出到源码所在目录；可通过配置修改
- **终端兼容**：优先将命令发送到 `betterTerm`（如已安装），否则使用 Neovim 内置终端
- **自动运行**：可选保存后自动构建并运行（按文件类型过滤）
- **便捷快捷键**：默认提供 `<leader>cb`、`<leader>cr`、`<leader>cR`、`<leader>cD`

## 依赖

- Neovim 0.8+
- 至少一种 C/C++ 编译器（按平台自动探测）：
  - Windows: `gcc/g++`（MinGW）或 `cl`（MSVC）或 `clang/clang++`
  - Unix: `gcc/g++` 或 `clang/clang++`
- 可选：
  - [`betterTerm`](https://github.com/CRAG666/betterTerm.nvim)（若安装则优先使用）
  - 调试：[`nvim-dap`](https://github.com/mfussenegger/nvim-dap) 与 `codelldb`

## 安装

使用 lazy.nvim：

```lua
{
  "AuroBreeze/Quick-c",
  config = function()
    require("quick-c").setup()
  end,
}
```

使用 packer.nvim：

```lua
use({
  "AuroBreeze/Quick-c",
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

默认配置（摘自 `lua/quick-c/init.lua` 的 `M.config`）：

```lua
require("quick-c").setup({
  outdir = "source", -- 输出到源码目录；也可改为自定义目录
  toolchain = {
    windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
    unix = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
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
})
```

自定义示例：指定固定输出目录，并优先使用 `clang/clang++`：

```lua
require("quick-c").setup({
  outdir = vim.fn.stdpath("data") .. "/quick-c-bin",
  toolchain = {
    windows = { c = { "clang", "gcc", "cl" }, cpp = { "clang++", "g++", "cl" } },
    unix = { c = { "clang", "gcc" }, cpp = { "clang++", "g++" } },
  },
})
```

## 命令与快捷键

- `:QuickCBuild` 构建当前 C/C++ 文件
- `:QuickCRun` 运行当前文件对应的可执行文件
- `:QuickCBR` 构建并运行
- `:QuickCDebug` 使用 `nvim-dap` 以 `codelldb` 调试可执行文件
- `:QuickCAutoRunToggle` 切换保存即运行（受 `autorun.filetypes` 限制）

默认快捷键（普通模式）：

- `<leader>cb` → 构建
- `<leader>cr` → 运行
- `<leader>cR` → 构建并运行
- `<leader>cD` → 调试

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

## 目录结构

- `plugin/quick-c.lua` 自动调用 `require('quick-c').setup()`
- `lua/quick-c/init.lua` 插件主体、配置与命令实现

