import Foundation

/// Documentación formal de las limitaciones reales de la plataforma iOS/watchOS
/// y guía de validación en dispositivos físicos.
public enum PlatformLimitations {

    /// Resumen de limitaciones de la plataforma y consideraciones operativas
    public static let architecturalReport: String = """
    ================================================================================
    STAYTRACK — LIMITACIONES REALES DE ARQUITECTURA EN iOS Y watchOS
    ================================================================================

    1. DETECCIÓN DE MOVIMIENTO (CoreMotion):
       - Limitación del simulador: CMMotionActivityManager.isActivityAvailable() siempre
         retorna `false` en el simulador de Xcode. El coprocesador de movimiento (M-series)
         y el acelerómetro no están emulados.
       - Validación física requerida:
         a) Dejar el iPhone en reposo en una mesa (stationary == true).
         b) Caminar con el Apple Watch en la muñeca (walking == true) dentro y fuera de zonas.
         c) Verificar que la lógica de reconciliación descarta la estancia solapada del iPhone
            estático en favor del Apple Watch en movimiento.

    2. SEGUIMIENTO DE UBICACIÓN EN SEGUNDO PLANO (CoreLocation):
       - Limitación en iOS: iOS aplica políticas agresivas de suspensión de energía (Jetsam).
         Sin la capacidad de fondo 'Location updates' (UIBackgroundModes -> location) y
         el inicio explícito de CLBackgroundActivitySession (iOS 17+), el proceso es suspendido
         en menos de 30 segundos tras pasar a segundo plano.
       - Consumo de batería vs. Precisión:
         Utilizar `kCLLocationAccuracyBest` de forma continua drena la batería de un iPhone en ~8 horas
         y la del Apple Watch en ~4-5 horas. StayTrack utiliza `kCLLocationAccuracyNearestTenMeters`
         con `distanceFilter = 10m` y `pausesLocationUpdatesAutomatically = true` para mitigar el consumo
         hasta un 40%.
       - WatchOS en modo autónomo:
         Cuando el Apple Watch está desconectado del iPhone, activa su propia antena GPS interna.
         CoreLocation en watchOS requiere que la sesión de fondo esté adecuadamente autorizada.

    3. SINCRONIZACIÓN Y CONECTIVIDAD (WatchConnectivity):
       - Simulación vs. Realidad:
         Aunque Xcode soporta emparejamiento de simuladores, el comportamiento real de conmutación
         entre Bluetooth Low Energy (BLE), Wi-Fi ad-hoc y Conexión Celular solo puede validarse
         en hardware físico.
       - Resiliencia: `transferUserInfo` garantiza la entrega encolando los mensajes en el daemon
         del sistema (`companionappd`), lo cual asegura que los datos no se pierdan si un dispositivo
         se apaga o pierde cobertura temporalmente.

    4. CRITERIOS DE CHECK-IN Y FILTRADO:
       - Umbral de 2 minutos: Evita falsos check-ins en atascos o paradas breves de semáforo.
       - Filtro de precisión: Lecturas con horizontalAccuracy > 50 m o valores negativos (error)
         se descartan para neutralizar rebotes en cañones urbanos o interiores de edificios.
    ================================================================================
    """
}
