# 03-firewall.ps1 — 放行 Valheim 局域网端口（UDP 2456-2458）
# 用法: powershell -ExecutionPolicy Bypass -File .\03-firewall.ps1
#       powershell -ExecutionPolicy Bypass -File .\03-firewall.ps1 -Remove

[CmdletBinding()]
param(
    [switch]$Remove,
    [string]$RulePrefix = "Valheim LAN"
)

$ErrorActionPreference = "Stop"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - 防火墙配置" -ForegroundColor White
Line

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Bad "需要管理员权限。请右键 PowerShell → 以管理员身份运行"
    exit 1
}

# ---------- 移除 ----------
if ($Remove) {
    Head "移除规则"
    $existing = Get-NetFirewallRule -DisplayName "$RulePrefix*" -ErrorAction SilentlyContinue
    if ($existing) {
        foreach ($r in $existing) {
            Remove-NetFirewallRule -Name $r.Name -ErrorAction SilentlyContinue
            OK "已移除: $($r.DisplayName)"
        }
    } else {
        Info "无匹配规则"
    }
    Line
    exit 0
}

# ---------- 添加 ----------
Head "添加规则（UDP 2456-2458，专用网络）"

# 清理同名旧规则，避免重复
$existing = Get-NetFirewallRule -DisplayName "$RulePrefix*" -ErrorAction SilentlyContinue
if ($existing) {
    foreach ($r in $existing) {
        Remove-NetFirewallRule -Name $r.Name -ErrorAction SilentlyContinue
        Info "清理旧规则: $($r.DisplayName)"
    }
}

$ruleName = "$RulePrefix (UDP 2456-2458)"
try {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol UDP `
        -LocalPort 2456-2458 `
        -Profile Private, Domain `
        -Description "Valheim 局域网联机（UDP 2456-2458）" | Out-Null
    OK "入站规则已添加: $ruleName"
} catch {
    Bad "添加失败: $($_.Exception.Message)"
    exit 1
}

# 出站一般默认允许，但显式加一条更保险
try {
    New-NetFirewallRule `
        -DisplayName "$RulePrefix (Outbound)" `
        -Direction Outbound `
        -Action Allow `
        -Protocol UDP `
        -LocalPort 2456-2458 `
        -Profile Private, Domain `
        -Description "Valheim 局域网联机出站" | Out-Null
    OK "出站规则已添加"
} catch {
    Warn "出站规则添加失败（通常不影响，默认放行）"
}

# ---------- 验证 ----------
Head "验证"
$rules = Get-NetFirewallRule -DisplayName "$RulePrefix*" -ErrorAction SilentlyContinue
foreach ($r in $rules) {
    $pf = $r | Get-NetFirewallPortFilter
    OK "$($r.DisplayName)"
    Info "  Enabled=$($r.Enabled)  Direction=$($r.Direction)  Action=$($r.Action)"
    Info "  Protocol=$($pf.Protocol)  LocalPort=$($pf.LocalPort)  Profile=$($r.Profile)"
}

# ---------- 提示 ----------
Head "网络位置检查"
$profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue
foreach ($p in $profiles) {
    if ($p.NetworkCategory -eq "Public") {
        Warn "网络 '$($p.Name)' 被识别为【公用】"
        Warn "规则只对【专用/域】生效，公用网络下仍会被拦"
        Info "解决: 设置 → 网络和 Internet → 属性 → 改为【专用网络】"
    } else {
        OK "网络 '$($p.Name)' = $($p.NetworkCategory)"
    }
}

Line
OK "防火墙配置完成"
Write-Host ""
Write-Host "下一步: 04-launch.ps1" -ForegroundColor White
Write-Host ""
