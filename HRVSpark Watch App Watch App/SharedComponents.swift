import SwiftUI

public struct SparklineView: View {
    public var data: [Double?]
    public var label: String?
    public var maxContiguousGap: Int
    
    public init(data: [Double?], label: String? = nil, maxContiguousGap: Int = 1) {
        self.data = data
        self.label = label
        self.maxContiguousGap = maxContiguousGap
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let validData = data.compactMap { $0 }
            if validData.isEmpty {
                Text("No Data")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maxVal = validData.max() ?? 0
                let minVal = validData.min() ?? 0
                let range = maxVal - minVal
                let normRange = range == 0 ? 1 : range
                
                // Add padding to the top and bottom so the line doesn't go edge-to-edge
                // This gives the text room to breathe above the peak and below the trough
                let verticalPadding: CGFloat = 16.0
                let drawHeight = geometry.size.height - (verticalPadding * 2)
                let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                
                ZStack {

                    // Extract all valid points and their true visual indices
                    let points: [(index: Int, point: CGPoint)] = data.enumerated().compactMap { index, optionalValue in
                        guard let value = optionalValue else { return nil }
                        let xPosition = CGFloat(index) * stepX
                        let yPosition: CGFloat
                        if range == 0 {
                            // All values are the same — center vertically
                            yPosition = verticalPadding + drawHeight / 2
                        } else {
                            yPosition = verticalPadding + (drawHeight - CGFloat((value - minVal) / normRange) * drawHeight)
                        }
                        return (index: index, point: CGPoint(x: xPosition, y: yPosition))
                    }
                    
                    // 1. Draw Dashed Gap Lines
                    Path { path in
                        if points.count < 2 { return }
                        for i in 0..<points.count - 1 {
                            let p1 = points[i]
                            let p2 = points[i+1]
                            
                            // If index difference is > maxContiguousGap, there's a significant gap
                            if p2.index - p1.index > maxContiguousGap {
                                path.move(to: p1.point)
                                path.addLine(to: p2.point)
                            }
                        }
                    }
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 4]))
                    
                    // 2. Draw Solid Contiguous Curves
                    // Build the path once, reuse for fringe + main stroke
                    let solidPath = Path { path in
                        if points.isEmpty { return }
                        if points.count == 1 {
                            // Single point — draw a visible filled circle instead of invisible zero-length path
                            return
                        }
                        
                        var isStartOfSegment = true
                        for i in 0..<points.count - 1 {
                            let p1 = points[i]
                            let p2 = points[i+1]
                            
                            // Only draw contiguous lines here
                            if p2.index - p1.index <= maxContiguousGap {
                                if isStartOfSegment {
                                    path.move(to: p1.point)
                                    isStartOfSegment = false
                                }
                                
                                let controlPointOffset = (p2.point.x - p1.point.x) * 0.45
                                let cp1 = CGPoint(x: p1.point.x + controlPointOffset, y: p1.point.y)
                                let cp2 = CGPoint(x: p2.point.x - controlPointOffset, y: p2.point.y)
                                
                                path.addCurve(to: p2.point, control1: cp1, control2: cp2)
                            } else {
                                // The next point is across a gap, so we close this solid segment
                                isStartOfSegment = true
                            }
                        }
                    }
                    
                    // 2a+2b. White stroke with stacked blue shadows (same technique as hero numbers)
                    solidPath
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0), radius: 3, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 8, x: 0, y: 0)
                        .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.4), radius: 16, x: 0, y: 0)
                    
                    // 2c. Single-point dot: draw a visible filled circle
                    if points.count == 1 {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0), radius: 3, x: 0, y: 0)
                            .shadow(color: Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.7), radius: 8, x: 0, y: 0)
                            .position(points[0].point)
                    }
                    
                    // Min/Max Annotations
                    if let maxIndex = data.firstIndex(of: maxVal), let minIndex = data.firstIndex(of: minVal) {
                        let maxX = CGFloat(maxIndex) * stepX
                        let maxY: CGFloat = range == 0
                            ? verticalPadding + drawHeight / 2
                            : verticalPadding + (drawHeight - CGFloat((maxVal - minVal) / normRange) * drawHeight)
                        
                        let minX = CGFloat(minIndex) * stepX
                        let minY: CGFloat = range == 0
                            ? verticalPadding + drawHeight / 2
                            : verticalPadding + (drawHeight - CGFloat((minVal - minVal) / normRange) * drawHeight)
                        
                        let safeX = { (x: CGFloat) -> CGFloat in
                            if x < 10 { return x + 10 }
                            if x > geometry.size.width - 10 { return x - 10 }
                            return x
                        }
                        
                        // Push text firmly above or below the point
                        let safeY = { (y: CGFloat, isMax: Bool) -> CGFloat in
                            if isMax { return y - 10 } // Push up
                            return y + 10 // Push down
                        }
                        
                        Text("\(Int(round(maxVal)))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 0, y: 1)
                            .position(x: safeX(maxX), y: safeY(maxY, true))
                        
                        if minVal != maxVal {
                            Text("\(Int(round(minVal)))")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(white: 0.7))
                                .shadow(color: .black, radius: 1, x: 0, y: 1)
                                .position(x: safeX(minX), y: safeY(minY, false))
                        }
                    }
                    
                    // Optional top-left label
                    if let label = label {
                        Text(label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                            .position(x: 10, y: 10)
                    }
                }
            }
        }
    }
}
