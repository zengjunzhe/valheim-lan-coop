# 二进制核查记录

实际下载并分析的文件。**二进制本身不入库**（体积大、且随时可重下），只记录校验值和关键属性。

## libsteam_api.dylib（macOS）

来源：`aaf2tbz/goldberg_emulator` release `latest`（2026-08-14）

```
大小: 6,045,408 bytes (5903 KB)
魔数: cafebabe (FAT universal, big-endian)
架构: x86_64 + arm64
```

`file` 输出：

```
Mach-O universal binary with 2 architectures:
  [x86_64: Mach-O 64-bit x86_64 dynamically linked shared library,
   flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|WEAK_DEFINES|BINDS_TO_WEAK|NO_REEXPORTED_DYLIBS|HAS_TLV_DESCRIPTORS>]
  [arm64: Mach-O 64-bit arm64 dynamically linked shared library,
   flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|WEAK_DEFINES|BINDS_TO_WEAK|NO_REEXPORTED_DYLIBS|HAS_TLV_DESCRIPTORS>]
```

导出符号（`strings -a | grep -E "^Steam"`）：

- 总计 372 个 `Steam*` 符号
- `SteamAPI_Init`
- `SteamNetworkingSockets001/002/003/004/006/008/009/011/012/013`
- `SteamNetworkingSocketsSerialized002/003/004`
- `SteamMatchmaking` 系列

配置键实测（`strings | grep -c`）：

| 键 | 次数 |
|---|---|
| `enable_lan_only` | **0** |
| `disable_lan_only` | 2 |
| `disable_networking` | 2 |
| `listen_port` | 4 |
| `custom_broadcasts` | 4 |
| `old_p2p_packet_sharing_mode` | **0** |

存档路径字节（Python 直接读文件定位 ` Saves` 前内容）：

```
Go\0ld\0be\0rg \0St\0ea\0mE\0mu\0 Saves\0
```

拼接 → `Goldberg SteamEmu Saves`

非 Windows 分支逻辑（`dll/local_storage.cpp`）：

```c
char *datadir = getenv("XDG_DATA_HOME");
if (datadir) { user_appdata_path = datadir; }
else {
    char *homedir = getenv("HOME");
    if (homedir) user_appdata_path = std::string(homedir) + "/.local/share";
}
return user_appdata_path + "/" + "Goldberg SteamEmu" + " Saves";
```

> macOS 上 `XDG_DATA_HOME` 通常未设置，`HOME` 有值 → `~/.local/share/Goldberg SteamEmu Saves`。
> 但 emu 内部可能还有 `Library/Application Support` 分支，**实际路径需在真机验证**。

## libsteam_api64.dll（Windows）

同 release。

```
大小: 6,049,923 bytes (5908 KB)
MZ:   b'MZ'
PE:   offset 0x80, sig b'PE\x00\x00'
machine: 0x8664 (x64)  ← 正确，非 x86
```

配置键实测：

| 键 | 次数 |
|---|---|
| `custom_broadcasts` | 2 |
| `listen_port` | 1 |
| `disable_networking` | 1 |
| `force_steamid` | 1 |

## 复现方式

```bash
# 下载
curl -sL -o libsteam_api.dylib \
  "$(curl -s https://api.github.com/repos/aaf2tbz/goldberg_emulator/releases/latest \
     | python3 -c 'import json,sys; d=json.load(sys.stdin); print([a["browser_download_url"] for a in d["assets"] if a["name"]=="libsteam_api.dylib"][0])')"

# 架构
file libsteam_api.dylib

# 配置键
for kw in enable_lan_only disable_lan_only disable_networking listen_port custom_broadcasts; do
  echo "$kw: $(strings -a libsteam_api.dylib | grep -c "$kw")"
done
```
