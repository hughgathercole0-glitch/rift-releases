$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$env:CSC_IDENTITY_AUTO_DISCOVERY='false'
$work=Join-Path $env:RUNNER_TEMP 'rift-update-test'
New-Item -ItemType Directory -Path $work -Force|Out-Null
Write-Output 'Creating test-only code certificate'
$code=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=RIFT CI Test' -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(1)
Write-Output 'Creating localhost TLS certificate'
$tls=New-SelfSignedCertificate -DnsName localhost -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(1)
$codeCer=Join-Path $work 'code.cer'
$tlsCer=Join-Path $work 'tls.cer'
Export-Certificate -Cert $code -FilePath $codeCer|Out-Null
Export-Certificate -Cert $tls -FilePath $tlsCer|Out-Null
Write-Output 'Trusting certificates only in disposable runner machine store'
& certutil.exe -f -addstore Root $codeCer
if($LASTEXITCODE -ne 0){throw 'Test code root import failed'}
& certutil.exe -f -addstore Root $tlsCer
if($LASTEXITCODE -ne 0){throw 'Test TLS root import failed'}
$pass=[guid]::NewGuid().ToString()
Write-Output "::add-mask::$pass"
$secure=ConvertTo-SecureString $pass -AsPlainText -Force
$pfx=Join-Path $work 'tls.pfx'
Export-PfxCertificate -Cert $tls -FilePath $pfx -Password $secure|Out-Null
$target=Join-Path $work 'installed'
$old=Join-Path $PWD 'validation/RIFT-Setup-0.6.0-x64.exe'
Write-Output 'Installing original public preview'
$install=Start-Process $old -ArgumentList @('/S',"/D=$target") -PassThru
if(-not $install.WaitForExit(120000)){throw 'Initial install timed out'}
if($install.ExitCode -ne 0){throw 'Initial install failed'}
$app=Join-Path $target 'RIFT.exe'
if(-not(Test-Path $app)){throw 'Initial application was not installed'}
$source=Join-Path $work 'next-source'
Write-Output 'Extracting next-version fixture'
& node ci/unpack-next.cjs (Join-Path $target 'resources/app.asar') $source
if($LASTEXITCODE -ne 0){throw 'Next-version source extraction failed'}
Write-Output 'Running installed agent tests on native Windows'
& node --test (Join-Path $source 'agent/engine.test.mjs') (Join-Path $source 'agent/connections.test.mjs')
if($LASTEXITCODE -ne 0){throw 'Native Windows agent fixture tests failed'}
$builder=Join-Path $PWD 'ci-tools/node_modules/.bin/electron-builder.cmd'
$config=Join-Path $PWD 'ci/test-builder.cjs'
Write-Output 'Building next-version test installer'
for($attempt=1;$attempt -le 3;$attempt++){
 $buildLog=Join-Path $PWD 'validation/next-build.log'
 & $builder --projectDir $source --config $config --win nsis --x64 --publish never 2>&1|Tee-Object -FilePath $buildLog
 if($LASTEXITCODE -eq 0){break}
 $buildText=Get-Content -LiteralPath $buildLog -Raw
 if($attempt -eq 3 -or $buildText -notmatch '50[234]|ETIMEDOUT|ECONNRESET'){throw 'Next-version build failed'}
 Write-Output 'Retrying transient build-tool download failure using cached dependencies'
 Start-Sleep -Seconds 3
}
$server=Join-Path $work 'server'
New-Item -ItemType Directory -Path $server -Force|Out-Null
$next=Join-Path $env:RUNNER_TEMP 'rift-next-build/RIFT-Setup-0.6.1-x64.exe'
Copy-Item $next (Join-Path $server 'bad.exe')
Copy-Item $next (Join-Path $server 'good.exe')
Write-Output 'Signing next-version installer with disposable test certificate'
$signature=Set-AuthenticodeSignature -FilePath (Join-Path $server 'good.exe') -Certificate $code -HashAlgorithm SHA256
if($signature.Status -ne 'Valid'){throw "Test signature invalid: $($signature.Status)"}
Copy-Item (Join-Path $server 'good.exe') (Join-Path $server 'interrupted.exe')
[IO.File]::AppendAllText((Join-Path $server 'interrupted.exe'),'network-test-fixture')
Set-Content -LiteralPath (Join-Path $server 'mode.txt') -Value good
$state=@{app=$app;source=$source;server=$server;pfx=$pfx;certificateScope='isolated test runner only';publisher='RIFT CI Test'}
$state|ConvertTo-Json|Set-Content validation/update-fixture.json -Encoding UTF8
"RIFT_TEST_APP=$app"|Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
"RIFT_TEST_SERVER=$server"|Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
"RIFT_TEST_PFX=$pfx"|Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
"RIFT_TEST_PFX_PASSWORD=$pass"|Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
Write-Output 'Isolated Windows signing and TLS fixtures prepared. No test certificate is published.'
