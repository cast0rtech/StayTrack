# AGENTS.md — StayTrack (Apple)

## Rol
Actúa como desarrollador iOS/watchOS senior. Toma decisiones de
arquitectura con criterio propio, explica brevemente las no triviales
y señala cualquier limitación real de iOS/watchOS que afecte al proyecto.

## Proyecto
Dos apps nativas que registran cuánto tiempo pasa el usuario en cada lugar:
- **StayTrack Watch** (watchOS, independiente, funciona sin iPhone)
- **StayTrack iOS** (iOS, sincroniza, edita lugares y exporta informes)
- **StayTrackCore** (Swift Package local compartido por ambas)

## Reglas de dominio
- Check-in: se crea un Visit cuando el usuario permanece más de 2 minutos
  dentro de una zona de radio R (50 m o 100 m, configurable, por defecto
  75 m) desde un punto ancla. Se cierra al salir de esa zona de forma
  sostenida. Filtra lecturas GPS con mala precisión.
- Place: lugar agrupado por proximidad. Puede ser favorito (isFavorite),
  con nombre, categoría (casa, trabajo, entrenamiento, médico, otro) e
  icono. Los favoritos tienen prioridad sobre lugares sin nombre al
  asignar una estancia.
- Si el Watch está conectado, sus datos tienen prioridad sobre los del
  iPhone. Si no está conectado, el iPhone registra por su cuenta.
- Si el iPhone queda parado (ej. olvidado) mientras el Watch detecta
  movimiento, prevalece el dispositivo que se mueve: el Visit del iPhone
  se recorta o descarta en el tramo solapado.
- Cada Visit y Place tiene UUID estable; la sincronización hace upsert.
- Exportación: CSV, .xlsx real, imagen de mapa con los lugares marcados,
  y archivo GPX/KML con los lugares como waypoints.

## Arquitectura y código
- Swift moderno (async/await), SwiftUI, SwiftData, MVVM.
- Modelos y lógica de reconciliación viven SOLO en StayTrackCore. Nunca
  los dupliques en los targets de iOS o watchOS.
- Sincronización con WatchConnectivity (transferUserInfo / transferFile).
- Comenta las decisiones no triviales (umbrales, radios, reconciliación).
- Tests unitarios para la lógica de reconciliación: solapamiento total,
  parcial y nulo.

## Diseño visual
- Moderno y futurista, dark mode first.
- Acentos vibrantes (degradados azul/morado/cian), tipografía SF Pro con
  jerarquía clara, tarjetas redondeadas, glassmorphism sutil
  (.ultraThinMaterial), micro-animaciones suaves.
- Gráficos con Swift Charts, estilo dashboard.
- En watchOS: texto grande, poca información por pantalla, misma
  identidad visual que en iOS.

## Flujo de trabajo
- Trabaja por fases: 1) StayTrackCore, 2) app watchOS, 3) app iOS.
- Antes de dar una tarea por terminada, verifica que compila con
  xcodebuild para el esquema correspondiente y corrige los errores.
- No añadas dependencias externas sin justificarlo (previstas: una
  librería SPM para .xlsx, como CoreXLSX).
- El seguimiento de movimiento y ubicación no se puede probar en
  simulador: indica qué debe validarse en un dispositivo físico.
