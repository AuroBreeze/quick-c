# Quick-c Release Notes

## v1.2.0 (2025-10-24)

### 新增
- Make 目标参数支持：执行目标前可输入附加参数（如 `-j4 VAR=1`），并按目录记忆最近一次输入。
- `.PHONY` 优先：`.PHONY` 目标优先显示并标注 `[PHONY]`；在 Telescope 中可用 `<C-p>` 切换“仅显示 .PHONY”。

### 改进
- README 重构：移除 Autorun 功能与文档残留；完善 Make 参数与 `.PHONY` 说明，三重懒加载示例保持一致。
- 目标解析结构化：`make -qp` 解析同时产出 `{ targets, phony }` 并加入缓存（TTL + mtime）。

### 兼容性
- `make.args` 新配置：`prompt`/`default`/`remember`。
- `make.targets.prioritize_phony` 新配置，默认开启。

---
## v1.1.1 (2025-10-24)

### 改进
- 终端选择器 UX：选择已打开的内置终端发送时，默认打开/聚焦该终端窗口；默认策略条目显示命令前缀（如 `make`）。
- `make.prefer` 支持字符串或列表，按顺序探测（例如 `{ 'make', 'mingw32-make' }`）。
- 解析 make 目标增加缓存（TTL + Makefile mtime），减少重复解析（默认 10s，可通过 `make.cache.ttl` 配置）。
- Makefile 搜索支持配置化忽略目录，在多结果/单根查找中一致生效：`make.search.ignore_dirs`。
- README 更新：加入三重懒加载（ft/keys/cmd）安装与配置示例，完善预览与终端选择文档。

### 修复
- 去除了 `init.lua` 中重复的函数定义，减少冗余。
- 小幅文档修正与注释完善。

---

## v1.1.0 (2025-10-24)

### 新增
- Telescope 选择器内置 Makefile 预览：
  - 目录选择与目标选择均可预览 Makefile。
  - 目标选择阶段固定预览所选目录中的 Makefile，避免频繁刷新导致卡顿。
- 大文件与编码兼容：预览支持按字节/行数截断，避免卡顿或解码异常。
- 终端选择可配置：`make.telescope.choose_terminal = 'auto'|'always'|'never'`。
  - 选择已打开的内置终端发送时，会自动打开/聚焦该终端窗口。
- make 程序优先级支持列表：`make.prefer = { 'make', 'mingw32-make' }`，按顺序探测。

### 改进
- 预览使用更稳健的实现与跨平台路径拼接（Windows 兼容）。
- 键位注入采用 `unique=true`，不再覆盖用户已有映射。
- 解析 make 目标增加缓存（TTL + Makefile mtime），减少重复解析。

### 配置变化
- `make.telescope` 新增：
  - `preview`、`max_preview_bytes`、`max_preview_lines`、`set_filetype`、`choose_terminal`。
- 默认配置注释更详尽，README 新增使用说明与故障排查。
- 默认快捷键：`make` 改为 `<leader>cM`（避免与部分配置冲突）。

### 迁移指南
- 如你依赖旧的 `<leader>cm`，请在 `setup({ keymaps = { make = '<leader>cm' } })` 中显式设置。
- 如不希望弹出终端选择器，将 `make.telescope.choose_terminal = 'never'`。

---

## v1.0.1 (2025-10-24)

### 内部重构

- 拆分大文件 `init.lua` 为多个模块，维护性更好，API 不变：
  - `config.lua` 默认配置
  - `util.lua` 工具函数（平台/路径/消息）
  - `terminal.lua` 终端封装（betterTerm/内置）
  - `make_search.lua` 异步 Makefile 搜索与目录选择
  - `make.lua` 选择 make/解析目标/在 cwd 执行
  - `telescope.lua` Telescope 交互（目录与目标、自定义参数）
  - `build.lua` 构建/运行/调试
  - `autorun.lua` 保存即运行
  - `keys.lua` 键位注入

