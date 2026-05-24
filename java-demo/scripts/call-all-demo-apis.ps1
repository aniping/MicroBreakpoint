param(
    [string]$BaseUrl = "http://127.0.0.1:8080"
)

$ErrorActionPreference = "Stop"
$BaseUrl = $BaseUrl.TrimEnd("/")

function Invoke-DemoCurl {
    param(
        [string]$Title,
        [string]$Method,
        [string]$Path,
        [string]$JsonBody = ""
    )

    Write-Host ""
    Write-Host "=== $Title ==="

    $curlArgs = @(
        "-sS",
        "--fail"
    )

    if ($Method -eq "POST") {
        $curlArgs += @(
            "-X", "POST",
            "$BaseUrl$Path",
            "-H", "Content-Type: application/json"
        )
    } else {
        $curlArgs += @("$BaseUrl$Path")
    }

    $payloadFile = $null
    if ($JsonBody.Length -gt 0) {
        $payloadFile = Join-Path ([System.IO.Path]::GetTempPath()) ("micro-breakpoint-" + [System.Guid]::NewGuid().ToString("N") + ".json")
        [System.IO.File]::WriteAllText($payloadFile, $JsonBody, [System.Text.Encoding]::UTF8)
        $curlArgs += @("--data-binary", "@$payloadFile")
    }

    & curl.exe @curlArgs
    $exitCode = $LASTEXITCODE

    if ($payloadFile -and (Test-Path -LiteralPath $payloadFile)) {
        Remove-Item -LiteralPath $payloadFile
    }

    if ($exitCode -ne 0) {
        throw "curl failed: $Title"
    }
    Write-Host ""
}

Invoke-DemoCurl `
    -Title "GET /api/demo/ping" `
    -Method "GET" `
    -Path "/api/demo/ping"

Invoke-DemoCurl `
    -Title "POST /api/demo/initialize - VNA slot 1" `
    -Method "POST" `
    -Path "/api/demo/initialize" `
    -JsonBody '{"instType":"VNA","slotId":1}'

Invoke-DemoCurl `
    -Title "POST /api/demo/initialize - SA slot 2" `
    -Method "POST" `
    -Path "/api/demo/initialize" `
    -JsonBody '{"instType":"SA","slotId":2}'

Invoke-DemoCurl `
    -Title "POST /api/demo/control - VNA start" `
    -Method "POST" `
    -Path "/api/demo/control" `
    -JsonBody '{"instType":"VNA","cmdName":"start","slotId":1,"params":{"mode":"AUTO","durationMs":1000,"operator":"curl-demo"}}'

Invoke-DemoCurl `
    -Title "POST /api/demo/control - SA measure" `
    -Method "POST" `
    -Path "/api/demo/control" `
    -JsonBody '{"instType":"SA","cmdName":"measure","slotId":2,"params":{"frequencyHz":1000000000,"spanHz":10000000,"points":201}}'

Invoke-DemoCurl `
    -Title "POST /api/demo/control - VNA stop" `
    -Method "POST" `
    -Path "/api/demo/control" `
    -JsonBody '{"instType":"VNA","cmdName":"stop","slotId":1,"params":{"reason":"script-finished"}}'

Write-Host ""
Write-Host "All java-demo API calls finished."
