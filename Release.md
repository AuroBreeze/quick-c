# Quick-c Release Notes

## v1.0.0 (2025-10-24)

这是 Quick-c 的首个稳定版本，带来异步构建/运行、Make 适配与 Telescope 集成，以及更好的跨平台终端兼容性。

### 新增

- 异步构建/运行
  - 构建进程通过 `jobstart` 异步执行，不阻塞 Neovim 主线程。
  - 多源文件输出名使用 `vim.ui.input` 提示（非阻塞）。
  - 提供回调：`build(nil, nil, { on_exit = function(code, exe) ... end })` 可扩展自定义行为。
- Make 适配（可选）
  - 自动检测 `make` 或 Windows 下的 `mingw32-make`。
  - 通过 `make -qp` 异步解析目标（过滤伪目标与模式目标）。
  - Telescope 集成：`:QuickCMake` 打开选择器，选择如 `clean`、`install` 等目标后执行。
  - 直接运行：`:QuickCMakeRun [target]`。
- 新命令与快捷键
  - `:QuickCBuild`、`:QuickCRun`、`:QuickCBR`、`:QuickCDebug`
  - `:QuickCAutoRunToggle`（保存时自动构建并运行的开关）
  - `:QuickCMake`、`:QuickCMakeRun [target]`
  - 默认快捷键：`<leader>cb`、`<leader>cr`、`<leader>cR`、`<leader>cD`、`<leader>cm`
  - 键位可配置/禁用：通过 `setup({ keymaps = { ... } })` 自定义（设为 `nil`/`''` 可单独禁用；`enabled=false` 可全部禁用）

### 变更

- 默认输出名策略保持不变；当需要询问输出名时，改用 `vim.ui.input`，不再阻塞。
- `QuickCBR` 改为在构建成功后回调触发运行，避免定时器带来的竞态。
- 在 Windows/PowerShell 下对路径进行恰当引用，提升空格路径的兼容性。

### 依赖与兼容

- 需要 Neovim 0.8+。
- 可选依赖：
  - 终端：`betterTerm`（若安装则优先使用）
  - 调试：`nvim-dap` 与 `codelldb`
  - Make 选择器：`nvim-telescope/telescope.nvim` 与 `nvim-lua/plenary.nvim`

### 升级指引

- 如想关闭 Make 集成或指定 `make` 可执行名，可在 `setup` 中：
  ```lua
  require('quick-c').setup({
    make = {
      enabled = true,
      prefer = nil, -- Windows 可设 "mingw32-make"
      cwd = nil,
      telescope = { prompt_title = "Quick-c Make Targets" },
    },
  })
  ```
- 快捷键 `<leader>cm` 用于打开 Make 目标选择器，可自行移除或修改映射。

### 已知问题

- `make -qp` 目标解析依赖项目目录下的 `Makefile`，若未找到可能无法显示目标。
- Windows 用户若无 `make` 可安装 MinGW 并使用 `mingw32-make`。
