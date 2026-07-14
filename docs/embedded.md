# Embedded (ESP32 / STM32 / PlatformIO)

Embedded support is a **profile inside C++**, not a language. Open a file in a
detected project and the `<leader>l` verbs (`lb`/`lr`/`lR`/`le`) swap to the right
backend; a `<leader>lf*` **+Flash/Device** sub-group appears; clangd is pointed at
the cross-compiler. A host C++ buffer is unaffected. Design: `~/SPEC-embedded.md`.

## Detection

Walked up from the buffer's directory (first match wins, in order):

| Profile | Markers |
|---------|---------|
| `esp_idf` | `sdkconfig` / `sdkconfig.defaults`, or a CMakeLists with `include($ENV{IDF_PATH}` / `idf_component_register` |
| `platformio` | `platformio.ini` |
| `stm32` | a `.ioc`, or `CMakePresets.json` + an `*arm-none-eabi*.cmake` toolchain file, or a CMakeLists setting `CMAKE_TOOLCHAIN_FILE` to arm-none-eabi |

## Prerequisites

Most of the toolchain is in the Arch repos:

```bash
sudo pacman -S --needed \
  arm-none-eabi-gcc arm-none-eabi-newlib arm-none-eabi-gdb arm-none-eabi-binutils \
  openocd stlink dfu-util tio python-pyserial \
  nodejs npm uv cmake ninja git
```

Not in the repos:

- **ESP-IDF** — clone + install, then source before launching nvim (recommended):
  ```bash
  git clone -b v5.5 --recursive https://github.com/espressif/esp-idf ~/esp/esp-idf
  ~/esp/esp-idf/install.sh all
  source ~/esp/esp-idf/export.sh          # exports IDF_PATH + IDF_PYTHON_ENV_PATH
  ```
  If `$IDF_PATH`/`$IDF_PYTHON_ENV_PATH` are already exported, the config uses them
  directly (preferred). Otherwise it looks for an **EIM** activation script
  (`~/.espressif/activate_idf_*.sh`, ESP-IDF v6+) and finally `$IDF_PATH/export.sh`
  (v5.x). Do not assume `export.sh` exists — v6.0 replaced it with EIM.
- **PlatformIO** — `uv tool install platformio` (or `pipx install platformio`).
- **cortex-debug adapter** (STM32 debug) — provided by the
  `nvim-dap-cortex-debug` plugin; needs Node. A missing Node degrades to "STM32
  debug unavailable", not a broken `<leader>d`.

### Serial permissions (Arch)

Flashing needs your user in the `uucp` group, else `/dev/ttyUSB0` fails with
EACCES:

```bash
sudo usermod -aG uucp $USER   # then log out and back in
```

The flash notification will call this out explicitly if it sees a permissions
failure. It will not try to fix it for you.

## clangd

This is the part that makes or breaks the experience. Two strategies:

### ESP-IDF / Xtensa

Stock clangd has **no Xtensa backend** — ESP32/S2/S3 need Espressif's LLVM fork:

```bash
$IDF_PATH/tools/idf_tools.py install esp-clang
# -> ~/.espressif/tools/esp-clang/<ver>/esp-clang/bin/clangd  (auto-discovered)
```

RISC-V parts (C3/C6/H2/…) use **stock** clangd; only the binary switches for
Xtensa.

**(A) Preferred — a clang-clean index build dir.** The config points clangd at
`build.clang/compile_commands.json`, generated configure-only (fast):

```bash
idf.py -B build.clang -D IDF_TOOLCHAIN=clang reconfigure
```

This runs automatically on target change (`lfb`) and on `sdkconfig` save (a
`menuconfig` can add/remove components from the include path), and manually via
`:EspReindex`. You cannot emit a GCC build and a clang compile DB in the same
build dir — hence the second dir. Add `build.clang/` to your project `.gitignore`.

**(B) Fallback — `.clangd` flag surgery.** If the clang reconfigure fails (IDF's
clang support is not CI-gated), point clangd at the GCC `build/compile_commands.json`
and drop a project-local `.clangd` that strips the GCC-only flags:

```yaml
CompileFlags:
  Add:
    - --query-driver=<...>/xtensa-esp-elf/bin/xtensa-esp-elf-gcc
    - -ferror-limit=0
  Remove:
    - -fno-tree-switch-conversion
    - -mtext-section-literals
    - -mlongcalls
    - -mlong-calls
    - -fstrict-volatile-bitfields
    - -fno-shrink-wrap
    - -march=rv32imc_zicsr_zifencei
```

The config never overwrites an existing `.clangd`.

### STM32 / PlatformIO / arm-none-eabi

clangd resolves the `arm-none-eabi` triple to its BareMetal driver and loses
system includes. Fixed with `--query-driver` — **it must point at
`arm-none-eabi-g++`, not `-gcc`**, or every C++ standard header reds out (C stays
clean, which makes it a maddening bug). The config passes both, plus a CubeCLT
glob (`/opt/st/**/arm-none-eabi*`). PlatformIO's toolchain is found by globbing
`~/.platformio/packages/toolchain-*`.

## On-chip debug (`<leader>d`, no new keys)

- **STM32** — cortex-debug (`servertype=openocd`, `arm-none-eabi-gdb`). SVD
  (`*.svd` at root) and RTT are wired when available. If the Node dependency is
  unacceptable, **`probe-rs dap-server`** speaks DAP natively (no Node, ST-LINK /
  J-Link / CMSIS-DAP, own chip DB) — swap it in as the adapter.
- **ESP32** — `lfo` starts `idf.py openocd` (GDB server on :3333); `dc` attaches a
  gdb DAP session (`xtensa-esp-elf-gdb` / `riscv32-esp-elf-gdb`). USB-JTAG boards
  (S3/C3/C6) need no probe; a classic ESP32 needs an ESP-PROG. cortex-debug is
  Cortex-M only and does **not** apply to Xtensa.

## New projects — `<leader>op`

Pick a generator (C++/ESP-IDF/Python/Bash), name it, accept the parent dir; it
scaffolds, `:tcd`s into the new root, and opens the entry file so detection fires
naturally. Adding a project type is one entry in `lua/config/scaffold.lua` — never
a new keybind.
