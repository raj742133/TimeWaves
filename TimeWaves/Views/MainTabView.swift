import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = TideViewModel()
    
    var body: some View {
        TabView {
            TideHistoryView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
            
            TideGraphView(viewModel: viewModel)
                .tabItem {
                    Label("Graph", systemImage: "waveform.path.ecg")
                }
        }
    }
} 