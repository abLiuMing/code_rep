$ErrorActionPreference = "Stop"
$Generated = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../build/generated_resources"))
Write-Host "OFA demo running with:"
Get-ChildItem -LiteralPath $Generated -File | ForEach-Object { Write-Host $_.FullName }
