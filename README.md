# StayTrack (Apple: iOS & watchOS)

**StayTrack** es un sistema compuesto por dos aplicaciones nativas y un paquete de dominio compartido diseñados para registrar automáticamente cuánto tiempo pasa el usuario en cada lugar físico, con privacidad en local, soporte offline continuo y reconciliación inteligente basada en sensores de movimiento.

---

## 🏗 Arquitectura del Proyecto

El proyecto está estructurado estrictamente según las directrices de [AGENTS.md](AGENTS.md):

* **`StayTrackCore`** (*Swift Package local compartido*):
  * **Modelos SwiftData unificados**: `Place`, `Visit`, `MovementSample` y `Coordinate`.
  * **Lógica de detección pura**: `AnchorZoneDetector` (evaluación de estancias > 2 min, radio configurable 50/75/100m, filtro de precisión GPS y tolerancia a deriva). Totalmente desacoplada de hardware para ejecución en tests y simulación.
  * **Asignación y gestión de lugares**: `PlaceMatcher` (prioridad a favoritos) y `PlaceManager` (fusión de lugares y preservación de histórico).
  * **Motor de Reconciliación**: `VisitReconciler` (prioridad absoluta del Apple Watch y recorte/descarte de estancias ficticias del iPhone).
  * **Exportadores multiformato**:
    * `CSVExporter`: CSV estándar con formato RFC 4180.
    * `XLSXExporter`: Generador OpenXML (.xlsx real) nativo en Swift puro empaquetado con compresión DEFLATE (`zlib`), compatible de inmediato con Microsoft Excel, Apple Numbers y Google Sheets sin dependencias externas pesadas.
    * `MapSnapshotGenerator`: Capturas en alta resolución con `MKMapSnapshotter` con círculos de zona, pines coloreados por categoría y etiquetas visibles de nombres.
    * `GPXExporter` y `KMLExporter`: Waypoints geoespaciales con metadatos.

* **`StayTrack Watch`** (*watchOS 10+*):
  * App 100% independiente (`WKRunsIndependentlyOfCompanionApp: true`).
  * Registra estancias y actividad física (`CMMotionActivityManager`, `CMPedometer`) con la pantalla apagada o sin iPhone cerca.
  * Persistencia local con SwiftData en disco del reloj y encolado en background vía `WatchConnectivity` (`transferUserInfo`).
  * Interfaz futurista en dark mode, tarjeta Hero con contador en vivo, micro-animación de check-in con háptica (`WKInterfaceDevice.current().play(.success)`).

* **`StayTrack iOS`** (*iOS 17+*):
  * App compañera para visualización, edición manual de estancias y exportación de informes.
  * **Modo Respaldo Inteligente**: El iPhone activa su GPS únicamente cuando el Apple Watch está desconectado o inalcanzable. Si el reloj se reconecta tras haberse movido mientras el iPhone estaba quieto, aplica reconciliación inmediata.
  * **Gestión de Favoritos y Lugares**: Creación rápida con un toque desde la posición actual, edición de radios, renombrado y fusión de lugares con migración de histórico.
  * **Informes y Gráficos**: Gráficos interactivos con Swift Charts (tiempo por lugar y categoría) y exportación directa con `UIActivityViewController`.

---

## 🔐 Permisos y Configuración de Info.plist

Ambas aplicaciones requieren permisos explícitos de ubicación y movimiento para operar según las especificaciones:

### iOS (`StayTrackiOS/Info.plist`)
* **`NSLocationAlwaysAndWhenInUseUsageDescription`**: *"StayTrack necesita acceso continuo a tu ubicación en segundo plano para registrar estancias como respaldo cuando no lleves el Apple Watch."*
* **`NSLocationWhenInUseUsageDescription`**: *"StayTrack registra el tiempo de permanencia dentro de tus lugares y zonas configuradas."*
* **`NSMotionUsageDescription`**: *"StayTrack analiza el movimiento para desambiguar visitas y otorgar prioridad al dispositivo que realmente se desplaza cuando uno queda estático."*
* **`UIBackgroundModes`**: Incluye `location` para el modo de respaldo.

### watchOS (`StayTrackWatch/Info.plist`)
* **`NSLocationAlwaysAndWhenInUseUsageDescription`**: *"StayTrack Watch necesita acceso continuo a tu ubicación para registrar de forma autónoma el tiempo de estancia en cada lugar sin depender del iPhone."*
* **`NSLocationWhenInUseUsageDescription`**: *"StayTrack Watch registra el tiempo de permanencia en tus lugares mientras te encuentras en la zona."*
* **`NSMotionUsageDescription`**: *"StayTrack Watch utiliza los sensores de movimiento para verificar si estás en desplazamiento real, otorgar prioridad a las estancias del reloj y desambiguar visitas cuando el iPhone queda estático."*
* **`WKRunsIndependentlyOfCompanionApp`**: `true`.

---

## 📱 Qué Debe Validarse en Dispositivos Físicos

El Simulator de Xcode **no** emula la gestión de energía del kernel, la recepción GPS real ni los coprocesadores de movimiento. En hardware físico real (iPhone y Apple Watch) debe validarse:

1. **Ahorro de batería y ciclo de vida en segundo plano**:
   * En Apple Watch, comprobar que la alternancia adaptativa entre baja precisión (`kCLLocationAccuracyHundredMeters`) durante desplazamientos y alta precisión (`kCLLocationAccuracyNearestTenMeters`) durante paradas mantiene el consumo en niveles sostenibles para el día completo.
   * Verificar que `WKExtendedRuntimeSession` preserva la estancia activa al entrar en reposo con la muñeca hacia abajo (*Wrist Down*).

2. **Detección corporal de movimiento**:
   * Caminar o correr llevando puesto el reloj y verificar que `WatchMotionDetector` registra el evento a través de `CMMotionActivityManager` / `CMPedometer`.

3. **Reconciliación: iPhone estático y Watch en movimiento**:
   * Dejar el iPhone quieto en una mesa (por ejemplo en el trabajo o casa) y salir a caminar llevando puesto únicamente el Apple Watch.
   * Al regresar y reconectarse por Bluetooth/Wi-Fi, verificar que la estancia ficticia generada por el iPhone se recorta o descarta automáticamente en favor de la actividad del reloj.

4. **Sincronización en cola offline**:
   * Poner el iPhone en Modo Avión durante una parada superior a 2 minutos con el reloj puesto.
   * Desactivar el Modo Avión y comprobar que el paquete `SyncPayload` se transfiere automáticamente mediante el daemon de `WCSession.transferUserInfo` sin duplicar registros.

---

## 🛠 Verificación de Compilación y Tests

El proyecto se valida ejecutando los comandos de build y testing en terminal:

```bash
# 1. Ejecutar la suite completa de tests unitarios de StayTrackCore
swift test --package-path StayTrackCore

# 2. Compilar la app nativa de iOS para simulador
xcodebuild -scheme StayTrack -destination "generic/platform=iOS Simulator"

# 3. Compilar la app nativa de watchOS para simulador
xcodebuild -scheme StayTrackWatch -destination "generic/platform=watchOS Simulator"
```
