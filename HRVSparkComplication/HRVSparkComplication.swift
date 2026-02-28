import WidgetKit
import SwiftUI
import HealthKit

private let gaugeTimeframeColor = Color(red: 0.34, green: 0.72, blue: 1.0)

// MARK: - App Group Manager

// We use an App Group or UserDefaults to share data between the main App and the Widget.
// For now, since we haven't set up an App Group, the widget will fetch its own data directly.
// This is perfectly fine for a watchOS complication.

// MARK: - Entry

struct HRVEntry: TimelineEntry {
    let date: Date
    let latestReading: Int?
    let sparkline8h: [Double?]
    let hourlyAverages24h: [Double?]
    let rollingAvg1h: Int?
    let rollingAvg24h: Int?
    let dailyAverages7d: [Double?]
    let dailyAverages30d: [Double?]
}

// MARK: - Default Provider

struct Provider: TimelineProvider {
    // Keep a single manager instance alive for the widget extension process so
    // WCSession delegate callbacks can hydrate long-term payloads over time.
    private static let sharedDataManager = HRVDataManager()
    private var dataManager: HRVDataManager { Self.sharedDataManager }

    func placeholder(in context: Context) -> HRVEntry {
        HRVEntry(
            date: Date(),
            latestReading: 50,
            sparkline8h: [45, 48, 52, 50, 49, 53, 50],
            hourlyAverages24h: [48, 50, 49, 51, 52, 50],
            rollingAvg1h: 50,
            rollingAvg24h: 48,
            dailyAverages7d: [46, 48, 50, 49, 51, 48, 50],
            dailyAverages30d: [45, 47, 49, 48, 50, 49, 48]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HRVEntry) -> ()) {
        let entry = HRVEntry(
            date: Date(),
            latestReading: 50,
            sparkline8h: [45, 48, 52, 50, 49, 53, 50],
            hourlyAverages24h: [48, 50, 49, 51, 52, 50],
            rollingAvg1h: 50,
            rollingAvg24h: 48,
            dailyAverages7d: [46, 48, 50, 49, 51, 48, 50],
            dailyAverages30d: [45, 47, 49, 48, 50, 49, 48]
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        dataManager.fetchAllComplicationData { latestReading, sparkline8h, hourlyAverages24h, rollingAvg1h, rollingAvg24h, dailyAverages7d, dailyAverages30d in
            let entry = HRVEntry(
                date: Date(),
                latestReading: latestReading,
                sparkline8h: sparkline8h,
                hourlyAverages24h: hourlyAverages24h,
                rollingAvg1h: rollingAvg1h,
                rollingAvg24h: rollingAvg24h,
                dailyAverages7d: dailyAverages7d,
                dailyAverages30d: dailyAverages30d
            )
            
            // Retry faster when 30D still appears sparse so companion payload can take over sooner.
            let visible30dCount = dailyAverages30d.compactMap { $0 }.count
            let refreshMinutes = visible30dCount < 20 ? 3 : 15
            let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))

            completion(timeline)
        }
    }
}

// MARK: - Generic Specific Complication Family Views
// We parameterize these so we can reuse them across all 10 complications

struct GenericCircularComplicationView: View {
    var currentValue: Int?
    var dataArray: [Double?]
    var timeframeLabel: String
    
    var gaugeCharacter: String {
        switch timeframeLabel {
        case "8H": return "8"
        case "1D": return "D"
        case "7D": return "W"
        case "1M": return "M"
        default: return ""
        }
    }
    var body: some View {
        let current = Double(currentValue ?? 0)
        let validData = dataArray.compactMap { $0 }
        let minVal = validData.min() ?? 0
        let calculatedMax = validData.max() ?? 100
        let maxVal = max(calculatedMax, current) + 1
        
        Gauge(value: current, in: minVal...maxVal) {
            Text("")
        } currentValueLabel: {
            VStack(spacing: 0) {
                if let val = currentValue {
                    Text("\(val)")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 6, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 20, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 35, x: 0, y: 0)
                } else {
                    Text("--")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                }
                Text(gaugeCharacter)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(gaugeTimeframeColor)
            }
            .offset(y: 2)
        } minimumValueLabel: {
            Text("\(Int(round(minVal)))")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        } maximumValueLabel: {
            Text("\(Int(round(maxVal - 1)))")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.white)
    }
}

struct GenericCornerComplicationView: View {
    var currentValue: Int?
    var dataArray: [Double?]
    var timeframeLabel: String
    
    var body: some View {
        let current = Double(currentValue ?? 0)
        let validData = dataArray.compactMap { $0 }
        let minVal = validData.min() ?? 0
        let calculatedMax = validData.max() ?? 100
        let maxVal = max(calculatedMax, current) + 1
        
        // Main content: label (watchOS auto-sizes in accessoryCorner)
        Text("HRV")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.gray)
            .widgetCurvesContent()
        // Widget label: gauge renders as curved arc hugging the outer corner rim
        .widgetLabel {
            Gauge(value: current, in: minVal...maxVal) {
                Text("HRV")
            } currentValueLabel: {
                Text("") 
            } minimumValueLabel: {
                Text("\(Int(round(minVal)))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
            } maximumValueLabel: {
                Text("\(Int(round(maxVal - 1)))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryLinear)
            .tint(.white)
        }
    }
}

struct GenericRectangularComplicationView: View {
    var currentValue: Int?
    var dataArray: [Double?]
    var timeframeLabel: String
    var maxSolidGap: Int = 1
    
    var body: some View {
        HStack(spacing: 8) {
            // Left Side: Sparkline Graph
            SparklineView(data: dataArray, maxContiguousGap: maxSolidGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Right Side: Text Data
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(-90))
                    Text(timeframeLabel)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Color.white.opacity(0.92))
                
                Text("HRV")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.72))
                
                if let val = currentValue {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(val)")
                            .font(.system(.headline, design: .monospaced, weight: .bold))
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 2, x: 0, y: 0)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 6, x: 0, y: 0)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 11, x: 0, y: 0)
                        Text("ms")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("--")
                        .font(.system(.headline, design: .monospaced, weight: .bold))
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 2, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 6, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 11, x: 0, y: 0)
                }
            }
            .layoutPriority(1) // Ensure text doesn't get squished by the graph
        }
    }
}

// MARK: - 1. FREE TIER COMPLICATIONS

struct FreeSparklineComplication: Widget {
    let kind: String = "FreeSparklineComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericRectangularComplicationView(currentValue: entry.latestReading, dataArray: entry.sparkline8h, timeframeLabel: "8H", maxSolidGap: 12)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("R1: 8H RAW + LATEST HRV")
        .description("A sparkline of your raw HRV readings over the last 8 hours, with your most recent reading highlighted. Great for tracking intraday trends at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct FreeGaugeComplication: Widget {
    let kind: String = "FreeGaugeComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericCircularComplicationView(currentValue: entry.latestReading, dataArray: entry.sparkline8h, timeframeLabel: "8H")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("G1: 8H RANGE + LATEST HRV")
        .description("A circular gauge showing where your latest HRV falls within your 8-hour min/max range. Quickly see if your current reading is high or low relative to your recent baseline.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct FreeCornerComplication: Widget {
    let kind: String = "FreeCornerComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericCornerComplicationView(currentValue: entry.latestReading, dataArray: entry.sparkline8h, timeframeLabel: "8H")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("C1: LATEST HRV + 8H ARC")
        .description("Displays your most recent HRV reading with a curved gauge showing 8-hour context. Fits neatly in a corner complication slot.")
        .supportedFamilies([.accessoryCorner])
    }
}

// MARK: - 2. PRO TIER (24H / DAILY)

struct ProHourlyComplication: Widget {
    let kind: String = "ProHourlyComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericRectangularComplicationView(currentValue: entry.rollingAvg1h, dataArray: entry.hourlyAverages24h, timeframeLabel: "1D")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("R2: 24H PER-HOUR AVG + 1H AVG")
        .description("A sparkline of your hourly HRV averages over the last 24 hours, plus your current 1-hour rolling average. Reveals daily rhythm patterns.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct ProHourlyGaugeComplication: Widget {
    let kind: String = "ProHourlyGaugeComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericCircularComplicationView(currentValue: entry.rollingAvg1h, dataArray: entry.hourlyAverages24h, timeframeLabel: "1D")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("G2: 24H RANGE + 1H AVG")
        .description("A circular gauge placing your current 1-hour rolling average within the full 24-hour min/max range. See how your current state compares to your day.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct ProDailyBaselineComplication: Widget {
    let kind: String = "ProDailyBaselineComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericRectangularComplicationView(currentValue: entry.rollingAvg24h, dataArray: entry.hourlyAverages24h, timeframeLabel: "24H")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("R3: 24H PER-HOUR AVG + 24H AVG")
        .description("A sparkline of hourly averages over the last 24 hours, paired with your 24-hour rolling average. Useful for tracking your daily baseline trend.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - 3. PRO TIER (WEEKLY / MONTHLY)

struct Pro7DayComplication: Widget {
    let kind: String = "Pro7DayComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericRectangularComplicationView(currentValue: entry.rollingAvg24h, dataArray: entry.dailyAverages7d, timeframeLabel: "7D")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("R4: 7D PER-DAY AVG + 24H AVG")
        .description("A sparkline of your daily HRV averages over the last 7 days, with your current 24-hour rolling average. Ideal for spotting weekly recovery and stress patterns at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct Pro7DayGaugeComplication: Widget {
    let kind: String = "Pro7DayGaugeComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericCircularComplicationView(currentValue: entry.rollingAvg24h, dataArray: entry.dailyAverages7d, timeframeLabel: "7D")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("G3: 7D RANGE + 24H AVG")
        .description("A circular gauge showing where your current 24-hour average sits within your 7-day min/max range. Great for weekly context on your current state.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct Pro30DayComplication: Widget {
    let kind: String = "Pro30DayComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericRectangularComplicationView(currentValue: entry.rollingAvg24h, dataArray: entry.dailyAverages30d, timeframeLabel: "1M")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("R5: 1M PER-DAY AVG + 24H AVG")
        .description("A sparkline of your daily HRV averages over the last 30 days, with your current 24-hour rolling average. The broadest view of your long-term recovery and readiness trend.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct Pro30DayGaugeComplication: Widget {
    let kind: String = "Pro30DayGaugeComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GenericCircularComplicationView(currentValue: entry.rollingAvg24h, dataArray: entry.dailyAverages30d, timeframeLabel: "1M")
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("G4: 1M RANGE + 24H AVG")
        .description("A circular gauge showing where your current 24-hour average falls within your 30-day min/max range. Your long-term readiness at a glance.")
        .supportedFamilies([.accessoryCircular])
    }
}
