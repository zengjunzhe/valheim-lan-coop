# 07-sync-both.ps1 — 一键：先拉再推
# 用法:
#   powershell -ExecutionPolicy Bypass -File .\07-sync-both.ps1
#   powershell -ExecutionPolicy Bypass -File .\07-sync-both.ps1 -IncludeSaves -Diag

[CmdletBinding()]
param(
    [string]$RepoDir = "",
    [switch]$IncludeSaves,
    [switch]$Diag,
    [string]$Message = ""
)

$ErrorActionPreference = "Continue"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Valheim LAN Coop - 双向同步" -ForegroundColor White
Line

$here = $PSScriptRoot
$common = @{}
if ($RepoDir) { $common["RepoDir"] = $RepoDir }

Write-Host ""
Write-Host ">>> 第一步：拉取对方更新" -ForegroundColor Cyan
& (Join-Path $here "05-sync-pull.ps1") @common -Quiet
$pullRc = $LASTEXITCODE

Write-Host ""
Write-Host ">>> 第二步：推送自己的更新" -ForegroundColor Cyan
$pushParams = @{} + $common
if ($IncludeSaves) { $pushParams["IncludeSaves"] = $true }
if ($Diag)         { $pushParams["Diag"] = $true }
if ($Message)      { $pushParams["Message"] = $Message }
& (Join-Path $here "06-sync-push.ps1") @pushParams
$pushRc = $LASTEXITCODE

Line
if ($pullRc -eq 0 -and $pushRc -eq 0) {
    Write-Host "  双向同步完成" -ForegroundColor Green
} else {
    Write-Host "  有步骤失败（pull=$pullRc push=$pushRc），检查上面的输出" -ForegroundColor Yellow
}
Write-Host ""
