$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$work=Join-Path $env:RUNNER_TEMP 'rift-native-package'
$payload=Join-Path $work 'payload'
$prepackaged=Join-Path $work 'win-unpacked'
$source=Join-Path $work 'source'
New-Item -ItemType Directory -Force -Path $payload|Out-Null
$seven=(Get-Command 7z.exe).Source
& $seven e -r -y '-bsp0' '-bso0' (Join-Path $PWD 'validation/RIFT-Setup-0.6.1-x64.exe') "-o$payload" '*app-64.7z'
if($LASTEXITCODE -ne 0){throw 'Application payload extraction failed'}
& $seven x -y '-bsp0' '-bso0' (Join-Path $payload 'app-64.7z') "-o$prepackaged"
if($LASTEXITCODE -ne 0){throw 'Windows runtime extraction failed'}
& node ci/native-package.cjs $prepackaged $source
if($LASTEXITCODE -ne 0){throw 'Next version preparation failed'}
$builder=Join-Path $PWD 'ci-tools/node_modules/.bin/electron-builder.cmd'
$config=Join-Path $PWD 'ci/test-builder.cjs'
for($attempt=1;$attempt -le 3;$attempt++){
 $buildLog=Join-Path $PWD 'validation/native-build.log'
 & $builder --projectDir $source --config $config --prepackaged $prepackaged --win nsis --x64 --publish never 2>&1|Tee-Object -FilePath $buildLog
 if($LASTEXITCODE -eq 0){break}
 if($attempt -eq 3 -or (Get-Content $buildLog -Raw) -notmatch '50[234]|ETIMEDOUT|ECONNRESET'){throw 'Native Windows installer build failed'}
 Start-Sleep -Seconds 3
}
$exe=Join-Path $PWD 'validation/RIFT-Setup-0.6.2-x64.exe'
Copy-Item (Join-Path $env:RUNNER_TEMP 'rift-next-build/RIFT-Setup-0.6.2-x64.exe') $exe
$hash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  RIFT-Setup-0.6.2-x64.exe"|Set-Content validation/SHA256SUMS.txt -Encoding ASCII
@{version='0.6.2';filename='RIFT-Setup-0.6.2-x64.exe';size=(Get-Item $exe).Length;sha256=$hash;unsigned=$true;nativeWindowsBuild=$true}|ConvertTo-Json|Set-Content validation/native-release.json -Encoding utf8
$previousVersion=$env:RIFT_CI_VERSION
try {$env:RIFT_CI_VERSION='0.6.2';& ./ci/smoke.ps1}finally{$env:RIFT_CI_VERSION=$previousVersion}
$probeTarget=Join-Path $env:RUNNER_TEMP 'rift-app'
$userData=Join-Path $env:APPDATA 'RIFT'
New-Item -ItemType Directory -Force -Path $userData|Out-Null
$marker=Join-Path $userData 'rift-ci-uninstall-retention.txt'
'Synthetic fixture only'|Set-Content $marker
$uninstaller=Join-Path $env:RUNNER_TEMP 'rift-standalone-uninstall.exe'
Copy-Item (Join-Path $probeTarget 'Uninstall RIFT.exe') $uninstaller
Start-Sleep -Seconds 1
$process=Start-Process $uninstaller -ArgumentList @('/S','/KEEP_APP_DATA','--updated',"_?=$probeTarget") -PassThru
if(-not $process.WaitForExit(90000)){$process.Kill();throw 'Native uninstaller timed out'}
if($process.ExitCode -ne 0 -or (Test-Path (Join-Path $probeTarget 'RIFT.exe'))){& ./ci/windows-diagnostics.ps1;throw "Native uninstaller failed: $($process.ExitCode)"}
if(-not(Test-Path $marker)){throw 'Uninstaller removed the user-data fixture'}
@{version='0.6.2';install='passed';startup='passed';uninstall='passed';userDataRetained=$true}|ConvertTo-Json|Set-Content validation/native-install-result.json -Encoding utf8
Write-Output 'Native Windows installer, startup, uninstaller and user-data retention passed.'
