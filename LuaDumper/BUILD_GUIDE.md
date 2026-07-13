# LuaDumper.dylib 编译指南

## 概述
LuaDumper.dylib 用于 hook `luaL_loadbufferx` 函数，在 Lua 字节码解密后、加载前将其 dump 到文件。

## 前置条件
需要一台 Mac 电脑（或 Mac 虚拟机）来编译 iOS dylib。

## 步骤

### 1. 安装 Theos
```bash
# 在 Mac 上执行
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
$THEOS/bin/install-theos
```

### 2. 复制源码
将 `F:\workbuddy\MatisuNXS\LuaDumper\` 目录下的文件复制到 Mac。

### 3. 编译
```bash
cd LuaDumper
make package FINALPACKAGE=1
```

### 4. 获取编译产物
编译完成后，在 `com.yourname.luadumper/` 目录下找到 `LuaDumper.dylib`。

### 5. 安装到设备
将 `LuaDumper.dylib` 放入 iOS 设备的：
```
/var/mobile/Media/0000.../RootService.app/Root/Frameworks/
```

或通过懒人精灵的文件管理功能上传。

### 6. 使用 luadump 版本的 IPA
使用 `MatisuNXS_18_luadump_v6.ipa` 安装到设备，该版本已修改 RootCore 加载 LuaDumper.dylib。

### 7. 查看 dump 结果
```bash
# 在设备上查看 dump 的字节码
ls /tmp/lua_dump/
# 文件格式: 0000_unknown.luac, 0001_xxx.luac, ...
```

## 使用 luadec 反编译
dump 出来的 `.luac` 文件可以用 `luadec` 反编译：
```bash
# 安装 luadec
brew install luadec

# 反编译
luadec 0001_Matisu.luac > Matisu_decompiled.lua
```

## 注意事项
- luadump IPA 中的 RootCore 已被修改，会尝试加载 `@executable_path/../Frameworks/LuaDumper.dylib`
- 如果 dylib 不存在，RootCore 会正常运行（只是不会 dump）
- dump 的文件保存在 `/tmp/lua_dump/` 目录
- 每次重启后 `/tmp` 会被清空
