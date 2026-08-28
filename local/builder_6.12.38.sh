#!/bin/bash
set -e
# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
PATCH_ROOT="${SCRIPT_DIR}/zero_patch"
# ===== 设置自定义参数 =====
echo "===== 欧加真SM8850通用6.12.38 A16 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android16-5-g8c67d4274c0a-ab14275539-4k）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android16-5-g8c67d4274c0a-ab14275539-4k}
read -p "是否启用susfs+ZeroMount(Super‑Builders)?(y/n，默认：y): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}
read -p "是否启用 KPM？(y-启用 KpatchNext独立kpm实现, n-关闭kpm，默认：n): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
read -p "KSU分支版本(r=ReSukiSU, y=SukiSU Ultra, n=KernelSU Next, k=KSU, l=lkm模式(无内置KSU), 默认：r): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-r}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否启用网络功能增强优化配置？(y/n，默认：y): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
read -p "是否启用WireGuard内核模块？(y/n，默认：n): " APPLY_WIREGUARD
APPLY_WIREGUARD=${APPLY_WIREGUARD:-n}
read -p "是否添加 BBR 等一系列拥塞控制算法？(y添加/n禁用/d默认，默认：n): " APPLY_BBR
APPLY_BBR=${APPLY_BBR:-n}
read -p "是否添加 Droidspaces 容器支持？(n禁用/s标准/e扩展，默认：n): " APPLY_DROIDSPACES
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
read -p "是否启用ADIOS调度器？(y/n，默认：y): " APPLY_ADIOS
APPLY_ADIOS=${APPLY_ADIOS:-y}
read -p "是否启用Re‑Kernel？(y/n，默认：n): " APPLY_REKERNEL
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
read -p "是否启用内核级基带保护？(y/n，默认：y): " APPLY_BBG
APPLY_BBG=${APPLY_BBG:-y}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="ReSukiSU"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
else
  KSU_TYPE="no KSU"
fi

echo
echo "===== 配置信息 ====="
echo "适用机型: $MANIFEST"
echo "自定义内核后缀: -$CUSTOM_SUFFIX"
echo "KSU分支版本: $KSU_TYPE"
echo "启用susfs+ZeroMount(Super‑Builders): $APPLY_SUSFS"
echo "启用 KPM: $USE_PATCH_LINUX"
echo "应用 lz4&zstd 补丁: $APPLY_LZ4"
echo "应用 lz4kd 补丁: $APPLY_LZ4KD"
echo "应用网络功能增强优化配置: $APPLY_BETTERNET"
echo "启用WireGuard内核模块: $APPLY_WIREGUARD"
echo "应用 BBR 等算法: $APPLY_BBR"
echo "应用 Droidspaces 容器支持: $APPLY_DROIDSPACES"
echo "启用ADIOS调度器: $APPLY_ADIOS"
echo "启用Re‑Kernel: $APPLY_REKERNEL"
echo "启用内核级基带保护: $APPLY_BBG"
echo "===================="
echo

# ===== 创建工作目录 =====
WORKDIR="$SCRIPT_DIR"
cd "$WORKDIR"

# ===== 安装构建依赖 =====
echo ">>> 安装构建依赖..."
SU() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}
SU apt-mark hold firefox && apt-mark hold libc-bin && apt-mark hold man-db
SU rm -rf /var/lib/man-db/auto-update
SU apt-get update
SU apt-get install --no-install-recommends -y curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev libdw-dev cpio xz-utils tar unzip aria2

# ===== 初始化仓库 =====
echo ">>> 初始化仓库..."
rm -rf kernel_workspace
mkdir kernel_workspace
cd kernel_workspace
echo "正在克隆源码仓库..."
aria2c -s16 -x16 -k1M https://github.com/cctv18/android_kernel_common_oneplus_sm8845/archive/refs/heads/oneplus/sm8845_b_16.0.0_ace_6t.zip -o common.zip &&
unzip -q common.zip &&
mv "android_kernel_common_oneplus_sm8845-oneplus-sm8845_b_16.0.0_ace_6t" common &&
rm -rf common.zip &

echo "正在克隆llvm‑clang19工具链..." &&
mkdir -p clang19 &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM‑Clang19‑r536225/clang‑r536225.zip -o clang.zip &&
unzip -q clang.zip -d clang19 &&
rm -rf clang.zip &

echo "正在克隆Rust 1.82.0工具链..." &&
mkdir -p rust &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM‑Clang19‑r536225/rust.zip -o rust.zip &&
unzip -q rust.zip -d rust &&
rm -rf rust.zip &

echo "正在克隆构建工具..." &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM‑Clang19‑r536225/build‑tools.zip -o build‑tools.zip &&
unzip -q build‑tools.zip &&
rm -rf build‑tools.zip &

wait
echo "所有源码及llvm‑clang19工具链初始化完成！"
echo ">>> 初始化仓库完成!"
for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"‑${CUSTOM_SUFFIX}\"|" "$f"
done
sudo sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-'${CUSTOM_SUFFIX}'"/' ./common/arch/arm64/configs/gki_defconfig
sed -i 's/${scm_version}//' ./common/scripts/setlocalversion
echo "CONFIG_LOCALVERSION_AUTO=n" >> ./common/arch/arm64/configs/gki_defconfig

# ===== 拉取 KSU 并设置版本号 =====
if [[ $KSU_BRANCH == [yYrR] ]]; then
  echo ">>> 拉取 ReSukiSU 并设置版本（由于SukiSU长期未维护无法正常编译，且ReSukiSU兼容sukisu管理器，故SukiSU源码仓库已重定向为resukisu）..."
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s main
  echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%‑%COMMIT_SHA%@cctv18"' >> ./common/arch/arm64/configs/gki_defconfig
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  echo ">>> 拉取 KernelSU Next 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU‑Next/refs/heads/dev‑susfs/kernel/setup.sh" | bash -s dev‑susfs
  cd KernelSU‑Next
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU‑Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0‑9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU‑Next/KernelSU‑Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_GIT_TAG/g" kernel/Kbuild
  cd ../common/drivers/kernelsu
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/apk_sign.patch
  patch -p2 -N -F 3 < apk_sign.patch || true
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo "正在配置原版 KernelSU (tiann/KernelSU)..."
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0‑9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
else
  echo "已选择无内置KernelSU模式，跳过配置..."
fi

# ===== 应用 Super‑Builders SUSFS & ZeroMount 补丁（不再使用susfs4oki） =====
cd "$WORKDIR/kernel_workspace"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 应用 Super‑Builders SUSFS&ZeroMount补丁"
  if [[ ! -d "$PATCH_ROOT" ]]; then
    echo "ERROR: zero_patch目录不存在，请放置在脚本同级目录！"
    exit 1
  fi
  rm -rf common/drivers/susfs common/fs/susfs
  cd common
  patch -p1 -F3 --no-backup-if-mismatch < "${PATCH_ROOT}/50_add_susfs_in_gki-android16‑6.12.patch"
  patch -p1 -F3 --no-backup-if-mismatch < "${PATCH_ROOT}/51_enhanced_susfs-android16‑6.12.patch"
  cd ../KernelSU  
  cd common
patch -p1 -F3 --no-backup-if-mismatch < "${PATCH_ROOT}/50_add_susfs_in_gki-android16-6.12.patch"
patch -p1 -F3 --no-backup-if-mismatch < "${PATCH_ROOT}/51_enhanced_susfs-android16-6.12.patch"

echo ">>> Disable legacy KSU hooks for ReSukiSU Inline Hook"

python3 - <<'PY'
from pathlib import Path

targets = [
    "fs/exec.c",
    "fs/read_write.c",
    "drivers/input/input.c",
]

for f in targets:
    p = Path(f)
    if not p.exists():
        continue

    s = p.read_text()

    # 禁止 legacy hook 调用，但保留 SUSFS 主体
    s = s.replace(
        "if (unlikely(ksu_execveat_hook",
        "if (unlikely(false && ksu_execveat_hook"
    )

    s = s.replace(
        "if (ksu_input_hook)",
        "if (false && ksu_input_hook)"
    )

    s = s.replace(
        "if (ksu_init_rc_hook)",
        "if (false && ksu_init_rc_hook)"
    )

    p.write_text(s)
PY

patch -p1 -F3 --no-backup-if-mismatch < "${PATCH_ROOT}/60_zeromount-android16-6.12.patch"
  patch -p1 -F3 --no-backup-if-mismatch < "${PATCH_ROOT}/60_zeromount-android16‑6.12.patch"
  set +e
  sed -i 's/getname_flags(filename, lookup_flags, NULL)/getname_flags(filename, lookup_flags)/' fs/open.c
  set -e
fi

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8850.git
  cp ./oppo_oplus_realme_sm8850/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8850/zram_patch/002-zstd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  patch -p1 -F 3 < 001-lz4.patch || true
  patch -p1 -F 3 < 002-zstd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4&ZSTD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 应用 LZ4KD 补丁 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  echo ">>> 应用 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace/common"
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/lz4kd.patch
  patch -p1 -F 3 < lz4kd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 添加 defconfig 配置项 =====
echo ">>> 添加 defconfig 配置项..."
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig

echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo "CONFIG_SUSFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_ZEROMOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SUSFS_HOOK_VFS=y" >> "$DEFCONFIG_FILE"
else
  echo "CONFIG_SUSFS=n" >> "$DEFCONFIG_FILE"
fi

#添加对 Mountify (backslashxx/mountify) 模块的支持
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"

# 开启O2编译优化配置
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
#跳过将uapi标准头安装到 usr/include 目录的不必要操作，节省编译时间
echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"

# 应用 CVE_2026_43499 修复补丁
cd common
wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/cve-2026-43499-rtmutex-6.12.patch
patch -p1 -F 3 < cve-2026-43499-rtmutex-6.12.patch
cd ..

# 6.12内核Rust配置
echo "CONFIG_RUST=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_ANDROID_BINDER_IPC_RUST=m" >> ./common/arch/arm64/configs/gki_defconfig

# 仅在启用了 LZ4KD 补丁时添加相关算法支持
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
CONFIG_ZRAM_BACKEND_LZ4HC=y
CONFIG_ZRAM_BACKEND_LZ4K=y
CONFIG_ZRAM_BACKEND_LZ4KD=y
CONFIG_ZRAM_BACKEND_842=y
EOF
fi

# ===== 启用网络功能增强优化配置 =====
if [[ "$APPLY_BETTERNET" == "y" || "$APPLY_BETTERNET" == "Y" ]]; then
  echo ">>> 正在启用网络功能增强优化配置..."
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"
  # Super‑Builders补充网络能力
  echo "CONFIG_IP_NF_TARGET_TTL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_HL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_MATCH_HL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KALLSYMS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KALLSYMS_ALL=y" >> "$DEFCONFIG_FILE"
  #WiFi抗缓冲膨胀队列调优
  echo "CONFIG_NET_SCH_SFQ=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NET_SCH_PIE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_PSI=y" >> "$DEFCONFIG_FILE"

  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

# ===== WireGuard模块配置 =====
if [[ "$APPLY_WIREGUARD" == "y" || "$APPLY_WIREGUARD" == "Y" ]]; then
  echo ">>> 启用WireGuard内核模块配置"
  echo "CONFIG_WIREGUARD=m" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CRYPTO_CHACHA20POLY1305=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CRYPTO_CURVE25519=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_CRYPTO_BLAKE2S=y" >> "$DEFCONFIG_FILE"
fi

# ===== 添加 BBR 等一系列拥塞控制算法 =====
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
  echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
  else
    echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
  fi
fi

# ===== 启用 Droidspaces 容器支持 =====
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  echo ">>> 正在添加 Droidspaces 容器支持..."
  echo "CONFIG_PID_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IPC_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_USER_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SYSVIPC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_DEVTMPFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NAMESPACES=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_POSIX_MQUEUE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_TARGET_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_RECENT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NTSYNC=y" >> "$DEFCONFIG_FILE"
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/fix_sysvipc_kabi_a16-6.12.patch
  patch -p1 -F 3 < fix_sysvipc_kabi_a16-6.12.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/fix_oplus_bsp_midas.patch
  patch -p1 -F 3 < fix_oplus_bsp_midas.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/ddl_hit_hook.patch
  patch -p1 -F 3 < ddl_hit_hook.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/ntsync_compat_android16-6.12.patch
  patch -p1 -F 3 < ntsync_compat_android16-6.12.patch || true
  cd ..
  if [[ "$APPLY_DROIDSPACES" == [eE] ]]; then
    echo "正在启用容器环境扩展支持..."
    echo "CONFIG_BT_HCIVHCI=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_STATIC_USERMODEHELPER=n" >> "$DEFCONFIG_FILE"
  fi
fi

# ===== 启用ADIOS调度器 =====
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  echo ">>> 正在启用ADIOS调度器..."
  echo "CONFIG_MQ_IOSCHED_ADIOS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用Re‑Kernel =====
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  echo ">>> 正在启用Re‑Kernel..."
  echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_REKERNEL_NETWORK=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用内核级基带保护 =====
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  echo ">>> 正在启用内核级基带保护..."
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd ./common
  curl -sSL https://github.com/cctv18/Baseband-guard/raw/master/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd ..
fi

# ===== 禁用 defconfig 检查 =====
echo ">>> 禁用 defconfig 检查..."
sed -i 's/check_defconfig//' ./common/build.config.gki

# ===== 编译内核 =====
echo ">>> 开始编译内核..."
WORKDIR="$(pwd)"
export PATH="$WORKDIR/clang19/bin:$PATH"
export PATH="$WORKDIR/build-tools/bin:$PATH"
export PATH="$WORKDIR/rust/bin:$PATH"
CLANG_DIR="$WORKDIR/clang19/bin"
CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($CLANG_DIR/ld.lld --version | head -n 1)"
RUSTC_VERSION="$(rustc -V 2>/dev/null | head -n1)"
BINDGEN_VERSION="$(bindgen --version 2>/dev/null | head -n1)"
export CC="$CLANG_DIR/clang"
export HOSTCC="$CLANG_DIR/clang"
export RUSTC="rustc"
export BINDGEN="bindgen"
export LIBCLANG_PATH="$WORKDIR/clang19/lib"
export LLVM=1 LLVM_IAS=1
export ARCH=arm64 SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LD=ld.lld HOSTLD=ld.lld AR=llvm-ar NM=llvm-nm AS=clang READELF=llvm-readelf
export OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump OBJSIZE=llvm-size STRIP=llvm-strip
KCFLAGS+=" -no-canonical-prefixes"
KCFLAGS+=" -O2"
KCFLAGS+=" -pipe"
KCFLAGS+=" -Wno-error"
KCFLAGS+=" -fno-stack-protector"
KCFLAGS+=" -D__ANDROID_COMMON_KERNEL__"
export KCFLAGS
echo "编译器信息:"
echo "Clang版本: $CLANG_VERSION"
echo "LLD版本: $LLD_VERSION"
echo "Rustc版本: $RUSTC_VERSION"
echo "Bindgen版本: $BINDGEN_VERSION"
pahole_version=$(pahole --version 2>/dev/null | head -n1); [ -z "$pahole_version" ] && echo "pahole版本：未安装" || echo "pahole版本：$pahole_version"
cd common
COMMON_REAL_PATH=$(pwd -P)
ROOT_REAL_PATH=$(dirname "$COMMON_REAL_PATH")
KCFLAGS+=" -fdebug-prefix-map=$ROOT_REAL_PATH=."
KCFLAGS+=" -fmacro-prefix-map=$ROOT_REAL_PATH=."
KCFLAGS+=" -ffile-prefix-map=$ROOT_REAL_PATH=."
export KCFLAGS
source "./_setup_env.sh" 2>/dev/null || true
echo "KCFLAGS=$KCFLAGS"
make -j$(nproc --all) \
    LLVM=1 \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CC="$CLANG_DIR/clang" \
    HOSTCC="$CLANG_DIR/clang" \
    LD=ld.lld \
    HOSTLD=ld.lld \
    RUSTC="rustc" \
    OBJCOPY="llvm-objcopy" \
    O=out \
    gki_defconfig Image 2>&1 | tee $WORKDIR/build.log
echo ">>> 内核编译成功！"

# ===== 选择使用 patch_linux (KPM补丁)=====
WORKDIR="$SCRIPT_DIR"
OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  echo ">>> 使用 kptools-linux 工具处理输出..."
  cd "$OUT_DIR"
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kptools-linux
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kpimg-linux
  chmod +x ./kptools-linux
  ./kptools-linux -p -i ./Image -k ./kpimg-linux -o ./oImage
  rm -f Image
  mv oImage Image
  echo ">>> 已成功打上KP-N补丁!"
fi

# ===== 克隆并打包 AnyKernel3 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 克隆 AnyKernel3 项目..."
git clone https://github.com/cctv18/AnyKernel3 --depth=1
echo ">>> 清理 AnyKernel3 Git 信息..."
rm -rf ./AnyKernel3/.git
echo ">>> 拷贝内核镜像到 AnyKernel3 目录..."
cp "$OUT_DIR/Image" ./AnyKernel3/
echo ">>> 进入 AnyKernel3 目录并打包 zip..."
cd "$WORKDIR/kernel_workspace/AnyKernel3"

if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  wget https://raw.githubusercontent.com/cctv18/oppo_oplus_realme_sm8850/refs/heads/main/zram.zip
fi
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  wget https://github.com/cctv18/KPatch-Next/releases/latest/download/kpn.zip
fi

# ===== 生成 ZIP 文件名 =====
ZIP_NAME="Anykernel3-${MANIFEST}"
if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-susfs"
fi
if [[ "$APPLY_WIREGUARD" == "y" || "$APPLY_WIREGUARD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-wg"
fi
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4kd"
fi
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4-zstd"
fi
if [[ "$USE_PATCH_LINUX" == "y" || "$USE_PATCH_LINUX" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-kpm"
fi
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbr"
fi
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  ZIP_NAME="${ZIP_NAME}-dss"
fi
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-adios"
fi
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-rek"
fi
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbg"
fi
ZIP_NAME="${ZIP_NAME}-v$(date +%Y%m%d).zip"

# ===== 打包 ZIP 文件 =====
echo ">>> 打包文件: $ZIP_NAME"
zip -r "../$ZIP_NAME" ./*
ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> 打包完成 文件所在目录: $ZIP_PATH"
