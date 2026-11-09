$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:RIFT_CI_VERSION -notmatch '^\d+\.\d+\.\d+$'){throw 'Invalid version'}
$installer=Join-Path $PWD "validation/RIFT-Setup-$env:RIFT_CI_VERSION-x64.exe"
$target=Join-Path $env:RUNNER_TEMP 'rift-app'
$install=Start-Process -FilePath $installer -ArgumentList @('/S',"/D=$target") -PassThru
if(-not $install.WaitForExit(120000)){ $install.Kill();throw 'Windows installation timed out' }
if($install.ExitCode -ne 0){throw "Windows installation failed: $($install.ExitCode)"}
$app=Join-Path $target 'RIFT.exe'
if(-not(Test-Path -LiteralPath $app)){throw 'Installed app was not found.'}
$env:ELECTRON_ENABLE_LOGGING='1'
$stdout=Join-Path $PWD 'validation/windows-smoke.log'
$stderr=Join-Path $PWD 'validation/windows-smoke-errors.log'
$process=Start-Process -FilePath $app -ArgumentList @('--smoke-test','--disable-gpu') -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $process.WaitForExit(60000)){ $process.Kill();throw 'Windows app startup timed out' }
if($process.ExitCode -ne 0){throw "Windows app startup failed: $($process.ExitCode)"}
$text=Get-Content -LiteralPath $stdout -Raw
if($text -notmatch 'RIFT_SMOKE_OK'){throw 'App exited without a smoke-test confirmation.'}
@{platform='Windows';version=$env:RIFT_CI_VERSION;install='passed';startup='passed';publisherSigning='unsigned';checkoutVerification='not tested'}|ConvertTo-Json|Set-Content validation/result.json -Encoding UTF8
Write-Output 'Native Windows installation and RIFT startup passed.'
