# Mac 客机完整步骤（Steam 版）

前提：**已经用 Steam 客户端把 Valheim 下载好**。Mac 是客机，通过 IP 加入 Windows 的世界。

> ⚠️ 这一步会让 Mac 侧脱离 Steam 正版身份。如果必须保持 Mac 正版，本方案不适用——见 `README.md`。

---

## 步骤 0：Steam 下载

1. Mac 打开 Steam，登录**同一个账号**
2. 库 → Valheim → 安装
3. 下载完成后**先不要启动**
4. 退出 Steam（`Cmd+Q`，检查菜单栏图标）

两台用同一账号下载的好处：**buildid 必然一致**，省掉版本对齐。

---

## 步骤 1：环境探测

```bash
cd scripts/mac
chmod +x *.sh
./01-detect.sh
```

脚本打印：

- macOS 版本、CPU 架构
- Valheim.app 路径与可执行文件架构
- `libsteam_api.dylib` 的实际位置、大小、**架构**
- 架构是否匹配本机（**关键检查**）
- `steam_settings` 现状
- `buildid`（和 Windows 对比）
- Steam 进程、签名状态、quarantine 状态
- 本机内网 IP

### 架构必须匹配

| Mac | 需要 dylib 架构 |
|---|---|
| Apple Silicon（M1/M2/M3/M4） | `arm64` 或 `universal` |
| Intel | `x86_64` |

脚本会直接告警不匹配。纯 `x86_64` 的 dylib 在 arm64 进程里加载会立刻崩。

**如果架构不匹配**，三条路：

1. 找 Goldberg 的 universal 构建（部分 release 提供）
2. 自己编译 macOS 版：
   ```bash
   git clone https://github.com/Mr_Goldberg/goldberg_emulator
   cd goldberg_emulator
   cmake -B build -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
   cmake --build build
   ```
3. 走 CrossOver 备选方案（见文末）

---

## 步骤 2：下载 Goldberg

```bash
mkdir -p ~/goldberg
# 浏览器下载 goldberg_emulator.zip 解压到 ~/goldberg
```

确认里面有 `libsteam_api.dylib`：

```bash
find ~/goldberg -name "libsteam_api.dylib"
```

没有输出 → 该 release 不含 macOS 构建，需要自编译或用 CrossOver。

---

## 步骤 3：打补丁

```bash
./02-apply-goldberg.sh --goldberg-dir ~/goldberg
```

或指定身份（客机默认就是 PlayerB）：

```bash
./02-apply-goldberg.sh \
  --goldberg-dir ~/goldberg \
  --account-name PlayerB \
  --steam-id 76561198000000002
```

脚本做的事：

1. 关闭 Steam（会询问）
2. `find` 定位 `libsteam_api.dylib`（兼容 `Contents/Plugins/` 和 `Contents/Frameworks/`）
3. **架构校验**，不匹配会警告并要求确认
4. 备份 `.orig`（只备份一次）
5. 覆盖 dylib
6. 在**两个候选位置**都写 `steam_settings`（`Contents/MacOS/` 和 dylib 同目录），Goldberg 会自己找
7. **自动重签名 + 清 quarantine**
8. 验证所有文件

### 打完补丁的结构

```
/Applications/Valheim.app/Contents/
├── MacOS/
│   ├── valheim
│   └── steam_settings/            ← 位置 1
│       ├── steam_appid.txt
│       ├── configs.user.ini
│       └── configs.main.ini
└── Plugins/steam_api.bundle/Contents/MacOS/
    ├── libsteam_api.dylib         ← Goldberg 版
    ├── libsteam_api.dylib.orig    ← 原版
    └── steam_settings/            ← 位置 2（冗余，保险）
```

两处都写是因为不同 Goldberg 版本查找路径不一致，冗余不影响。

---

## 步骤 4：重签名（脚本已自动做，可单独重跑）

```bash
./03-resign.sh
```

执行：

```bash
xattr -cr /Applications/Valheim.app
codesign --force --deep --sign - /Applications/Valheim.app
xattr -dr com.apple.quarantine /Applications/Valheim.app
```

**每次替换 dylib 后都必须重签**，否则双击图标闪一下就没了。

如果报 `resource fork, Finder information, or similar detritus not allowed`，脚本会自动 `xattr -cr` 后重试。

---

## 步骤 5：启动

```bash
./04-launch.sh --host 192.168.1.23 --port 2456
```

脚本会：

1. 校验补丁完整性（缺 `enable_lan_only=1` 直接拒绝）
2. 校验签名，无效则自动重签
3. 检查 Steam 进程，询问关闭
4. 检查游戏是否已在运行
5. 测试主机 ICMP 连通性（仅参考）
6. `open -a` 启动
7. **等 3 秒验证进程存活**，启动即崩会打印崩溃日志路径和常见原因

---

## 步骤 6：加入世界

1. Windows 那台已经 `Start Game` 进了世界
2. Mac 进游戏 → `Join Game`
3. 选 **`Join IP`**（不是 `Join with code`）
4. 填 `192.168.1.23:2456`
5. 输入世界密码（如果设了）

`Join IP` 选项找不到时，按 `F5` 开控制台：

```
connect 192.168.1.23:2456
```

---

## 常见问题

| 现象 | 处理 |
|---|---|
| 双击图标闪退 | 没重签名，跑 `./03-resign.sh` |
| 崩溃日志 `code signature invalid` | 同上，先 `xattr -cr` |
| 崩溃日志 `incompatible architecture` | dylib 架构不对，见步骤 1 |
| 崩溃日志 `Library not loaded` | 从 `.orig` 恢复后换 Goldberg 版本 |
| 无限 `Connecting...` | 两侧 `enable_lan_only` 没都设；或 buildid 不一致 |
| 连上后立刻断开 | `account_steamid` 与 Windows 重复 |
| 完全连不上 | 路由器 AP 隔离；或 Windows 防火墙只放行公用网络 |
| 游戏极卡 | 画质调 Medium，关 SSAO / 动态模糊 / 抗锯齿 |

崩溃日志位置：

```bash
ls -lt ~/Library/Logs/DiagnosticReports/ | head -5
log show --last 5m --predicate 'process CONTAINS "alheim"'
```

---

## 备选：Mac 侧搞不定时用 CrossOver

在 Mac 上用 **CrossOver** 或 **Parallels** 跑 **Windows 版 Valheim + Goldberg**。

优点：两台都是同一份 Windows 二进制，Goldberg 在 Windows 上成熟度远高，签名/架构问题全部消失。

CrossOver 步骤：

1. 装 CrossOver，新建 Windows 10 bottle
2. 把 Windows 那台的 `Valheim` 整个目录拷进 bottle（比在 bottle 里重下快）
3. 同样替换 `steam_api64.dll`，写 `steam_settings`（`account_steamid=...0002`）
4. 从 bottle 里启动 `valheim.exe`
5. `Join IP` 填 Windows 内网 IP

Valheim 配置要求不高，CrossOver 里 Medium 可玩。

---

## 更新游戏后

Steam 更新会覆盖 `libsteam_api.dylib`。重跑：

```bash
./01-detect.sh
./02-apply-goldberg.sh --goldberg-dir ~/goldberg
./03-resign.sh
```

---

## 回滚

```bash
./99-rollback.sh
```

恢复原版 dylib，移走 `steam_settings`，重签名，之后可正常通过 Steam 启动。
