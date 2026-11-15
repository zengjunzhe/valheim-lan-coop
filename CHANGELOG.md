# CHANGELOG

## v1.2.0 — GitHub 作为两台机之间的中转

**新增**：仓库兼作 Windows ↔ Mac 的数据管道，不再只托管代码。

新增 `sync/` 目录 + 6 个同步脚本：

| 脚本 | 作用 |
|---|---|
| `05-sync-pull` | 拉取对方放的存档/状态/诊断 |
| `06-sync-push` | 推送自己的存档/状态/诊断 |
| `07-sync-both` | 一键先拉再推 |

关键设计：

- **目录按机器划分**：Windows 只写 `saves/windows/`、`status-windows.md`、`from-windows/`；Mac 只写自己那几个 → 不会产生 Git 冲突
- **状态自动生成**：脚本读 IP、buildid、补丁状态、签名状态、端口监听，写成 markdown，对方 pull 一下就看到，不用微信问"你 IP 多少"
- **存档体积保护**：单文件超过 50MB 自动跳过并提示；拷贝时先清空旧内容，只保留最新一份
- **诊断一键打包**：`-Diag` / `--diag` 生成含系统信息、配置内容、dll 哈希、崩溃日志的文本
- **pull 前自动 stash**：本地有未提交改动时自动 `git stash`，pull 完再 pop

同时修正 `.gitignore`：

- 之前的 `diag-*.txt` 无前导斜杠，会误伤 `sync/diag/` 下要入库的诊断文件 → 改为 `/diag-*.txt`
- `steam_settings/` 保持忽略（那是游戏目录里的，不该入库）


## v1.1.0 — 改为 Steam 下载流程

**变更**：不再用 steamcmd 匿名安装客户端，改为两台都用 Steam 客户端下载。

理由：

- 同一 Steam 账号在两台机器分别下载，buildid 天然一致，省掉最麻烦的版本对齐
- 不需要额外下载 steamcmd（约 10MB）
- Steam 下载有 CDN 加速和断点续传，比 steamcmd 快
- 减少一个失败点（steamcmd 自更新经常卡住）

具体调整：

- 删除 `scripts/windows/02-install-client.ps1`
- `02-apply-goldberg.ps1` 改为自动定位 Steam 库（读注册表 + `libraryfolders.vdf`），支持多盘多库
- `01-detect.ps1` 增加 Steam 安装检测、库路径扫描、buildid 自动读取
- `04-launch.ps1` 增加补丁完整性校验、Steam 进程处理、启动后存活检测
- 脚本编号顺移：`03-firewall` / `04-launch` / `99-rollback`
- 文档同步改写，强调"先 Steam 下载 → 退出 Steam → 打补丁 → 直接跑 exe"

保留：Goldberg 补丁流程、`enable_lan_only=1` 核心配置、IP 直连方案、回滚能力。

## v1.0.0 — 初始版本

- Windows / Mac 双侧 Goldberg 方案
- steamcmd 匿名安装客户端
- 局域网 IP 直连（`enable_lan_only=1`）
- 完整脚本：探测、安装、打补丁、防火墙、启动、回滚
- 文档：架构、Windows、Mac、开玩、排错、回滚
