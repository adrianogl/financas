enum HomeDayScale {
    static func days(in month: YearMonth) -> [Int] {
        HomeConstants.dayScaleMarks + [month.dayCount]
    }
}
