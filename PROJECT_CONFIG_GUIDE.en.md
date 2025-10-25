# Quick-c Project Configuration Guide

## Overview

Quick-c supports project-level configuration files (`.quick-c.json`), allowing you to customize configuration for specific projects and override global default settings. This provides great flexibility for multi-project development environments.

## Configuration File Location and Lookup Rules

### Configuration File Name
- File name: `.quick-c.json`
- Location: Project root directory

### Lookup Rules
1. **Upward Search**: Starts from the current editing file's directory and searches upward level by level
2. **First Match**: Stops at the first `.quick-c.json` file found
3. **Nested Support**: Supports multi-level project structures, each subproject can have independent configuration

### Lookup Example
```
project/
├── .quick-c.json          # Root project configuration
├── src/
│   ├── main.c
│   └── subproject/
│       ├── .quick-c.json  # Subproject configuration (takes priority)
│       └── sub.c
└── tests/
    └── test.c
```

## Configuration Format and Options

### Basic Structure
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

### Complete Configuration Options

#### Build Output Configuration
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

#### Toolchain Configuration
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

#### Make Integration Configuration
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
      "prompt_title": "Project Build Targets",
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

#### Diagnostics Configuration
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

#### Terminal Configuration
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

#### Keymaps Configuration
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
    "
quickfix": "<leader>cf"
  }
}
```

#### Auto-run Configuration
```json
{
  "autorun": {
    "enabled": false,
    "events": ["BufWritePost"],
    "filetypes": ["c", "cpp"]
  }
}
```

## Practical Application Scenarios

### Scenario 1: Build System Project
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

### Scenario 2: Embedded Development Project
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

### Scenario 3: Cross-platform Project
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

## Configuration Priority and Inheritance

### Configuration Priority (Highest to Lowest)
1. **Project-level Configuration** (`.quick-c.json`) - Highest priority
2. **User Configuration** (`setup()` parameters) - Medium priority  
3. **Default Configuration** - Lowest priority

### Configuration Merge Rules
- Uses deep merge strategy
- Project configuration completely overrides user and default configurations
- Array-type configurations are replaced rather than merged

### Configuration Activation Timing
- **During Initialization**: Automatically detected and applied when plugin loads
- **When Switching Projects**: Automatically applies corresponding configuration when switching to different projects
- **Requires Reload**: Plugin needs reloading after configuration file changes

## Debugging and Troubleshooting

### Enable Debug Mode
```lua
-- Set in Neovim configuration
vim.g.quick_c_debug = true
```

### Verify Configuration Loading
```lua
:lua print(vim.inspect(require("quick-c.project_config").get_current_project_config()))
```

### Common Issues

#### 1. Configuration Not Taking Effect
- Check if configuration file path is correct
- Confirm configuration file format (JSON)
- Verify configuration option spelling

#### 2. Configuration Syntax Errors
```json
// Incorrect example
{
  outdir: "build"  // Missing quotes
}

// Correct example
{
  "outdir": "build"
}
```

#### 3. Configuration Priority Issues
- Project configuration completely overrides global configuration
- Ensure project configuration includes all required options

## Best Practices

### 1. Version Control
- Add `.quick-c.json` to version control
- Provide consistent development environment for team members

### 2. Configuration Templates
Create configuration templates for different project types:
- `embedded-project.json`
- `library-project.json` 
- `cli-tool-project.json`

### 3. Environment Adaptation
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

### 4. Performance Optimization
```json
{
  "make": {
    "cache": {
      "ttl": 30  // Increase cache time to improve performance
    }
  }
}
```

## Summary

Project configuration files provide powerful project-level customization capabilities for Quick-c, enabling:
- ✅ Independent build configuration for each project
- ✅ Consistent configuration across team collaboration
- ✅ Unified configuration for cross-platform development environments
- ✅ Simplified configuration management for complex project structures

By properly using project configuration files, you can significantly improve C/C++ project development efficiency and team collaboration experience.