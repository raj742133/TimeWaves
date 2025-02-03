import SwiftUI

struct TideHistoryView: View {
    @ObservedObject var viewModel: TideViewModel
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                LocationSearchBar(viewModel: viewModel)
                
                DatePicker("Select Date",
                          selection: $selectedDate,
                          in: ...Date(),
                          displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                List(viewModel.tideData.filter { 
                    Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate)
                }) { tide in
                    TideListRow(tide: tide, style: .history)
                }
            }
            .navigationTitle("Tide History")
        }
    }
} 