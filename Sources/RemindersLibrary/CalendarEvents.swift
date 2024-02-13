import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = DateFormatter()

private func formattedDueDateEvent(from date: Date) -> String? {
    let dateformat = DateFormatter()
    dateformat.dateFormat = "yyyy-MM-dd HH:mm"
    return dateformat.string(from: date)
}

private func meeting_url(_ event: EKEvent) -> String {
    let regexes = [
        "https://teams\\.microsoft\\.com/l/meetup-join/[a-zA-Z0-9/%?&amp;=._-]+",
        "https://teams\\.live\\.com/meet/[a-z0-9]+",
        "https://[a-z0-9]+\\.zoom\\.us/[a-z0-9_.-]+/\\d+\\?pwd=[a-z0-9]+",
        "https://([a-z0-9]+\\.)?zoom\\.us/j/\\d+(\\?pwd=[a-z0-9]+)?",
    ]

    let fields = [
        event.url == nil ? "" : event.url!.absoluteString,
        event.structuredLocation == nil ? "" : event.structuredLocation!.title!,
        event.notes == nil ? "" : event.notes!,
    ]

    for field in fields {
        for pattern in regexes {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(field.startIndex..<field.endIndex, in: field)
            if let match = regex.firstMatch(in: field, options: [], range: range) {
                return String(field[Range(match.range, in: field)!])
            }
            } catch {
                print("Invalid regex pattern: \(error)")
            }
        }
    }

    return ""
}

struct Event: Codable {
    var id: String
    var title: String
    var start: String
    var end: String
    var allDay: String
    var location: String
    var calendar: String
    var confirmed: String
    var meeting_url: String
}

private func format(_ event: EKEvent) -> String {
    let start = formattedDueDateEvent(from: event.startDate).map { "\($0)" } ?? ""
    let end = formattedDueDateEvent(from: event.endDate).map { "\($0)" } ?? ""
    var location = event.structuredLocation == nil ? "" : event.structuredLocation!.title!
    location = location.replacingOccurrences(of: "\n", with: ", ")

    let event = Event(
        id: event.eventIdentifier!,
        title: event.title ?? "?",
        start: start,
        end: end,
        allDay: "\(event.isAllDay)",
        location: location,
        calendar: event.calendar.title,
        confirmed: "\(event.status == EKEventStatus.none || event.status == EKEventStatus.confirmed)",
        meeting_url: meeting_url(event)
    )

    let encoder = JSONEncoder()
    let jsonData = try! encoder.encode(event)
    return String(data: jsonData, encoding: .utf8)!
}

public final class CalendarEvents {
    public static func requestAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var grantedAccess = false
        Store.requestAccess(to: .event) { granted, _ in
            grantedAccess = granted
            semaphore.signal()
        }

        semaphore.wait()
        return grantedAccess
    }

    func showCalendars() {
        let calendars = self.getCalendars()
        for calendar in calendars {
            print(calendar.title)
        }
    }

    func events(listName: String?, limit: Int?) {
        let calendar = listName != nil ? self.calendar(withName: listName!) : nil
        let semaphore = DispatchSemaphore(value: 0)

        let now = Date()

        let days:TimeInterval = Double((limit == nil ? 5 : limit!)*24*3600)
        let next = Date(timeIntervalSinceNow: +days)
        let calendars = calendar != nil ? [calendar!] : []

        let predicate = Store.predicateForEvents(withStart: now, end: next, calendars: calendars)

        let events = Store.events(matching: predicate)

        if events.count == 0 { semaphore.signal() }

        for event in events {
            print(format(event))
            semaphore.signal()
        }

        semaphore.wait()
    }

    func addEvent(string: String, toListNamed name: String, startDate: String, endDate: String?, location: String?) {
        let dateformat = DateFormatter()
        dateformat.dateFormat = "yyyy-MM-dd HH:mm"
        let start = dateformat.date(from: startDate)
        let end = endDate != nil ? dateformat.date(from: endDate!) : start!.addingTimeInterval(60 * 60)

        let calendar = self.calendar(withName: name)
        let event = EKEvent(eventStore: Store)

        event.calendar = calendar
        event.title = string
        event.startDate = start
        event.endDate = end
        if (location != nil)
        {
            event.structuredLocation = EKStructuredLocation(title: location!)
        }

        do {
            try Store.save(event, span: .thisEvent, commit: true)
            print("Added '\(event.title!)' to '\(calendar.title)'")
        } catch let error {
            print("Failed to save event with error: \(error)")
            exit(1)
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        } else {
            print("No reminders list matching \(name)")
            exit(1)
        }
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .event)
                .filter { $0.allowsContentModifications }
    }
}
