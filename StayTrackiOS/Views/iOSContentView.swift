import SwiftUI
import SwiftData
import StayTrackCore

/// Contenedor principal de la app StayTrack para iOS.
public struct iOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var trackingViewModel = iOSTrackingViewModel()

    public init() {}

    public var body: some View {
        TabView {
            DashboardView(viewModel: trackingViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }

            FavoritesView(viewModel: trackingViewModel)
                .tabItem {
                    Label("Favoritos", systemImage: "star.fill")
                }

            PlacesListView(viewModel: trackingViewModel)
                .tabItem {
                    Label("Lugares", systemImage: "mappin.and.ellipse")
                }

            VisitsHistoryView(viewModel: trackingViewModel)
                .tabItem {
                    Label("Estancias", systemImage: "clock.fill")
                }

            ExportReportsView(trackingViewModel: trackingViewModel)
                .tabItem {
                    Label("Informes", systemImage: "square.and.arrow.up.fill")
                }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .onAppear {
            trackingViewModel.setModelContext(modelContext)
            if trackingViewModel.authorizationStatus == .notDetermined {
                trackingViewModel.requestAuthorization()
            }
        }
    }
}
