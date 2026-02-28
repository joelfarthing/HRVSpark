//
//  HRVSparkComplicationBundle.swift
//  HRVSparkComplication
//
//  Created by Joel Farthing on 2/22/26.
//

import WidgetKit
import SwiftUI

@main
struct HRVSparkComplicationBundle: WidgetBundle {
    var body: some Widget {
        // Free
        FreeSparklineComplication()
        FreeGaugeComplication()
        FreeCornerComplication()
        // Pro Daily
        ProHourlyComplication()
        ProHourlyGaugeComplication()
        ProDailyBaselineComplication()
        // Pro Long Term
        Pro7DayComplication()
        Pro7DayGaugeComplication()
        Pro30DayComplication()
        Pro30DayGaugeComplication()
    }
}
