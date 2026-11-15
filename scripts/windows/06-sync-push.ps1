# 06-sync-push.ps1 — 把自己的东西推到 GitHub 中转
# 用法:
#   powershell -ExecutionPolicy Bypass -File .\06-sync-push.ps1
#   powershell -ExecutionPolicy Bypass -File .\06-sync-push.ps1 -IncludeSaves
#   powershell -ExecutionPolicy Bypass -File .\06-sync-push.ps1 -Diag -Message "世界已开"
#
# 做的事: 写状态文件 → 可选拷存档/诊断 → git add/commit/push

[CmdletBinding()]
param(
    [string]$RepoDir = "",
    [string]$ValheimDir = "",
    [switch]$IncludeSaves,
    [switch]$Diag,
    [string]$Message = "",
    [int]$SaveSizeLimitMB = 50,
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - 同步推送" -ForegroundColor White
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
    Bad "未找到 git 仓库。请用 -RepoDir 指定"
    exit 1
}
OK "仓库: $RepoDir"

Push-Location $RepoDir
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Bad "未安装 git"
        exit 1
    }

    # ---------- 定位 Valheim ----------
    if (-not $ValheimDir) {
        $steamExe = $null
        foreach ($p in @("${env:ProgramFiles(x86)}\Steam\steam.exe", "$env:ProgramFiles\Steam\steam.exe", "D:\Steam\steam.exe")) {
            if (Test-Path $p) { $steamExe = $p; break }
        }
        if (-not $steamExe) {
            $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
            if ($reg -and $reg.SteamExe) { $steamExe = $reg.SteamExe }
        }
        if ($steamExe) {
            $steamRoot = Split-Path $steamExe -Parent
            $libs = @()
            $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
            if (Test-Path $vdf) {
                $m = Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches
                foreach ($mm in $m.Matches) { $libs += ($mm.Groups[1].Value -replace '\\\\','\') }
            }
            $libs += Join-Path $steamRoot "steamapps"
            foreach ($lib in $libs) {
                $c = Join-Path $lib "common\Valheim"
                if (Test-Path (Join-Path $c "valheim.exe")) { $ValheimDir = $c; break }
            }
        }
    }

    # ---------- 收集状态 ----------
    Head "收集本机状态"
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hostname = $env:COMPUTERNAME

    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -like "192.168.*" } |
           Select-Object -First 1).IPAddress
    if (-not $ip) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 |
               Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
               Select-Object -First 1).IPAddress
    }
    if (-not $ip) { $ip = "未知" }

    $buildid = "未知"
    $patchStatus = "未打"
    if ($ValheimDir) {
        $acf = Join-Path (Split-Path (Split-Path $ValheimDir -Parent) -Parent) "appmanifest_892970.acf"
        if (Test-Path $acf) {
            $m = Select-String -Path $acf -Pattern '"buildid"\s+"(\d+)"'
            if ($m) { $buildid = $m.Matches[0].Groups[1].Value }
        }
        $bak = Join-Path $ValheimDir "valheim_Data\Plugins\x86_64\steam_api64.dll.orig"
        $ss  = Join-Path $ValheimDir "steam_settings\configs.main.ini"
        if ((Test-Path $bak) -and (Test-Path $ss)) {
            $lan = Select-String -Path $ss -Pattern "enable_lan_only\s*=\s*1"
            if ($lan) { $patchStatus = "已打（enable_lan_only=1）" } else { $patchStatus = "已打（但 enable_lan_only 未设）" }
        }
    } else {
        $ValheimDir = "未找到"
    }

    $steamProc = if (Get-Process steam -ErrorAction SilentlyContinue) { "运行中" } else { "未运行" }
    $worldState = if (netstat -ano | Select-String ":2456\s" | Select-String "UDP") { "已开启（端口监听中）" } else { "未开启" }

    OK "IP=$ip  buildid=$buildid  补丁=$patchStatus"

    # ---------- 写状态文件 ----------
    Head "写 status-windows.md"
    $statusPath = Join-Path $RepoDir "sync\shared\status-windows.md"
    $statusContent = @"
# Windows 状态

> 由 ``06-sync-push.ps1`` 自动生成。手动改也行，但下次推送会覆盖。

``````
更新时间   : $now
主机名     : $hostname
内网 IP    : $ip
端口       : 2456
buildid    : $buildid
Valheim 路径: $ValheimDir
补丁状态   : $patchStatus
Steam 进程 : $steamProc
世界状态   : $worldState
``````

## 备注

$(if ($Message) { $Message } else { "（本次推送无附加留言）" })
"@
    Set-Content -Path $statusPath -Value $statusContent -Encoding UTF8
    OK "已写入"

    # ---------- 拷存档 ----------
    if ($IncludeSaves) {
        Head "拷贝存档"
        $saveSrc = "$env:USERPROFILE\AppData\LocalLow\IronGate\Valheim"
        if (-not (Test-Path $saveSrc)) {
            Warn "存档目录不存在: $saveSrc"
        } else {
            $dst = Join-Path $RepoDir "sync\saves\windows"
            New-Item -ItemType Directory -Force -Path $dst | Out-Null

            # 清空旧内容（只保留最新）
            Get-ChildItem $dst -File -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

            $totalMB = 0
            $copied = 0
            foreach ($sub in @("worlds", "characters")) {
                $s = Join-Path $saveSrc $sub
                if (-not (Test-Path $s)) { continue }
                Get-ChildItem $s -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $sizeMB = $_.Length / 1MB
                    if ($sizeMB -gt $SaveSizeLimitMB) {
                        Warn "跳过 $($_.Name)（$([math]::Round($sizeMB,1)) MB > 上限 $SaveSizeLimitMB MB）"
                        Info "  大存档建议本地备份，不推 Git"
                        return
                    }
                    Copy-Item $_.FullName (Join-Path $dst $_.Name) -Force
                    $totalMB += $sizeMB
                    $copied++
                }
            }
            if ($copied -gt 0) {
                OK "拷贝 $copied 个文件，共 $([math]::Round($totalMB,1)) MB → sync\saves\windows\"
                if ($totalMB -gt 20) {
                    Warn "存档较大（$([math]::Round($totalMB,1)) MB），仓库会持续变大"
                    Info "长期使用建议只推 .fwl，或用 git gc 清理"
                }
            } else {
                Info "没有可拷贝的存档文件"
            }
        }
    }

    # ---------- 生成诊断 ----------
    if ($Diag) {
        Head "生成诊断"
        $diagDir = Join-Path $RepoDir "sync\diag\windows"
        New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $diagFile = Join-Path $diagDir "diag-$stamp.txt"

        $lines = @()
        $lines += "=== Windows 诊断 $now ==="
        $lines += ""
        $lines += "--- 系统 ---"
        $lines += "OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
        $lines += "架构: $env:PROCESSOR_ARCHITECTURE"
        $lines += "主机名: $hostname"
        $lines += ""
        $lines += "--- 网络 ---"
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } |
            ForEach-Object { $lines += "$($_.IPAddress)/$($_.PrefixLength)" }
        $lines += ""
        $lines += "--- 网络位置 ---"
        Get-NetConnectionProfile -ErrorAction SilentlyContinue |
            ForEach-Object { $lines += "$($_.Name): $($_.NetworkCategory)" }
        $lines += ""
        $lines += "--- Valheim ---"
        $lines += "路径: $ValheimDir"
        $lines += "buildid: $buildid"
        $lines += "补丁: $patchStatus"
        if ($ValheimDir -ne "未找到") {
            $lines += ""
            $lines += "--- steam_settings ---"
            $ss = Join-Path $ValheimDir "steam_settings"
            if (Test-Path $ss) {
                Get-ChildItem $ss -File | ForEach-Object {
                    $lines += "== $($_.Name) ($($_.Length) bytes) =="
                    $lines += (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue)
                }
            }
            $lines += ""
            $lines += "--- dll ---"
            $dll = Join-Path $ValheimDir "valheim_Data\Plugins\x86_64\steam_api64.dll"
            if (Test-Path $dll) {
                $lines += "steam_api64.dll: $((Get-Item $dll).Length) bytes"
                $lines += "sha256: $((Get-FileHash $dll -Algorithm SHA256).Hash)"
            }
            $bak = "$dll.orig"
            if (Test-Path $bak) { $lines += "orig: $((Get-Item $bak).Length) bytes" }
        }
        $lines += ""
        $lines += "--- 端口 ---"
        $lines += (netstat -ano | Select-String "245[678]" | ForEach-Object { $_.ToString().Trim() })
        $lines += ""
        $lines += "--- 防火墙 ---"
        Get-NetFirewallRule -DisplayName "Valheim LAN*" -ErrorAction SilentlyContinue |
            ForEach-Object { $lines += "$($_.DisplayName): enabled=$($_.Enabled) profile=$($_.Profile)" }

        Set-Content -Path $diagFile -Value ($lines -join "`r`n") -Encoding UTF8
        OK "诊断 → sync\diag\windows\diag-$stamp.txt"
    }

    # ---------- git 提交推送 ----------
    Head "提交并推送"
    git add sync/ 2>&1 | ForEach-Object { Info $_ }

    $staged = git diff --cached --name-only 2>$null
    if (-not $staged) {
        Info "sync/ 下无变化，跳过提交"
    } else {
        Info "暂存文件:"
        $staged | Select-Object -First 20 | ForEach-Object { Info "  $_" }

        $commitMsg = if ($Message) { "sync(windows): $Message" } else { "sync(windows): $now" }
        git commit -q -m $commitMsg 2>&1 | ForEach-Object { Info $_ }
        if ($LASTEXITCODE -eq 0) { OK "已提交: $commitMsg" } else { Warn "提交失败" }
    }

    if ($NoPush) {
        Info "-NoPush 指定，不推送"
    } else {
        Info "执行: git pull --rebase --autostash && git push"
        $pullOut = git pull --rebase --autostash 2>&1
        $pullOut | ForEach-Object { Info $_ }
        if ($LASTEXITCODE -ne 0) {
            Warn "pull 失败，尝试直接 push"
        }
        $pushOut = git push 2>&1
        $pushOut | ForEach-Object { Info $_ }
        if ($LASTEXITCODE -eq 0) { OK "推送成功" } else { Bad "推送失败 (rc=$LASTEXITCODE)" }
    }

    Line
    OK "同步推送完成"
    Write-Host ""
    Write-Host "Mac 侧跑 ./05-sync-pull.sh 即可看到" -ForegroundColor Gray
    Write-Host ""
} finally {
    Pop-Location
}
