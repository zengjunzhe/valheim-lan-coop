# 用 GitHub 当两台机之间的中转

这个仓库不只是代码托管，它同时是 **Windows ↔ Mac 的数据管道**。没有 U 盘、没有微信传文件、不用开内网共享，只要两边都能访问 GitHub 就能交换数据。

---

## 中转能干什么

| 场景 | 走哪个目录 | 谁写 | 谁读 |
|---|---|---|---|
| 传世界存档（主机 → 客机备份，或换主机） | `sync/saves/` | 主机 | 客机 |
| 传角色存档 | `sync/saves/` | 各自 | 各自 |
| 交换 IP / 端口 / buildid / 状态 | `sync/shared/status-windows.md`、`status-mac.md` | 各自 | 对方 |
| 传诊断信息（排错用） | `sync/diag/windows/`、`sync/diag/mac/` | 各自 | 排查方 |
| 传临时文件、截图、日志 | `sync/from-windows/`、`sync/from-mac/` | 各自 | 对方 |
| 传配置（改了 steamid 等） | `sync/shared/` | 任一方 | 对方 |

---

## 目录约定

```
sync/
├── shared/                     ← 双方都读写，小文本
│   ├── status-windows.md       ← Windows 写自己的 IP/buildid/状态
│   ├── status-mac.md           ← Mac 写自己的状态
│   └── notes.md                ← 留言板
├── saves/
│   ├── windows/                ← 主机存档（世界 + 角色）
│   └── mac/                    ← 客机角色存档
├── diag/
│   ├── windows/                ← Windows 诊断输出
│   └── mac/                    ← Mac 诊断输出
├── from-windows/               ← Windows 单向放文件给 Mac
└── from-mac/                   ← Mac 单向放文件给 Windows
```

**规则**：只往自己的目录写，不删对方目录里的东西。`shared/` 里只写自己的那个 status 文件。

---

## 两个脚本搞定日常

### Windows

```powershell
cd scripts\windows

# 拉取对方更新（Mac 放的东西）
.\05-sync-pull.ps1

# 推送自己的东西（存档、状态、诊断）
.\06-sync-push.ps1

# 一键：拉 + 推
.\07-sync-both.ps1
```

### Mac

```bash
cd scripts/mac

./05-sync-pull.sh     # 拉取 Windows 放的东西
./06-sync-push.sh     # 推送自己的东西
./07-sync-both.sh     # 一键
```

---

## 典型用法

### 场景 1：Mac 想知道 Windows 的 IP 和 buildid

Windows 跑一次 `06-sync-push.ps1`，它会把 IP、buildid、端口写进 `sync/shared/status-windows.md` 并推上去。

Mac 跑 `05-sync-pull.sh`，直接看到：

```
主机 IP    : 192.168.1.23
端口       : 2456
buildid    : 12345678
状态       : 世界已开启
```

不用再微信问"你 IP 多少"。

### 场景 2：备份主机存档到云端

Windows 跑：

```powershell
.\06-sync-push.ps1 -IncludeSaves
```

把 `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds\` 和 `characters\` 拷进 `sync/saves/windows/` 再推。

Mac 拉下来就有一份异地备份。存档坏了能回滚。

### 场景 3：Mac 连不上，把诊断发给 Windows 看

Mac 跑：

```bash
./06-sync-push.sh --diag
```

诊断输出进 `sync/diag/mac/`。Windows 拉下来直接看，不用截图。

### 场景 4：换主机（Mac 开世界，Windows 加入）

Mac 把自己存档推到 `sync/saves/mac/`，Windows 拉下来放进自己的存档目录，然后反过来的角色配置也一并同步。

---

## 冲突处理

Git 的常规冲突在这里基本不会发生，因为**目录是分开的**：Windows 只写 `saves/windows/`、`status-windows.md`、`from-windows/`；Mac 只写自己那几个。

唯一可能冲突的是 `sync/shared/notes.md`（双方都写）。脚本对它的处理是：**拉取时先 rebase，冲突则保留双方内容追加**，不丢信息。

如果真遇到冲突：

```bash
# 看哪些文件冲突
git status

# 简单粗暴：保留对方版本
git checkout --theirs <文件>
git add <文件>
git commit -m "resolve"

# 或者手动编辑后
git add <文件> && git commit -m "resolve"
```

---

## 注意

### 存档是二进制，会撑大仓库

Valheim 世界存档 `.db` 单文件可能几十 MB，每次推都新增一个 blob。Git 历史会越来越大。

处理方式：

- 脚本默认**只保留最新一份**（`sync/saves/` 下的文件每次覆盖，不按时间戳堆）
- 如果长期使用，考虑 `git gc` 或定期重建仓库
- 超大存档（>50MB）建议只推 `.fwl`（世界元数据，小）不推 `.db`

脚本 `06-sync-push` 会在存档超过阈值时提示。

### 仓库是 public 的

`sync/` 里的东西全世界都能看。存档、诊断日志里可能包含：

- 你的内网 IP（无所谓）
- 角色名、世界名
- 系统信息

**不要往 `sync/` 放任何密码、token、私钥**。要放就把仓库改 private。

### 别把 Steam 账号信息放进来

`account_steamid` 是假 ID（`76561198000000001`），无所谓。但**真 Steam 账号密码、API key、token 绝对不能进这个仓库**。

---

## 手动操作（不想用脚本时）

```bash
# 拉
git pull --rebase

# 放文件到对应目录，然后
git add sync/
git commit -m "sync: 说明改了什么"
git push
```

脚本只是把这三步包了一层，加了目录约定和自动填写状态文件。
