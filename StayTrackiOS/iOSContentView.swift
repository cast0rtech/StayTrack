import SwiftUI
import SwiftData
import StayTrackCore

/// Vista contenedora principal para StayTrack iOS con navegación por pestañas,
/// estilo futurista oscuro y acentos vibrantes.
public struct iOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = iOSTrackingViewModel()
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.needle.fill")
                }
                .tag(0)

            VisitsHistoryView(viewModel: viewModel)
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            PlacesManagementView(viewModel: viewModel)
                .tabItem {
                    Label("Lugares", systemImage: "mappin.and.ellipse")
                }
                .tag(2)

            ExportReportsView(viewModel: viewModel)
                .tabItem {
                    Label("Exportar", systemImage: "square.and.arrow.up.fill")
                }
                .tag(3)

            SettingsDiagnosticView(viewModel: viewModel)
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.cyan)
        .onAppear {
            viewModel.configure(modelContext: modelContext)
        }
    }
}
