# macOS 网络层：已修好 emulator，但卡在 Valheim 不开监听

> 2026-11-15 深夜。承接 `10-mac-verified.md` 的结论（aaf2tbz 构建网络层为空实现）。
> **进展：换构建 + 自建薄壳后，macOS 上 emulator 的 P2P 真的能用了。卡点转移到了 Valheim 侧。**

---

## 一、换掉 aaf2tbz 的构建

`aaf2tbz` 的 dylib 是空实现。实测这两个 macOS 构建**网络功能是好的**（会绑 47584）：

| 仓库 | 构建 | 体积 | 状况 |
|---|---|---|---|
| `da-wood69/goldberg-emulator-macos` | `macos-universal-2026-09-02`（universal） | 4.4 MB zip | ✅ 采用 |
| `surf5726/goldberg_emulator_macos` | `v0.2.5`（仅 arm64） | 3.2 MB | ✅ 也绑 47584 |
| `aaf2tbz/goldberg_emulator` | `latest`（universal） | 6.0 MB | ❌ 零 socket |

判据（同一个探针，调 `CreateListenSocketP2P` 后看进程 socket）：

```
da-wood69 / surf5726:  UDP *:47584 + TCP *:47584 (LISTEN) + 和 192.168.5.12 的 TCP 连接
aaf2tbz:               无
```

## 二、缺 v012 取用函数，用薄壳补上

这些构建（含上游 `gbe_fork`）只导出 `SteamAPI_SteamNetworkingSockets_v008/_v009`
和 `SteamAPI_SteamNetworkingUtils_v003`，而 Valheim 要 `_v012` / `_v004`。

但它们**内部实现已经是 v012 布局**（导出了 `GetConnectionRealTimeStatus`、
`ConfigureConnectionLanes` 等 v012 专有方法），所以只要补一个转发的取用函数：

```c
extern void *SteamAPI_SteamNetworkingSockets_v009(void);
extern void *SteamAPI_SteamNetworkingUtils_v003(void);

__attribute__((visibility("default")))
void *SteamAPI_SteamNetworkingSockets_v012(void) { return SteamAPI_SteamNetworkingSockets_v009(); }
__attribute__((visibility("default")))
void *SteamAPI_SteamNetworkingUtils_v004(void)   { return SteamAPI_SteamNetworkingUtils_v003(); }
```

编译（重导出 + 同级 rpath）：

```bash
cp libsteam_api.dylib libsteam_api_emu.dylib
install_name_tool -id @rpath/libsteam_api_emu.dylib libsteam_api_emu.dylib
codesign --force --sign - libsteam_api_emu.dylib

clang -dynamiclib -O2 -arch arm64 -arch x86_64 -o libsteam_api.dylib shim.c \
  -Wl,-reexport_library,"$PWD/libsteam_api_emu.dylib" \
  -Wl,-install_name,@rpath/libsteam_api.dylib
install_name_tool -add_rpath @loader_path libsteam_api.dylib
codesign --force --sign - libsteam_api.dylib
```

装进游戏：`steam_api.bundle/Contents/MacOS/` 放 `libsteam_api.dylib`（薄壳）+
`libsteam_api_emu.dylib`（真身），然后只签外层 app（**不要 `--deep`**，
`steam_settings` 是数据目录，`--deep` 会报 "code object is not signed at all"）。

验证：

```
SNS v012 iface=0x...   ← 非空
Utils v004 iface=0x... ← 非空
CreateListenSocketP2P(0) -> 1
UDP *:47584 / TCP *:47584 LISTEN
TCP 192.168.5.11:47584 <- 192.168.5.12:11395  ESTABLISHED   ← 已经和 Windows 那台在通信
```

另外，`SteamInternal_CreateInterface` 只认 `SteamClient020`，但
`ISteamClient::GetISteamGenericInterface` 对各版本都返回**不同的**对象：

```
GetGeneric("SteamNetworkingSockets012") -> 0x...fb08   ← 和 v009 的 0x...fb00 不同
GetGeneric("SteamNetworkingUtils004")   -> 0x...fa68
```

## 三、新的卡点：Valheim 自己不开监听 socket

进了世界（`ZNet Start`、`ZNet.LoadWorld`、`Loading: Done` 全部正常），但：

```
进程 socket：只有 UDP *:54848（Unity 的临时 port）+ 两条到 PlayFab 的 TCP
netstat | grep 2456|47584  → 空
```

用带日志的薄壳拦截这些调用，**一条都没触发**：

```
拦过：SteamAPI_Init                              → 只有 INIT 打出来
      SteamAPI_SteamNetworkingSockets_v012/v011/v010/v009
      SteamAPI_SteamNetworkingUtils_v004/v003
      SteamAPI_SteamNetworking_v006
      SteamAPI_SteamNetworkingMessages_v002
      SteamAPI_SteamMatchmaking_v009 / MatchmakingServers_v002
      CreateListenSocketP2P / CreateListenSocketIP / ConnectP2P
      SteamInternal_CreateInterface
结果：只有 INIT -> 0x1 和 CreateInterface("SteamClient020")
```

即：Valheim 只问 emulator 要了 SteamClient，然后**再没碰过任何网络接口**，
更没让 emulator 建监听 socket。日志里 `Authentication:k_ESteamNetworkingAvailability_Current`
说明 emulator 报告的 Steam 网络状态是"可用"，所以不是状态判断挡的。

## 四、推断：跨平台（PlayFab Party）开着

`assembly_valheim.dll` 里有 `m_crossplay`、`m_crossplayServerToggle`、`-crossplay`、
`CrossplayAllowed`、`SetCrossplayPrivilege` —— 跨平台是**世界级开关**。
UI 上「跨平台游戏」是橙色实心圆（开启），「启动服务器」「社区服务器」是灰色不可选。
开了跨平台 → ZNet 走 PlayFab Party，而 PlayFab 用 Goldberg 的伪造 ticket 必然登不上
（日志里 `errorcode:3 / errorcode:101`），于是既不建 Steam 监听也不建 PlayFab 网络。

UI 上这个开关点不动（本机实测：点不掉），所以当前所有世界都卡在这一条。

## 五、还没排除的可能

1. **Valheim 1.0.21 的通病**，不是 macOS 特有 → 需要 Windows 那台验证：
   在 Windows 上进一个世界，`Get-NetUDPEndpoint` 看除 47584 之外有没有新端口。
   有 → Valheim 会开监听，问题在 Mac 侧（可能是薄壳的对象不对）。
   没有 → Windows 也一样不开，那整条路被 Valheim 的跨平台默认值挡死。
2. **跨平台标志可能存进世界文件**。`_main.0.fwl2`（51 字节）结构尚未定位到该位；
   需要一个「跨平台关闭」的世界做对照 diff。
3. **改 `assembly_valheim.dll`** 强制 `crossplay=false`（IL patch，1~2 小时，脏但直接）。
4. **换 Valheim 专用服务器**：Mac 的 bundle 里**没有** `valheim_server`（只有 `Valheim`），
   要另装 896660，且需要另一套 emulator 支持。

## 六、可用的文件

- `scripts/mac/shim/shim.c`：带探针的薄壳源码（`WRAP` 宏可加任意符号）
- `~/goldberg/mac-shim/`：构建产物（`libsteam_api.dylib` 薄壳 + `libsteam_api_emu.dylib`）
- `~/goldberg/candidates/`：下载的候选构建
- 探针日志：`/tmp/steamapi_shim.log`
