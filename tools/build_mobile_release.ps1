param(
    [ValidateSet('prod','demo')][string]$Flavor='prod',
    [Parameter(Mandatory=$true)][ValidatePattern('^chorvam-[a-z0-9-]+$')][string]$Milestone
)
$ErrorActionPreference='Stop'
$repository=Split-Path $PSScriptRoot -Parent
$destination=Join-Path $repository "data/artifacts/$Milestone"
if(Test-Path -LiteralPath $destination){throw 'Choose a new artifact folder; existing artifacts are retained'}
$androidSdk=$env:ANDROID_SDK_ROOT
if(-not $androidSdk){$androidSdk=Join-Path $env:LOCALAPPDATA 'Android/Sdk'}
$buildTools=Get-ChildItem -LiteralPath (Join-Path $androidSdk 'build-tools') -Directory |
    Where-Object Name -Match '^\d+\.\d+\.\d+$' |
    Sort-Object {[version]$_.Name} -Descending | Select-Object -First 1
if(-not $buildTools){throw 'Android SDK build-tools not found'}
$task=':app:assemble'+(Get-Culture).TextInfo.ToTitleCase($Flavor)+'Release'
Push-Location (Join-Path $repository 'mobile/android')
try {
    & ./gradlew.bat $task '-Psplit-per-abi=true' '-Ptarget-platform=android-arm64' '-Pforce-version-code-ignoring-abi=true'
    if($LASTEXITCODE -ne 0){throw 'Release build failed'}
} finally {Pop-Location}
$source=Join-Path $repository "mobile/build/app/outputs/apk/$Flavor/release/app-$Flavor-arm64-v8a-release.apk"
$expectedPackage='ai.biolivestock.biolivestock_capture'
if($Flavor -eq 'demo'){$expectedPackage+='.demo'}
$manifest=& (Join-Path $buildTools.FullName 'aapt.exe') dump badging $source
if($LASTEXITCODE -ne 0){throw 'APK manifest unavailable'}
if(($manifest | Select-String '^package:') -notmatch "name='$([regex]::Escape($expectedPackage))' versionCode='1'"){throw 'Unexpected package/version'}
$permissions=& (Join-Path $buildTools.FullName 'aapt.exe') dump permissions $source
if($LASTEXITCODE -ne 0){throw 'APK permissions unavailable'}
$internet=($permissions -join "`n") -match 'android.permission.INTERNET'
if(($Flavor -eq 'demo' -and $internet) -or ($Flavor -eq 'prod' -and -not $internet)){throw 'Incorrect network permission isolation'}
$signature=& (Join-Path $buildTools.FullName 'apksigner.bat') verify --verbose --print-certs $source
if($LASTEXITCODE -ne 0 -or ($signature -join "`n") -notmatch '8e43cfb55a120f18a62cf955d19a5ed40816f34a96c1416b27644b08de500c90'){throw 'Original APK signer not verified'}
New-Item -ItemType Directory -Path $destination | Out-Null
$apk=Join-Path $destination "app-$Flavor-release.apk"
Copy-Item -LiteralPath $source -Destination $apk
$manifest | Set-Content -LiteralPath (Join-Path $destination 'manifest.txt')
$permissions | Set-Content -LiteralPath (Join-Path $destination 'permissions.txt')
$signature | Set-Content -LiteralPath (Join-Path $destination 'signature.txt')
$digest=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
"$digest  app-$Flavor-release.apk" | Set-Content -LiteralPath (Join-Path $destination 'SHA256SUMS.txt')
Write-Output "$apk`nSHA256: $digest`nPackage/version/signer/network permissions verified. No device access."
