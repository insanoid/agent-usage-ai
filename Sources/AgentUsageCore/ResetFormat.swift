import Foundation

/// Text for when a limit resets.
public enum ResetFormat {
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600
    private static let secondsPerDay = 86400

    /// Time left until `date`: "4d 3h", "2h 05m", "12m", or "now".
    public static func countdown(to date: Date, now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds >= secondsPerMinute else { return "now" }

        let days = seconds / secondsPerDay
        let hours = seconds % secondsPerDay / secondsPerHour
        let minutes = seconds % secondsPerHour / secondsPerMinute

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }

    /// Wall-clock time of `date` in the user's locale: "12:50" when it is
    /// today, "Tue 07:00" otherwise.
    public static func clock(
        _ date: Date,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .hour()
            .minute()
        if !calendar.isDate(date, inSameDayAs: now) {
            style = style.weekday(.abbreviated)
        }
        return date.formatted(style)
    }
}
