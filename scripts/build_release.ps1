param(
    [Parameter(Mandatory = $true)]
    [string]$BackendUrl,

    [Parameter(Mandatory = $true)]
    [string]$NombreEmpresa,

    [Parameter(Mandatory = $true)]
    [string]$NumRegistro,

    [Parameter(Mandatory = $true)]
    [string]$NombreServidor,

    [Parameter(Mandatory = $true)]
    [string]$CelularDestino,

    [string]$NombreUsuario = 'OPERADOR',
    [string]$MiCelular = '',
    [string]$FlutterExe = 'C:\Users\julio\AppData\Local\Programs\flutter\bin\flutter.bat',
    [string]$AdbExe = 'C:\Users\julio\AppData\Local\Android\Sdk\platform-tools\adb.exe',
    [string]$OutputApk = 'D:\Desarrollo_Flutter\clientes\facturame.apk',
    [string]$DeviceId = 'R5CY11ZPTDJ'
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Action
}

Invoke-Step 'Flutter analyze' {
    & $FlutterExe analyze
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter analyze failed.'
    }
}

Invoke-Step 'Flutter test' {
    & $FlutterExe test
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter test failed.'
    }
}

$buildArgs = @(
    'build',
    'apk',
    '--release',
    "--dart-define=APP_DEFAULT_BACKEND_URL=$BackendUrl",
    "--dart-define=APP_DEFAULT_NOMBRE_EMPRESA=$NombreEmpresa",
    "--dart-define=APP_DEFAULT_NUM_REGISTRO=$NumRegistro",
    "--dart-define=APP_DEFAULT_NOMBRE_SERVIDOR=$NombreServidor",
    "--dart-define=APP_DEFAULT_CELULAR_DESTINO=$CelularDestino",
    "--dart-define=APP_DEFAULT_NOMBRE_USUARIO=$NombreUsuario",
    "--dart-define=APP_DEFAULT_MI_CELULAR=$MiCelular"
)

Invoke-Step 'Flutter build apk --release' {
    & $FlutterExe @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter build apk failed.'
    }
}

$releaseApk = Join-Path $PSScriptRoot '..\build\app\outputs\flutter-apk\app-release.apk'
$releaseApk = [System.IO.Path]::GetFullPath($releaseApk)

Invoke-Step 'Copiar APK final' {
    Copy-Item -LiteralPath $releaseApk -Destination $OutputApk -Force
    Get-Item -LiteralPath $OutputApk | Select-Object FullName, Length, LastWriteTime
}

if ($DeviceId -ne '') {
    $devicesOutput = & $AdbExe devices
    $deviceOnline = $devicesOutput | Where-Object { $_ -match "^$([regex]::Escape($DeviceId))\s+device$" }

    if ($deviceOnline) {
        Invoke-Step "Instalar APK en $DeviceId" {
            & $AdbExe -s $DeviceId install -r $OutputApk
            if ($LASTEXITCODE -ne 0) {
                throw 'adb install failed.'
            }
        }
    } else {
        Write-Warning "No se detectó el dispositivo '$DeviceId'. El APK quedó generado en $OutputApk."
    }
}

Write-Host 'APK listo.' -ForegroundColor Green
