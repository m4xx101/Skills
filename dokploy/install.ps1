# Dokploy Skill Suite — Windows Installer (PowerShell)
param()

$SkillsDir = if ($env:HERMES_SKILLS_DIR) { $env:HERMES_SKILLS_DIR } else { "$env:USERPROFILE\.hermes\skills\devops" }
$TargetDir = "$SkillsDir\dokploy"

Write-Host "Dokploy Skill Suite — Installer"
Write-Host "========================================"
Write-Host ""

if (!(Test-Path $TargetDir)) { New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null }

Write-Host "Installing to $TargetDir"

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Copy-Item -Path "$SourceDir\*" -Destination $TargetDir -Recurse -Force

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. `$env:DOKPLOY_API_KEY='your-key-here'"
Write-Host "  2. In Hermes: /dokploy"
Write-Host ""
Write-Host "Docs: https://github.com/m4xx101/dokploy-skills"
