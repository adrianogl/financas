enum BusinessCalendar {
    static func easter(in year: Int) -> CalendarDay {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return CalendarDay(year: year, month: month, day: day)
    }

    static func holidays(in year: Int) -> Set<CalendarDay> {
        let fixed = IncomeConstants.fixedHolidays.map { CalendarDay(year: year, month: $0.month, day: $0.day) }
        let easter = easter(in: year)
        let movable = IncomeConstants.easterOffsets.map { easter.adding(days: $0) }
        return Set(fixed + movable)
    }

    static func isBusinessDay(_ day: CalendarDay) -> Bool {
        let weekday = day.weekday
        return weekday != 1 && weekday != 7 && !holidays(in: day.year).contains(day)
    }

    static func businessDayOnOrAfter(_ day: CalendarDay) -> CalendarDay {
        var current = day
        while !isBusinessDay(current) {
            current = current.adding(days: 1)
        }
        return current
    }

    static func businessDays(in month: YearMonth) -> Int {
        (1...month.dayCount).filter { isBusinessDay(month.day($0)) }.count
    }
}
