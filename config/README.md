# 角色配置 — Mac 当主机

**当前：Mac 是主机（开世界），Windows 是客机（加入）。** Mac 配置更好，跑世界模拟更稳。

---

## 为什么 Mac 当主机

Valheim 的主机要承担：

- 世界状态模拟（地形、建筑、掉落物）
- 怪物 AI 与寻路
- 物理计算（船、推车、掉落）
- 向所有客机广播状态

配置越好，帧数和同步越稳。**主机的性能下限决定全队的体验上限**。客机只负责渲染自己看到的部分，压力小得多。

所以让配置好的那台当主机是对的。

---

## 当前配置

`config/role.conf`：

```ini
HOST_ROLE=mac          ← Mac 是主机
HOST_NAME=PlayerA      ← Mac 的身份
HOST_STEAMID=76561198000000001
CLIENT_NAME=PlayerB    ← Windows 的身份
CLIENT_STEAMID=76561198000000002
PORT=2456
```

| 机器 | 角色 | account_name | account_steamid |
|---|---|---|---|
| **Mac** | 主机（开世界） | `PlayerA` | `76561198000000001` |
| **Windows** | 客机（加入） | `PlayerB` | `76561198000000002` |

---

## 脚本会自动读这个配置

| 脚本 | 行为差异 |
|---|---|
| `01-detect` | 显示「本机角色: 主机/客机」+ 自己的身份 |
| `02-apply-goldberg` | 主机写 `PlayerA`/`...0001`，客机写 `PlayerB`/`...0002` |
| `04-launch` | 主机提示「Start Game 进世界」+ 显示本机 IP；客机提示「Join IP」+ 需要对方 IP |
| `05-sync-pull` | 显示本机角色和对方身份 |
| `06-sync-push` | status 文件里标注角色；主机记录世界状态，客机标「不适用」 |

**不需要手动改任何脚本**。

---

## 切换主机（如果以后想换）

改 `config/role.conf` 的 `HOST_ROLE`：

```bash
sed -i 's/^HOST_ROLE=mac/HOST_ROLE=windows/' config/role.conf
git add config/role.conf && git commit -m "role: 切到 Windows 当主机" && git push
```

另一台 `git pull` 后，**两台都要重跑 `02-apply-goldberg`**：

```bash
./02-apply-goldberg.sh --goldberg-dir ~/goldberg        # Mac
```

```powershell
.\02-apply-goldberg.ps1 -GoldbergDir C:\goldberg        # Windows
```

必须重跑，因为 `account_steamid` 要对调。不重跑会导致两端 steamid 重复，角色数据互相覆盖。

然后重跑 `04-launch`。

---

## 主机和客机的操作差异

| 项 | 主机（Mac） | 客机（Windows） |
|---|---|---|
| 启动后 | `Start Game` → 新建/选世界 → **真正进入世界** | `Join Game` → `Join IP` |
| 端口 | 监听 2456 | 不监听 |
| 存档 | `worlds/` 是权威版本 | `worlds/` 基本不用 |
| 退出影响 | **全队断线** | 只影响自己 |
| 性能压力 | 高 | 低 |
| 防火墙 | 需要放行 UDP 2456-2458 | 不需要 |

---

## Mac 主机的性能建议

既然让 Mac 当主机，画质设置要注意——**主机卡了全队都卡**。

| 设置 | 建议 | 原因 |
|---|---|---|
| 分辨率 | 原生或略降 | 影响渲染，不影响模拟 |
| 画质预设 | Medium ~ High | 太高会挤占 CPU |
| 动态模糊 | 关 | 无收益，吃 GPU |
| SSAO | 关或低 | 吃 GPU |
| 抗锯齿 | 关或 FXAA | 吃 GPU |
| 视距 | 中 | 视距越大模拟负担越重 |
| 阴影 | 中或低 | 阴影是主要 GPU 开销 |
| **后台程序** | 关掉浏览器等 | 主机要留 CPU 给模拟 |

**关键**：主机的瓶颈通常不是 GPU 而是 **CPU 单核性能 + 内存**。Apple Silicon 单核很强，是当主机的好选择。

监控方式：

```bash
# 看 CPU 占用（Valheim 进程）
top -o cpu -n 10

# 看内存压力
memory_pressure
```

如果 Valheim 占用超过 80% CPU 且持续，降视距和画质。

---

## 常见误区

**「配置好的当主机，客机就轻松了」** —— 对，但别指望客机能完全无压力。客机仍需渲染、处理网络包、跑本地物理预测。只是不用模拟整个世界。

**「主机挂机就行，不用管」** —— 主机退出游戏世界就关了。要常驻见 `04-play-and-join.md`。

**「Mac 当主机，Windows 就可以随便配置」** —— Windows 也要能跑动 Valheim 本身。它只是不用管世界模拟。
