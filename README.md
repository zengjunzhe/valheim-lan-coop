# ⚠️ 本仓库当前状态：未经证实的方案

> **2026-11-15 更新：核心技术论断已被推翻。**
>
> 详细核查见 **[`docs/08-verification.md`](docs/08-verification.md)**。
>
> **`scripts/` 目录下的脚本基于错误的配置键，按现状执行必然失败。**

---

## 一句话现状

| 项 | 状态 |
|---|---|
| 目标 | Valheim 局域网双人联机，一份 Steam 授权 |
| 技术路线 | Goldberg Steam Emulator 替换 steam api |
| 可行性 | **技术上有希望，但未实测** |
| 现有脚本 | **配置键全错，不能直接用** |
| 现成方案 | **GitHub 上找不到任何现成项目** |
| 下一步 | 先在 Mac 上做单机验证，通过后再谈联机 |

---

## 关键错误（已修正到 08 号文档）

| 之前写的 | 实际 |
|---|---|
| `github.com/Mr_Goldberg/goldberg_emulator` | 404。原版在 `gitlab.com/Mr_Goldberg/goldberg_emulator` |
| 核心配置 `enable_lan_only=1` | **该键不存在**，两个项目的二进制里都搜不到 |
| 两端都写 `configs.main.ini` | Windows 用 ini，**macOS 构建只认 `.txt`**，格式不兼容 |
| 端口 2456 | Goldberg emu 用 **47584**；2456 是 Valheim 游戏端口，两者不同 |
| Mac 存档在 `~/.config/unity3d/IronGate/Valheim` | Goldberg 存档在 `~/Library/Application Support/Goldberg SteamEmu Saves/` |

---

## 正确的技术事实

### 下载地址

```
原版（Windows/Linux，1094★）
  https://gitlab.com/Mr_Goldberg/goldberg_emulator

活跃 fork（Windows，2856★，推荐）
  https://github.com/Detanup01/gbe_fork
  ⚠️ 必须 ≥ release-2026_01_17（更早版本破坏 Valheim 联机，issue #396）

macOS 构建（唯一实测可用）
  https://github.com/aaf2tbz/goldberg_emulator
  ✅ universal binary（x86_64 + arm64），372 个 Steam 导出符号
  ⚠️ 仅 6★、单作者，不是可靠长期依赖
```

### 正确的配置键

| 用途 | 键名 | 值 |
|---|---|---|
| 游戏 ID | `steam_appid.txt` | `892970` |
| 玩家名 | `account_name` / `account_name.txt` | 两端不同 |
| Steam ID | `account_steamid` / `user_steam_id.txt` | 两端不同 |
| 网络功能 | `disable_networking` / `disable_networking.txt` | **必须 0** |
| 发现端口 | `listen_port` / `listen_port.txt` | **47584**，两端一致 |
| 局域网发现 | `custom_broadcasts.txt` | 广播地址 + 对端 IP |

### 局域网发现机制

**不是** `enable_lan_only`。是 `custom_broadcasts.txt`（gbe_fork issue #41 维护者确认）：

```
192.168.1.255      ← 本网段广播地址
192.168.1.23       ← 主机 IP
192.168.1.45       ← 客机 IP
```

### Valheim 的两套联机协议

- **PlayFab** — 官方跨平台联机，**Goldberg 无法模拟**（需真 Steam ticket）
- **LAN**（Steam server browser）— Goldberg 可模拟，依赖 `custom_broadcasts.txt`

所以只能走 LAN，且需要玩家自己开世界（专用服务器路径有已知兼容问题）。

---

## 为什么没有现成方案

GitHub 全站搜索：

```
valheim + goldberg + guide        → 0
valheim + coop + one copy         → 0
valheim + multiplayer + emulator  → 0
```

只有 2 个相关 issue，都在 `Detanup01/gbe_fork`：

- **#41**（已关）— Valheim LAN 支持，维护者指向 `custom_broadcasts.txt`
- **#396**（已关）— Valheim 联机被破坏，2026-01-17 修复

这条路是社区零星摸索出来的，没有成文方案。

---

## 建议的推进顺序

**详细步骤见 [`docs/09-next-steps.md`](docs/09-next-steps.md)**（含具体命令和判据）。

```
阶段 1：Mac 单机验证          ← 现在应该做这个
阶段 2：Windows 单机验证
阶段 3：联机验证
阶段 4：才写自动化脚本
```

**阶段 1 没通过之前，脚本都是空转。** 如果阶段 3 卡住，直接买第二份（¥30）更划算。

---

## 仓库内容

| 路径 | 内容 | 状态 |
|---|---|---|
| `docs/08-verification.md` | **事实核查，先看这个** | ✅ 已核查 |
| `docs/09-next-steps.md` | 验证步骤（含命令和判据） | ✅ 可执行 |
| `docs/00-checklist.md` | 操作清单 | ⚠️ 基于错误配置，待重写 |
| `docs/01-architecture.md` | 架构原理 | ⚠️ 部分错误 |
| `docs/02-windows-setup.md` | Windows 步骤 | ⚠️ 配置键错误 |
| `docs/03-mac-setup.md` | Mac 步骤 | ⚠️ 配置格式错误 |
| `docs/04-play-and-join.md` | 开玩 | ⚠️ 端口错误 |
| `docs/05-troubleshooting.md` | 排错 | ⚠️ 部分失效 |
| `docs/06-rollback.md` | 回滚 | ✅ 逻辑可用 |
| `docs/07-git-as-bridge.md` | GitHub 当数据管道 | ✅ 可用 |
| `scripts/` | 自动化脚本 | ❌ **配置键全错**，见 `scripts/README.md` |
| `research/` | 核查证据与来源索引 | ✅ 可复现 |
| `config/role.conf` | 主机/客机角色配置 | ✅ 设计可用 |
| `sync/` | 数据中转目录 | ✅ 可用 |

---

## 备选方案（如果 Goldberg 路线走不通）

| 方案 | 成本 | 可靠性 |
|---|---|---|
| 买第二份游戏（史低约 ¥30） | ¥30 | ⭐⭐⭐⭐⭐ 官方支持 |
| PC Game Pass（Windows 侧） | 订阅费 | ⭐⭐⭐⭐⭐ 官方支持 Steam↔GamePass 跨平台 |
| Goldberg 路线 | 0 | ⭐⭐ 未实测，依赖第三方 fork |

**官方 crossplay 确认可用**：Steam 版 ↔ Game Pass 版可跨平台联机，两端加 `-crossplay` 即可。
