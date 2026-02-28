import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var dataManager = iOSDataManager()
    
    // Theme Colors
    let slateBlueTheme = LinearGradient(
        colors: [Color(red: 0.18, green: 0.22, blue: 0.30), Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // StoreKit Pro unlock
    @StateObject private var storeKit = StoreKitManager.shared
    
    private let cardGraphTitleFont = Font.system(size: 16, weight: .bold)
    private let cardTitleColor = Color.white.opacity(0.74)
    
    var body: some View {
        if !dataManager.isAuthorized {
            authorizationView
        } else {
            TabView {
                dashboardTab
                    .tabItem {
                        Label("Dashboard", systemImage: "waveform.path.ecg")
                    }
                
                engineTab
                    .tabItem {
                        Label("Engine", systemImage: "bolt.heart.fill")
                    }
                
                infoTab
                    .tabItem {
                        Label("Info", systemImage: "info.circle.fill")
                    }
            }
            .tint(.white) // Tab bar selection color
            .onAppear {
                // Ensure tab bar is somewhat translucent over the dark background
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
    
    private var brandHeaderReservedSpace: some View {
        Image("HRVSparkWordmark")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .padding(.top, 20) // Normal top spacing, not touching the island
    }
    
    // MARK: - 1. Authorization Screen
    var authorizationView: some View {
        ZStack {
            slateBlueTheme.ignoresSafeArea()
            VStack {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
                Text("Welcome to HRVSpark")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.bottom, 4)
                Text("HRVSpark requires HealthKit access to serve data to your Apple Watch.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                
                Button(action: {
                    dataManager.requestAuthorization { _ in }
                }) {
                    Text("Authorize in Health App")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            dataManager.requestAuthorization { _ in }
        }
    }
    
    // MARK: - 2. Dashboard Tab
    var dashboardTab: some View {
        NavigationStack {
            ZStack {
                slateBlueTheme.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        brandHeaderReservedSpace
                        
                        Text("Pull down to sync to Apple Watch")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        
                        Text("LIVE COMPLICATIONS GALLERY")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 4, x: 0, y: 0)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 13, x: 0, y: 0)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 23, x: 0, y: 0)
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        VStack(spacing: 16) {
                            
                            // ==========================================
                            // MARK: FREE TIER (8 Hours)
                            // ==========================================
                            
                            // R1: 8H Sparkline
                            sparklineCard(
                                id: "R1",
                                title: "8H RAW + LATEST HRV",
                                timeframeLabel: "8H",
                                data: dataManager.sparklineData8Hours,
                                reading: dataManager.freeCardReading,
                                caption: "Every reading from the last 8 hours. Big number: your most recent HRV reading.",
                                maxContiguousGap: 12
                            )
                            
                            // Data sparsity info callout (collapsed by default)
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Dashed lines indicate periods when your watch took no readings\u{2014}this is normal. watchOS limits background HRV sampling to conserve battery.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.85))
                                    
                                    Text("Users with \u{201C}AFib History\u{201D} enabled in Settings \u{2192} Health \u{2192} Heart tend to see more frequent readings. You can also run a 1-minute Breathe session in Mindfulness to force a new reading at any time.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Seeing dashes in your line?")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .tint(.gray)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            
                            // G1: 8H Gauge
                            gaugeCard(
                                id: "G1",
                                title: "8H RANGE + LATEST HRV",
                                timeframeLabel: "8H",
                                data: dataManager.sparklineData8Hours,
                                reading: dataManager.freeCardReading,
                                caption: "Your latest HRV within your 8-hour min/max range"
                            )
                            
                            // C1: 8H Corner
                            cornerCard(
                                id: "C1",
                                title: "LATEST HRV + 8H ARC",
                                timeframeLabel: "8H",
                                data: dataManager.sparklineData8Hours,
                                reading: dataManager.freeCardReading,
                                caption: "Corner complication. Your latest HRV with a curved 8-hour range gauge along the bezel. Works on Infograph, Meridian, and other corner-slot faces."
                            )
                            
                            // ==========================================
                            // MARK: PRO DIVIDER
                            // ==========================================
                            
                            if !storeKit.isProUnlocked {
                                Button(action: {
                                    Task {
                                        try? await storeKit.purchase()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "lock.fill")
                                        if let product = storeKit.proProduct {
                                            Text("Unlock Pro — \(product.displayPrice)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        } else {
                                            Text("Unlock Pro Complications & Dashboard")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(storeKit.purchaseInProgress)
                                
                                Button(action: {
                                    Task { await storeKit.restore() }
                                }) {
                                    Text("Restore Purchases")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                                
                                if let status = storeKit.statusMessage {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 4)
                                }
                            } else {
                                Divider().background(Color.gray.opacity(0.5)).padding(.vertical, 8)
                                
                                Text("PRO UNLOCKED")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                // ==========================================
                                // MARK: PRO TIER
                                // ==========================================
                                
                                // R2: 24H Hourly Sparkline (1H Avg Highlight)
                                sparklineCard(
                                    id: "R2",
                                    title: "24H PER-HOUR AVG + 1H AVG",
                                    timeframeLabel: "24H",
                                    data: dataManager.hourlyAverages8Hours,
                                    reading: dataManager.proCard2Reading,
                                    caption: "Hourly averages over the last 24 hours. Big number: your rolling 60-minute average HRV."
                                )
                                
                                // R3: 24H Hourly Sparkline (24H Avg Highlight)
                                sparklineCard(
                                    id: "R3",
                                    title: "24H PER-HOUR AVG + 24H AVG",
                                    timeframeLabel: "24H",
                                    data: dataManager.hourlyAverages8Hours,
                                    reading: dataManager.proCard3Reading,
                                    caption: "Hourly averages over the last 24 hours. Big number: your rolling 24-hour average HRV."
                                )
                                
                                // R4: 7D Daily Sparkline
                                sparklineCard(
                                    id: "R4",
                                    title: "7D PER-DAY AVG + 24H AVG",
                                    timeframeLabel: "7D",
                                    data: dataManager.dailyAverages7Days,
                                    reading: dataManager.proCard3Reading,
                                    caption: "Daily averages over the last 7 days. Big number: your rolling 24-hour average HRV."
                                )
                                
                                // R5: 30D Daily Sparkline
                                sparklineCard(
                                    id: "R5",
                                    title: "1M PER-DAY AVG + 24H AVG",
                                    timeframeLabel: "1M",
                                    data: dataManager.dailyAverages30Days,
                                    reading: dataManager.proCard4Reading,
                                    caption: "Daily averages over the last 30 days. Big number: your rolling 24-hour average HRV."
                                )
                                
                                // G2: 24H Gauge (1H Avg Highlight)
                                gaugeCard(
                                    id: "G2",
                                    title: "24H RANGE + 1H AVG",
                                    timeframeLabel: "24H",
                                    data: dataManager.hourlyAverages8Hours,
                                    reading: dataManager.proCard2Reading,
                                    caption: "Your current 1-hour rolling average within the full 24-hour min/max range"
                                )
                                
                                // G3: 7D Gauge
                                gaugeCard(
                                    id: "G3",
                                    title: "7D RANGE + 24H AVG",
                                    timeframeLabel: "7D",
                                    data: dataManager.dailyAverages7Days,
                                    reading: dataManager.proCard3Reading,
                                    caption: "Your 24-hour average within your 7-day min/max range"
                                )
                                
                                // G4: 30D Gauge
                                gaugeCard(
                                    id: "G4",
                                    title: "1M RANGE + 24H AVG",
                                    timeframeLabel: "1M",
                                    data: dataManager.dailyAverages30Days,
                                    reading: dataManager.proCard4Reading,
                                    caption: "Your 24-hour average within your 30-day min/max range"
                                )
                            }
                        }
                        .padding()
                    }
                }
                .refreshable {
                    dataManager.fetchAllData()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - 3. Engine Tab (Original View)
    var engineTab: some View {
        NavigationStack {
            ZStack {
                slateBlueTheme.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        brandHeaderReservedSpace
                        
                        Text("Pull down to sync to Apple Watch")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.top, 4)
                        
                        // Status Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("ENGINE STATUS")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                Spacer()
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                        .bold()
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.2))
                            
                            HStack {
                                Text("HealthKit Access")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Apple Watch Paired")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "applewatch")
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("Last sync to watch")
                                    .foregroundColor(.white)
                                Spacer()
                                if let publishedAt = dataManager.lastCompanionContextPublishDate {
                                    Text(publishedAt, style: .relative)
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("Waiting")
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOW OFF-LOADING WORKS")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            
                            Text("To preserve the battery life and memory of your wearable, HRVSpark uses your iPhone to calculate massive historical data aggregations (like the 30-Day Pro metrics).")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text("Keep this app installed so your complications can seamlessly request data updates in the background.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
                .refreshable {
                    dataManager.fetchAllData()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - 4. Info & Workaround Tab
    var infoTab: some View {
        NavigationStack {
            ZStack {
                slateBlueTheme.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        brandHeaderReservedSpace
                        
                        VStack(spacing: 24) {
                            infoCard(
                                title: "How It Works",
                                iconName: nil,
                                iconColor: nil,
                                subtitle: nil,
                                bodyText: "HRVSpark reads data directly from Apple Health. It performs no diagnosis or algorithmic interpretation—it simply visualizes your raw SDNN measurements.",
                                secondaryBodyText: nil
                            )
                            
                            infoCard(
                                title: "The Mindfulness Workaround",
                                iconName: "lungs.fill",
                                iconColor: .teal,
                                subtitle: "watchOS restricts how often apps can measure HRV in the background to save battery.",
                                bodyText: "To force a new, immediate reading at any time, run a 1-Minute 'Breathe' session in the native Apple Mindfulness app. HRVSpark (and its complications) will automatically detect the new reading within minutes.",
                                secondaryBodyText: nil
                            )
                            
                            infoCard(
                                title: "Watch History Window",
                                iconName: "applewatch",
                                iconColor: .blue,
                                subtitle: "Your watch may retain a shorter local HRV history than your iPhone.",
                                bodyText: "Complications perform best when your iPhone is reachable, because long-term aggregates can be off-loaded to the companion app.",
                                secondaryBodyText: nil
                            )
                            
                            infoCard(
                                title: "Medical Disclaimer",
                                iconName: "cross.case.fill",
                                iconColor: .red.opacity(0.8),
                                subtitle: "HRVSpark is for informational purposes only. It visualizes heart\u{2011}rate variability data generated and stored exclusively on your personal devices\u{2014}no data ever leaves your iPhone or Apple Watch.",
                                bodyText: "HRVSpark is not intended to diagnose, treat, cure, or prevent any disease or medical condition. It does not provide medical advice. Always consult a qualified healthcare provider with any questions regarding a medical condition.",
                                secondaryBodyText: nil
                            )
                            
                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Reusable Info Card Builder

    private func infoCard(title: String, iconName: String?, iconColor: Color?, subtitle: String?, bodyText: String, secondaryBodyText: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let iconName = iconName, let iconColor = iconColor {
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                        .font(.title2)
                }
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.white)
            }

            Text(bodyText)
                .font(.body)
                .foregroundColor(.gray)

            if let secondaryBodyText = secondaryBodyText {
                Text(secondaryBodyText)
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Reusable Dashboard Card Builders
    
    /// Circled complication identifier badge (e.g., R1, G2, C1)
    private func complicationBadge(_ id: String) -> some View {
        Text(id)
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
    }
    
    /// Blue glow number stack used across all sparkline cards
    private func heroNumber(_ reading: Int?) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(reading.map { "\($0)" } ?? "--")
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 4, x: 0, y: 0)
                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 13, x: 0, y: 0)
                .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 23, x: 0, y: 0)

            Text("ms")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.leading, 4)
        }
    }
    
    /// Full-width sparkline card with R-badge, title, sparkline graph, and big number
    private func sparklineCard(
        id: String,
        title: String,
        timeframeLabel: String,
        data: [Double?],
        reading: Int?,
        caption: String,
        maxContiguousGap: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    complicationBadge(id)
                    Text(title)
                        .font(cardGraphTitleFont)
                        .foregroundColor(cardTitleColor)
                }
                
                HStack(spacing: 12) {
                    SparklineView(data: data, maxContiguousGap: maxContiguousGap)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .rotationEffect(.degrees(-90))
                            Text(timeframeLabel)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.gray)
                        
                        Text("HRV")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        heroNumber(reading)
                    }
                    .layoutPriority(1)
                }
                .frame(height: 100)
                .padding(.top, 8)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            Text(caption)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)
        }
    }
    
    /// Full-width gauge card with G-badge, circular gauge preview on left, explanation on right
    private func gaugeCard(
        id: String,
        title: String,
        timeframeLabel: String,
        data: [Double?],
        reading: Int?,
        caption: String
    ) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                complicationBadge(id)
                Text(title)
                    .font(cardGraphTitleFont)
                    .foregroundColor(cardTitleColor)
            }
            
            HStack(spacing: 24) {
                // Left: Circular gauge preview
                gaugePreview(data: data, reading: reading, timeframeLabel: timeframeLabel)
                    .frame(width: 100, height: 100)
                
                // Right: English explanation
                Text(caption)
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    /// Circular gauge preview using native SwiftUI Gauge — pixel-perfect match to watchOS complication
    private func gaugePreview(data: [Double?], reading: Int?, timeframeLabel: String) -> some View {
        let current = Double(reading ?? 0)
        let validData = data.compactMap { $0 }
        let minVal = validData.min() ?? 0
        let calculatedMax = validData.max() ?? 100
        let maxVal = max(calculatedMax, current) + 1
        
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
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 6, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 20, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 35, x: 0, y: 0)
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
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        } maximumValueLabel: {
            Text("\(Int(round(maxVal - 1)))")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.white)
        .scaleEffect(2.0)
    }
    
    /// Full-width corner card with C-badge, linear gauge preview on left, text on right
    private func cornerCard(
        id: String,
        title: String,
        timeframeLabel: String,
        data: [Double?],
        reading: Int?,
        caption: String
    ) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                complicationBadge(id)
                Text(title)
                    .font(cardGraphTitleFont)
                    .foregroundColor(cardTitleColor)
            }
            
            HStack(spacing: 16) {
                // Left: Corner complication preview
                cornerPreview(data: data, reading: reading, timeframeLabel: timeframeLabel)
                    .frame(width: 100, height: 100)
                
                // Right: English explanation
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    /// Corner complication preview using native SwiftUI Gauge with .accessoryLinear style
    private func cornerPreview(data: [Double?], reading: Int?, timeframeLabel: String) -> some View {
        let current = Double(reading ?? 0)
        let validData = data.compactMap { $0 }
        let minVal = validData.min() ?? 0
        let calculatedMax = validData.max() ?? 100
        let maxVal = max(calculatedMax, current) + 1
        
        return VStack(spacing: 8) {
            // Big number — matches watch triple blue glow
            if let reading = reading {
                Text("\(reading)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(1.0), radius: 4, x: 0, y: 0)
                    .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 13, x: 0, y: 0)
                    .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.5), radius: 23, x: 0, y: 0)
            } else {
                Text("--")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Native linear gauge
            Gauge(value: current, in: minVal...maxVal) {
                Text("")
            } currentValueLabel: {
                Text("")
            } minimumValueLabel: {
                Text("\(Int(round(minVal)))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            } maximumValueLabel: {
                Text("\(Int(round(maxVal - 1)))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .gaugeStyle(.accessoryLinear)
            .tint(.white)
        }
    }
}

#Preview {
    ContentView()
}
