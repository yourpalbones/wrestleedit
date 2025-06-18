<#
.SYNOPSIS
    Auto-regenerate WrestleEdit.Core via OpenAI + push to GitHub.
#>

param(
    [string]$OpenAIKey = $env:OPENAI_API_KEY
)

if (-not $OpenAIKey) {
    Write-Error "Please set your OPENAI_API_KEY environment variable."
    exit 1
}

# 1) Define your prompt here...
$Prompt = @"
You are an expert C# engineer and retro ROM hacker working inside GPT-4.  
Your mission: generate a production-quality .NET 8 class library called WrestleEdit.Core that will form the foundation of a WWF Raw / WWF Royal Rumble SNES sprite-modding tool.
... (paste your full prompt spec here) ...
"@

# 2) Call the API
$Body = @{
    model    = "gpt-4o-mini"
    messages = @(
        @{ role = "user"; content = $Prompt }
    )
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
    -Headers @{ "Authorization" = "Bearer $OpenAIKey" } `
    -Body $Body -Method Post -ContentType "application/json"

$text = $response.choices[0].message.content

# 3) Parse out files marked with "// File: <filename>"
$pattern = '(?ms)// File: (?<fname>.+?)\r?\n(?<code>.*?)(?=(?:// File: )|\z)'
[regex]::Matches($text, $pattern) | ForEach-Object {
    $fname = $_.Groups['fname'].Value.Trim()
    $code  = $_.Groups['code'].Value.TrimEnd()
    Write-Host "Writing file: $fname"
    $path = Join-Path (Get-Location) $fname
    $code | Out-File -FilePath $path -Encoding utf8
}

# 4) Git add/commit/push
Write-Host "Staging changes..."
git add .

Write-Host "Committing..."
git commit -m "Auto-regenerate WrestleEdit.Core via OpenAI" -q

Write-Host "Pushing to origin/main..."
git push -q

Write-Host "Done!"
