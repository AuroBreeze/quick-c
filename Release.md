# Quick-c Release Notes

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

