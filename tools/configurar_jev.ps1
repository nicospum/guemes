# Configura una clave aportada por el jugador. No compra ni activa servicios.
# La entrada está oculta; el archivo local de Godot contiene la clave en texto.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$jevAppData = [Environment]::GetFolderPath('ApplicationData')
if ([string]::IsNullOrWhiteSpace($jevAppData)) {
    throw 'No se pudo localizar AppData del usuario de Windows.'
}
$jevUserDirectory = Join-Path $jevAppData 'Godot\app_userdata\Güemes — Juegos de la Patria'
$jevConfigPath = Join-Path $jevUserDirectory 'jev.cfg'

Write-Host 'Güemes se puede jugar completo sin conexión con decisiones locales.'
Write-Host 'Jev usa tu cuenta TypeSafe. El costo depende de esa cuenta; este programa no lo conoce.'
Write-Host 'Esta herramienta no realiza compras, no crea suscripciones y no prueba la API.'
Write-Host 'La clave se guardará en este archivo local, fuera de la carpeta del juego:'
Write-Host $jevConfigPath
Write-Host 'La entrada no se muestra. Dejá el campo vacío para cancelar sin modificar archivos.'

$jevSecureKey = Read-Host 'Clave TypeSafe existente' -AsSecureString
$jevKeyPointer = [IntPtr]::Zero
$jevPlainKey = $null
$jevTemporaryPath = $null
try {
    $jevKeyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($jevSecureKey)
    $jevPlainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($jevKeyPointer).Trim()
    if ([string]::IsNullOrWhiteSpace($jevPlainKey)) {
        Write-Host 'Cancelado. La configuración anterior se conserva.'
        return
    }
    if ($jevPlainKey.Contains("`r") -or $jevPlainKey.Contains("`n") -or $jevPlainKey.Length -gt 4096) {
        throw 'La clave no tiene un formato válido.'
    }

    $jevEscapedKey = $jevPlainKey.Replace('\', '\\').Replace('"', '\"')
    $jevEntry = 'api_key="' + $jevEscapedKey + '"'
    $jevLines = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $jevConfigPath -PathType Leaf) {
        $jevPrevious = [IO.File]::ReadAllLines($jevConfigPath, [Text.Encoding]::UTF8)
        foreach ($jevLine in $jevPrevious) { $jevLines.Add($jevLine) }
    }

    # Preserve unrelated settings and sections; update only typesafe.api_key.
    $jevSectionStart = -1
    $jevSectionEnd = $jevLines.Count
    for ($jevIndex = 0; $jevIndex -lt $jevLines.Count; $jevIndex++) {
        if ($jevLines[$jevIndex] -match '^\s*\[typesafe\]\s*$') {
            $jevSectionStart = $jevIndex
            for ($jevNext = $jevIndex + 1; $jevNext -lt $jevLines.Count; $jevNext++) {
                if ($jevLines[$jevNext] -match '^\s*\[') { $jevSectionEnd = $jevNext; break }
            }
            break
        }
    }
    if ($jevSectionStart -lt 0) {
        if ($jevLines.Count -gt 0) { $jevLines.Add('') }
        $jevLines.Add('[typesafe]')
        $jevLines.Add($jevEntry)
    }
    else {
        $jevExistingKeyIndex = -1
        for ($jevIndex = $jevSectionStart + 1; $jevIndex -lt $jevSectionEnd; $jevIndex++) {
            if ($jevLines[$jevIndex] -match '^\s*api_key\s*=') { $jevExistingKeyIndex = $jevIndex; break }
        }
        if ($jevExistingKeyIndex -ge 0) { $jevLines[$jevExistingKeyIndex] = $jevEntry }
        else { $jevLines.Insert($jevSectionEnd, $jevEntry) }
    }

    [IO.Directory]::CreateDirectory($jevUserDirectory) | Out-Null
    $jevTemporaryPath = Join-Path $jevUserDirectory ('jev-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $jevUtf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllLines($jevTemporaryPath, $jevLines.ToArray(), $jevUtf8)
    if (Test-Path -LiteralPath $jevConfigPath -PathType Leaf) {
        [IO.File]::Replace($jevTemporaryPath, $jevConfigPath, $null)
    }
    else { [IO.File]::Move($jevTemporaryPath, $jevConfigPath) }
    $jevTemporaryPath = $null
    Write-Host 'Clave guardada. Cerrá y abrí Güemes, elegí La Serna y resolvé una ronda.'
    Write-Host 'El indicador distinguirá una decisión en vivo de la alternativa local.'
    Write-Host 'La clave queda en texto en tu archivo local; no lo compartas con la entrega.'
}
finally {
    if ($jevKeyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($jevKeyPointer)
    }
    if ($null -ne $jevSecureKey) { $jevSecureKey.Dispose() }
    $jevPlainKey = $null
    if ($null -ne $jevTemporaryPath -and (Test-Path -LiteralPath $jevTemporaryPath)) {
        Remove-Item -LiteralPath $jevTemporaryPath -Force
    }
}
