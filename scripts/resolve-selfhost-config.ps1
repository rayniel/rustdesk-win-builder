$ErrorActionPreference = "Stop"

function Normalize-Value {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Trim()
}

$configString = ""
$source = ""

$host = Normalize-Value $env:RUSTDESK_HOST
$relay = Normalize-Value $env:RUSTDESK_RELAY
$api = Normalize-Value $env:RUSTDESK_API
$key = Normalize-Value $env:RUSTDESK_KEY
$rawConfig = Normalize-Value $env:RUSTDESK_CONFIG

if (-not [string]::IsNullOrWhiteSpace($host) -or -not [string]::IsNullOrWhiteSpace($key) -or -not [string]::IsNullOrWhiteSpace($relay) -or -not [string]::IsNullOrWhiteSpace($api)) {
    if ([string]::IsNullOrWhiteSpace($host) -or [string]::IsNullOrWhiteSpace($key)) {
        throw "Self-host split secrets are incomplete. RUSTDESK_HOST and RUSTDESK_KEY are required when using split secrets."
    }

    $config = [ordered]@{
        host = $host
        relay = $relay
        api = $api
        key = $key
    }

    $json = $config | ConvertTo-Json -Compress
    $base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=')
    $base64 = $base64.Replace('+', '-').Replace('/', '_')
    $chars = $base64.ToCharArray()
    [Array]::Reverse($chars)
    $configString = -join $chars
    $source = "RUSTDESK_HOST/RUSTDESK_KEY"
} elseif (-not [string]::IsNullOrWhiteSpace($rawConfig)) {
    $configString = $rawConfig
    $source = "RUSTDESK_CONFIG"
}

if ([string]::IsNullOrWhiteSpace($configString)) {
    "enabled=false" >> $env:GITHUB_OUTPUT
    exit 0
}

"enabled=true" >> $env:GITHUB_OUTPUT
"source=$source" >> $env:GITHUB_OUTPUT
"value<<EOF" >> $env:GITHUB_OUTPUT
$configString >> $env:GITHUB_OUTPUT
"EOF" >> $env:GITHUB_OUTPUT