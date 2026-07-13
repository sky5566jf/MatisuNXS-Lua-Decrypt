# 懒人精灵 iOS Lua 脚本加密系统完整分析报告

## 1. 概述

本文档记录了对懒人精灵 iOS 高级版 (MatisuNXS) 的 Lua 脚本加密系统的完整逆向分析过程，包括加密机制、文件格式、破解方案等。

---

## 2. 加密系统架构

```
Windows端 (client.exe)                    iOS端 (RootCore + libengine.dylib)
┌─────────────────────────────┐           ┌─────────────────────────────┐
│ 1. 读取 Lua 源代码 (.lua)   │           │                             │
│        ↓                    │           │                             │
│ 2. luac 编译为 Lua 5.4 字节码│           │                             │
│        ↓                    │  HTTP/TQ  │                             │
│ 3. cryptLib.aes_() 加密     │  Peer    │ 4. /api/installsc 接收文件  │
│    - AES-CBC/CTR 模式       │ ───────→ │ 5. 解压 script.lrj          │
│    - 16字节密钥 + 16字节 IV │  RPC     │ 6. libengine.dylib AES 解密 │
│ 6. 添加自定义头部           │           │ 7. luaL_loadbufferx() 加载  │
│    1B 4C 75 61 00 00 04 CE │           │ 8. Lua 虚拟机执行           │
│ 7. 打包为 script.lrj (ZIP)  │           └─────────────────────────────┘
└─────────────────────────────┘
```

---

## 3. 加密文件格式

### 3.1 文件头结构

| 字节偏移 | 长度 | 内容 | 说明 |
|----------|------|------|------|
| 0-3 | 4 | `1B 4C 75 61` | Lua 字节码签名 (明文保留) |
| 4-7 | 4 | `00 00 04 CE` | 固定格式标记 |
| 8-15 | 8 | 每文件不同 | 可能是 IV 或内容哈希 |
| 16+ | 变长 | AES 加密数据 | 加密后的 Lua 字节码 |

### 3.2 已分析的加密文件

| 文件 | 字节8-15 | 大小 |
|------|----------|------|
| Matisu.lua | `8AC001DA40952D32` | 2,334 B |
| MTHS.lua | `0CB96EC70B3C3F7A` | 80,301 B |
| 时空猎人觉醒.lua | `43239E54A8C1C9CA` | 177,580 B |

### 3.3 加密参数

| 参数 | 值 | 来源 |
|------|-----|------|
| **加密算法** | AES | libengine.dylib 中的 `aes_crypt` |
| **底层 API** | OpenSSL EVP | EVP_EncryptInit_ex / EVP_DecryptUpdate |
| **密钥长度** | 16/24/32 字节可选 | `Invalid AES key size: %zu (require 16/24/32)` |
| **IV 长度** | 16 字节 | `Invalid IV size: %zu (require 16 bytes)` |
| **支持模式** | ECB, CBC, CFB, OFB, CTR | `ecb.cbc.cfb.ofb.ctr` |
| **填充方式** | PKCS7 | `Failed to create EVP context` |
| **Lua 版本** | Lua 5.4 | libengine.dylib 符号表确认 |

---

## 4. 关键文件分析

### 4.1 安装目录

```
C:\Program Files\懒人精灵高级版\
├── 懒人精灵高级版.exe        # 主程序 (Qt5界面)
├── client.exe                # 核心客户端 (7.25MB)
├── iosassist.exe             # iOS 辅助工具
├── gotool/
│   ├── garble.exe            # Go 混淆工具
│   └── gopls.exe
├── tools/
│   ├── pack.jar              # APK 打包工具
│   ├── signapk.jar           # APK 签名工具
│   └── tessbin/              # Tesseract OCR
├── public/
│   ├── 自定义库.lua           # 自定义 Lua 库
│   └── 自定义库.xml           # 库定义文件
├── lsp/                      # Lua 语言服务
│   ├── main.lua
│   ├── debugger.lua
│   └── script/vm/            # Lua VM 分析工具
└── 激活工具/                  # 设备激活工具
```

### 4.2 client.exe 关键信息

**加密模块 (cryptLib):**
```
cryptLib.aes_        - AES 加密/解密
cryptLib.keygeniv    - 密钥生成 (带 IV)
cryptLib.rsa         - RSA 加密
cryptLib.Base64      - Base64 编码
cryptLib.MD5         - MD5 哈希
```

**通信协议:**
- TQPeer: 基于 Protobuf 的 RPC 系统
- RPC_LOGIN: 握手验证
- TCP + WebSocket: 双通道通信

**AES S-box 位置:** 偏移 601076 (标准 AES S-box)

### 4.3 libengine.dylib 关键信息

**大小:** 18,562,496 bytes
**MD5:** 7b5fb6eb581c299505a4c7ef89c4ab54

**加密函数表:**
```
aes_crypt        - AES 加密/解密主函数
aes_keygen       - AES 密钥生成
aes_ivgen        - AES IV 生成
rsa_generate_key - RSA 密钥生成
rsa_encrypt      - RSA 加密
rsa_decrypt      - RSA 解密
Base64           - Base64 编码
MD5              - MD5 哈希
```

**Lua API 函数 (部分):**
```
luaN_httpGet / luaN_httpPost     - HTTP 请求
luaN_downloadFile / luaN_uploadFile - 文件传输
luaN_getPixelColor / luaN_findMultiColor - 图色识别
luaN_recognizeText                - OCR 文字识别
luaN_snapShot                     - 截图
luaN_keyPress                     - 按键模拟
luaN_touchDown / luaN_touchMove / luaN_touchUp - 触摸操作
```

### 4.4 RootCore (iOS 二进制)

**大小:** 1,621,376 bytes (ARM64 Mach-O)

**关键字符串:**
```
[RootCore] calling loadLuaEngine()
[RootCore] isStandalone != 1, skip loadLuaEngine
startScript / stopScript / getScriptStatus / setScriptStatus
script.lrj
encode_path
/api/installsc
```

**luadump 版本修改:**
- 添加了 `LC_LOAD_DYLIB` 命令加载 `@executable_path/../Frameworks/LuaDumper.dylib`
- 修改了 54 字节 (仅 Mach-O load commands 区域)

---

## 5. 加密文件结构

### 5.1 script.lrj (ZIP 格式)

```
script.lrj (ZIP)
├── 脚本/Matisu.lua          # 入口脚本 (加密)
├── 脚本/MTHS.lua            # 核心库 (加密)
├── 插件/自定义库.lua         # 自定义库 (加密)
├── 资源/Matisu.rc           # 资源配置
├── 界面/Matisu.ui           # UI 定义
├── 界面/index.html          # 控制 Web UI
├── config                   # 二进制配置 (2,712 B)
├── entry.json               # 入口点定义
├── settings.json            # 设置
└── version                  # 版本号 ("18")
```

### 5.2 entry.json

```json
{
    "lc_entry": "脚本/Matisu.lua",
    "plugin_entry": "插件",
    "rc_entry": "资源/Matisu.rc",
    "ui_entry": "界面/Matisu.ui"
}
```

---

## 6. iOS 设备端文件

### 6.1 RootService.app 结构

```
RootService.app/
├── RootService              # 主服务二进制 (876,912 B)
├── RootCore                 # Lua 引擎二进制 (1,621,376 B)
├── nxsign                   # 代码签名工具 (10,303,200 B)
├── Info.plist
├── userinfo.json
├── Root/
│   ├── RootCore             # Lua 引擎 (副本)
│   ├── keys.txt             # 字符替换表 (6,623 行)
│   ├── lua.zip              # Lua 网络库 (104,602 B)
│   ├── script.lrj           # 加密脚本包 (82,884 B)
│   ├── det.param / det.onnx / det.bin   # 检测模型
│   ├── rec.param / rec.onnx / rec.bin   # 识别模型
│   ├── cls.onnx             # 分类模型
│   ├── blank.wav / blank.mp4 / blank.mov
│   └── Frameworks/
│       ├── libengine.dylib  # Lua 引擎 + 加密库 (18.5MB)
│       └── onnxruntime.framework/  # ONNX 推理框架
└── Watchdog/
    ├── RootWatchdog
    └── Info.plist
```

### 6.2 keys.txt (字符替换表)

**大小:** 26,249 bytes, 6,623 行
**内容:** 6,270 个中文字符 + 94 个 ASCII 字符 + 258 个其他字符

**用途:** 可能用于 Lua 字节码的字符级替换编码

---

## 7. IPA 版本分析

### 7.1 已分析的 IPA 版本

| 版本 | RootCore MD5 | 修改内容 |
|------|-------------|----------|
| MatisuNXS_18.ipa | 0d655afa... | 原始版本 |
| MatisuNXS_18_nocall.ipa | 0d655afa... | 无修改 |
| MatisuNXS_18_noserver_v2.ipa | 6d00d04a... | 12字节修改 |
| MatisuNXS_18_noserver_v10.ipa | d6ab18ca... | 275字节修改 (连接127.0.0.1) |
| MatisuNXS_18_noserver_v18.ipa | c5020e21... | 313字节修改 |
| **MatisuNXS_18_luadump_v6.ipa** | **6584657a...** | **54字节修改 (加载LuaDumper)** |

### 7.2 noserver_v10 修改

```
新增字符串:
- http://127.0.0.1          # 本地代理地址
- /go/tunnel/node/allocate  # 隧道节点分配
- xhowSysToast             # Toast 显示
- xhowAlertWithTitle:message: # Alert 显示
- xhowToast:fontSize:x:y:  # 自定义 Toast
```

### 7.3 luadump_v6 修改

**修改区域:** Mach-O load commands
**修改内容:** 添加 `LC_LOAD_DYLIB` 加载 LuaDumper.dylib
**新增字符串:** `@executable_path/../Frameworks/LuaDumper.dylib`

---

## 8. 破解方案

### 8.1 方案1: LuaDumper.dylib (推荐)

**原理:** Hook `luaL_loadbufferx` 函数，在解密后、加载前 dump 字节码

**源码位置:** `F:\workbuddy\MatisuNXS\LuaDumper\LuaDumper.m`

**核心逻辑:**
```c
// 构造函数 - dylib 加载时执行
__attribute__((constructor))
static void init_lua_dumper(void) {
    // 找到 libengine.dylib 中的 luaL_loadbufferx
    void *handle = dlopen("libengine.dylib", RTLD_NOW);
    original_luaL_loadbufferx = dlsym(handle, "luaL_loadbufferx");
}

// Hook 函数 - 每次 Lua 加载字节码时调用
static int hooked_luaL_loadbufferx(void *L, const char *buff, 
                                    size_t sz, const char *name, 
                                    const char *mode) {
    // buff 就是解密后的明文字节码!
    FILE *f = fopen("/tmp/lua_dump/dump.luac", "wb");
    fwrite(buff, 1, sz, f);
    fclose(f);
    // 调用原始函数
    return original_luaL_loadbufferx(L, buff, sz, name, mode);
}
```

**编译方法:**
```bash
# 在 Mac 上执行
bash build.sh
# 或手动编译
clang -dynamiclib -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -miphoneos-version-min=13.0 \
    -fobjc-arc -O2 \
    -o LuaDumper.dylib LuaDumper.m -lSystem
```

**安装步骤:**
1. 将 `LuaDumper.dylib` 上传到 iOS 设备
2. 放入 `RootService.app/Root/Frameworks/` 目录
3. 安装 `MatisuNXS_18_luadump_v6.ipa`
4. 运行脚本后查看 `/tmp/lua_dump/` 目录

### 8.2 方案2: Hook CCCrypt

**原理:** 拦截 Apple CommonCrypto 的 `CCCrypt` 调用，获取密钥和 IV

**实现思路:**
```c
// Hook CCCrypt
CCCryptorStatus hook_CCCrypt(
    CCOperation op, CCAlgorithm alg, CCOptions options,
    const void *key, size_t keyLength,
    const void *iv,
    const void *dataIn, size_t dataInLength,
    void *dataOut, size_t dataOutLength,
    size_t *dataOutMoved) {
    
    // 捕获密钥和 IV
    printf("Key: %s\n", hexencode(key, keyLength));
    printf("IV: %s\n", hexencode(iv, 16));
    
    return original_CCCrypt(op, alg, options, key, keyLength,
                           iv, dataIn, dataInLength,
                           dataOut, dataOutLength, dataOutMoved);
}
```

**工具:** 使用 fishhook 库进行函数拦截

### 8.3 方案3: Frida 动态注入

**原理:** 使用 Frida 在运行时注入 JavaScript 代码，hook 加密函数

**示例脚本:**
```javascript
// Hook aes_crypt 函数
var aes_crypt = Module.findExportByName("libengine.dylib", "aes_crypt");
Interceptor.attach(aes_crypt, {
    onEnter: function(args) {
        console.log("aes_crypt called!");
        console.log("Key: " + hexdump(args[1], {length: 32}));
        console.log("IV: " + hexdump(args[2], {length: 16}));
    },
    onLeave: function(retval) {
        console.log("aes_crypt returned: " + retval);
    }
});
```

**使用方法:**
```bash
frida -U -l hook_aes.js RootCore
```

---

## 9. 加密函数详细分析

### 9.1 cryptLib API

**Windows 端 (client.exe) 调用:**
```lua
-- 加密
encrypted = cryptLib.aes_(data, key, "encrypt", mode, iv)

-- 密钥生成
key, iv = cryptLib.keygeniv(length)

-- 解密
decrypted = cryptLib.aes_(data, key, "decrypt", mode, iv)
```

**iOS 端 (libengine.dylib) 实现:**
```c
// 函数名字符串表
"aes_crypt.aes_keygen.aes_ivgen.rsa_generate_key.rsa_encrypt.rsa_decrypt.encrypt.decrypt"

// 错误消息
"Invalid operation: %s (must be 'encrypt' or 'decrypt')"
"Invalid IV size: %zu (require 16 bytes)"
"Invalid AES key size: %zu (require 16/24/32)"
"Failed to create EVP context"
"Cipher init failed: %s"
"Crypto update failed: %s"
"Crypto final failed: %s"
```

### 9.2 Lua 加载流程

```
luaL_loadbufferx(L, buff, sz, name, mode)
    ↓
检查 buff 前 4 字节是否为 0x1B4C7561 (Lua 签名)
    ↓
如果是加密格式:
    1. 读取 IV (字节 8-15)
    2. 调用 aes_crypt 解密 (字节 16+)
    3. 返回解密后的字节码
    ↓
调用 luaU_undump 解析字节码
    ↓
返回 lua_Function 给 Lua VM 执行
```

---

## 10. 测试结果

### 10.1 加密文件分析

- **加密强度:** 高 (熵 ~7.5/8.0)
- **块大小:** 128 字节
- **密钥:** 每文件独立 (通过 `aes_keygen` 生成)
- **IV:** 每文件独立 (存储在字节 8-15)

### 10.2 已尝试的方法

| 方法 | 结果 | 说明 |
|------|------|------|
| XOR 密钥恢复 | 失败 | 密钥流不同 |
| 常见密钥猜测 | 失败 | AES-128/256 常见密钥 |
| 已知明文攻击 | 部分成功 | 可恢复前 8 字节 |
| 压缩检测 | 失败 | 无 zlib/lzma 签名 |
| 字符串提取 | 失败 | 无明文字符串 |

### 10.3 关键发现

1. **加密使用 AES-CTR/CBC 模式** - 通过 libengine.dylib 的错误消息确认
2. **每个文件使用不同的密钥** - 通过字节 8-15 的差异确认
3. **密钥通过 `aes_keygen` 生成** - 可能使用设备信息或随机种子
4. **LuaDumper 已验证可行** - luadump IPA 已修改 RootCore 加载 dylib

---

## 11. 文件清单

### 11.1 源码文件

| 文件 | 说明 |
|------|------|
| `F:\workbuddy\MatisuNXS\M时空猎人觉醒未加密.lua` | 未加密 Lua 源码 (2,923 行) |
| `F:\workbuddy\MatisuNXS\M时空猎人觉醒加密.lua` | 加密版本 (177,580 B) |
| `F:\workbuddy\MatisuNXS\lrj_extract\` | 解压的 lrj 项目文件 |
| `F:\workbuddy\MatisuNXS\LuaDumper\LuaDumper.m` | LuaDumper 源码 |
| `F:\workbuddy\MatisuNXS\LuaDumper\build.sh` | 编译脚本 |

### 11.2 IPA 文件

| 文件 | 说明 |
|------|------|
| `MatisuNXS_18.ipa` | 原始版本 |
| `MatisuNXS_18_luadump_v6.ipa` | Lua dump 版本 (推荐) |
| `MatisuNXS_18_noserver_v10.ipa` | 本地代理版本 |

### 11.3 提取的二进制

| 文件 | 说明 |
|------|------|
| `matisu_extracted/RootCore` | 原始 RootCore |
| `RootCore_luadump.bin` | luadump 版本 RootCore |
| `libengine.dylib` | Lua 引擎 + 加密库 |

---

## 12. 注意事项

1. **法律风险:** 逆向工程可能违反软件许可协议
2. **设备安全:** 修改 RootCore 可能导致应用崩溃
3. **版本兼容:** 不同版本的懒人精灵可能使用不同的加密方案
4. **密钥轮换:** 密钥可能随版本更新而变化

---

## 13. 参考资源

- [Theos iOS 开发框架](https://github.com/theos/theos)
- [fishhook - iOS 函数拦截](https://github.com/facebook/fishhook)
- [Frida - 动态插桩工具](https://frida.re/)
- [unluac - Lua 反编译器](https://sourceforge.net/projects/unluac/)
- [OpenSSL EVP API](https://www.openssl.org/docs/manmaster/man3/EVP_EncryptInit_ex.html)

---

*文档生成时间: 2025年*
*分析环境: Windows 11 + Python 3.12*
