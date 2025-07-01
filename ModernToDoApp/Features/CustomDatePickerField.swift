import SwiftUI

struct CustomDatePickerField: View {
    @Binding var date: Date?
    @State private var dateString: String = ""
    @State private var showingDatePickerSheet = false
    @State private var selectedDateInSheet: Date = Date() // Temporary state for the sheet's DatePicker

    var body: some View {
        HStack {
            TextField("date.placeholder_example".localized, text: $dateString)
                .keyboardType(.default)
                .onChange(of: dateString) { newValue in
                    if let parsedDate = parseDate(from: newValue) {
                        date = parsedDate
                    }
                }
                .onSubmit {
                    if let parsedDate = parseDate(from: dateString) {
                        date = parsedDate
                    } else {
                        date = nil
                    }
                }
            
            Button(action: {
                selectedDateInSheet = date ?? Date() // Initialize with current date or now
                showingDatePickerSheet = true
            }) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .highPriorityGesture(
                TapGesture()
                    .onEnded { _ in
                        selectedDateInSheet = date ?? Date()
                        showingDatePickerSheet = true
                    }
            )
            .sheet(isPresented: $showingDatePickerSheet) {
                NavigationView {
                    VStack {
                        Spacer()
                        
                        DatePicker(
                            "",
                            selection: $selectedDateInSheet,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                        
                        Spacer()
                    }
                    .navigationTitle("date.select_due_date".localized)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("action.cancel".localized) {
                                showingDatePickerSheet = false // Dismiss without saving
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("action.done".localized) {
                                date = selectedDateInSheet
                                dateString = formatDateForDisplay(selectedDateInSheet)
                                showingDatePickerSheet = false
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if let existingDate = date {
                dateString = formatDateForDisplay(existingDate)
            }
        }
    }
    
    private func parseDate(from dateString: String) -> Date? {
        // Try to parse common date formats
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy HH:mm"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy HH:mm"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy"
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let parsedDate = formatter.date(from: dateString) {
                return parsedDate
            }
        }
        return nil
    }
    
    private func formatDateForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}