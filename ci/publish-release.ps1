param([Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$Repository,[switch]$KeepDraft)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:OS -ne 'Windows_NT'){throw 'Build and sign releases on Windows.'}
if(-not(Get-Command gh -ErrorAction SilentlyContinue)){throw 'Install GitHub CLI and sign in before publishing.'}
if([string]::IsNullOrWhiteSpace($env:RIFT_PUBLISHER_NAME)){throw 'Set RIFT_PUBLISHER_NAME to the exact signing-certificate publisher.'}
$projectDirectory=Split-Path $PSScriptRoot -Parent
$notesPath=$null
Push-Location $projectDirectory
try {
 & gh auth status --hostname github.com
 if($LASTEXITCODE -ne 0){throw 'GitHub authentication is required.'}
 $repoText=& gh api "repos/$Repository"
 if($LASTEXITCODE -ne 0){throw 'The repository must already exist and be accessible.'}
 if(($repoText|ConvertFrom-Json).private){throw 'Use the approved public installer repository.'}
 $env:RIFT_UPDATE_URL="https://github.com/$Repository/releases/latest/download/"
 & npm run sync:ui
 if($LASTEXITCODE -ne 0){throw 'UI synchronisation failed.'}
 & npm test
 if($LASTEXITCODE -ne 0){throw 'Desktop tests failed.'}
 & npm run dist:win
 if($LASTEXITCODE -ne 0){throw 'Windows build failed.'}
 $version=(Get-Content package.json -Raw|ConvertFrom-Json).version
 $installer=Join-Path $projectDirectory "release/RIFT-Setup-$version-x64.exe"
 $blockmap="$installer.blockmap"
 $metadata=Join-Path $projectDirectory 'release/latest.yml'
 foreach($file in @($installer,$blockmap,$metadata)){if(-not(Test-Path -LiteralPath $file)){throw "Missing artifact: $file"}}
 $installedExecutable=Join-Path $projectDirectory 'release/win-unpacked/RIFT.exe'
 foreach($signedFile in @($installedExecutable,$installer)){
  if(-not(Test-Path -LiteralPath $signedFile)){throw "Missing signed file: $signedFile"}
  $signature=Get-AuthenticodeSignature -FilePath $signedFile
  if($signature.Status -ne 'Valid'){throw 'Application or installer signing is invalid. Nothing was published.'}
  if($null -eq $signature.TimeStamperCertificate){throw 'Timestamp missing. Nothing was published.'}
  $publisher=$signature.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName,$false)
  if($publisher -ne $env:RIFT_PUBLISHER_NAME -or $publisher -eq 'RIFT CI Test'){throw 'The publisher is mismatched or test-only. Nothing was published.'}
 }
 $tag="v$version"
 & gh release view $tag --repo $Repository *> $null
 if($LASTEXITCODE -eq 0){throw 'That release exists. Increment the version instead of overwriting it.'}
 $notesPath=Join-Path ([IO.Path]::GetTempPath()) ("rift-release-"+[guid]::NewGuid().ToString()+'.md')
 @("RIFT $version for Windows x64.",'','Signed installer, update blockmap and metadata.','Checkout capabilities remain those documented in the application.')|Set-Content -LiteralPath $notesPath -Encoding UTF8
 & gh release create $tag $installer $blockmap $metadata --repo $Repository --title "RIFT $version" --notes-file $notesPath --draft
 if($LASTEXITCODE -ne 0){throw 'Upload failed. Inspect any draft before retrying.'}
 if(-not $KeepDraft){& gh release edit $tag --repo $Repository --draft=false --latest;if($LASTEXITCODE -ne 0){throw 'The uploaded draft could not be published.'}}
 Write-Output "Release: https://github.com/$Repository/releases/tag/$tag"
 Write-Output "Update feed: $env:RIFT_UPDATE_URL"
}finally{if($notesPath -and (Test-Path -LiteralPath $notesPath)){Remove-Item -LiteralPath $notesPath -Force};Pop-Location}
