import Foundation

/// Objeto de transferencia de datos para MovementSample.
public struct MovementSampleDTO: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var device: DeviceSource
    public var startDate: Date
    public var endDate: Date

    public var dispositivo: DeviceSource {
        get { device }
        set { device = newValue }
    }
    public var inicio: Date {
        get { startDate }
        set { startDate = newValue }
    }
    public var fin: Date {
        get { endDate }
        set { endDate = newValue }
    }

    public var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    public init(
        id: UUID = UUID(),
        device: DeviceSource = .watch,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.device = device
        self.startDate = startDate
        self.endDate = endDate
    }

    public init(from sample: MovementSample) {
        self.id = sample.id
        self.device = sample.dispositivo
        self.startDate = sample.inicio
        self.endDate = sample.fin
    }
}
