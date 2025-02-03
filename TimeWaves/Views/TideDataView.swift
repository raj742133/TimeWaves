import SwiftUI

struct TideDataView: View {
    let tideData: [TideData]
    
    private var filteredData: [TideData] {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        return tideData
            .filter { $0.timestamp >= now && $0.timestamp <= tomorrow }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    private var significantTides: [TideData] {
        filteredData.filter { $0.type != .current }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Current Tide Card
            if let currentTide = tideData.first(where: { $0.type == .current }) {
                CurrentTideCard(tide: currentTide)
            }
            
            // Next High/Low Tide
            if let nextTide = significantTides.first(where: { $0.timestamp > Date() }) {
                NextTideCard(tide: nextTide)
            }
            
            // 24-Hour Forecast
            VStack(alignment: .leading, spacing: 12) {
                Text("24-Hour Forecast")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredData) { tide in
                            TideListRow(tide: tide, style: .forecast)
                                .padding(.vertical, 8)
                            
                            if tide != filteredData.last {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2, y: 1)
            }
        }
        .padding()
    }
}

struct CurrentTideCard: View {
    let tide: TideData
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Current Tide")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(String(format: "%.1f m", tide.height))
                .font(.system(size: 34, weight: .bold))
            
            Text(tide.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, y: 1)
    }
}

struct NextTideCard: View {
    let tide: TideData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Next \(tide.type == .high ? "High" : "Low") Tide")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f m", tide.height))
                    .font(.title2.bold())
                
                Text(tide.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: tide.type == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(tide.type == .high ? .blue : .teal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, y: 1)
    }
} 