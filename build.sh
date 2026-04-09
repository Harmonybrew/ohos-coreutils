#!/bin/sh
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    ohos-sdk \
    daily_build.log \
    manifest_tag.xml \
    coreutils-9.10 \
    coreutils-9.10-ohos-arm64

# 准备 ohos-sdk
curl -fL -o ohos-sdk-full_6.1-Release.tar.gz https://cidownload.openharmony.cn/version/Master_Version/OpenHarmony_6.1.0.31/20260311_020435/version-Master_Version-OpenHarmony_6.1.0.31-20260311_020435-ohos-sdk-full_6.1-Release.tar.gz
tar -zxf ohos-sdk-full_6.1-Release.tar.gz
rm -rf ohos-sdk-full_6.1-Release.tar.gz ohos-sdk/windows ohos-sdk/ohos
cd ohos-sdk/linux
unzip -q native-*.zip
unzip -q toolchains-*.zip
rm -rf *.zip
cd ../..

# 设置交叉编译所需的环境变量
LLVM_BIN=$WORKDIR/ohos-sdk/linux/native/llvm/bin
export CC=$LLVM_BIN/aarch64-unknown-linux-ohos-clang
export CXX=$LLVM_BIN/aarch64-unknown-linux-ohos-clang++
export LD=$LLVM_BIN/ld.lld
export AR=$LLVM_BIN/llvm-ar
export AS=$LLVM_BIN/llvm-as
export NM=$LLVM_BIN/llvm-nm
export OBJCOPY=$LLVM_BIN/llvm-objcopy
export OBJDUMP=$LLVM_BIN/llvm-objdump
export RANLIB=$LLVM_BIN/llvm-ranlib
export STRIP=$LLVM_BIN/llvm-strip

# 准备源码
curl -fLO https://ftp.gnu.org/gnu/coreutils/coreutils-9.10.tar.gz
tar -zxf coreutils-9.10.tar.gz
cd coreutils-9.10

# 打个小补丁。这是为了让 gnulib 支持 ohos 平台。
# 相关参考资料：
# - 鸿蒙 musl 里面的文件结构体定义：https://gitcode.com/openharmony/third_party_musl/blob/OpenHarmony-v6.0-Release/porting/linux/user/src/internal/stdio_impl.h#L74
# - 鸿蒙 musl 里面的 __freadahead、__freadptr、__freadptrinc 内部接口实现：https://gitcode.com/openharmony/third_party_musl/blob/OpenHarmony-v6.0-Release/src/stdio/ext2.c#L4
patch -p1 < ../0001-port-gnulib-to-ohos.patch

# 编译 coreutils
./configure \
    --prefix=$WORKDIR/coreutils-9.10-ohos-arm64 \
    --host=aarch64-linux-musl \
    --enable-no-install-program=date
make -j$(nproc)
make install
cd ..

# 进行代码签名
cd $WORKDIR/coreutils-9.10-ohos-arm64
find . -type f \( -perm -0111 -o -name "*.so*" \) | while read FILE; do
    if file -b "$FILE" | grep -iqE "elf|sharedlib|ELF|shared object"; then
        echo "Signing binary file $FILE"
        ORIG_PERM=$(stat -c %a "$FILE")
        $WORKDIR/ohos-sdk/linux/toolchains/lib/binary-sign-tool sign -inFile "$FILE" -outFile "$FILE" -selfSign 1
        chmod "$ORIG_PERM" "$FILE"
    fi
done
cd $WORKDIR

# 履行开源义务，将 license 随制品一起发布
cp coreutils-9.10/COPYING coreutils-9.10-ohos-arm64/
cp coreutils-9.10/AUTHORS coreutils-9.10-ohos-arm64/

# 打包最终产物
tar -zcf coreutils-9.10-ohos-arm64.tar.gz coreutils-9.10-ohos-arm64
