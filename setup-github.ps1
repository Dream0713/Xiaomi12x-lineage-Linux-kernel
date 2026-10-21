[CmdletBinding()]
param(
    [string]$Repo = "Dream0713/Xiaomi12x-lineage-Linux-kernel",
    [switch]$OpenCreate
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
Set-Location $Root

function Invoke-Git {
    param([string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git not found. Install Git for Windows first."
}

if (-not (Test-Path (Join-Path $Root ".git"))) {
    Write-Host "Initializing git repository..." -ForegroundColor Cyan
    Invoke-Git @("init")
}

$email = (& git config user.email 2>$null)
if (-not $email) {
    Invoke-Git @("config", "user.email", "psyche@local")
}
$name = (& git config user.name 2>$null)
if (-not $name) {
    Invoke-Git @("config", "user.name", "psyche")
}

Write-Host ""
Write-Host "Create an EMPTY public repository named 'psyche-folkpatch-kernel' at:" -ForegroundColor Yellow
Write-Host "  https://github.com/new" -ForegroundColor White
Write-Host "Do NOT initialize it with README/.gitignore/license." -ForegroundColor Yellow
Write-Host "Repository to push to: $Repo" -ForegroundColor White
Write-Host ""
if ($OpenCreate) {
    Start-Process "https://github.com/new"
}
Read-Host "Press Enter after the empty repository exists"

Invoke-Git @("add", ".")
& git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    Invoke-Git @("commit", "-m", "Build psyche kernel with kallsyms for FolkPatch")
} else {
    Write-Host "No changes to commit (repository already up to date)." -ForegroundColor Yellow
}

# Rename the initial branch to main (works for unborn and existing branches).
& git branch -M main 2>$null

$remote = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -eq 0 -and $remote) {
    Invoke-Git @("remote", "set-url", "origin", "https://github.com/$Repo.git")
} else {
    Invoke-Git @("remote", "add", "origin", "https://github.com/$Repo.git")
}

Write-Host ""
Write-Host "Pushing to https://github.com/$Repo ..." -ForegroundColor Cyan
Write-Host "Git Credential Manager may open a GitHub login window; sign in and allow." -ForegroundColor Yellow
Invoke-Git @("push", "-u", "origin", "main")

Write-Host ""
Write-Host "Done. GitHub Actions should start automatically." -ForegroundColor Green
Write-Host "Actions: https://github.com/$Repo/actions" -ForegroundColor White
Write-Host "Releases: https://github.com/$Repo/releases" -ForegroundColor White
