# Quick-c 项目配置文件使用指南

## 概述

Quick-c 支持项目级配置文件（`.quick-c.json`），允许您为特定项目定制配置，覆盖全局默认设置。这为多项目开发环境提供了极大的灵活性。

## 配置文件位置与查找规则

### 配置文件名称
- 文件名：`.quick-c.json`
- 位置：项目根目录

### 查找规则（v1.4.0 起）
1. **项目根查找**：仅在当前工作目录（`:pwd`，项目根）查找 `.quick-c.json`
2. **文件名固定**：`.quick-c.json`
3. **自动重载**：切换目录（`DirChanged`）自动重载（含 400ms 防抖）；保存项目根的 `.quick-c.json` 时自动重载并提示

### 查找示例
```
project/
├── .quick-c.json          # 项目根配置
├── src/
│   ├── main.c
│   └── subproject/
│       └── sub.c
└── tests/
    └── test.c
```

## 项目级配置文件

在项目根目录创建 `.quick-c.json` 文件，可以为特定项目定制配置，覆盖全局配置。当插件检测到项目配置文件时，会自动加载并应用配置。

**配置文件查找规则：**
- 仅在当前工作目录（`:pwd`，项目根）查找
- 文件名固定为 `.quick-c.json`
- 如切换目录（`DirChanged`），会自动重新载入（含 400ms 防抖）

**配置格式：**
- 使用 JSON 格式
- 配置结构与 Lua 配置相同
- 支持所有配置选项

示例 `.quick-c.json`（含注释）：
```jsonc
{
  // 可执行文件输出目录："source" 表示写到源码同目录；也可指定自定义路径
  "outdir": "build",

  // 工具链优先级（按平台、按语言），会按顺序探测第一个可执行项
  "toolchain": {
    "windows": { "c": ["gcc", "cl"], "cpp": ["g++", "cl"] },
    "unix":    { "c": ["gcc", "clang"], "cpp": ["g++", "clang++"] }
  },

  // 为 LSP（如 clangd）生成/使用 compile_commands.json
  "compile_commands": {
    "mode": "generate",    // generate | use
    "outdir": "build"       // 写入位置；"source" 表示写到当前源文件目录
    // "use_path": "./compile_commands.json" // 当 mode = use 时，从该路径复制
  },

  // 构建诊断收集到 quickfix 的策略
  "diagnostics": {
    "quickfix": {
      "open": "warning",     // always | error | warning | never
      "jump": "warning",     // always | error | warning | never
      "use_telescope": true   // 打开列表优先使用 Telescope quickfix
    }
  },

  // Make 相关配置
  "make": {
    // 首选 make 程序：可为字符串或数组；Windows 可用 ["make", "mingw32-make"]
    "prefer": ["make", "mingw32-make"],
    // 当 prefer 指定的程序不存在或不在 PATH 中时，是否仍强制使用
    // 例如 { "prefer": "make", "prefer_force": true } 在 PATH 找不到 make 时也会尝试调用
    "prefer_force": false,
    // 可选：在 Windows 下通过 WSL 执行（未来计划，示例占位）
    // "wrapper": "wsl",

    // 固定工作目录：优先作为 -C 的目录
    // 注意：该目录必须存在；若不存在会回退到起点并提示
    // 若该目录本身没有 Makefile，会在该目录内“向下搜索”（深度见 search.down）
    "cwd": ".",

    // 搜索策略（仅在未指定 cwd 或 cwd 内需继续向下查找时使用）
    "search": {
      "up": 2,                     // 向上回溯的层数（受 :pwd 边界限制）
      "down": 3,                   // 每层向下递归的最大深度
      "ignore_dirs": [".git", "node_modules", ".cache"] // 忽略目录
      // 增强：即便目录在忽略名单内，也会进行“一层探测”，如根下有 Makefile 仍纳入候选
    },

    // Telescope 相关展示
    "telescope": { "prompt_title": "项目构建目标" },

    // 解析缓存：同一 cwd 且 Makefile 未变化时，在 TTL 内复用结果
    "cache": { "ttl": 10 },

    // 追加 make 参数（如 -j4、VAR=1），并按 cwd 记住最近一次输入
    "args": { "prompt": true, "default": "-j4", "remember": true }
  },

  // 默认键位（可自定义/禁用），仅在 keymaps.enabled != false 时注入
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

## 配置格式与选项

### 基本结构
```json
{
  
}
```

#### 构建输出配置
```jsonc
{
  // 可执行文件输出目录：
  //  - "source" 表示输出到源码所在目录
  //  - 自定义路径：例如 "build" 或 绝对路径
  "outdir": "build",

  // LSP 编译数据库（clangd 等）
  "compile_commands": {
    // 生成或使用外部文件：'generate' | 'use'
    "mode": "generate",
    // 输出目录：'source' 表示写到当前源文件目录；否则写到此处
    "outdir": "build",
    // 当 mode = 'use' 时，从该路径复制 compile_commands.json 到 outdir
    // 例如："./compile_commands.json"
    "use_path": null
  }
}
```

#### 工具链配置
```jsonc
{
  // 按平台/语言设置编译器优先级，会按顺序探测第一个可执行项
  "toolchain": {
    "windows": {
      // C 语言：gcc > cl；可根据环境调整顺序
      "c": ["gcc", "cl"],
      // C++：g++ > cl
      "cpp": ["g++", "cl"]
    },
    "unix": {
      // C 语言：gcc > clang
      "c": ["gcc", "clang"],
      // C++：g++ > clang++
      "cpp": ["g++", "clang++"]
    }
  }
}
```

#### Make 集成配置
```jsonc
{
  "make": {
    // 启用/禁用 make 集成
    "enabled": true,

    // 首选 make 程序（按顺序探测）；Windows 可用 ["make", "mingw32-make"]
    // 也可指定绝对路径（支持空格路径）
    "prefer": ["make", "mingw32-make"],
    // 当 prefer 不可执行或不在 PATH 中时，是否仍强制使用
    // 例如 { "prefer": "make", "prefer_force": true }
    "prefer_force": false,

    // 固定工作目录：作为 -C 的目录；必须存在
    // 若目录内没有 Makefile，会在该目录“向下搜索”至多 search.down 层
    "cwd": ".",

    // 搜索策略（当未设置 cwd 或需在 cwd 中继续查找时）
    "search": {
      // 起点向上回溯的层数（受 :pwd 边界限制）
      "up": 2,
      // 每层向下递归的最大深度
      "down": 3,
      // 忽略的目录名；增强：对忽略目录做“一层探测”，若根下有 Makefile 仍纳入候选
      "ignore_dirs": [".git", "node_modules", ".cache", "build"]
    },

    // Telescope 选择器
    "telescope": {
      // 选择器标题
      "prompt_title": "项目构建目标",
      // 是否启用预览；预览显示已选目录中的 Makefile
      "preview": true,
      // 发送命令到终端时的选择：auto | always | never
      "choose_terminal": "auto"
    },

    // 目标解析缓存（TTL 秒）。同一 cwd 且 Makefile 未变化时复用
    "cache": { "ttl": 10 },

    // 目标列表行为
    "targets": {
      // 是否优先显示 .PHONY 目标；在选择器中可用 <C-p> 切换仅显示 .PHONY
      "prioritize_phony": true
    },

    // 追加 make 参数（如 -j4、VAR=1），并按 cwd 记住最近一次输入
    "args": { "prompt": true, "default": "-j4", "remember": true }
  }
}
```

#### 诊断配置
```jsonc
{
  "diagnostics": {
    "quickfix": {
      // 是否收集到 quickfix
      // 打开策略：always | error | warning | never
      "open": "warning",
      // 跳转策略：always | error | warning | never
      "jump": "warning",
      // 打开列表时优先使用 Telescope quickfix（如已安装）
      "use_telescope": true
    }
  }
}
```

#### 终端配置
```jsonc
{
  // 内置终端窗口参数
  "terminal": {
    // 运行命令时是否自动打开终端
    "open": true,
    // 终端窗口高度
    "height": 15
  },
  // betterTerm（如安装则优先使用）
  "betterterm": {
    // 是否启用 betterTerm 集成
    "enabled": true,
    // 目标终端索引（0 为第一个）
    "index": 0,
    // 发送命令延迟（毫秒）
    "send_delay": 200,
    // 发送后是否聚焦终端
    "focus_on_run": true,
    // 终端未打开时是否自动打开
    "open_if_closed": true
  }
}
```

#### 快捷键配置
```jsonc
{
  "keymaps": {
    // 设为 false 不注入任何默认键位
    "enabled": true,
    // 置为 null/空字符串 可单独禁用某个映射
    "build": "<leader>cb",         // 构建
    "run": "<leader>cr",           // 运行
    "build_and_run": "<leader>cR", // 构建并运行
    "debug": "<leader>cD",         // 调试
    "make": "<leader>cM",          // 打开 Make 选择器
    "sources": "<leader>cS",       // 打开源文件多选（Telescope）
    "quickfix": "<leader>cf"       // 打开 quickfix 列表（Telescope）
  }
}
```

## 实际应用场景

### 场景 1：构建系统项目
```json
{
  "outdir": "build",
  "compile_commands": {
    "mode": "generate",
    "outdir": "build"
  },
  "make": {
    "prefer": ["make"],
    "cwd": ".",
    "search": {
      "ignore_dirs": [".git", "build", "dist", "node_modules"]
    },
    "args": {
      "default": "-j8",
      "remember": true
    }
  },
  "keymaps": {
    "build": "<leader>mb",
    "run": "<leader>mr",
    "make": "<leader>mm"
  }
}
```

### 场景 2：嵌入式开发项目
```json
{
  "outdir": "build",
  "toolchain": {
    "windows": { "c": ["arm-none-eabi-gcc"] },
    "unix": { "c": ["arm-none-eabi-gcc"] }
  },
  "compile_commands": {
    "mode": "use",
    "outdir": "build",
    "use_path": "./compile_commands.json"
  },
  "diagnostics": {
    "quickfix": {
      "open": "error",
      "jump": "error"
    }
  }
}
```

### 场景 3：跨平台项目
```json
{
  "outdir": "bin",
  "toolchain": {
    "windows": { 
      "c": ["cl", "gcc"],
      "cpp": ["cl", "g++"]
    },
    "unix": { 
      "c": ["gcc", "clang"],
      "cpp": ["g++", "clang++"]
    }
  },
  "make": {
    "prefer": {
      "windows": ["mingw32-make", "make"],
      "unix": ["make"]
    }
  }
}
```

## 配置优先级与继承

### 配置优先级（从高到低）
1. **项目级配置** (`.quick-c.json`) - 最高优先级
2. **用户配置** (`setup()` 参数) - 中等优先级  
3. **默认配置** - 最低优先级

### 配置合并规则
- 使用深度合并策略
- 项目配置会完全覆盖用户配置和默认配置
- 数组类型配置会被替换而非合并

### 配置生效时机
- **初始化时**：插件加载时自动检测并应用配置
- **项目切换时**：切换到不同项目时自动应用（`DirChanged` 自动重载，400ms 防抖）
- **保存配置时**：在项目根保存 `.quick-c.json` 会自动重载并提示
- **手动重载**：可使用 `:QuickCReload`；使用 `:QuickCConfig` 查看生效配置与检测到的配置路径

## 调试与故障排除

### 启用调试模式
```lua
-- 在 Neovim 配置中设置
vim.g.quick_c_debug = true
```

### 验证配置加载
```lua
:lua print(vim.inspect(require("quick-c.project_config").get_current_project_config()))
```

### 常见问题

#### 1. 配置未生效
- 检查配置文件路径是否正确
- 确认配置文件格式（JSON）
- 验证配置选项拼写

#### 2. 配置语法错误
```json
// 错误示例
{
  outdir: "build"  // 缺少引号
}

// 正确示例
{
  "outdir": "build"
}
```

#### 3. 配置优先级问题
- 项目配置会完全覆盖全局配置
- 确保项目配置包含所有需要的选项

## 最佳实践

### 1. 版本控制
- 将 `.quick-c.json` 添加到版本控制
- 为团队成员提供一致的开发环境

### 2. 配置模板
为不同类型项目创建配置模板：
- `embedded-project.json`
- `library-project.json` 
- `cli-tool-project.json`

### 3. 环境适配
```json
{
  "make": {
    "prefer": {
      "windows": ["mingw32-make", "make"],
      "unix": ["make"]
    }
  }
}
```

### 4. 性能优化
```json
{
  "make": {
    "cache": {
      "ttl": 30  // 增加缓存时间提升性能
    }
  }
}
```

## 总结

项目配置文件为 Quick-c 提供了强大的项目级定制能力，使得：
- ✅ 每个项目可以有独立的构建配置
- ✅ 团队协作时配置保持一致
- ✅ 跨平台开发环境配置统一
- ✅ 复杂项目结构配置管理简化

通过合理使用项目配置文件，您可以大幅提升 C/C++ 项目的开发效率和团队协作体验。