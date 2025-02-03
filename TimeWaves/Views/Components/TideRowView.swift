import SwiftUI

struct TideRowView: View {
    let tide: TideData
    let style: RowStyle
    
    enum RowStyle {
        case history
        case forecast
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Time
            Text(tide.timestamp.formatted(date: style == .history ? .abbreviated : .omitted, 
                                        time: .shortened))
                .font(.body)
                .frame(width: style == .history ? 100 : 70, alignment: .leading)
            
            // Type indicator
            if tide.type != .current {
                Image(systemName: tide.type == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(tide.type == .high ? .blue : .teal)
                    .frame(width: 44, height: 44)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
            
            // Height
            Text(String(format: "%.1f m", tide.height))
                .font(.body)
            
            Spacer()
            
            // Type label
            if tide.type != .current {
                Text(tide.type == .high ? "High" : "Low")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .frame(height: 44) // Apple's minimum touch target size
    }
} 