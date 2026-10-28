# Jev / TypeSafe: contrato y estado de la integración

## Estado comprobado

El cliente real de HTTP está implementado en `scripts/jev_client.gd` y compila con Godot 4.7.2. Se ejecutaron 15 comprobaciones de contrato y recuperación sin fallos. La API de TypeSafe no se llamó con una credencial válida en este entorno: no hay `TYPESAFE_API_KEY` configurada. **No se ha comprobado una decisión real de Jev aplicada a una partida.** La partida utiliza una alternativa local cuando falta acceso.

Las respuestas inválidas y el timeout se inyectaron en el punto de entrada del transporte para probar su recuperación; son pruebas simuladas explícitas. La ruta de alternativa local sí se ejecutó en Godot. El primer resultado local demoró 0 ms según el reloj monotónico de esa ejecución; no representa latencia de red ni calidad de decisiones de Jev.

## Papel en el juego

La integración elige una intención entre las opciones legales que suministran las reglas. Las reglas vuelven a comprobar la opción y resuelven sus efectos. Jev no modifica directamente tropas, recursos, navegación, daño ni victoria. El cliente no necesita interpretar texto libre.

Interfaz:

```gdscript
var client = preload("res://scripts/jev_client.gd").new()
add_child(client)
client.decision_ready.connect(_receive_intent)
client.request_intent(observation, legal_choices, fallback_id, {
    "game_id": game_id, "round": round_number, "state_version": version
})
```

`legal_choices` es un diccionario de identificadores y descripciones; `fallback_id` debe pertenecer a él. `decision_ready` entrega `choice`, `source`, `context`, `latency_ms`, `request_id`, modelo, distribución y motivo. `source` solo es `live` después de un HTTP 200 con respuesta validada; los demás casos producen `local_fallback` con su motivo.

El código de reglas debe llamar a `mark_applied(decision, current_context)` al aceptar la intención. Solo admite una aplicación de cada resultado. Una intención pendiente queda invalidada al reiniciar, cargar o reemplazar la solicitud mediante `invalidate()`. La identidad de partida, ronda y versión impide consumir decisiones de otra situación.

## Datos y frecuencia

El constructor del estado debe mostrar únicamente lo que conoce el actor consultado. El cliente acepta estos campos: `actor`, `scenario`, `round`, `self_forces`, `self_supplies`, `self_cohesion`, `known_sectors`, `visible_enemies`, `visible_resources`, `public_events`, `goal` y `situation`. Excluye campos ajenos a esa lista. La lista no reemplaza el filtrado de unidades ocultas dentro de `visible_enemies`: esa responsabilidad pertenece al constructor de observación de las reglas.

Una consulta contiene un resumen estructurado y una pregunta `Choice`. Solo hay una petición activa; una nueva cancela la anterior. Presupuesto configurado: 2 segundos por petición y al menos 3 segundos entre inicios de llamadas de red. Una ronda puede continuar con la alternativa local al agotarse el presupuesto. No hay consultas por cuadro, por jinete ni por paso de navegación. El gasto real no se midió porque no se hizo una consulta autenticada.

Contrato HTTP verificado el 28 de octubre de 2026:

```json
{
  "model": "jev-latest",
  "state": {"actor": "realistas", "self_supplies": 40},
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "¿Qué intención legal responde mejor a la situación observada de este actor para conservar su capacidad operativa?",
      "criteria": {
        "protect_supply": "Proteger un abastecimiento conocido",
        "regroup": "Reagrupar fuerzas agotadas"
      }
    }
  }
}
```

Endpoint: `POST https://api.typesafe.ai/v1/systemone`. La respuesta se obtiene de `answers.intent.choice`. Se comprueban tipo, pertenencia al conjunto legal, distribución completa, valores finitos, suma aproximada a uno y rango de confianza. La confianza se registra; no concede ventajas ni se usa como umbral arbitrario para inventar otra acción.

## Configurar una clave propia sin incluirla en el juego

La clave se busca primero en la variable de entorno `TYPESAFE_API_KEY`; alternativamente en `[typesafe] api_key` de `user://jev.cfg`, fuera de la instalación. No se incluye ningún secreto en el proyecto o el ejecutable. `TYPESAFE_MODEL` permite elegir un modelo disponible; el valor predeterminado es `jev-latest` y el modelo efectivamente respondido queda registrado.

Ejemplo para iniciar desde PowerShell sin escribir la clave en el historial:

```powershell
$jevSecret = Read-Host "Clave TypeSafe" -AsSecureString
$env:TYPESAFE_API_KEY = [Net.NetworkCredential]::new("", $jevSecret).Password
try { Start-Process .\PatriaGuemes.exe -Wait }
finally { Remove-Item Env:TYPESAFE_API_KEY }
```

El archivo opcional de configuración local guarda la clave como texto; la variable de entorno de la sesión evita crear ese archivo. Para una distribución comercial con clave del desarrollador se necesitaría un servicio propio: esta entrega local usa exclusivamente la clave del jugador, si la aporta.

## Evidencia y prueba que falta

`user://jev_decisions.jsonl` registra solo decisiones aceptadas: identidad de partida/ronda/versión, opción, modo, motivo, tiempo, modelo y payload sin cabecera de autorización. También conserva el hash del payload para reproducirlo. No se usa caché: no puede presentarse una respuesta precargada como una llamada viva.

Para cerrar la aceptación pendiente: configurar acceso autorizado, iniciar una partida del norte, resolver una ronda, comprobar `source: live`, `applied: true`, el modelo respondido y el cambio de intención en el estado de esa partida. Conservar el registro y repetir con conexión ausente para comparar la recuperación. La integración se considera incompleta respecto de ese criterio hasta que se haga esa prueba.

Prueba reproducible sin red:

```text
godot --headless --path . --script tests/jev_contract_test.gd
```

Resultado ejecutado: `checks: 15`, `failures: []`, `live_api_tested: false`, `failure_transport: simulated`.

## Fuentes y habilidad aplicada

- [Skill oficial typesafe-ai](https://github.com/typesafe-ai/skills/blob/302eea662c54bca6730873fe245bec1d69ebc23d/skills/typesafe-ai/SKILL.md), MIT, commit `302eea662c54bca6730873fe245bec1d69ebc23d`, leído completo. Se aplicó la separación entre juicios del modelo y autoridad del código, opciones definidas, payload auditable y errores explícitos.
- [System One](https://docs.typesafe.ai/api/system-one).
- [Choice](https://docs.typesafe.ai/primitives/choice).
- [OpenAPI oficial](https://api.typesafe.ai/openapi.json), versión declarada 0.2.0.

Las reglas locales pueden decidir de forma consistente sin un modelo externo. Jev es una variación de intención opcional, exigida como integración por el encargo, y no una dependencia necesaria para terminar los escenarios.
