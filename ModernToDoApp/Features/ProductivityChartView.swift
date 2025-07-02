import SwiftUI
import Charts
import CoreData

struct DailyCompletion: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct ProductivityChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var dailyCompletions: [DailyCompletion] = []

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                chartContent
            }
        } else {
            NavigationView {
                chartContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var chartContent: some View {
        VStack {
            Text("insights.chart_title".localized)
                .font(.headline)
                .padding()

                if dailyCompletions.isEmpty {
                    ContentUnavailableView("insights.no_data".localized, systemImage: "chart.bar.fill")
                } else {
                    Chart {
                        ForEach(dailyCompletions) { data in
                            BarMark(
                                x: .value("Date", data.date, unit: .day),
                                y: .value("Tasks Completed", data.count)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .padding()
                    .frame(height: 250)
                }
                
                Spacer()
            }
            .navigationTitle("nav.insights".localized)
            .onAppear(perform: loadDailyCompletions)
    }

    private func loadDailyCompletions() {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Task.updatedAt, ascending: true)]

        do {
            let completedTasks = try viewContext.fetch(fetchRequest)
            var dailyCounts: [Date: Int] = [:]
            let calendar = Calendar.current

            for task in completedTasks {
                if let date = task.updatedAt {
                    let startOfDay = calendar.startOfDay(for: date)
                    dailyCounts[startOfDay, default: 0] += 1
                }
            }

            dailyCompletions = dailyCounts.map { (date, count) in
                DailyCompletion(date: date, count: count)
            }.sorted { $0.date < $1.date }

        } catch {
            print("Error fetching completed tasks: \(error)")
        }
    }
}