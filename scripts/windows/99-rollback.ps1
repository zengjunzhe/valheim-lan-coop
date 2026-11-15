# 99-rollback.ps1 — 回滚到正版
# 用法: powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1
#       powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1 -ValheimDir "D:\SteamLibrary\steamapps\common\Valheim"

[CmdletBinding()]
param(
    [string]$ValheimDir = "",
    [switch]$KeepSettings,
    [switch]$RemoveFirewall
)

$ErrorActionPreference = "Stop"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - 回滚到正版" -ForegroundColor White
Line

# ---------- 定位 ----------
Head "定位 Valheim"
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
if (-not $ValheimDir -or -not (Test-Path (Join-Path $ValheimDir "valheim.exe"))) {
    Bad "未找到 Valheim。请用 -ValheimDir 指定"
    exit 1
}
OK "Valheim: $ValheimDir"

# ---------- 关闭进程 ----------
Head "关闭游戏进程"
$vp = Get-Process valheim -ErrorAction SilentlyContinue | Select-Object -First 1
if ($vp) {
    Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    OK "已关闭 valheim.exe"
} else {
    Info "游戏未运行"
}

# ---------- 恢复 dll ----------
Head "恢复 steam_api64.dll"
$dll = Join-Path $ValheimDir "valheim_Data\Plugins\x86_64\steam_api64.dll"
$bak = "$dll.orig"

if (Test-Path $bak) {
    Copy-Item $bak $dll -Force
    OK "已恢复原版 dll ($((Get-Item $dll).Length) bytes)"
    Info "备份保留在: $bak"
} else {
    Warn "未找到 .orig 备份"
    Info "若需恢复，在 Steam 里：右键 Valheim → 属性 → 已安装文件 → 验证文件完整性"
}

# ---------- 处理 steam_settings ----------
Head "处理 steam_settings"
$ss = Join-Path $ValheimDir "steam_settings"
if (Test-Path $ss) {
    if ($KeepSettings) {
        Info "-KeepSettings 指定，保留 steam_settings（补丁未完全移除）"
    } else {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $bakDir = Join-Path $ValheimDir "steam_settings.bak_$stamp"
        Move-Item $ss $bakDir -Force
        OK "已移走 → steam_settings.bak_$stamp"
    }
} else {
    Info "steam_settings 不存在"
}

# ---------- 防火墙 ----------
if ($RemoveFirewall) {
    Head "移除防火墙规则"
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        $rules = Get-NetFirewallRule -DisplayName "Valheim LAN*" -ErrorAction SilentlyContinue
        foreach ($r in $rules) {
            Remove-NetFirewallRule -Name $r.Name -ErrorAction SilentlyContinue
            OK "已移除: $($r.DisplayName)"
        }
    } else {
        Warn "需要管理员权限才能移除防火墙规则"
        Info "手动: Remove-NetFirewallRule -DisplayName 'Valheim LAN*'"
    }
} else {
    Info "防火墙规则保留（加 -RemoveFirewall 可移除）"
}

# ---------- 验证 ----------
Head "验证回滚"
$ok = $true
if (Test-Path $bak) {
    $same = (Get-FileHash $dll -Algorithm SHA256).Hash -eq (Get-FileHash $bak -Algorithm SHA256).Hash
    if ($same) { OK "dll 与原版一致" } else { Bad "dll 与原版不一致"; $ok = $false }
}
if (-not (Test-Path $ss)) { OK "steam_settings 已移除" }
else { Warn "steam_settings 仍存在" }

Line
if ($ok) {
    OK "回滚完成"
    Write-Host ""
    Write-Host "现在可以正常通过 Steam 启动:" -ForegroundColor White
    Write-Host "  steam://rungameid/892970" -ForegroundColor Gray
    Write-Host ""
    Write-Host "存档未受影响:" -ForegroundColor Gray
    Write-Host "  $env:USERPROFILE\AppData\LocalLow\IronGate\Valheim\" -ForegroundColor DarkGray
} else {
    Warn "回滚不完整，建议在 Steam 里验证文件完整性"
}
Write-Host ""
