# Quick-c 项目配置文件使用指南

## 概述

Quick-c 支持项目级配置文件（`.quick-c.json`），允许您为特定项目定制配置，覆盖全局默认设置。这为多项目开发环境提供了极大的灵活性。

## 配置文件位置与查找规则

### 配置文件名称
- 文件名：`.quick-c.json`
- 位置：项目根目录

### 查找规则
1. **向上查找**：从当前编辑的文件所在目录开始，逐级向上查找
2. **首次匹配**：找到第一个 `.quick-c.json` 文件即停止
3. **支持嵌套**：支持多级项目结构，每个子项目可以有独立配置

### 查找示例
```
project/
├── .quick-c.json          # 项目根配置
├── src/
│   ├── main.c
│   └── subproject/
│       ├── .quick-c.json  # 子项目配置（优先使用）
│       └── sub.c
└── tests/
    └── test.c
```

## 配置格式与选项

### 基本结构
```json
{
  "outdir": "build",
  "toolchain": {
    "windows": { "c": ["gcc", "cl"], "cpp": ["g++", "cl"] },
    "unix": { "c": ["gcc", "clang"], "cpp": ["g++", "clang++"] }
  },
  "make": {
    "prefer": ["make", "mingw32-make"],
    "cwd": "."
  },
  "keymaps": {
    "build": "<leader>cb",
    "run": "<leader>cr"
  }
}
```

### 完整配置选项

#### 构建输出配置
```json
{
  "outdir": "build",
  "compile_commands": {
    "mode": "generate",
    "outdir": "build",
    "use_path": null
  }
}
```

#### 工具链配置
```json
{
  "toolchain": {
    "windows": {
      "c": ["gcc", "cl"],
      "cpp": ["g++", "cl"]
    },
    "unix": {
      "c": ["gcc", "clang"],
      "cpp": ["g++", "clang++"]
    }
  }
}
```

#### Make 集成配置
```json
{
  "make": {
    "enabled": true,
    "prefer": ["make", "mingw32-make"],
    "cwd": ".",
    "search": {
      "up": 2,
      "down": 3,
      "ignore_dirs": [".git", "node_modules", ".cache", "build"]
    },
    "telescope": {
      "prompt_title": "项目构建目标",
      "preview": true,
      "choose_terminal": "auto"
    },
    "cache": {
      "ttl": 10
    },
    "targets": {
      "prioritize_phony": true
    },
    "args": {
      "prompt": true,
      "default": "-j4",
      "remember": true
    }
  }
}
```

#### 诊断配置
```json
{
  "diagnostics": {
    "quickfix": {
      "open": "warning",
      "jump": "warning",
      "use_telescope": true
    }
  }
}
```

#### 终端配置
```json
{
  "terminal": {
    "open": true,
    "height": 15
  },
  "betterterm": {
    "enabled": true,
    "index": 0,
    "send_delay": 200,
    "focus_on_run": true,
    "open_if_closed": true
  }
}
```

#### 快捷键配置
```json
{
  "keymaps": {
    "enabled": true,
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

#### 自动运行配置
```json
{
  "autorun": {
    "enabled": false,
    "events": ["BufWritePost"],
    "filetypes": ["c", "cpp"]
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
- **项目切换时**：切换到不同项目时自动应用对应配置
- **需要重新加载**：配置文件变更后需要重新加载插件

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