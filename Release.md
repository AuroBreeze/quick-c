# Quick-c Release Notes

## v1.4.0 (2025-10-26)

### 新增
- 项目级配置文件支持 (`.quick-c.json`)
  - 在项目根目录（`:pwd`）查找并加载，覆盖全局配置
  - 配置优先级：项目配置 > 用户配置 > 默认配置
  - 新命令：`QuickCReload`（重载默认+用户+项目配置）、`QuickCConfig`（打印生效配置与检测到的项目配置路径）
- 配置校验：新增 `QuickCCheck` 命令与校验模块
  - 检查项目/全局配置类型与关键路径，解析 `make.cwd` 并提示是否会在该目录内向下搜索
  - 显示最终选择的 make 程序与建议
- 文档：新增/更新项目配置指南（`PROJECT_CONFIG_GUIDE*.md`，含注释 JSONC 示例）与 README（中/英）

### 改进
- 配置加载更健壮：
  - JSON 解析支持 `vim.json.decode` 与 `vim.fn.json_decode` 回退
  - 处理 UTF-8 BOM
  - `DirChanged` 自动重载并加入 400ms 防抖
  - 重复提示去重：仅在项目配置路径变化时提示“已加载项目配置文件”，并加入 1s 提示抑制窗口
  - 使用自动命令组避免重复注册导致的多次提示
- Make 使用体验：
  - `QuickCMakeRun` 现在遵循 `make.args.prompt/default/remember`，可在运行目标时弹输入框
  - 相对 `make.cwd` 基于“当前文件所在目录”解析为绝对路径；若目录不存在自动回退到起点目录
  - 指定 `make.cwd` 但该目录没有 Makefile 时，会在该目录内“向下搜索”，深度沿用 `make.search.down`
  - Telescope 入口修正基准目录为“当前文件目录”，避免相对路径二次拼接
  - 搜索增强：对被忽略目录进行“一层探测”（不递归），若根下存在 Makefile 也纳入候选
  - `choose_make` 增强：
    - 支持 `make.prefer` 传绝对路径（含空格路径）
    - 新增 `make.prefer_force`，即使不可执行也可强制使用首选项（高阶用法）
- 键位管理：
  - 新增 `keymaps.unmap_defaults`（默认开启）：当你修改或禁用某个键位时，自动解除默认键位的旧映射，避免 which-key 中残留旧键位

### 修复
- 之前在未找到项目配置时仍提示“已加载项目配置文件”的问题
- 进入项目/保存 `.quick-c.json` 时重复提示的情况（augroup + 抑制窗口）
- 目标选择时右侧预览偶发不显示 Makefile 的问题
- `make.cwd` 无效导致 `jobstart` 报错（Invalid argument）的情况，现已在解析阶段回退并给出提示

### 兼容性
- 无破坏性变更；默认行为更稳健
- 如依赖“向上查找项目配置”的旧行为，请将 `.quick-c.json` 放到项目根（`:pwd`），或与我们讨论加入策略开关

### 迁移指南
- 无需迁移。建议：
  - 在项目根放置 `.quick-c.json`
  - 使用 `QuickCReload` 使配置立即生效；`QuickCConfig` 查看生效配置；`QuickCCheck` 自检配置

## v1.3.1 (2025-10-25)

### 新增
- Makefile 搜索结果缓存（TTL）
  - 为 `find_make_root_async` 与 `find_make_roots_async` 增加内存级缓存，默认 10 秒（可通过 `make.cache.ttl` 配置）。
  - 在 TTL 内复用相同查询结果，显著减少重复扫描、提升响应速度。

### 改进
- 文档美化：中英文 README 增添简洁图标并结构优化。
  - 增加最小配置示例（Minimal example）。
  - 新增“支持的编译器输出 / Supported compiler outputs”。
  - 小幅措辞与交互提示优化（如 Telescope 多选按键标注）。
 - 并行目录扫描：搜索阶段并发处理多个目录（最多 8 个）；在不支持异步 `fs_scandir` 的环境下自动回退为同步扫描并通过调度避免阻塞，整体搜索更快。

### 修复
- 若干 README 细节修正（排版与标注）。

### 兼容性
- 无破坏性变更；默认行为保持一致。

### 迁移指南
- 无需迁移。

## v1.3.0 (2025-10-25)

### 新增
- LSP：`compile_commands.json` 支持
  - 生成模式：为当前文件目录生成最简编译数据库
  - 指定模式：从配置的路径复制到目标目录
  - 新命令：`QuickCCompileDB` / `QuickCCompileDBGen` / `QuickCCompileDBUse`
- 多文件构建/运行
  - `:QuickCBuild/QuickCBR/QuickCRun [file1 ... fileN]` 支持传入多个源文件
  - 输出名缓存：按“源文件集合”记忆上次输入的输出名（如 `[1.c,2.c]` 与 `[1.c,2.c,3.c]` 各自独立）
- Telescope 源选择器
  - `<leader>cqS` 打开，支持多选后选择 Build / Run / Build & Run
  - 多选提示：Tab 选择，Shift+Tab 反向选择，Ctrl+Space 切换选择但不移动
 - 快速查看诊断的便捷入口
   - 新命令：`QuickCQuickfix`（优先打开 Telescope quickfix，无则 `:copen`）
   - 新键位：`<leader>cqf`

### 改进
- 默认键位前缀统一为 `<leader>cq*`
  - 构建/运行/构建并运行/调试/Make/源选择：`<leader>cqb/cqr/cqR/cqD/cqM/cqS`
- README：补充多文件与 Telescope 多选使用说明

### 修复
- `build_and_run` 运行阶段直接使用构建返回的可执行文件路径，避免多文件或自定义输出名时“构建成功但运行找不到可执行文件”

### 迁移指南
- 如你依赖旧键位，请在 `setup({ keymaps = { ... } })` 中显式配置回旧值
- `compile_commands` 默认不自动触发；需要时使用命令或在配置中切换 `mode`

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

