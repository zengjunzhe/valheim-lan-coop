# 05-sync-pull.ps1 — 从 GitHub 拉取对方放的东西
# 用法:
#   powershell -ExecutionPolicy Bypass -File .\05-sync-pull.ps1
#   powershell -ExecutionPolicy Bypass -File .\05-sync-pull.ps1 -RepoDir D:\valheim-lan-coop
#
# 做的事: git pull --rebase，然后展示对方（Mac）放的最新内容

[CmdletBinding()]
param(
    [string]$RepoDir = "",
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - 同步拉取" -ForegroundColor White
Line

# ---------- 定位仓库 ----------
Head "定位仓库"
if (-not $RepoDir) {
    $cur = $PSScriptRoot
    while ($cur) {
        if (Test-Path (Join-Path $cur ".git")) { $RepoDir = $cur; break }
        $parent = Split-Path $cur -Parent
        if ($parent -eq $cur -or -not $parent) { break }
        $cur = $parent
    }
}
if (-not $RepoDir -or -not (Test-Path (Join-Path $RepoDir ".git"))) {
    Bad "未找到 git 仓库。请用 -RepoDir 指定仓库根目录"
    Info "例如: -RepoDir D:\valheim-lan-coop"
    exit 1
}
OK "仓库: $RepoDir"

Push-Location $RepoDir
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Bad "未安装 git"
        Info "下载: https://git-scm.com/download/win"
        exit 1
    }

    # ---------- 远程 ----------
    Head "远程仓库"
    $remote = git remote -v 2>$null
    if (-not $remote) {
        Bad "未配置远程仓库"
        Info "执行: git remote add origin git@github.com:zengjunzhe/valheim-lan-coop.git"
        exit 1
    }
    $remote | Select-Object -First 1 | ForEach-Object { Info $_.Trim() }

    # ---------- 本地改动 ----------
    Head "检查本地改动"
    $dirty = git status --porcelain
    if ($dirty) {
        Warn "本地有未提交改动:"
        $dirty | Select-Object -First 15 | ForEach-Object { Info $_.Trim() }
        if (($dirty | Measure-Object).Count -gt 15) { Info "... 还有更多" }
        Warn "pull 前需要处理。选项:"
        Info "  a) 先跑 06-sync-push.ps1 提交"
        Info "  b) git stash 暂存"
        Info "  c) git checkout -- . 丢弃（危险）"
        $ans = Read-Host "  用 stash 暂存后继续? (y/N)"
        if ($ans -eq "y") {
            git stash push -u -m "auto-stash before pull $(Get-Date -f 'yyyyMMdd_HHmmss')"
            OK "已 stash"
        } else {
            Warn "已中止。请先处理本地改动"
            exit 1
        }
    } else {
        OK "工作区干净"
    }

    # ---------- 拉取 ----------
    Head "拉取"
    Info "执行: git pull --rebase --autostash"
    $out = git pull --rebase --autostash 2>&1
    $rc = $LASTEXITCODE
    $out | ForEach-Object { Info $_ }

    if ($rc -ne 0) {
        Bad "拉取失败 (rc=$rc)"
        Info "可能原因:"
        Info "  1. SSH key 未配置 → 见 docs/07-git-as-bridge.md"
        Info "  2. 网络问题 → 试 git pull 手动"
        Info "  3. 冲突 → git status 查看，手动解决后 git rebase --continue"
        exit 1
    }
    OK "拉取完成"

    # ---------- 角色配置 ----------
    $libPath = Join-Path $PSScriptRoot "lib\role.ps1"
    if (Test-Path $libPath) { . $libPath }
    $repoRootForRole = Find-RepoRoot -StartDir $PSScriptRoot
    if ($repoRootForRole) {
        $roleCfg = Get-RoleConfig -RepoDir $repoRootForRole
        $myId = Get-MyIdentity -RepoDir $repoRootForRole
        Head "角色配置"
        if ($myId.Role -eq "host") {
            OK "本机角色: 主机（开世界）"
            Info "身份: $($myId.Name) / $($myId.SteamId)"
            Info "Mac 是客机"
        } else {
            OK "本机角色: 客机（加入）"
            Info "身份: $($myId.Name) / $($myId.SteamId)"
            Info "Mac 是主机"
        }
        Info "端口: $($roleCfg.Port)"
        Info "配置: $($roleCfg.Source)"
    }

    # ---------- 展示对方内容 ----------
    if (-not $Quiet) {
        Head "Mac 侧状态"
        $macStatus = Join-Path $RepoDir "sync\shared\status-mac.md"
        if (Test-Path $macStatus) {
            Get-Content $macStatus -Encoding UTF8 | ForEach-Object { Info $_ }
        } else {
            Info "（尚无 status-mac.md）"
        }

        Head "Mac 放的诊断"
        $macDiag = Join-Path $RepoDir "sync\diag\mac"
        if (Test-Path $macDiag) {
            $files = Get-ChildItem $macDiag -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".gitkeep" }
            if ($files) {
                $files | Sort-Object LastWriteTime -Descending | ForEach-Object {
                    Info "$($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB, $($_.LastWriteTime.ToString('MM-dd HH:mm')))"
                }
            } else { Info "（空）" }
        } else { Info "（目录不存在）" }

        Head "Mac 放的存档"
        $macSaves = Join-Path $RepoDir "sync\saves\mac"
        if (Test-Path $macSaves) {
            $files = Get-ChildItem $macSaves -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".gitkeep" }
            if ($files) {
                $files | ForEach-Object {
                    Info "$($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB)"
                }
            } else { Info "（空）" }
        } else { Info "（目录不存在）" }

        Head "Mac 放的文件"
        $fromMac = Join-Path $RepoDir "sync\from-mac"
        if (Test-Path $fromMac) {
            $files = Get-ChildItem $fromMac -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".gitkeep" }
            if ($files) {
                $files | Sort-Object LastWriteTime -Descending | ForEach-Object {
                    Info "$($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB)"
                }
            } else { Info "（空）" }
        } else { Info "（目录不存在）" }

        Head "留言板"
        $notes = Join-Path $RepoDir "sync\shared\notes.md"
        if (Test-Path $notes) {
            Get-Content $notes -Encoding UTF8 -Tail 20 | ForEach-Object { Info $_ }
        } else { Info "（无 notes.md）" }
    }

    # ---------- 恢复 stash ----------
    $stashes = git stash list 2>$null
    if ($stashes -and ($stashes -join "") -match "auto-stash before pull") {
        Head "恢复暂存的改动"
        Info "执行: git stash pop"
        $popOut = git stash pop 2>&1
        $popRc = $LASTEXITCODE
        $popOut | ForEach-Object { Info $_ }
        if ($popRc -eq 0) { OK "已恢复" } else { Warn "恢复失败，改动仍在 stash 里: git stash list" }
    }

    Line
    OK "同步拉取完成"
    Write-Host ""
} finally {
    Pop-Location
}
