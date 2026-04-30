# Runs the GUT test suite from the command line, headless.
# Requires: Godot 4.x in PATH, or set $env:GODOT_BIN to the godot.exe path.
#
# Usage:
#   .\tools\run_tests.ps1
#   $env:GODOT_BIN = "C:\Path\To\Godot.exe"; .\tools\run_tests.ps1

$ErrorActionPreference = "Stop"

# Locate Godot
$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = (Get-Command "godot" -ErrorAction SilentlyContinue).Source
}
if (-not $godot) {
    $godot = (Get-Command "Godot_v4.6-stable_win64.exe" -ErrorAction SilentlyContinue).Source
}
if (-not $godot) {
    Write-Error "Godot binary not found. Set `$env:GODOT_BIN to your Godot executable path, or add 'godot' to PATH."
    exit 1
}

# Repo root = parent of this script
$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Running tests with: $godot"
Write-Host "Repo root: $repoRoot"

& $godot --headless --path $repoRoot -s addons/gut/gut_cmdln.gd `
    -gconfig=res://tests/.gutconfig.json
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "`n[PASS] All tests passed" -ForegroundColor Green
} else {
    Write-Host "`n[FAIL] Tests failed (exit $exitCode)" -ForegroundColor Red
}
exit $exitCode
