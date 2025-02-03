import SwiftUI

struct TideGraphView: View {
    @ObservedObject var viewModel: TideViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LocationSearchBar(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView("Loading tide data...")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else if !viewModel.tideData.isEmpty {
                        TideLineGraph(data: viewModel.tideData)
                            .frame(height: 200)
                            .padding()
                        
                        TideDataView(tideData: viewModel.tideData)
                    }
                }
            }
            .navigationTitle("Tide Graph")
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct TideLineGraph: View {
    let data: [TideData]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                GridLinesView()
                
                // Tide curve
                Path { path in
                    guard !data.isEmpty else { return }
                    
                    let relevantData = getRelevantTideData()
                    let points = relevantData.enumerated().map { index, tide -> CGPoint in
                        let x = CGFloat(index) / CGFloat(relevantData.count - 1) * geometry.size.width
                        let heightRatio = (tide.height - minHeight) / (maxHeight - minHeight)
                        let y = (1 - heightRatio) * geometry.size.height
                        return CGPoint(x: x, y: y)
                    }
                    
                    // Draw curve
                    if points.count > 1 {
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            let control1 = CGPoint(
                                x: points[i-1].x + (points[i].x - points[i-1].x) / 3,
                                y: points[i-1].y
                            )
                            let control2 = CGPoint(
                                x: points[i].x - (points[i].x - points[i-1].x) / 3,
                                y: points[i].y
                            )
                            path.addCurve(to: points[i], control1: control1, control2: control2)
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Current tide indicator
                if let currentTide = data.first(where: { $0.type == .current }) {
                    CurrentTideIndicator(tide: currentTide, geometry: geometry)
                }
            }
        }
    }
    
    private func getRelevantTideData() -> [TideData] {
        let sortedData = data.sorted { $0.timestamp < $1.timestamp }
        guard let currentIndex = sortedData.firstIndex(where: { $0.type == .current }) else {
            return sortedData
        }
        
        var relevantIndices: [Int] = [currentIndex]
        
        // Find previous high/low
        if let prevHighLowIndex = sortedData[..<currentIndex].lastIndex(where: { $0.type != .current }) {
            relevantIndices.append(prevHighLowIndex)
        }
        
        // Find next high/low
        if let nextHighLowIndex = sortedData[(currentIndex + 1)...].firstIndex(where: { $0.type != .current }) {
            relevantIndices.append(nextHighLowIndex)
        }
        
        return relevantIndices.sorted().map { sortedData[$0] }
    }
    
    private var maxHeight: Double {
        data.map(\.height).max() ?? 1.0
    }
    
    private var minHeight: Double {
        data.map(\.height).min() ?? 0.0
    }
}

struct GridLinesView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Horizontal lines
                for i in 0...4 {
                    let y = CGFloat(i) * geometry.size.height / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }
}

struct CurrentTideIndicator: View {
    let tide: TideData
    let geometry: GeometryProxy
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .position(x: geometry.size.width * 0.5,
                     y: geometry.size.height * (1 - normalizedHeight))
    }
    
    private var normalizedHeight: CGFloat {
        CGFloat((tide.height - 0) / (5 - 0)) // Assuming tide range 0-5m
    }
}

struct CurrentTideInfoView: View {
    let tide: TideData
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Current Tide")
                .font(.headline)
            Text(String(format: "%.2f meters", tide.height))
                .font(.title2)
            Text(tide.timestamp, style: .time)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
} 