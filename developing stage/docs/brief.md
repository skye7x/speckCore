# SpeckCore — Complete Build Tutorial
## From Linus Torvalds' Kernel to a Bootable ISO, From Scratch

**Target:** A beginner who has never built a Linux distro before.
**Result:** A bootable SpeckCore ISO under 80 MB with a modern Wayland desktop.
**Host OS required:** Ubuntu 22.04 or 24.04 (64-bit). Everything runs on your main machine or in a VM.

---

> **Read this before starting:**
> This tutorial has 12 phases. Do not skip phases. Do not run commands from
> phase 5 if you have not finished phase 4. Each phase produces something
> you can test before moving on. If a phase fails, fix it before continuing.
> Every single command in this tutorial is meant to be copy-pasted exactly.

---

## Phase 0 — Host machine setup

You need a Linux machine to build on. If you are on Windows, install
Ubuntu 24.04 in VirtualBox or WSL2. Give it at least:
- 4 CPU cores
- 8 GB RAM
- 60 GB disk space

All commands in this tutorial run as a regular user unless explicitly told
to use `sudo`. Never build as root.

### 0.1 — Install all build dependencies at once

Open a terminal and run this entire block. It will take 5–15 minutes
depending on your internet speed. Do not interrupt it.

```bash
sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y \
  build-essential \
  gcc \
  g++ \
  make \
  cmake \
  ninja-build \
  meson \
  pkg-config \
  bison \
  flex \
  bc \
  libssl-dev \
  libelf-dev \
  libncurses-dev \
  libncursesw5-dev \
  python3 \
  python3-pip \
  python3-setuptools \
  git \
  wget \
  curl \
  xz-utils \
  zstd \
  squashfs-tools \
  cpio \
  rsync \
  xorriso \
  grub-pc-bin \
  grub-efi-amd64-bin \
  dosfstools \
  mtools \
  qemu-system-x86 \
  qemu-utils \
  ovmf \
  nasm \
  gawk \
  texinfo \
  unzip \
  libgmp-dev \
  libmpfr-dev \
  libmpc-dev \
  autoconf \
  automake \
  libtool \
  gettext \
  libffi-dev \
  libexpat1-dev \
  libpng-dev \
  libjpeg-dev \
  libfreetype-dev \
  libfontconfig1-dev \
  libpixman-1-dev \
  libinput-dev \
  libxkbcommon-dev \
  libgbm-dev \
  libdrm-dev \
  libegl-dev \
  libgl-dev \
  libgles-dev \
  libvulkan-dev \
  libwayland-dev \
  wayland-protocols \
  libseat-dev \
  libpcre2-dev \
  libdbus-1-dev \
  libudev-dev \
  libsystemd-dev \
  libpam0g-dev \
  libcap-dev \
  libcairo2-dev \
  libpango1.0-dev \
  libgdk-pixbuf-2.0-dev \
  libxml2-dev \
  libevdev-dev \
  libmtdev-dev \
  liblzma-dev \
  libzstd-dev \
  lzma \
  file \
  symlinks \
  strace \
  patchelf
```

Wait for this to complete fully before moving on.

### 0.2 — Create the SpeckCore workspace

Every file SpeckCore produces lives inside this directory tree.
Run this block to create the full structure:

```bash
mkdir -p ~/speckcore
mkdir -p ~/speckcore/sources          # downloaded source tarballs and git repos
mkdir -p ~/speckcore/build            # all compilation happens here
mkdir -p ~/speckcore/toolchain        # the musl cross-compiler will live here
mkdir -p ~/speckcore/sysroot          # staged root filesystem (what becomes initramfs)
mkdir -p ~/speckcore/initramfs        # the actual initramfs directory tree
mkdir -p ~/speckcore/iso              # what gets burned to ISO
mkdir -p ~/speckcore/output           # final ISO and artifacts
mkdir -p ~/speckcore/scripts          # helper scripts we write
mkdir -p ~/speckcore/speck-packages   # .speck extension packages
```

Set a permanent environment variable so every command knows where
SpeckCore lives. Add these lines to the end of `~/.bashrc`:

```bash
cat >> ~/.bashrc << 'EOF'

# SpeckCore build environment
export SPECKROOT="$HOME/speckcore"
export SPECK_TOOLCHAIN="$SPECKROOT/toolchain"
export SPECK_SYSROOT="$SPECKROOT/sysroot"
export SPECK_INITRAMFS="$SPECKROOT/initramfs"
export SPECK_ISO="$SPECKROOT/iso"
export SPECK_OUTPUT="$SPECKROOT/output"
export SPECK_SOURCES="$SPECKROOT/sources"
export SPECK_BUILD="$SPECKROOT/build"

# Cross-compilation target
export SPECK_TARGET="x86_64-linux-musl"
export SPECK_ARCH="x86_64"

# Add toolchain to PATH
export PATH="$SPECK_TOOLCHAIN/bin:$PATH"
EOF
```

Now reload it:

```bash
source ~/.bashrc
```

Verify the variable is set:

```bash
echo $SPECKROOT
# should print: /home/YOURNAME/speckcore
```

---

## Phase 1 — Build the musl cross-compilation toolchain

This is the most important phase. The cross-toolchain is a special
version of GCC that runs on your Ubuntu machine but produces binaries
for SpeckCore using musl libc instead of glibc. Every single piece of
SpeckCore software gets compiled with this toolchain.

**Why musl?** It produces smaller binaries. A statically linked BusyBox
against musl is 200 KB smaller than against glibc. Musl also starts
faster and has a cleaner codebase.

### 1.1 — Download musl-cross-make

`musl-cross-make` is a small build system that automates building
GCC + musl + binutils as a complete cross-compiler in one command.

```bash
cd $SPECK_SOURCES
git clone https://github.com/richfelker/musl-cross-make.git
cd musl-cross-make
```

### 1.2 — Configure it

Create the config file that tells musl-cross-make what to build:

```bash
cat > config.mak << 'EOF'
MUSL_VER = 1.2.5
EOF
```

### 1.3 — Build the toolchain

This step takes 20–40 minutes. It compiles GCC, musl, and binutils
from source. Go make coffee.

```bash
make -j$(nproc) 2>&1 | tee $SPECK_BUILD/toolchain-build.log
make install
```

If it fails, check the last 50 lines of the log:
```bash
tail -50 $SPECK_BUILD/toolchain-build.log
```

### 1.4 — Verify the toolchain works

```bash
# Check that the cross-compiler exists
which x86_64-linux-musl-gcc
# should print: /home/YOURNAME/speckcore/toolchain/bin/x86_64-linux-musl-gcc
if not add to path:

export PATH=$HOME/speckcore/toolchain/bin:$PATH
# Print its version
x86_64-linux-musl-gcc --version
# should print something like: x86_64-linux-musl-gcc (GCC) 13.2.0

# Test it: compile a tiny hello world
cat > /tmp/hello.c << 'EOF'
#include <stdio.h>
int main() { puts("SpeckCore toolchain works!"); return 0; }
EOF

x86_64-linux-musl-gcc -static -o /tmp/hello-musl /tmp/hello.c
file /tmp/hello-musl
# should say: ELF 64-bit, statically linked, stripped

/tmp/hello-musl
# should print: SpeckCore toolchain works!
```

If all three checks pass, your toolchain is working. Move to Phase 2.

---

## Phase 2 — Build the Linux kernel from Linus Torvalds' tree

You are building the actual Linux kernel. Not a distro's patched version —
Linus Torvalds' own repository, the master source of Linux itself.

### 2.1 — Clone the kernel

This downloads the full Linux kernel source. It is ~4 GB. This will
take a while depending on your connection.

```bash
cd $SPECK_SOURCES
git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
# --depth=1 means we get only the latest commit, not all history
# This makes the download much smaller (~250 MB vs 4 GB)

cd linux
```

Check what version you got:

```bash
make kernelversion
# will print something like: 6.10.0
```

### 2.2 — Understand kernel configuration

The kernel has thousands of configuration options. Running `make defconfig`
gives you a generic configuration with hundreds of drivers you do not need.
Instead you will start from absolute zero (`make allnoconfig`) and enable
only what SpeckCore requires.

Here is what SpeckCore's kernel needs:

| Feature | Why |
|---|---|
| x86_64 architecture | obvious |
| 64-bit kernel | obvious |
| ELF binary support | to run programs |
| tmpfs | RAM-based filesystem |
| initramfs | the boot mechanism |
| squashfs | to mount .speck packages |
| ext4 | optional disk persistence |
| overlayfs | to layer filesystems |
| DRM/KMS | GPU output for Wayland |
| virtio-gpu | GPU in QEMU |
| USB HID | keyboard and mouse |
| virtio-net | networking in QEMU |
| TCP/IPv4 | networking |
| Unix sockets | IPC between programs |
| Epoll | needed by Wayland |
| Loop devices | to mount .speck squashfs files |
| /proc and /sys | standard Linux virtual filesystems |

### 2.3 — Start from zero and enable exactly what you need

This creates the configuration. Run these commands exactly:

```bash
cd $SPECK_SOURCES/linux

# Start from absolute zero — every option disabled
make ARCH=x86_64 allnoconfig

# Now use the script helper to enable specific options.
# Each 'scripts/config' call sets one kernel config option.

# --- Architecture ---
./scripts/config --enable CONFIG_64BIT
./scripts/config --enable CONFIG_X86_64
./scripts/config --enable CONFIG_SMP
./scripts/config --set-val CONFIG_NR_CPUS 8

# --- Kernel base ---
./scripts/config --enable CONFIG_MULTIUSER
./scripts/config --enable CONFIG_SYSFS
./scripts/config --enable CONFIG_PROC_FS
./scripts/config --enable CONFIG_PROC_SYSCTL
./scripts/config --enable CONFIG_SYSCTL
./scripts/config --enable CONFIG_PRINTK
./scripts/config --enable CONFIG_BUG
./scripts/config --enable CONFIG_ELF_CORE
./scripts/config --enable CONFIG_BINFMT_ELF
./scripts/config --enable CONFIG_BINFMT_SCRIPT

# --- Memory management ---
./scripts/config --enable CONFIG_MMU
./scripts/config --enable CONFIG_FUTEX
./scripts/config --enable CONFIG_EPOLL
./scripts/config --enable CONFIG_SIGNALFD
./scripts/config --enable CONFIG_TIMERFD
./scripts/config --enable CONFIG_EVENTFD
./scripts/config --enable CONFIG_SHMEM
./scripts/config --enable CONFIG_AIO
./scripts/config --enable CONFIG_ADVISE_SYSCALLS
./scripts/config --enable CONFIG_MEMBARRIER

# --- initramfs (THIS IS HOW WE BOOT) ---
./scripts/config --enable CONFIG_BLK_DEV_INITRD
./scripts/config --enable CONFIG_INITRAMFS_SOURCE
./scripts/config --enable CONFIG_RD_ZSTD
./scripts/config --enable CONFIG_RD_GZIP

# --- Filesystems ---
./scripts/config --enable CONFIG_TMPFS
./scripts/config --enable CONFIG_TMPFS_XATTR
./scripts/config --enable CONFIG_DEVTMPFS
./scripts/config --enable CONFIG_DEVTMPFS_MOUNT
./scripts/config --enable CONFIG_SQUASHFS
./scripts/config --enable CONFIG_SQUASHFS_ZSTD
./scripts/config --enable CONFIG_SQUASHFS_XZ
./scripts/config --enable CONFIG_OVERLAY_FS
./scripts/config --enable CONFIG_EXT4_FS
./scripts/config --enable CONFIG_FAT_FS
./scripts/config --enable CONFIG_VFAT_FS
./scripts/config --enable CONFIG_ISO9660_FS
./scripts/config --enable CONFIG_JOLIET
./scripts/config --enable CONFIG_INOTIFY_USER
./scripts/config --enable CONFIG_FUSE_FS

# --- Loop devices (for .speck mounts) ---
./scripts/config --enable CONFIG_BLK_DEV_LOOP
./scripts/config --set-val CONFIG_BLK_DEV_LOOP_MIN_COUNT 64

# --- Block devices ---
./scripts/config --enable CONFIG_BLOCK
./scripts/config --enable CONFIG_BLK_DEV
./scripts/config --enable CONFIG_BLK_DEV_RAM
./scripts/config --set-val CONFIG_BLK_DEV_RAM_COUNT 16
./scripts/config --set-val CONFIG_BLK_DEV_RAM_SIZE 65536

# --- Virtual block (for QEMU) ---
./scripts/config --enable CONFIG_VIRTIO
./scripts/config --enable CONFIG_VIRTIO_PCI
./scripts/config --enable CONFIG_VIRTIO_BLK
./scripts/config --enable CONFIG_VIRTIO_NET
./scripts/config --enable CONFIG_VIRTIO_INPUT
./scripts/config --enable CONFIG_VIRTIO_BALLOON

# --- PCI bus ---
./scripts/config --enable CONFIG_PCI
./scripts/config --enable CONFIG_PCI_MSI
./scripts/config --enable CONFIG_PCIEPORTBUS

# --- Serial console (important for debugging) ---
./scripts/config --enable CONFIG_SERIAL_8250
./scripts/config --enable CONFIG_SERIAL_8250_CONSOLE
./scripts/config --enable CONFIG_VT
./scripts/config --enable CONFIG_CONSOLE_TRANSLATIONS
./scripts/config --enable CONFIG_VT_CONSOLE
./scripts/config --enable CONFIG_UNIX98_PTYS

# --- Networking ---
./scripts/config --enable CONFIG_NET
./scripts/config --enable CONFIG_INET
./scripts/config --enable CONFIG_IPV6
./scripts/config --enable CONFIG_UNIX
./scripts/config --enable CONFIG_PACKET
./scripts/config --enable CONFIG_NETFILTER
./scripts/config --enable CONFIG_NET_NS
./scripts/config --enable CONFIG_NETWORK_FILESYSTEMS

# --- USB input ---
./scripts/config --enable CONFIG_USB_SUPPORT
./scripts/config --enable CONFIG_USB
./scripts/config --enable CONFIG_USB_XHCI_HCD
./scripts/config --enable CONFIG_USB_EHCI_HCD
./scripts/config --enable CONFIG_USB_UHCI_HCD
./scripts/config --enable CONFIG_HID
./scripts/config --enable CONFIG_HID_GENERIC
./scripts/config --enable CONFIG_USB_HID
./scripts/config --enable CONFIG_INPUT
./scripts/config --enable CONFIG_INPUT_KEYBOARD
./scripts/config --enable CONFIG_INPUT_MOUSE
./scripts/config --enable CONFIG_KEYBOARD_ATKBD
./scripts/config --enable CONFIG_MOUSE_PS2
./scripts/config --enable CONFIG_SERIO
./scripts/config --enable CONFIG_SERIO_I8042

# --- Graphics: DRM/KMS (needed for Wayland) ---
./scripts/config --enable CONFIG_DRM
./scripts/config --enable CONFIG_DRM_KMS_HELPER
./scripts/config --enable CONFIG_DRM_FBDEV_EMULATION
./scripts/config --enable CONFIG_DRM_VIRTIO_GPU
./scripts/config --enable CONFIG_DRM_BOCHS
./scripts/config --enable CONFIG_DRM_SIMPLE_BRIDGE
./scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE
./scripts/config --enable CONFIG_FB

# --- Clock and timers ---
./scripts/config --enable CONFIG_ACPI
./scripts/config --enable CONFIG_PCI_MMCONFIG
./scripts/config --enable CONFIG_HZ_250
./scripts/config --enable CONFIG_RTC_CLASS
./scripts/config --enable CONFIG_RTC_DRV_CMOS

# --- Security / capabilities ---
./scripts/config --enable CONFIG_MULTIUSER
./scripts/config --enable CONFIG_SYSVIPC
./scripts/config --enable CONFIG_POSIX_MQUEUE
./scripts/config --enable CONFIG_NAMESPACES
./scripts/config --enable CONFIG_SECCOMP

# --- Compression (for initramfs) ---
./scripts/config --enable CONFIG_ZSTD_COMPRESS
./scripts/config --enable CONFIG_ZSTD_DECOMPRESS
./scripts/config --enable CONFIG_LZ4_COMPRESS
./scripts/config --enable CONFIG_LZ4_DECOMPRESS

# --- Disable debug (makes kernel smaller) ---
./scripts/config --disable CONFIG_DEBUG_KERNEL
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_KGDB
./scripts/config --disable CONFIG_KALLSYMS

# Regenerate dependencies (important — do this after all scripts/config calls)
make ARCH=x86_64 olddefconfig
```

### 2.4 — Compile the kernel

This takes 10–30 minutes depending on your machine.
The `-j$(nproc)` flag uses all your CPU cores.

before make sure u: ```sudo pacman -S bc```

```bash
cd $SPECK_SOURCES/linux

make ARCH=x86_64 \
     CROSS_COMPILE=x86_64-linux-musl- \
     -j$(nproc) \
     bzImage \
     2>&1 | tee $SPECK_BUILD/kernel-build.log
```

Watch the output. If it says `Kernel: arch/x86/boot/bzImage is ready` at
the end, it succeeded.

### 2.5 — Copy the kernel to the ISO staging directory

```bash
mkdir -p $SPECK_ISO/boot
cp $SPECK_SOURCES/linux/arch/x86/boot/bzImage $SPECK_ISO/boot/vmlinuz

# Verify the size
ls -lh $SPECK_ISO/boot/vmlinuz
# Should be somewhere between 3 MB and 8 MB depending on config
```

### 2.6 — Test the kernel boots (without initramfs yet)

```bash
qemu-system-x86_64 \
  -kernel $SPECK_ISO/boot/vmlinuz \
  -append "console=ttyS0 panic=1" \
  -nographic \
  -m 256M \
  -no-reboot \
  2>&1 | head -30
```

You will see the kernel boot and then panic with "No working init found"
or similar. That is correct — you have not built the initramfs yet.
The important thing is the kernel starts and prints boot messages.
Press Ctrl+C to quit QEMU.

it can look like:
```
Linux version 7.2.0-rc1 (bartek@cachyos) (x86_64-linux-musl-gcc (GCC) 9.4.0, GNU ld (GNU Binutils) 2.44) #1 SMP PREEMPT Sun Jun 28 23:19:25 CEST 2026
Command line: console=ttyS0 panic=1
BIOS-provided physical RAM map:
BIOS-e820: [mem 0x0000000000000000-0x000000000009fbff]  System RAM
BIOS-e820: [mem 0x000000000009fc00-0x000000000009ffff]  device reserved
BIOS-e820: [gap 0x00000000000a0000-0x00000000000effff]
BIOS-e820: [mem 0x00000000000f0000-0x00000000000fffff]  device reserved
BIOS-e820: [mem 0x0000000000100000-0x000000000ffdffff]  System RAM
BIOS-e820: [mem 0x000000000ffe0000-0x000000000fffffff]  device reserved
BIOS-e820: [gap 0x0000000010000000-0x00000000fffbffff]
BIOS-e820: [mem 0x00000000fffc0000-0x00000000ffffffff]  device reserved
BIOS-e820: [gap 0x0000000100000000-0x000000fcffffffff]
BIOS-e820: [mem 0x000000fd00000000-0x000000ffffffffff]  device reserved
NX (Execute Disable) protection: active
APIC: Static calls initialized
DMI: SMBIOS 2.8 present.
DMI: QEMU Standard PC (i440FX + PIIX, 1996), BIOS Arch Linux 1.17.0-2-2 04/01/2014
DMI: Memory slots populated: 1/1
tsc: Fast TSC calibration using PIT
tsc: Detected 2111.877 MHz processor
last_pfn = 0xffe0 max_arch_pfn = 0x400000000
MTRR map: 4 entries (3 fixed + 1 variable; max 19), built from 8 variable MTRRs
```

---

## Phase 3 — Build BusyBox (the entire userland)

BusyBox is a single binary that contains ~300 Unix tools. It replaces
`ls`, `cat`, `cp`, `sh`, `mount`, `grep`, `awk`, `wget`, and hundreds
more. The entire SpeckCore userland (outside the GUI) is this one file.

### 3.1 — Download BusyBox source

```bash
cd $SPECK_SOURCES

# Download the latest stable release
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar -xjf busybox-1.36.1.tar.bz2
cd busybox-1.36.1
```

### 3.2 — Configure BusyBox

Start from the default config and then customize:

```bash
# Start with a base config
make ARCH=x86_64 defconfig
```

Now customize it for SpeckCore.
Open the interactive configurator:

b4 make sure u have:
```
sudo pacman -S ncurses
```
```bash
make ARCH=x86_64 menuconfig
```

In the menuconfig interface, navigate with arrow keys, press Space to
toggle, Enter to enter a submenu, and Escape to go back.

Make these changes:

**Settings > Build Options:**
- Set "Cross compiler prefix" to: `x86_64-linux-musl-`
- Enable "Build static binary (no shared libs)"
- Enable "Build with Large File Support"

**Settings > General Configuration:**
- Enable everything under Networking utilities you need
- Keep init-related things enabled

Press Escape until asked to save. Say Yes.

Alternatively, if you want to skip the interactive step, run these
`sed` commands to configure it non-interactively:

```bash
# Set the cross-compiler
sed -i 's|.*CONFIG_CROSS_COMPILER_PREFIX.*|CONFIG_CROSS_COMPILER_PREFIX="x86_64-linux-musl-"|' .config

# Enable static build (most important for musl)
sed -i 's|.*CONFIG_STATIC.*|CONFIG_STATIC=y|' .config

# Enable extra utilities SpeckCore needs
cat >> .config << 'EOF'
CONFIG_STATIC=y
CONFIG_CROSS_COMPILER_PREFIX="x86_64-linux-musl-"
CONFIG_EXTRA_CFLAGS="-Os -ffunction-sections -fdata-sections"
CONFIG_EXTRA_LDFLAGS="-Wl,--gc-sections"
CONFIG_FEATURE_2_4_MODULES=y
CONFIG_MOUNT=y
CONFIG_LOSETUP=y
CONFIG_FEATURE_LOSETUP_MAX_LOOP=64
CONFIG_WGET=y
CONFIG_FEATURE_WGET_HTTPS=y
CONFIG_FEATURE_WGET_STATUSBAR=y
CONFIG_IFCONFIG=y
CONFIG_IP=y
CONFIG_UDHCPC=y
CONFIG_UDHCPD=y
CONFIG_PING=y
CONFIG_SH_IS_ASH=y
CONFIG_BASH_IS_NONE=y
CONFIG_ASH=y
CONFIG_ASH_OPTIMIZE_FOR_SIZE=y
CONFIG_VI=y
CONFIG_AWK=y
CONFIG_SED=y
CONFIG_GREP=y
CONFIG_FIND=y
CONFIG_XARGS=y
CONFIG_TAR=y
CONFIG_GZIP=y
CONFIG_ZCAT=y
CONFIG_UNZIP=y
CONFIG_INSMOD=y
CONFIG_RMMOD=y
CONFIG_LSMOD=y
CONFIG_DEPMOD=y
CONFIG_SYSCTL=y
CONFIG_DMESG=y
CONFIG_FREE=y
CONFIG_TOP=y
CONFIG_PS=y
CONFIG_KILL=y
CONFIG_KILLALL=y
CONFIG_MDEV=y
CONFIG_FEATURE_MDEV_CONF=y
CONFIG_FEATURE_MDEV_EXEC=y
CONFIG_FEATURE_MDEV_LOAD_FIRMWARE=y
CONFIG_MDEV_DAEMON=y
EOF

# Regenerate
make ARCH=x86_64 oldconfig
```

### 3.3 — Compile BusyBox

```bash
cd $SPECK_SOURCES/busybox-1.36.1

make ARCH=x86_64 \
     CROSS_COMPILE=x86_64-linux-musl- \
     -j$(nproc) \
     2>&1 | tee $SPECK_BUILD/busybox-build.log

# Check that it built
ls -lh busybox
# Should be around 800 KB to 1.5 MB
file busybox
# Should say: ELF 64-bit, statically linked
```

### 3.4 — Install BusyBox into the initramfs

IF IT NOT WORKS THEN CHECK PATHS TOOLCHAIN AND BIN!
```bash
# Install into the staging sysroot
make ARCH=x86_64 \
     CROSS_COMPILE=x86_64-linux-musl- \
     CONFIG_PREFIX=$SPECK_INITRAMFS \
     install

# BusyBox creates a symlink farm — hundreds of symlinks all pointing to
# the main busybox binary. Verify it:
ls $SPECK_INITRAMFS/bin/ | head -20
# Should show: ash, cat, cp, date, echo, ls, mkdir, mount, mv, sh, etc.

ls -lh $SPECK_INITRAMFS/bin/busybox
# Should be the main binary, around 800 KB-1.5 MB
```

---

## Phase 4 — Build the initramfs skeleton

The initramfs is a small filesystem that lives entirely in RAM.
The kernel extracts it on boot and runs `/init` from it.
Everything SpeckCore needs to boot lives here.

### 4.1 — Create the directory structure

```bash
cd $SPECK_INITRAMFS

# These directories must exist for Linux to function
mkdir -p proc sys dev tmp run mnt opt home root etc
mkdir -p usr/bin usr/sbin usr/lib usr/lib64 usr/share
mkdir -p lib lib64 sbin
mkdir -p opt/specks opt/mnt opt/persist

# Create device nodes (needed before udev starts)
# These are not real devices, just the device node files
sudo mknod -m 666 dev/null    c 1 3
sudo mknod -m 666 dev/zero    c 1 5
sudo mknod -m 666 dev/random  c 1 8
sudo mknod -m 666 dev/urandom c 1 9
sudo mknod -m 600 dev/console c 5 1
sudo mknod -m 666 dev/tty     c 5 0
sudo mknod -m 666 dev/tty0    c 4 0
sudo mknod -m 666 dev/tty1    c 4 1
sudo mknod -m 660 dev/loop0   b 7 0
sudo mknod -m 660 dev/loop1   b 7 1
sudo mknod -m 660 dev/loop2   b 7 2
sudo mknod -m 660 dev/loop3   b 7 3
sudo mknod -m 660 dev/loop4   b 7 4
sudo mknod -m 660 dev/loop5   b 7 5
sudo mknod -m 660 dev/loop6   b 7 6
sudo mknod -m 660 dev/loop7   b 7 7
```

### 4.2 — Write the /etc/passwd and /etc/group files

These are needed for login and correct file ownership:

```bash
cat > $SPECK_INITRAMFS/etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
speck:x:1000:1000:SpeckCore User:/home/speck:/bin/sh
nobody:x:65534:65534:nobody:/:/bin/false
EOF

cat > $SPECK_INITRAMFS/etc/group << 'EOF'
root:x:0:
speck:x:1000:
video:x:44:speck
input:x:105:speck
audio:x:29:speck
tty:x:5:speck
disk:x:6:speck
nobody:x:65534:
EOF

cat > $SPECK_INITRAMFS/etc/shadow << 'EOF'
root::0:0:99999:7:::
speck::0:0:99999:7:::
nobody:!:0:0:99999:7:::
EOF
chmod 640 $SPECK_INITRAMFS/etc/shadow

cat > $SPECK_INITRAMFS/etc/hostname << 'EOF'
speckcore
EOF

cat > $SPECK_INITRAMFS/etc/hosts << 'EOF'
127.0.0.1   localhost
127.0.0.1   speckcore
::1         localhost
EOF

cat > $SPECK_INITRAMFS/etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
```

### 4.3 — Write the /etc/profile and shell environment

```bash
cat > $SPECK_INITRAMFS/etc/profile << 'EOF'
# SpeckCore shell profile

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/bin"
export HOME="/home/speck"
export TERM="xterm-256color"
export LANG="C.UTF-8"
export LC_ALL="C"

# SpeckCore extensions path
export SPECK_MOUNT="/opt/mnt"
export SPECK_PKGS="/opt/specks"

# Source user profile if it exists
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi
EOF

mkdir -p $SPECK_INITRAMFS/home/speck
cat > $SPECK_INITRAMFS/home/speck/.profile << 'EOF'
# SpeckCore user profile
export PS1="\[\e[1;35m\]speck\[\e[0m\]@\[\e[1;34m\]speckcore\[\e[0m\]:\[\e[1;32m\]\w\[\e[0m\]\$ "
EOF
```

### 4.4 — Write the /init script

This is the most critical file. The kernel runs this as PID 1 on boot.
It sets up the system, then starts the Wayland session.

```bash
cat > $SPECK_INITRAMFS/init << 'INITEOF'
#!/bin/sh
# SpeckCore /init — PID 1 boot script
# This file is the very first program the kernel runs.

# ============================================================
# STEP 1: Mount essential virtual filesystems
# ============================================================
mount -t proc     proc     /proc
mount -t sysfs    sysfs    /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs    tmpfs    /dev/pts -o mode=0620,gid=5
mount -t tmpfs    tmpfs    /run  -o mode=0755
mount -t tmpfs    tmpfs    /tmp  -o mode=1777

# Create /dev/pts directory
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts -o mode=0620,gid=5

# ============================================================
# STEP 2: Set up logging
# ============================================================
# Redirect kernel messages to console only
echo 3 > /proc/sys/kernel/printk 2>/dev/null || true

# ============================================================
# STEP 3: Start device manager (mdev)
# ============================================================
# mdev is BusyBox's lightweight udev replacement
# It listens for kernel uevents and creates /dev entries
echo "" > /proc/sys/kernel/hotplug
mdev -s 2>/dev/null
echo /sbin/mdev > /proc/sys/kernel/hotplug

# ============================================================
# STEP 4: Set up loopback network
# ============================================================
ip link set lo up 2>/dev/null || ifconfig lo up 2>/dev/null || true

# ============================================================
# STEP 5: Set hostname
# ============================================================
hostname speckcore

# ============================================================
# STEP 6: Check for persistent storage
# ============================================================
# SpeckCore can optionally save data to a disk partition
# labeled "SPECKLABEL". If found, mount it and replay packages.
PERSIST_DEVICE=""
for dev in /dev/sd* /dev/vd* /dev/nvme*; do
    if [ -b "$dev" ] 2>/dev/null; then
        label=$(blkid -s LABEL -o value "$dev" 2>/dev/null)
        if [ "$label" = "SPECKLABEL" ]; then
            PERSIST_DEVICE="$dev"
            break
        fi
    fi
done

if [ -n "$PERSIST_DEVICE" ]; then
    mkdir -p /opt/persist
    mount "$PERSIST_DEVICE" /opt/persist -o rw
    echo "SpeckCore: persistence found on $PERSIST_DEVICE"
    
    # Replay installed packages from the persistent list
    if [ -f /opt/persist/installed.list ]; then
        while IFS= read -r pkg; do
            if [ -f "/opt/persist/specks/$pkg" ]; then
                LOOP=$(losetup -f)
                losetup "$LOOP" "/opt/persist/specks/$pkg"
                mkdir -p "/opt/mnt/$pkg"
                mount -t squashfs -o ro "$LOOP" "/opt/mnt/$pkg"
                echo "SpeckCore: loaded $pkg"
            fi
        done < /opt/persist/installed.list
    fi
fi

# ============================================================
# STEP 7: Set correct permissions
# ============================================================
chmod 755 /tmp /run
chown -R 1000:1000 /home/speck 2>/dev/null || true

# ============================================================
# STEP 8: Start the session
# ============================================================
# Check if we should boot to GUI or console
# (GUI requires a GPU/KMS — in a headless VM, we drop to console)

BOOT_MODE="gui"

# Check if a display is available
if [ ! -e /dev/dri/card0 ] && [ ! -e /dev/dri/card1 ]; then
    echo "SpeckCore: no GPU found, booting to console"
    BOOT_MODE="console"
fi

if [ "$BOOT_MODE" = "gui" ]; then
    # Start the Wayland session as the speck user
    # We use 'su' to drop from root to the speck user
    # XDG_RUNTIME_DIR is required by Wayland
    mkdir -p /run/user/1000
    chmod 700 /run/user/1000
    chown 1000:1000 /run/user/1000
    
    export XDG_RUNTIME_DIR=/run/user/1000
    
    # Start the compositor as speck user
    # (This line will be replaced with labwc after Phase 7)
    # For now, start a getty on tty1 for testing
    su -c "env XDG_RUNTIME_DIR=/run/user/1000 /sbin/start-session" speck &
fi

# ============================================================
# STEP 9: Start a getty on tty1 for console access
# ============================================================
# This gives you a login prompt on the virtual console
# even when the GUI is running (switch with Ctrl+Alt+F1)
exec /sbin/init_services

INITEOF

chmod +x $SPECK_INITRAMFS/init
```

### 4.5 — Write the service startup helper scripts

```bash
# The init_services script — manages services after init
cat > $SPECK_INITRAMFS/sbin/init_services << 'EOF'
#!/bin/sh
# SpeckCore service startup — runs after /init setup

# Start getty on tty1 (login console)
/sbin/getty -L tty1 0 vt100 &
/sbin/getty -L tty2 0 vt100 &

# Wait forever (PID 1 must never exit)
while true; do
    # Reap zombie processes
    wait
    sleep 1
done
EOF
chmod +x $SPECK_INITRAMFS/sbin/init_services

# Placeholder for the Wayland session starter (filled in Phase 7)
cat > $SPECK_INITRAMFS/sbin/start-session << 'EOF'
#!/bin/sh
# SpeckCore Wayland session starter
# This will be replaced in Phase 7 with the real compositor launch

echo "SpeckCore: Wayland session not yet installed."
echo "Press Enter for a shell."
read _
exec /bin/sh
EOF
chmod +x $SPECK_INITRAMFS/sbin/start-session
```

### 4.6 — Write the /etc/fstab

```bash
cat > $SPECK_INITRAMFS/etc/fstab << 'EOF'
# SpeckCore fstab — mostly RAM-based, no real disk entries needed
# The init script handles mounts dynamically
proc            /proc   proc    defaults    0 0
sysfs           /sys    sysfs   defaults    0 0
devtmpfs        /dev    devtmpfs defaults   0 0
tmpfs           /tmp    tmpfs   mode=1777   0 0
tmpfs           /run    tmpfs   mode=0755   0 0
EOF
```

### 4.7 — Pack the initramfs and test it

```bash
cd $SPECK_INITRAMFS

# Pack everything into a cpio archive compressed with zstd
find . | cpio -o -H newc --quiet | zstd -19 -o $SPECK_ISO/boot/initramfs.img

# Check the size
ls -lh $SPECK_ISO/boot/initramfs.img
# Should be well under 5 MB at this point (mostly BusyBox)

# Test in QEMU!
qemu-system-x86_64 \
  -kernel $SPECK_ISO/boot/vmlinuz \
  -initrd $SPECK_ISO/boot/initramfs.img \
  -append "console=ttyS0 rw" \
  -nographic \
  -m 256M \
  2>&1 | head -60
```

You should see the kernel boot, mdev run, and eventually a login prompt
on tty1, or a shell if getty is not available yet. If you see "Please
press Enter to activate this console" — it worked.

Press Ctrl+A then X to quit QEMU.

---

## Phase 5 — Build the Wayland graphics stack

This is the most complex phase. Wayland requires a chain of libraries
before you can build the actual compositor. You will build them in
dependency order.

The full chain is:
```
libdrm → libgbm (Mesa) → wayland + wayland-protocols →
libxkbcommon → pixman → wlroots → labwc
```

We build each one against musl and install it into a staging sysroot.

### 5.1 — Set up the sysroot for library staging

```bash
mkdir -p $SPECK_SYSROOT/usr/include
mkdir -p $SPECK_SYSROOT/usr/lib
mkdir -p $SPECK_SYSROOT/usr/lib/pkgconfig
mkdir -p $SPECK_SYSROOT/usr/bin

# Set pkg-config to find libraries in our sysroot
export PKG_CONFIG_PATH="$SPECK_SYSROOT/usr/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$SPECK_SYSROOT/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SPECK_SYSROOT"

# Compiler shortcuts (we'll use these for every build in Phase 5)
export CC="x86_64-linux-musl-gcc"
export CXX="x86_64-linux-musl-g++"
export AR="x86_64-linux-musl-ar"
export STRIP="x86_64-linux-musl-strip"
export CFLAGS="-Os -ffunction-sections -fdata-sections --sysroot=$SPECK_SYSROOT"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--gc-sections --sysroot=$SPECK_SYSROOT"
export PREFIX="$SPECK_SYSROOT/usr"
```

### 5.2 — Build libdrm

libdrm is the userspace interface to the kernel's Direct Rendering Manager.
Required by everything that talks to the GPU.

```bash
cd $SPECK_SOURCES
wget https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz
tar -xf libdrm-2.4.120.tar.xz
cd libdrm-2.4.120

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dintel=disabled \
  -Damdgpu=enabled \
  -Dradeon=disabled \
  -Dnouveau=disabled \
  -Dvmwgfx=disabled \
  -Dtests=false \
  -Dman-pages=disabled

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

Wait — before that works you need a meson cross-file. Create it now:

```bash
cat > $SPECKROOT/scripts/musl-cross.ini << EOF
[binaries]
c = 'x86_64-linux-musl-gcc'
cpp = 'x86_64-linux-musl-g++'
ar = 'x86_64-linux-musl-ar'
strip = 'x86_64-linux-musl-strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'

[properties]
sys_root = '${SPECK_SYSROOT}'
pkg_config_libdir = '${SPECK_SYSROOT}/usr/lib/pkgconfig'
EOF
```

Now run the libdrm build above again. Then continue:

### 5.3 — Build wayland (the protocol library)

This is the core Wayland library — not the compositor, just the IPC
protocol library that compositors and apps use to talk to each other.

```bash
cd $SPECK_SOURCES
wget https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.0/downloads/wayland-1.23.0.tar.xz
tar -xf wayland-1.23.0.tar.xz
cd wayland-1.23.0

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Ddocumentation=false \
  -Dtests=false \
  -Ddtd_validation=false

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.4 — Build wayland-protocols

These are the extra protocol definitions (xdg-shell, etc.) that modern
Wayland apps use.

```bash
cd $SPECK_SOURCES
wget https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.36/downloads/wayland-protocols-1.36.tar.xz
tar -xf wayland-protocols-1.36.tar.xz
cd wayland-protocols-1.36

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dtests=false

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.5 — Build libxkbcommon

Handles keyboard layout mapping. Required by all Wayland compositors.

```bash
cd $SPECK_SOURCES
wget https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz
tar -xf libxkbcommon-1.7.0.tar.xz
cd libxkbcommon-1.7.0

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Denable-docs=false \
  -Denable-wayland=true \
  -Denable-x11=false \
  -Denable-xkbregistry=false

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.6 — Build pixman

Software pixel manipulation library. Used by compositors for
software rendering fallback.

```bash
cd $SPECK_SOURCES
wget https://cairographics.org/releases/pixman-0.43.4.tar.gz
tar -xf pixman-0.43.4.tar.gz
cd pixman-0.43.4

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dtests=disabled \
  -Ddemos=disabled

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.7 — Build libinput

Handles mouse, keyboard, and touchpad input events. Required by wlroots.

```bash
cd $SPECK_SOURCES
wget https://gitlab.freedesktop.org/libinput/libinput/-/releases/1.26.0/downloads/libinput-1.26.0.tar.xz
tar -xf libinput-1.26.0.tar.xz
cd libinput-1.26.0

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dtests=false \
  -Ddocumentation=false \
  -Ddebug-gui=false \
  -Dlibwacom=false

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.8 — Build wlroots

wlroots is the foundational Wayland compositor library. labwc is built
on top of it. This is the heaviest build in the entire stack.

```bash
cd $SPECK_SOURCES
wget https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.17.4/wlroots-0.17.4.tar.gz
tar -xf wlroots-0.17.4.tar.gz
cd wlroots-0.17.4

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dxwayland=disabled \
  -Dbackends=drm,libinput,headless \
  -Drenderers=gles2,pixman \
  -Dallocators=gbm,shm \
  -Dexamples=false

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.9 — Build labwc (the SpeckCore compositor)

labwc is a small, fast Wayland compositor inspired by Openbox.
It uses wlroots as its backend. This is the program that manages
windows, draws borders, and handles the desktop.

```bash
cd $SPECK_SOURCES
git clone https://github.com/labwc/labwc.git
cd labwc
git checkout 0.7.3  # use a known stable tag

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dman-pages=disabled \
  -Dxwayland=disabled

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.10 — Build foot (the terminal)

foot is the fastest Wayland-native terminal emulator. It is GPU-accelerated,
starts instantly, and is written in C.

```bash
cd $SPECK_SOURCES
wget https://codeberg.org/dnkl/foot/releases/download/1.17.2/foot-1.17.2.tar.gz
tar -xf foot-1.17.2.tar.gz
cd foot-1.17.2

# foot needs fcft (font rendering) and tllist (linked list library)
# Build fcft first
cd $SPECK_SOURCES
git clone https://codeberg.org/dnkl/tllist.git
cd tllist
meson setup builddir --prefix=$SPECK_SYSROOT/usr --cross-file=$SPECKROOT/scripts/musl-cross.ini
ninja -C builddir -j$(nproc) && ninja -C builddir install

cd $SPECK_SOURCES
git clone https://codeberg.org/dnkl/fcft.git
cd fcft
meson setup builddir --prefix=$SPECK_SYSROOT/usr --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dfontconfig=disabled \
  -Dsvg-backend=none
ninja -C builddir -j$(nproc) && ninja -C builddir install

# Now build foot
cd $SPECK_SOURCES/foot-1.17.2
meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dime=false \
  -Dthemes=false

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.11 — Build fuzzel (app launcher)

fuzzel is the dmenu/rofi equivalent for Wayland. It shows a popup list
of commands. Extremely lightweight.

```bash
cd $SPECK_SOURCES
git clone https://codeberg.org/dnkl/fuzzel.git
cd fuzzel

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dpng-backend=none \
  -Dsvg-backend=none

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.12 — Build yambar (the status panel)

yambar is a lightweight, module-based status bar for Wayland.
It shows the clock, workspace info, battery, and whatever you configure.

```bash
cd $SPECK_SOURCES
git clone https://codeberg.org/dnkl/yambar.git
cd yambar

meson setup builddir \
  --prefix=$SPECK_SYSROOT/usr \
  --buildtype=minsize \
  --cross-file=$SPECKROOT/scripts/musl-cross.ini \
  -Dbackend-x11=disabled \
  -Dbackend-wayland=enabled \
  -Dplugin-pulse=disabled \
  -Dplugin-alsa=disabled \
  -Dplugin-mpd=disabled \
  -Dplugin-i3=disabled \
  -Dplugin-sway-xkb=disabled

ninja -C builddir -j$(nproc)
ninja -C builddir install
```

### 5.13 — Copy all libraries to the initramfs

The sysroot has all the compiled binaries and libraries.
Now copy them into the initramfs:

```bash
# Copy all shared libraries
cp -a $SPECK_SYSROOT/usr/lib/*.so*    $SPECK_INITRAMFS/usr/lib/ 2>/dev/null || true
cp -a $SPECK_SYSROOT/usr/lib/lib*.so* $SPECK_INITRAMFS/usr/lib/ 2>/dev/null || true

# Copy the compositor and apps
cp $SPECK_SYSROOT/usr/bin/labwc    $SPECK_INITRAMFS/usr/bin/
cp $SPECK_SYSROOT/usr/bin/foot     $SPECK_INITRAMFS/usr/bin/
cp $SPECK_SYSROOT/usr/bin/fuzzel   $SPECK_INITRAMFS/usr/bin/
cp $SPECK_SYSROOT/usr/bin/yambar   $SPECK_INITRAMFS/usr/bin/

# Strip all binaries (removes debug symbols, shrinks size significantly)
for bin in \
  $SPECK_INITRAMFS/usr/bin/labwc \
  $SPECK_INITRAMFS/usr/bin/foot \
  $SPECK_INITRAMFS/usr/bin/fuzzel \
  $SPECK_INITRAMFS/usr/bin/yambar; do
  x86_64-linux-musl-strip --strip-all "$bin" 2>/dev/null || true
done

for lib in $SPECK_INITRAMFS/usr/lib/*.so*; do
  x86_64-linux-musl-strip --strip-unneeded "$lib" 2>/dev/null || true
done

# Copy wayland protocols and xkb data
mkdir -p $SPECK_INITRAMFS/usr/share/wayland-protocols
mkdir -p $SPECK_INITRAMFS/usr/share/X11/xkb
cp -r $SPECK_SYSROOT/usr/share/wayland-protocols/* $SPECK_INITRAMFS/usr/share/wayland-protocols/ 2>/dev/null || true
cp -r /usr/share/X11/xkb/* $SPECK_INITRAMFS/usr/share/X11/xkb/ 2>/dev/null || true
```

---

## Phase 6 — Configure the SpeckCore UI

Now configure how the desktop actually looks and behaves.

### 6.1 — Create the labwc configuration directory

```bash
mkdir -p $SPECK_INITRAMFS/home/speck/.config/labwc
```

### 6.2 — Write labwc/rc.xml (compositor config)

This file controls everything about the compositor:
window borders, keybindings, corner radius, animations.

```bash
cat > $SPECK_INITRAMFS/home/speck/.config/labwc/rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<labwc_config>

  <!-- ============ GENERAL ============ -->
  <core>
    <gap>6</gap>
  </core>

  <!-- ============ APPEARANCE ============ -->
  <theme>
    <name>SpeckCore</name>
    <cornerRadius>10</cornerRadius>
  </theme>

  <font place="">
    <name>Inter</name>
    <size>11</size>
    <weight>Bold</weight>
  </font>

  <!-- ============ WINDOW ANIMATIONS ============ -->
  <animations>
    <fade>
      <enabled>yes</enabled>
      <duration>120</duration>
    </fade>
  </animations>

  <!-- ============ WINDOW RULES ============ -->
  <windowRules>
    <windowRule identifier="*">
      <serverDecoration>yes</serverDecoration>
      <skipTaskbar>no</skipTaskbar>
    </windowRule>
    <!-- Make the terminal start slightly transparent -->
    <windowRule identifier="foot">
      <initialWidth>800</initialWidth>
      <initialHeight>500</initialHeight>
    </windowRule>
  </windowRules>

  <!-- ============ KEYBINDINGS ============ -->
  <keyboard>
    <default/>

    <!-- Super+Enter = open terminal -->
    <keybind key="Super_L-Return">
      <action name="Execute">
        <command>foot</command>
      </action>
    </keybind>

    <!-- Super+Space = open launcher -->
    <keybind key="Super_L-space">
      <action name="Execute">
        <command>fuzzel</command>
      </action>
    </keybind>

    <!-- Super+Q = close window -->
    <keybind key="Super_L-q">
      <action name="Close"/>
    </keybind>

    <!-- Super+F = toggle fullscreen -->
    <keybind key="Super_L-f">
      <action name="ToggleFullscreen"/>
    </keybind>

    <!-- Super+M = maximize -->
    <keybind key="Super_L-m">
      <action name="ToggleMaximize"/>
    </keybind>

    <!-- Alt+F4 = close -->
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>

    <!-- Super+D = show desktop -->
    <keybind key="Super_L-d">
      <action name="ShowDesktop"/>
    </keybind>

    <!-- Super+Left/Right = snap to half screen -->
    <keybind key="Super_L-Left">
      <action name="SnapToEdge">
        <direction>left</direction>
      </action>
    </keybind>
    <keybind key="Super_L-Right">
      <action name="SnapToEdge">
        <direction>right</direction>
      </action>
    </keybind>
    <keybind key="Super_L-Up">
      <action name="ToggleMaximize"/>
    </keybind>
  </keyboard>

  <!-- ============ MOUSE ============ -->
  <mouse>
    <default/>
    <!-- Right-click on desktop = context menu -->
    <context name="Root">
      <mousebind button="Right" action="Press">
        <action name="ShowMenu">
          <menu>root-menu</menu>
        </action>
      </mousebind>
    </context>

    <!-- Scroll on titlebar = transparency change -->
    <context name="Titlebar">
      <mousebind button="Left" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="Right" action="Press">
        <action name="ShowMenu">
          <menu>client-menu</menu>
        </action>
      </mousebind>
      <mousebind button="Left" action="DoubleClick">
        <action name="ToggleMaximize"/>
      </mousebind>
    </context>
  </mouse>

  <!-- ============ MENUS ============ -->
  <menu>
    <ignoreButtonReleasePeriod>250</ignoreButtonReleasePeriod>
  </menu>

  <!-- ============ SESSION ============ -->
  <session>
    <!-- Programs to start automatically with the compositor -->
    <autostart>
      yambar &amp;
    </autostart>
  </session>

</labwc_config>
EOF
```

### 6.3 — Create the SpeckCore dark theme

```bash
mkdir -p $SPECK_INITRAMFS/usr/share/themes/SpeckCore/openbox-3

cat > $SPECK_INITRAMFS/usr/share/themes/SpeckCore/openbox-3/themerc << 'EOF'
# SpeckCore dark theme for labwc
# 2026 aesthetic: dark, purple accent, rounded corners

# ---- Padding ----
padding.width:                      6
padding.height:                     4

# ---- Window borders ----
border.width:                       1

# ---- Title bar ----
window.active.title.bg:             flat
window.active.title.bg.color:       #1a1a24
window.active.title.text.color:     #e8e8f0
window.active.border.color:         #7c6ff7

window.inactive.title.bg:           flat
window.inactive.title.bg.color:     #111118
window.inactive.title.text.color:   #888898
window.inactive.border.color:       #2a2a38

# ---- Handle (bottom resize bar) ----
window.active.handle.bg:            flat
window.active.handle.bg.color:      #1a1a24
window.inactive.handle.bg:          flat
window.inactive.handle.bg.color:    #111118

# ---- Buttons (close, maximize, minimize) ----
window.active.button.unpressed.bg:  flat
window.active.button.unpressed.bg.color: #7c6ff7
window.active.button.pressed.bg:    flat
window.active.button.pressed.bg.color: #5a54c4
window.active.button.hover.bg:      flat
window.active.button.hover.bg.color: #9088ff

window.inactive.button.unpressed.bg: flat
window.inactive.button.unpressed.bg.color: #2a2a38

# ---- Text font ----
window.label.text.justify:          center

# ---- Menu ----
menu.border.width:                  1
menu.border.color:                  #2a2a38
menu.bg:                            flat
menu.bg.color:                      #1a1a24
menu.title.bg:                      flat
menu.title.bg.color:                #111118
menu.title.text.color:              #7c6ff7
menu.items.bg:                      flat
menu.items.bg.color:                #1a1a24
menu.items.text.color:              #e8e8f0
menu.items.active.bg:               flat
menu.items.active.bg.color:         #2a2a38
menu.items.active.text.color:       #e8e8f0

# ---- On-screen display ----
osd.bg:                             flat
osd.bg.color:                       #111118
osd.border.width:                   1
osd.border.color:                   #2a2a38
osd.label.text.color:               #e8e8f0
EOF
```

### 6.4 — Configure foot terminal (dark theme + transparency)

```bash
mkdir -p $SPECK_INITRAMFS/home/speck/.config/foot

cat > $SPECK_INITRAMFS/home/speck/.config/foot/foot.ini << 'EOF'
# SpeckCore foot terminal configuration

[main]
font=JetBrains Mono:size=11
dpi-aware=yes
shell=/bin/sh

[mouse]
hide-when-typing=yes

[colors]
# SpeckCore dark palette
alpha=0.92
background=0f0f16
foreground=e8e8f0

# Black (normal + bright)
regular0=1a1a24
regular1=f07070
regular2=70c070
regular3=c0a060
regular4=7c6ff7
regular5=c070c0
regular6=60c0c0
regular7=c0c0d0

bright0=2a2a38
bright1=ff8888
bright2=88dd88
bright3=ddbb77
bright4=9088ff
bright5=dd88dd
bright6=77dddd
bright7=e8e8f0

# Cursor
cursor=7c6ff7
cursor-text=0f0f16

# Selection
selection-foreground=0f0f16
selection-background=7c6ff7

# URL underline color
url=9088ff

[scrollback]
lines=5000
EOF
```

### 6.5 — Configure fuzzel launcher

```bash
mkdir -p $SPECK_INITRAMFS/home/speck/.config/fuzzel

cat > $SPECK_INITRAMFS/home/speck/.config/fuzzel/fuzzel.ini << 'EOF'
# SpeckCore fuzzel launcher configuration

[main]
font=Inter:size=12
dpi-aware=yes
width=30
lines=10
terminal=foot
launch-prefix=
prompt=  

[colors]
# SpeckCore dark palette
background=0f0f16f0
text=e8e8f0ff
match=7c6ff7ff
selection=2a2a38ff
selection-text=e8e8f0ff
selection-match=9088ffff
border=7c6ff7ff

[border]
width=1
radius=10
EOF
```

### 6.6 — Configure yambar panel

```bash
mkdir -p $SPECK_INITRAMFS/home/speck/.config/yambar

cat > $SPECK_INITRAMFS/home/speck/.config/yambar/config.yml << 'EOF'
# SpeckCore yambar panel configuration
# This creates a minimal bottom status bar

bar:
  height: 28
  location: top
  background: 0f0f16e8
  font: Inter:size=10

  left:
    - label:
        content:
          string:
            text: "  SpeckCore"
            foreground: 7c6ff7ff
            font: Inter:weight=bold:size=10

  center:
    - clock:
        content:
          - string:
              text: "{date}"
              foreground: 888898ff
          - string:
              text: "  "
          - string:
              text: "{time}"
              foreground: e8e8f0ff
              font: Inter:weight=bold:size=10
        date-format: "%a %b %d"
        time-format: "%H:%M"

  right:
    - mem:
        poll-interval: 5000
        content:
          string:
            text: " {used:mb}M"
            foreground: 888898ff
    - battery:
        name: BAT0
        poll-interval: 30000
        content:
          - map:
              tag: status
              values:
                Charging:
                  string:
                    text: "  {capacity}%"
                    foreground: 70c070ff
                Discharging:
                  string:
                    text: "  {capacity}%"
                    foreground: e8e8f0ff
                Full:
                  string:
                    text: "  full"
                    foreground: 70c070ff
EOF
```

### 6.7 — Update the session starter to launch labwc

```bash
cat > $SPECK_INITRAMFS/sbin/start-session << 'EOF'
#!/bin/sh
# SpeckCore Wayland session starter

export XDG_RUNTIME_DIR=/run/user/1000
export XDG_SESSION_TYPE=wayland
export WAYLAND_DISPLAY=wayland-0
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export CLUTTER_BACKEND=wayland
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export MOZ_ENABLE_WAYLAND=1

# labwc reads its config from ~/.config/labwc/rc.xml
# and auto-starts yambar via the session.autostart section
exec labwc
EOF
chmod +x $SPECK_INITRAMFS/sbin/start-session
```

---

## Phase 7 — Add fonts

SpeckCore uses two fonts: Inter (UI) and JetBrains Mono (terminal).
We will subset them to keep the size small.

### 7.1 — Download the fonts

```bash
mkdir -p $SPECK_INITRAMFS/usr/share/fonts/speckcore

cd $SPECK_SOURCES

# Inter font (variable version, covers all weights in one file)
wget "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"
unzip Inter-4.0.zip -d inter-font
cp inter-font/fonts/otf/Inter-Regular.otf $SPECK_INITRAMFS/usr/share/fonts/speckcore/
cp inter-font/fonts/otf/Inter-Bold.otf    $SPECK_INITRAMFS/usr/share/fonts/speckcore/

# JetBrains Mono
wget "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
unzip JetBrainsMono-2.304.zip -d jb-mono
cp jb-mono/fonts/ttf/JetBrainsMono-Regular.ttf $SPECK_INITRAMFS/usr/share/fonts/speckcore/
```

### 7.2 — Generate font cache

```bash
# Copy the fc-cache binary from your host system
# (we will replace this with a statically compiled version later)
cp /usr/bin/fc-cache $SPECK_INITRAMFS/usr/bin/ 2>/dev/null || true

# Create the fontconfig config directory
mkdir -p $SPECK_INITRAMFS/etc/fonts

cat > $SPECK_INITRAMFS/etc/fonts/fonts.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>/usr/share/fonts</dir>
  <cachedir>/var/cache/fontconfig</cachedir>
  <match target="pattern">
    <test qual="any" name="family">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="assign" binding="same">
      <string>Inter</string>
    </edit>
  </match>
  <match target="pattern">
    <test qual="any" name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="assign" binding="same">
      <string>JetBrains Mono</string>
    </edit>
  </match>
</fontconfig>
EOF

mkdir -p $SPECK_INITRAMFS/var/cache/fontconfig
```

---

## Phase 8 — Write the specktool package manager

specktool is the entire SpeckCore package system in a single shell script.

```bash
cat > $SPECK_INITRAMFS/usr/bin/specktool << 'SPECKEOF'
#!/bin/sh
# specktool — SpeckCore package manager
# Usage: specktool install <name>
#        specktool remove <name>
#        specktool search <term>
#        specktool list
#        specktool update

SPECK_REPO_URL="https://packages.speckcore.org"
SPECK_REPO_INDEX="/var/cache/speck/index.json"
SPECK_PKG_DIR="/opt/specks"
SPECK_MNT_DIR="/opt/mnt"
SPECK_LIST="/opt/installed.list"

# Use persist dir if available
if [ -d /opt/persist ]; then
    SPECK_PKG_DIR="/opt/persist/specks"
    SPECK_LIST="/opt/persist/installed.list"
fi

mkdir -p "$SPECK_PKG_DIR" "$SPECK_MNT_DIR" /var/cache/speck
touch "$SPECK_LIST" 2>/dev/null || true

# -------------------------------------------------------
die() { echo "specktool: error: $1" >&2; exit 1; }
info() { echo "specktool: $1"; }

# -------------------------------------------------------
cmd_update() {
    info "updating package index..."
    mkdir -p "$(dirname $SPECK_REPO_INDEX)"
    wget -q -O "$SPECK_REPO_INDEX.tmp" "$SPECK_REPO_URL/index.json" \
        || die "failed to download index (are you online?)"
    mv "$SPECK_REPO_INDEX.tmp" "$SPECK_REPO_INDEX"
    count=$(grep -c '"name"' "$SPECK_REPO_INDEX" 2>/dev/null || echo 0)
    info "index updated. $count packages available."
}

# -------------------------------------------------------
cmd_search() {
    term="$1"
    [ -z "$term" ] && die "usage: specktool search <term>"
    [ -f "$SPECK_REPO_INDEX" ] || die "no index. run: specktool update"
    
    # Simple grep-based search through the JSON
    # Each package is a JSON object on multiple lines
    grep -A4 "\"name\"" "$SPECK_REPO_INDEX" \
        | grep -i "$term" \
        | sed 's/.*"name": "\([^"]*\)".*/\1/' \
        | grep -v "^$" \
        || echo "(no results for: $term)"
}

# -------------------------------------------------------
cmd_list() {
    if [ ! -s "$SPECK_LIST" ]; then
        echo "(no packages installed)"
        return
    fi
    echo "Installed packages:"
    while IFS= read -r pkg; do
        echo "  $pkg"
    done < "$SPECK_LIST"
}

# -------------------------------------------------------
cmd_install() {
    name="$1"
    [ -z "$name" ] && die "usage: specktool install <name>"
    
    # Check if already installed
    if grep -qx "$name" "$SPECK_LIST" 2>/dev/null; then
        info "$name is already installed"
        return
    fi
    
    # Look up package in index
    [ -f "$SPECK_REPO_INDEX" ] || die "no index. run: specktool update"
    
    # Parse the JSON index for this package
    # (simple grep-based parsing — no jq needed)
    pkg_file=$(grep -A10 "\"name\": \"$name\"" "$SPECK_REPO_INDEX" \
        | grep '"file"' \
        | head -1 \
        | sed 's/.*"file": "\([^"]*\)".*/\1/')
    
    pkg_sha=$(grep -A10 "\"name\": \"$name\"" "$SPECK_REPO_INDEX" \
        | grep '"sha256"' \
        | head -1 \
        | sed 's/.*"sha256": "\([^"]*\)".*/\1/')
    
    [ -z "$pkg_file" ] && die "package '$name' not found. run: specktool update"
    
    # Download the .speck file
    dest="$SPECK_PKG_DIR/$pkg_file"
    info "downloading $pkg_file..."
    wget -q --show-progress -O "$dest.tmp" "$SPECK_REPO_URL/packages/$pkg_file" \
        || die "download failed"
    
    # Verify checksum
    if [ -n "$pkg_sha" ]; then
        actual_sha=$(sha256sum "$dest.tmp" | cut -d' ' -f1)
        if [ "$actual_sha" != "$pkg_sha" ]; then
            rm -f "$dest.tmp"
            die "checksum mismatch for $pkg_file (download may be corrupt)"
        fi
        info "checksum OK"
    fi
    
    mv "$dest.tmp" "$dest"
    
    # Mount the squashfs
    LOOP=$(losetup -f)
    [ -z "$LOOP" ] && die "no free loop devices"
    
    losetup "$LOOP" "$dest" || die "failed to set up loop device"
    
    mkdir -p "$SPECK_MNT_DIR/$name"
    mount -t squashfs -o ro "$LOOP" "$SPECK_MNT_DIR/$name" \
        || { losetup -d "$LOOP"; die "failed to mount $name"; }
    
    # Add to PATH and library path
    if [ -d "$SPECK_MNT_DIR/$name/usr/bin" ]; then
        export PATH="$SPECK_MNT_DIR/$name/usr/bin:$PATH"
    fi
    if [ -d "$SPECK_MNT_DIR/$name/usr/lib" ]; then
        ldconfig "$SPECK_MNT_DIR/$name/usr/lib" 2>/dev/null || true
    fi
    
    # Run post-install script if it exists
    if [ -x "$SPECK_MNT_DIR/$name/.speck-install" ]; then
        "$SPECK_MNT_DIR/$name/.speck-install"
    fi
    
    # Record installation
    echo "$name" >> "$SPECK_LIST"
    
    info "$name installed successfully"
    
    # Show suggestions
    suggests=$(grep -A15 "\"name\": \"$name\"" "$SPECK_REPO_INDEX" \
        | grep '"suggests"' \
        | sed 's/.*"suggests": "\([^"]*\)".*/\1/')
    [ -n "$suggests" ] && info "suggestion: you may also want: $suggests"
}

# -------------------------------------------------------
cmd_remove() {
    name="$1"
    [ -z "$name" ] && die "usage: specktool remove <name>"
    
    grep -qx "$name" "$SPECK_LIST" 2>/dev/null \
        || die "$name is not installed"
    
    # Unmount
    if mountpoint -q "$SPECK_MNT_DIR/$name" 2>/dev/null; then
        umount "$SPECK_MNT_DIR/$name" || die "failed to unmount $name"
    fi
    
    # Find and detach the loop device
    loop_dev=$(losetup -a | grep "$SPECK_PKG_DIR/$name" | cut -d: -f1)
    [ -n "$loop_dev" ] && losetup -d "$loop_dev"
    
    # Remove mount point
    rmdir "$SPECK_MNT_DIR/$name" 2>/dev/null || true
    
    # Remove the package file (optional — keeps it for offline reinstall if omitted)
    # rm -f "$SPECK_PKG_DIR/${name}-"*.speck
    
    # Remove from installed list
    tmpfile=$(mktemp)
    grep -vx "$name" "$SPECK_LIST" > "$tmpfile"
    mv "$tmpfile" "$SPECK_LIST"
    
    info "$name removed"
}

# -------------------------------------------------------
# Main dispatch
case "$1" in
    install) cmd_install "$2" ;;
    remove)  cmd_remove  "$2" ;;
    search)  cmd_search  "$2" ;;
    list)    cmd_list ;;
    update)  cmd_update ;;
    *)
        echo "specktool — SpeckCore package manager"
        echo ""
        echo "Usage:"
        echo "  specktool update           update package index"
        echo "  specktool search <term>    search packages"
        echo "  specktool install <name>   install a package"
        echo "  specktool remove <name>    remove a package"
        echo "  specktool list             list installed packages"
        exit 1
        ;;
esac
SPECKEOF

chmod +x $SPECK_INITRAMFS/usr/bin/specktool
```

---

## Phase 9 — Build the .speck package format

This phase shows you how to create your own `.speck` packages.
We will build one example: the `speck-neofetch` package.

### 9.1 — Write the package build script

```bash
mkdir -p $SPECKROOT/scripts

cat > $SPECKROOT/scripts/build-speck.sh << 'BUILDEOF'
#!/bin/sh
# SpeckCore package builder
# Usage: build-speck.sh <package-name> <staging-dir>

set -e

PKG_NAME="$1"
STAGING="$2"
OUTPUT="${3:-$SPECKROOT/speck-packages}"

[ -z "$PKG_NAME" ] && { echo "Usage: $0 <name> <staging-dir>"; exit 1; }
[ -z "$STAGING" ]  && { echo "Usage: $0 <name> <staging-dir>"; exit 1; }
[ -d "$STAGING" ]  || { echo "staging dir $STAGING does not exist"; exit 1; }

mkdir -p "$OUTPUT"

# Get the version from the metadata file
VERSION=$(grep "^version=" "$STAGING/.speck-meta" 2>/dev/null | cut -d= -f2)
VERSION="${VERSION:-1.0}"

OUT_FILE="$OUTPUT/${PKG_NAME}-${VERSION}.speck"

echo "Building $PKG_NAME-$VERSION.speck..."

# Pack into squashfs with zstd compression
mksquashfs "$STAGING" "$OUT_FILE" \
  -comp zstd \
  -Xcompression-level 19 \
  -noappend \
  -quiet

# Generate SHA256
sha256sum "$OUT_FILE" | cut -d' ' -f1 > "$OUT_FILE.sha256"
SHA=$(cat "$OUT_FILE.sha256")

# Get size
SIZE_KB=$(du -k "$OUT_FILE" | cut -f1)

# Print index entry (add this to index.json manually or via a script)
echo ""
echo "Package built: $OUT_FILE"
echo "SHA256: $SHA"
echo ""
echo "Add this to your index.json:"
cat << JSONEOF
{
  "name": "$PKG_NAME",
  "version": "$VERSION",
  "file": "${PKG_NAME}-${VERSION}.speck",
  "sha256": "$SHA",
  "size_kb": $SIZE_KB,
  "suggests": "",
  "description": "SpeckCore package"
}
JSONEOF
BUILDEOF

chmod +x $SPECKROOT/scripts/build-speck.sh
```

### 9.2 — Build the example neofetch package

```bash
# Create a staging directory for neofetch
mkdir -p /tmp/speck-neofetch-staging/usr/bin

# Download neofetch
wget -O /tmp/speck-neofetch-staging/usr/bin/neofetch \
  "https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch"
chmod +x /tmp/speck-neofetch-staging/usr/bin/neofetch

# Write metadata
cat > /tmp/speck-neofetch-staging/.speck-meta << 'EOF'
name=neofetch
version=7.1.0
description=System info tool with logo display
suggests=
EOF

# Build the package
$SPECKROOT/scripts/build-speck.sh \
  neofetch \
  /tmp/speck-neofetch-staging \
  $SPECKROOT/speck-packages

ls -lh $SPECKROOT/speck-packages/
# Should show: neofetch-7.1.0.speck
```

---

## Phase 10 — Final initramfs assembly

Now put everything together into the final compressed initramfs.

### 10.1 — Verify the initramfs structure

```bash
# Check what we have
du -sh $SPECK_INITRAMFS/
# Check the biggest directories
du -sh $SPECK_INITRAMFS/*/ 2>/dev/null | sort -rh | head -15

# Verify critical files exist
ls -la $SPECK_INITRAMFS/init
ls -la $SPECK_INITRAMFS/bin/busybox
ls -la $SPECK_INITRAMFS/usr/bin/labwc 2>/dev/null || echo "labwc not yet copied"
```

### 10.2 — Strip all binaries one final time

```bash
echo "Stripping all binaries..."

find $SPECK_INITRAMFS -type f -name "*.so*" -exec \
  x86_64-linux-musl-strip --strip-unneeded {} \; 2>/dev/null

for dir in bin sbin usr/bin usr/sbin; do
  if [ -d "$SPECK_INITRAMFS/$dir" ]; then
    find "$SPECK_INITRAMFS/$dir" -type f -executable -exec \
      x86_64-linux-musl-strip --strip-all {} \; 2>/dev/null
  fi
done

echo "Stripping done."
du -sh $SPECK_INITRAMFS/
```

### 10.3 — Set correct ownership and permissions

```bash
# Root-owned files
sudo chown -R root:root $SPECK_INITRAMFS/

# Fix home directory for speck user
sudo chown -R 1000:1000 $SPECK_INITRAMFS/home/speck/

# Make sure init is executable
sudo chmod 755 $SPECK_INITRAMFS/init
sudo chmod 755 $SPECK_INITRAMFS/sbin/init_services
sudo chmod 755 $SPECK_INITRAMFS/sbin/start-session
sudo chmod 755 $SPECK_INITRAMFS/usr/bin/specktool

# Fix shadow permissions
sudo chmod 640 $SPECK_INITRAMFS/etc/shadow
```

### 10.4 — Pack the final initramfs

```bash
cd $SPECK_INITRAMFS

# Create the compressed cpio initramfs
# We use find to generate the file list, cpio to pack it,
# and zstd to compress it.
sudo find . -print0 \
  | sudo cpio --null --create --format=newc \
  | zstd --ultra -22 --no-progress \
  > $SPECK_ISO/boot/initramfs.img

ls -lh $SPECK_ISO/boot/initramfs.img
echo "Initramfs size: $(du -sh $SPECK_ISO/boot/initramfs.img | cut -f1)"
```

---

## Phase 11 — Build the bootable ISO

The ISO needs a bootloader, the kernel, and the initramfs.
SpeckCore uses GRUB for maximum hardware compatibility.

### 11.1 — Create the GRUB bootloader configuration

```bash
mkdir -p $SPECK_ISO/boot/grub

cat > $SPECK_ISO/boot/grub/grub.cfg << 'EOF'
# SpeckCore GRUB configuration

set timeout=3
set default=0

# SpeckCore purple theme
set menu_color_normal=light-gray/black
set menu_color_highlight=white/light-blue

menuentry "SpeckCore" {
    linux  /boot/vmlinuz \
        root=/dev/ram0 \
        rw \
        quiet \
        splash \
        loglevel=3 \
        rd.systemd.show_status=false \
        rd.udev.log_priority=3 \
        vt.global_cursor_default=0
    initrd /boot/initramfs.img
}

menuentry "SpeckCore (verbose boot)" {
    linux  /boot/vmlinuz \
        root=/dev/ram0 \
        rw \
        console=ttyS0 \
        loglevel=7
    initrd /boot/initramfs.img
}

menuentry "SpeckCore (safe mode - no GUI)" {
    linux  /boot/vmlinuz \
        root=/dev/ram0 \
        rw \
        speck.nogui=1 \
        console=ttyS0
    initrd /boot/initramfs.img
}
EOF
```

### 11.2 — Build the ISO with xorriso

```bash
# Create the ISO
grub-mkrescue \
  -o $SPECK_OUTPUT/speckcore.iso \
  $SPECK_ISO \
  -- \
  -volid "SPECKCORE" \
  -joliet \
  -rational-rock \
  2>&1 | tail -5

ls -lh $SPECK_OUTPUT/speckcore.iso
echo "ISO size: $(du -sh $SPECK_OUTPUT/speckcore.iso | cut -f1)"
```

If `grub-mkrescue` is not available, use this alternative:

```bash
# Alternative: manual ISO creation with xorriso
grub-mkstandalone \
  --format=i386-pc \
  --output=$SPECK_ISO/boot/grub/core.img \
  --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
  --modules="linux normal iso9660 biosdisk search" \
  --locales="" \
  --fonts="" \
  "boot/grub/grub.cfg=$SPECK_ISO/boot/grub/grub.cfg"

cat /usr/lib/grub/i386-pc/cdboot.img $SPECK_ISO/boot/grub/core.img > \
  $SPECK_ISO/boot/grub/bios.img

xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "SPECKCORE" \
  -eltorito-boot boot/grub/bios.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --eltorito-catalog boot/grub/boot.cat \
  --grub2-boot-info \
  --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
  -output $SPECK_OUTPUT/speckcore.iso \
  $SPECK_ISO
```

### 11.3 — Verify the ISO

```bash
ls -lh $SPECK_OUTPUT/speckcore.iso
file $SPECK_OUTPUT/speckcore.iso
# Should say: ISO 9660 CD-ROM filesystem data 'SPECKCORE'
```

---

## Phase 12 — Test the final ISO in QEMU

### 12.1 — Test in QEMU with GUI (KVM-accelerated)

```bash
# Test the full ISO with display (requires KVM)
qemu-system-x86_64 \
  -enable-kvm \
  -cdrom $SPECK_OUTPUT/speckcore.iso \
  -boot d \
  -m 512M \
  -smp 2 \
  -vga virtio \
  -display gtk,gl=on \
  -device virtio-gpu-pci \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -device virtio-rng-pci \
  -no-reboot \
  2>/dev/null
```

### 12.2 — Test without KVM (slower, but works in any VM)

```bash
qemu-system-x86_64 \
  -cdrom $SPECK_OUTPUT/speckcore.iso \
  -boot d \
  -m 512M \
  -smp 2 \
  -vga std \
  -display sdl \
  -device e1000,netdev=net0 \
  -netdev user,id=net0 \
  -no-reboot
```

### 12.3 — Test serial console only (no display needed)

```bash
qemu-system-x86_64 \
  -cdrom $SPECK_OUTPUT/speckcore.iso \
  -boot d \
  -m 256M \
  -nographic \
  -append "console=ttyS0 speck.nogui=1" \
  -no-reboot \
  2>&1 | head -80
```

Press Ctrl+A then X to exit QEMU.

---

## Phase 13 — Measure performance targets

Run these checks to verify SpeckCore meets its targets.

### 13.1 — ISO size

```bash
du -sh $SPECK_OUTPUT/speckcore.iso
# Target: under 80 MB
# Expected with full Wayland stack: 30–60 MB
```

### 13.2 — Boot time measurement

```bash
# Time the boot from ISO to shell prompt
time qemu-system-x86_64 \
  -enable-kvm \
  -cdrom $SPECK_OUTPUT/speckcore.iso \
  -boot d \
  -m 512M \
  -nographic \
  -append "console=ttyS0 quiet" \
  -no-reboot \
  2>&1 | grep -m1 "speckcore login:"
```

### 13.3 — Idle RAM usage (inside QEMU)

Boot SpeckCore and log in. Then at the shell prompt:

```sh
free -m
# Look at the "used" value in the Mem row.
# Target: under 100 MB at idle with compositor running.
```

---

## Rebuild script — rebuild the ISO in one command

After you have done Phase 0–12 once, use this script to
rebuild the ISO whenever you change something:

```bash
cat > $SPECKROOT/scripts/rebuild-iso.sh << 'EOF'
#!/bin/sh
# SpeckCore ISO rebuild script
# Repacks the initramfs and rebuilds the ISO.
# Assumes all binaries and config files are already in place.

set -e
SPECKROOT="$HOME/speckcore"

echo "==> Packing initramfs..."
cd "$SPECKROOT/initramfs"
sudo find . -print0 \
  | sudo cpio --null --create --format=newc \
  | zstd --ultra -22 --no-progress \
  > "$SPECKROOT/iso/boot/initramfs.img"
echo "    size: $(du -sh $SPECKROOT/iso/boot/initramfs.img | cut -f1)"

echo "==> Building ISO..."
grub-mkrescue \
  -o "$SPECKROOT/output/speckcore.iso" \
  "$SPECKROOT/iso" \
  -- -volid "SPECKCORE" -joliet -rational-rock 2>/dev/null

echo "==> Done!"
echo "    ISO: $SPECKROOT/output/speckcore.iso"
echo "    Size: $(du -sh $SPECKROOT/output/speckcore.iso | cut -f1)"
EOF

chmod +x $SPECKROOT/scripts/rebuild-iso.sh
```

---

## Troubleshooting common problems

**Kernel panics with "No working init found"**
→ The initramfs is missing or corrupt.
→ Check: `ls -lh $SPECK_ISO/boot/initramfs.img` — must exist and be non-empty.
→ Check: `$SPECK_INITRAMFS/init` must exist and be executable (`chmod +x`).
→ Check: `$SPECK_INITRAMFS/bin/busybox` must exist and be a valid ELF binary.
→ The `file` command should say "statically linked" for busybox.

**QEMU says "KVM not available"**
→ Your CPU doesn't support KVM or it's disabled in BIOS.
→ Remove `-enable-kvm` from the QEMU command.
→ Boot will be slower (10–30 seconds) but still works.

**Compositor doesn't start (drops to console)**
→ QEMU needs `-vga virtio -device virtio-gpu-pci` for Wayland.
→ If using a real machine, DRM/KMS must be enabled in the kernel config.
→ Check: `ls /dev/dri/` — if empty, no GPU driver loaded.

**labwc fails to start (error about wlroots)**
→ A shared library is missing from `/usr/lib` in the initramfs.
→ Run: `ldd $SPECK_SYSROOT/usr/bin/labwc` to see what it needs.
→ Copy any missing `.so` files from the sysroot.

**BusyBox build fails with musl errors**
→ Ensure `CONFIG_CROSS_COMPILER_PREFIX="x86_64-linux-musl-"` is set.
→ Run `make clean` then `make ARCH=x86_64 olddefconfig` again.

**Fonts not rendering correctly**
→ Ensure `/usr/share/X11/xkb` is populated in the initramfs.
→ Ensure `/etc/fonts/fonts.conf` exists.
→ Run fontconfig cache generation inside QEMU: `fc-cache -f`.

**ISO won't boot on real hardware**
→ Ensure UEFI Secure Boot is disabled in BIOS.
→ Try the alternative xorriso command in Phase 11.2.
→ Write the ISO to USB with: `dd if=speckcore.iso of=/dev/sdX bs=4M status=progress`

---

## What to work on next

Once your ISO boots successfully:

1. **Add NetworkManager or dhcpcd** as a `.speck` package for WiFi.
2. **Build a real labwc theme** with a proper GTK dark theme.
3. **Add a file manager** (nnn or lf are very small — under 1 MB each).
4. **Create a first-run wizard** — a shell script that asks for username
   and timezone on first boot, then writes the config to the persist partition.
5. **Automate package building** — write a `Speckfile` format (like a Dockerfile
   but for .speck packages) and a script that reads it.
6. **Set up a package repository** — even a simple GitHub releases page
   with an `index.json` file works as a specktool repository.
7. **Add a SpeckCore installer** — a TUI script that partitions a disk,
   copies the ISO contents, and creates the SPECKLABEL persist partition.

---

*SpeckCore tutorial — from Linus's kernel to a bootable ISO.*
*Build time estimate: 4–8 hours on a modern machine.*
*This document was written for beginners who have never built a Linux distro before.*