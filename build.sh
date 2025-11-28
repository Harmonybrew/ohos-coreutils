#!/bin/sh
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    coreutils-9.9 \
    ohos-sdk \
    coreutils-9.9-ohos-arm64

# 准备 ohos-sdk
mkdir ohos-sdk
curl -L -O https://repo.huaweicloud.com/openharmony/os/6.0-Release/ohos-sdk-windows_linux-public.tar.gz
tar -zxf ohos-sdk-windows_linux-public.tar.gz -C ohos-sdk
cd ohos-sdk/linux
unzip -q native-*.zip
cd ../..

# 设置交叉编译所需的环境变量
export OHOS_SDK=${WORKDIR}/ohos-sdk/linux
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=aarch64-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=aarch64-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-D__MUSL__=1"
export CXXFLAGS="-D__MUSL__=1"

# 准备源码
curl -L -O https://mirrors.ustc.edu.cn/gnu/coreutils/coreutils-9.9.tar.gz
tar -zxf coreutils-9.9.tar.gz
cd coreutils-9.9

# 打个小补丁。这是为了让 gnulib 支持 ohos 平台。
# 相关参考资料：
# - 鸿蒙 musl 里面的文件结构体定义：https://gitcode.com/openharmony/third_party_musl/blob/OpenHarmony-v6.0-Release/porting/linux/user/src/internal/stdio_impl.h#L74
# - 鸿蒙 musl 里面的 __freadahead、__freadptr、__freadptrinc 内部接口实现：https://gitcode.com/openharmony/third_party_musl/blob/OpenHarmony-v6.0-Release/src/stdio/ext2.c#L4
patch -p1 < ../0001-port-gnulib-to-ohos.patch

# 编译 coreutils
./configure --prefix=${WORKDIR}/coreutils-9.9-ohos-arm64 --host=aarch64-linux gl_cv_func_pthread_rwlock_init=no
make -j$(nproc)
make install
cd ..

# 履行开源义务，将 license 随制品一起发布
cp coreutils-9.9/COPYING coreutils-9.9-ohos-arm64/
cp coreutils-9.9/AUTHORS coreutils-9.9-ohos-arm64/

# 打包最终产物
tar -zcf coreutils-9.9-ohos-arm64.tar.gz coreutils-9.9-ohos-arm64
