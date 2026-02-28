import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @State private var dataManager = HRVDataManager()
    
    // BETA AUTO-UNLOCK (TEMPORARY — remove before production paid launch)
    @State private var isProUnlocked: Bool = true
    
    // Design System
    let slateBlueTheme = LinearGradient(
        colors: [Color(red: 0.18, green: 0.22, blue: 0.30), Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
    let cardTitleColor = Color.white.opacity(0.74)
    
    var body: some View {
        NavigationStack {
            ZStack {
                slateBlueTheme
                    .ignoresSafeArea()
                
                if !dataManager.isAuthorized {
                    VStack {
                        Image(systemName: "heart.text.square")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        Text("HRVSpark requires HealthKit access to display your data.")
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Authorize in Health App") {
                            dataManager.requestAuthorization { _ in }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            
                            Text("Pull down to sync to iPhone")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 2)
                                .padding(.bottom, 2)
                                
                            // LIVE COMPLICATIONS GALLERY HEADER
                            Text("LIVE GALLERY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 2, x: 0, y: 0)
                                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 6, x: 0, y: 0)
                                .tracking(2)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                            
                            // Sync status
                            HStack(spacing: 4) {
                                Image(systemName: "iphone")
                                    .font(.system(size: 9))
                                Text("Last Sync:")
                                    .font(.system(size: 9))
                                if let syncDate = dataManager.lastCompanionContextSyncDate {
                                    Text(syncDate, style: .relative)
                                        .font(.system(size: 9, weight: .bold))
                                } else {
                                    Text("waiting")
                                        .font(.system(size: 9, weight: .bold))
                                }
                            }
                            .foregroundColor(.gray.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 4)
                            
                            // ==========================================
                            // MARK: FREE TIER (8 Hours)
                            // ==========================================
                            
                            watchSparklineCard(
                                id: "R1",
                                title: "8H RAW + LATEST HRV",
                                timeframeLabel: "8H",
                                data: dataManager.sparklineData8Hours,
                                reading: dataManager.freeCardReading,
                                maxContiguousGap: 12
                            )
                            
                            watchGaugeCard(
                                id: "G1",
                                title: "8H RANGE + LATEST HRV",
                                timeframeLabel: "8H",
                                data: dataManager.sparklineData8Hours,
                                reading: dataManager.freeCardReading
                            )
                            
                            watchCornerCard(
                                id: "C1",
                                title: "LATEST HRV + 8H ARC",
                                timeframeLabel: "8H",
                                data: dataManager.sparklineData8Hours,
                                reading: dataManager.freeCardReading
                            )
                            
                            
                            // ==========================================
                            // MARK: PRO DIVIDER & TIER
                            // ==========================================
                            
                            if !isProUnlocked {
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "lock.fill")
                                        Text("Pro Complications")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    Text("Unlock in the iPhone app")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(12)
                            } else {
                                Divider().background(Color.gray.opacity(0.5))
                                
                                Text("PRO UNLOCKED")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                watchSparklineCard(
                                    id: "R2",
                                    title: "24H PER-HOUR AVG + 1H AVG",
                                    timeframeLabel: "24H",
                                    data: dataManager.hourlyAverages8Hours,
                                    reading: dataManager.proCard2Reading
                                )
                                
                                watchSparklineCard(
                                    id: "R3",
                                    title: "24H PER-HOUR AVG + 24H AVG",
                                    timeframeLabel: "24H",
                                    data: dataManager.hourlyAverages8Hours,
                                    reading: dataManager.proCard3Reading
                                )
                                
                                watchSparklineCard(
                                    id: "R4",
                                    title: "7D PER-DAY AVG + 24H AVG",
                                    timeframeLabel: "7D",
                                    data: dataManager.dailyAverages7Days,
                                    reading: dataManager.proCard3Reading
                                )
                                
                                watchSparklineCard(
                                    id: "R5",
                                    title: "1M PER-DAY AVG + 24H AVG",
                                    timeframeLabel: "1M",
                                    data: dataManager.dailyAverages30Days,
                                    reading: dataManager.proCard4Reading
                                )
                                
                                watchGaugeCard(
                                    id: "G2",
                                    title: "24H RANGE + 1H AVG",
                                    timeframeLabel: "24H",
                                    data: dataManager.hourlyAverages8Hours,
                                    reading: dataManager.proCard2Reading
                                )
                                
                                watchGaugeCard(
                                    id: "G3",
                                    title: "7D RANGE + 24H AVG",
                                    timeframeLabel: "7D",
                                    data: dataManager.dailyAverages7Days,
                                    reading: dataManager.proCard3Reading
                                )
                                
                                watchGaugeCard(
                                    id: "G4",
                                    title: "1M RANGE + 24H AVG",
                                    timeframeLabel: "1M",
                                    data: dataManager.dailyAverages30Days,
                                    reading: dataManager.proCard4Reading
                                )
                            }
                            
                            // ---- ABOUT BUTTON ----
                            NavigationLink(destination: AboutView()) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("About HRV & Apple Watch")
                                }
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.top, 16)
                            }
                            .buttonStyle(.plain)
                            
                        }
                        .padding()
                    }
                    .refreshable {
                        dataManager.fetchAllData()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
        .onAppear {
            dataManager.requestAuthorization { _ in }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                isProUnlocked = true
                
                if dataManager.isAuthorized {
                    dataManager.fetchAllData()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
    
    // MARK: - Watch Card Helpers
    
    private func watchBadge(_ id: String) -> some View {
        Text(id)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .overlay(
                Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
    }
    
    private func watchSparklineCard(
        id: String, title: String, timeframeLabel: String,
        data: [Double?], reading: Int?, maxContiguousGap: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                watchBadge(id)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(cardTitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            HStack(spacing: 6) {
                SparklineView(data: data, maxContiguousGap: maxContiguousGap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 7, weight: .bold))
                            .rotationEffect(.degrees(-90))
                        Text(timeframeLabel)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.gray)
                    
                    Text("HRV")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        if let r = reading {
                            Text("\(r)")
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 2, x: 0, y: 0)
                                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 6, x: 0, y: 0)
                        } else {
                            Text("--")
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("ms")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .layoutPriority(1)
            }
            .frame(height: 50)
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func watchGaugeCard(
        id: String, title: String, timeframeLabel: String,
        data: [Double?], reading: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                watchBadge(id)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(cardTitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            HStack {
                Spacer()
                watchGaugePreview(data: data, reading: reading, timeframeLabel: timeframeLabel)
                    .frame(width: 50, height: 50)
                Spacer()
            }
            .frame(height: 54)
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func watchGaugePreview(data: [Double?], reading: Int?, timeframeLabel: String) -> some View {
        let current = Double(reading ?? 0)
        let validData = data.compactMap { $0 }
        let minVal = validData.min() ?? 0
        let maxVal = max(validData.max() ?? 100, current) + 1
        let gaugeCharacter: String = {
            switch timeframeLabel {
            case "8H": return "8"
            case "24H": return "D"
            case "7D": return "W"
            case "1M": return "M"
            default: return ""
            }
        }()
        
        return Gauge(value: current, in: minVal...maxVal) {
            Text("")
        } currentValueLabel: {
            VStack(spacing: 0) {
                if let val = reading {
                    Text("\(val)")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 2, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 6, x: 0, y: 0)
                } else {
                    Text("--")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(gaugeCharacter)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.34, green: 0.72, blue: 1.0))
            }
            .offset(y: 2)
        } minimumValueLabel: {
            Text("\(Int(round(minVal)))")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        } maximumValueLabel: {
            Text("\(Int(round(maxVal - 1)))")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.white)
    }
    
    private func watchCornerCard(
        id: String, title: String, timeframeLabel: String,
        data: [Double?], reading: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                watchBadge(id)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(cardTitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            HStack {
                Spacer()
                watchCornerPreview(data: data, reading: reading, timeframeLabel: timeframeLabel)
                Spacer() 
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func watchCornerPreview(data: [Double?], reading: Int?, timeframeLabel: String) -> some View {
        let current = Double(reading ?? 0)
        let validData = data.compactMap { $0 }
        let minVal = validData.min() ?? 0
        let maxVal = max(validData.max() ?? 100, current) + 1
        
        return VStack(spacing: 8) {
            if let reading = reading {
                Text("\(reading)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 2, x: 0, y: 0)
                    .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 6, x: 0, y: 0)
            } else {
                Text("--")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Gauge(value: current, in: minVal...maxVal) {
                Text("")
            } currentValueLabel: {
                Text("")
            } minimumValueLabel: {
                Text("\(Int(round(minVal)))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            } maximumValueLabel: {
                Text("\(Int(round(maxVal - 1)))")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .gaugeStyle(.accessoryLinear)
            .tint(.white)
        }
    }
}

// MARK: - About Page

struct AboutView: View {
    // Re-use theme for consistency
    let slateBlueTheme = LinearGradient(
        colors: [Color(red: 0.18, green: 0.22, blue: 0.30), Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
    
    var body: some View {
        ZStack {
            slateBlueTheme.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How It Works")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("HRVSpark reads data directly from Apple Health. It performs no diagnosis or algorithmic interpretation—it simply visualizes your raw SDNN measurements.")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Text("The Mindfulness Workaround")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                    
                    Text("watchOS restricts how often apps can measure HRV in the background to save battery.\n\nTo force a new, immediate reading at any time, run a 1-Minute 'Breathe' session in the native Apple Mindfulness app. HRVSpark (and its complications) will automatically detect the new reading within minutes.")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    Text("Watch History Limits")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("The watch can show a shorter local HRV history than your iPhone. When your iPhone is reachable, complications can use iPhone-computed long-term data.")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
