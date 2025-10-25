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
  <a href="README.md">中文</a> | <b>English</b>
</p>

# Quick-c

Lightweight Neovim plugin for C/C++: build, run, and debug the current file in one key. Works on Windows/Linux/macOS. Integrates with BetterTerm and the built-in terminal. Fully async.

## Features

- Build/Run (async): `QuickCBuild`, `QuickCRun`, `QuickCBR` (build & run)
- Debug integration: `QuickCDebug` via `nvim-dap` and `codelldb`
- Cross-platform: auto select compiler (gcc/clang/cl) and runtime (PowerShell/terminal)
- Flexible output dir: default to source folder; configurable
- Make integration: Telescope pickers for Make targets, custom args with cache
- compile_commands.json: generate or use an external one for clangd
- Keymaps included and non-invasive (unique=true)

## Quick Start

- Build: `:QuickCBuild` or `<leader>cqb`
- Run: `:QuickCRun` or `<leader>cqr`
- Build & Run: `:QuickCBR` or `<leader>cqR`
- Debug: `:QuickCDebug` or `<leader>cqD`

Multi-file:

- C: `:QuickCBuild main.c util.c`
- C++: `:QuickCBR src/main.cpp src/foo.cpp`
- Or press `<leader>cqS` to open Telescope source picker
  - Tab multi-select (Shift+Tab backward, Ctrl+Space toggle)
  - Enter to choose Build / Run / Build & Run

Note: the list shows paths relative to cwd; absolute paths are used internally.

Output name prompt & cache:

- Multi-file: always prompt; default is the last name used for the same source set
- Single-file: default to current filename (Windows adds .exe)

If the current buffer is unnamed and modified, auto-jump from diagnostics is skipped to avoid save prompts.

## Dependencies

- Neovim 0.8+
- Telescope (optional, recommended)
- nvim-dap + codelldb (for debugging)

## Commands

- `:QuickCBuild`, `:QuickCRun`, `:QuickCBR`, `:QuickCDebug`
- `:QuickCMake`, `:QuickCMakeRun [target]`
- `:QuickCCompileDB`, `:QuickCCompileDBGen`, `:QuickCCompileDBUse`
- `:QuickCQuickfix` open quickfix (Telescope if available)

## Keymaps (normal mode)

- `<leader>cqb` build
- `<leader>cqr` run
- `<leader>cqR` build & run
- `<leader>cqD` debug
- `<leader>cqM` Telescope Make targets
- `<leader>cqS` Telescope source picker
- `<leader>cqf` Open quickfix (Telescope)

## Diagnostics -> Quickfix / Telescope

- Parses gcc/clang/MSVC output to quickfix (errors & warnings)
- Auto open/jump policy: `always | error | warning | never`
- Prefer Telescope quickfix when available (`use_telescope = true`)
- If current buffer is unnamed and modified, auto-jump is skipped to avoid save prompts

## Configuration

Example (trimmed):

```lua
require('quick-c').setup({
  outdir = 'source',
  toolchain = {
    windows = { c = { 'gcc', 'cl' }, cpp = { 'g++', 'cl' } },
    unix    = { c = { 'gcc', 'clang' }, cpp = { 'g++', 'clang++' } },
  },
  make = {
    prefer = { 'make', 'mingw32-make' },
    cache = { ttl = 10 },
    targets = { prioritize_phony = true },
    args = { prompt = true, default = '', remember = true },
    telescope = { choose_terminal = 'auto' },
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
    enabled = true,
    build = '<leader>cqb',
    run = '<leader>cqr',
    build_and_run = '<leader>cqR',
    debug = '<leader>cqD',
    make = '<leader>cqM',
    sources = '<leader>cqS',
    quickfix = '<leader>cqf',
  },
})
```

## Install (lazy.nvim)

```lua
{
  "AuroBreeze/quick-c",
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
    "QuickCMake", "QuickCMakeRun", "QuickCCompileDB",
    "QuickCCompileDBGen", "QuickCCompileDBUse", "QuickCQuickfix",
  },
  config = function()
    require("quick-c").setup()
  end,
}
```

## Install (packer.nvim)

```lua
use({
  'AuroBreeze/quick-c',
  config = function()
    require('quick-c').setup()
  end,
})
```

## Telescope preview notes

- Both directory and target pickers include a Makefile preview.
- In the target picker, the preview is fixed to the Makefile in the selected directory (no live refresh for performance).
- Large files are truncated by bytes/lines; controlled by:
  - `make.telescope.preview`
  - `make.telescope.max_preview_bytes`
  - `make.telescope.max_preview_lines`
  - `make.telescope.set_filetype`

## Terminal selection behavior

- After selecting a Make target, commands can be sent to an opened built-in terminal, or follow the default strategy (BetterTerm first, fallback to native terminal).
- Configure via `make.telescope.choose_terminal`:
  - `auto`: if a terminal is open, show selector; otherwise use default strategy
  - `always`: always show selector
  - `never`: always use default strategy

## Makefile search notes

- If `make.cwd` is not set, the plugin searches from the current file's directory:
  - Up to `search.up` levels upward (default 2)
  - For each level, recursively downward up to `search.down` (default 3)
  - The first directory containing `Makefile`/`makefile`/`GNUmakefile` is used as cwd
  - Directories in `ignore_dirs` are skipped (default: `.git`, `node_modules`, `.cache`)

## Architecture

- Modules
  - `lua/quick-c/init.lua`: wiring, commands, keymaps
  - `lua/quick-c/config.lua`: defaults
  - `lua/quick-c/util.lua`: utils (platform/path/messages)
  - `lua/quick-c/terminal.lua`: BetterTerm/native terminal
  - `lua/quick-c/make_search.lua`: async Makefile search & directory select
  - `lua/quick-c/make.lua`: choose make/parse targets/run in cwd
  - `lua/quick-c/telescope.lua`: Telescope interactions (make targets, custom args, source picker)
  - `lua/quick-c/build.lua`: build/run/debug
  - `lua/quick-c/cc.lua`: compile_commands.json
  - `lua/quick-c/keys.lua`: key injection

## Windows notes

- On PowerShell, runs as `& 'path\\to\\exe'`; on other shells, runs as `"path\\to\\exe"`.
- For MSVC `cl`, run Neovim from a Developer Command Prompt or with VS env vars initialized.

## Debugging

- Requires `nvim-dap` and `codelldb`.
- `:QuickCDebug` launches with codelldb; `program` points to the last build output.

## Troubleshooting

- Compiler not found: ensure `gcc/g++`, `clang/clang++`, or `cl` are in PATH.
- Build failed without output: check `:messages` or the terminal panel for warnings/errors.
- Cannot send to terminal: if BetterTerm fails, the plugin falls back to the native terminal automatically.
- Cannot run executable: build first with `:QuickCBuild`; also check output directory and `.exe` on Windows.
- No make targets found: ensure a Makefile exists and `make -qp` works in that directory; on Windows try `mingw32-make`.


## Release notes

See [Release.md](Release.md)
