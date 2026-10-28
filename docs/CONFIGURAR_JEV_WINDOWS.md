# Jugar sin conexión y habilitar Jev en Windows

## Empezar sin clave

Extraé la entrega y abrí `PatriaGuemes.exe`. Los dos escenarios utilizan reglas locales y se pueden completar sin cuenta TypeSafe. En La Serna, al resolver una ronda sin clave, el indicador informa **alternativa local**. No se inicia una compra, suscripción ni prueba paga.

## Habilitar una clave existente

Necesitás una clave de tu propia cuenta TypeSafe con acceso a System One. El juego no conoce el precio ni el saldo de esa cuenta: las consultas autenticadas pueden generar consumo según sus condiciones. Esta entrega no incluye crédito ni promete gratuidad. No hay una clave compartida incorporada al ejecutable.

1. Cerrá el juego. Abrí PowerShell en la carpeta que contiene `tools`.
2. Ejecutá `powershell -File .\tools\configurar_jev.ps1`.
3. Escribí la clave en el campo oculto. No aparece en pantalla, en el historial del comando ni en el chat. Una entrada vacía cancela sin cambios.
4. Volvé a abrir `PatriaGuemes.exe`, elegí **La Serna** y resolvé una ronda. El indicador dirá **decisión en vivo** solo si hubo una respuesta válida. Si falta red, la clave es rechazada o se agota el tiempo, continuará con **alternativa local** y su motivo.

El script guarda la clave fuera de la carpeta de instalación, en:

```text
%APPDATA%\Godot\app_userdata\Güemes — Juegos de la Patria\jev.cfg
```

El archivo contiene `[typesafe]` y `api_key`. Está en texto en tu perfil local porque Godot debe poder leerlo: no lo incluyas al compartir el juego. El script conserva otras secciones/configuraciones y no llama a la API. Si Windows bloquea el script por su política de ejecución, podés usar la variable de entorno de la sesión que se describe a continuación, sin cambiar esa política.

## Opción sin guardar la clave en un archivo

Desde PowerShell, en la carpeta del ejecutable:

```powershell
$jevSecret = Read-Host "Clave TypeSafe" -AsSecureString
$env:TYPESAFE_API_KEY = [Net.NetworkCredential]::new("", $jevSecret).Password
try { Start-Process .\PatriaGuemes.exe -Wait }
finally { Remove-Item Env:TYPESAFE_API_KEY; $jevSecret.Dispose() }
```

`TYPESAFE_API_KEY` tiene prioridad sobre el archivo local. Para volver al modo sin clave, eliminá esa variable de la sesión y quitá `api_key` de `jev.cfg` o renombrá el archivo. No hace falta reinstalar el juego.

## Verificar que fue una llamada real

En la misma carpeta de datos, `jev_decisions.jsonl` registra decisiones aplicadas. Un registro con `source: "live"`, `applied: true`, modelo respondido y contexto de tu partida demuestra una decisión viva aceptada; `local_fallback` corresponde a reglas locales. No publiques `jev.cfg` junto con el registro.

El cliente y la recuperación local se probaron durante el desarrollo. **La prueba autenticada con Jev sigue pendiente en esta entrega por falta de credencial.** El script PowerShell se preparó para Windows; no se ejecutó sobre el equipo del usuario durante el desarrollo en Linux.

Referencias: [System One](https://docs.typesafe.ai/api/system-one), [Choice](https://docs.typesafe.ai/primitives/choice), [Read-Host de Microsoft](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host).
