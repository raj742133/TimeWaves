import SwiftUI

struct LocationSearchBar: View {
    @ObservedObject var viewModel: TideViewModel
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
                
                TextField("Search location", text: $searchText)
                    .autocapitalization(.none)
                    .font(.body)
                    .onChange(of: searchText) { _, newValue in
                        guard !newValue.isEmpty else {
                            viewModel.searchResults = []
                            return
                        }
                        isSearching = true
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await MainActor.run {
                                viewModel.searchLocations(newValue)
                                isSearching = false
                            }
                        }
                    }
                
                if isSearching {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            if viewModel.isLoading {
                ProgressView("Loading tide data...")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            if !viewModel.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults) { location in
                            LocationRow(location: location) {
                                Task {
                                    viewModel.saveLocation(location)
                                    await MainActor.run {
                                        searchText = ""
                                        viewModel.searchResults = []
                                    }
                                    viewModel.fetchTideData()
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                }
                .frame(maxHeight: 250)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            } else if !viewModel.recentLocations.isEmpty && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Locations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.recentLocations) { location in
                                LocationRow(location: location, isRecent: true) {
                                    viewModel.saveLocation(location)
                                    viewModel.fetchTideData()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .alert("Search Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to search for locations. Please try again.")
        }
    }
}

struct LocationRow: View {
    let location: Location
    var isRecent: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isRecent ? "clock" : "mappin.circle.fill")
                    .foregroundColor(isRecent ? .gray : .blue)
                    .frame(width: 44, height: 44)
                
                Text(location.name)
                    .foregroundColor(.primary)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
} 