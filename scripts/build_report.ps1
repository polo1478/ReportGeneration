[CmdletBinding()]
param(
    [switch]$Pdf
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command julia -ErrorAction SilentlyContinue)) {
    throw 'Julia was not found on PATH. Install Julia, open a new PowerShell window, and retry.'
}
if (-not (Get-Command quarto -ErrorAction SilentlyContinue)) {
    throw 'Quarto was not found on PATH. Install Quarto, open a new PowerShell window, and retry.'
}

Push-Location $projectRoot
try {
    & julia '--project=.' 'scripts/run_all.jl'
    if ($LASTEXITCODE -ne 0) { throw 'Julia artifact generation failed.' }

    & julia '--project=.' 'test/runtests.jl'
    if ($LASTEXITCODE -ne 0) { throw 'Julia verification tests failed.' }

    Push-Location (Join-Path $projectRoot 'report')
    try {
        & quarto render 'internal_report.qmd' '--to' 'html'
        if ($LASTEXITCODE -ne 0) { throw 'Quarto HTML rendering failed.' }

        & quarto render 'internal_report.qmd' '--to' 'docx'
        if ($LASTEXITCODE -ne 0) { throw 'Quarto Word rendering failed.' }

        if ($Pdf) {
            & quarto render 'internal_report.qmd' '--to' 'pdf'
            if ($LASTEXITCODE -ne 0) { throw 'Quarto PDF rendering failed. Install a LaTeX distribution first.' }
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    Pop-Location
}

Write-Host "Report generated: report/_output/internal_report.html"
Write-Host "Word report generated: report/_output/internal_report.docx"

