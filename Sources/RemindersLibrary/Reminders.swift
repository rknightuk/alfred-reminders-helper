import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = DateFormatter()
private func formattedDueDate(from reminder: EKReminder) -> String? {
    if reminder.dueDateComponents == nil { return "" }
    let dateformat = DateFormatter()
    dateformat.dateFormat = "yyyy-MM-dd HH:mm"
    return dateformat.string(from: reminder.dueDateComponents!.date ?? Date())
}

private func format(_ reminder: EKReminder, at index: Int) -> String {
    let dateString = formattedDueDate(from: reminder).map { "\($0)" } ?? ""
    return "{ \"uuid\": \"\(reminder.calendarItemIdentifier)\", \"id\": \"\(index)\", \"title\": \"\(reminder.title ?? "?")\", \"date\": \"\(dateString)\", \"list\": \"\(reminder.calendar.title)\" }"
}

public final class Reminders {
    public static func requestAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var grantedAccess = false
        Store.requestAccess(to: .reminder) { granted, _ in
            grantedAccess = granted
            semaphore.signal()
        }

        semaphore.wait()
        return grantedAccess
    }

    func showLists() {
        let calendars = self.getCalendars()
        for calendar in calendars {
            print(calendar.title)
        }
    }

    func showUpcoming(limit: Int?) {
        let semaphore = DispatchSemaphore(value: 0)

        self.allReminders(limit: limit) { reminders in
            for (i, reminder) in reminders.enumerated() {
                print(format(reminder, at: i))
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showListItems(withName name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar) { reminders in
            for (i, reminder) in reminders.enumerated() {
                print(format(reminder, at: i))
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showAnytimeListItems(withName name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.anytimeReminders(onCalendar: calendar) { reminders in
            for (i, reminder) in reminders.enumerated() {
                print(format(reminder, at: i))
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func completeByUuid(uuid: String) {
        guard let reminder = Store.calendarItem(withIdentifier: uuid) as! EKReminder? else {
            print("No reminder found")
            exit(1)
        }
        
        do {
            reminder.isCompleted = true
            try Store.save(reminder, commit: true)
            print("Completed '\(reminder.title!)'")
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    func complete(itemAtIndex index: Int, onListNamed name: String?, anytime: Bool?) {
        let calendar = self.maybeCalendar(withName: name ?? "")
        let semaphore = DispatchSemaphore(value: 0)
        var useSpecificList = true
        let isAnytime = anytime ?? false

        if name == "RMindAllReminders" { useSpecificList = false }

        if (isAnytime)
        {
            self.anytimeReminders(onCalendar: calendar!) { reminders in
                guard let reminder = reminders[safe: index] else {
                    print("No reminder at index \(index)")
                    exit(1)
                }

                do {
                    reminder.isCompleted = true
                    try Store.save(reminder, commit: true)
                    print("Completed '\(reminder.title!)'")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    exit(1)
                }

                semaphore.signal()
            }
        } else if (useSpecificList) {
            self.reminders(onCalendar: calendar!) { reminders in
                guard let reminder = reminders[safe: index] else {
                    print("No reminder at index \(index) on \(name ?? "")")
                    exit(1)
                }

                do {
                    reminder.isCompleted = true
                    try Store.save(reminder, commit: true)
                    print("Completed '\(reminder.title!)'")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    exit(1)
                }

                semaphore.signal()
            }
        } else {
            self.allReminders(limit: nil) { reminders in
                guard let reminder = reminders[safe: index] else {
                    print("No reminder at index \(index)")
                    exit(1)
                }

                do {
                    reminder.isCompleted = true
                    try Store.save(reminder, commit: true)
                    print("Completed '\(reminder.title!)'")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    exit(1)
                }

                semaphore.signal()
            }
        }

        semaphore.wait()
    }

    func addReminder(string: String, toListNamed name: String, dueDate: DateComponents?, url: URL?, notes: String?, priority: Int, location: String?) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.dueDateComponents = dueDate
        reminder.url = url
        reminder.notes = notes
        reminder.priority = priority
        reminder.location = location

        do {
            try Store.save(reminder, commit: true)
            print("Added '\(reminder.title!)' to '\(calendar.title)'")
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    // MARK: - Private functions

    private func reminders(onCalendar calendar: EKCalendar,
                                      completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let nextFiveDays = Date(timeIntervalSinceNow: +5*24*3600)
        let predicate = Store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nextFiveDays, calendars: [calendar])
        Store.fetchReminders(matching: predicate) { reminders in
            var reminders = reminders?
                .filter { $0.dueDateComponents != nil }

            reminders = reminders!.sorted(by: { $0.dueDateComponents!.date ?? Date() < $1.dueDateComponents!.date ?? Date() })

            completion(reminders ?? [])
        }
    }

    private func anytimeReminders(onCalendar calendar: EKCalendar,
                                      completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
        Store.fetchReminders(matching: predicate) { reminders in
            let reminders = reminders?
                .filter { $0.dueDateComponents == nil }

            completion(reminders ?? [])
        }
    }

    private func allReminders(limit: Int?, completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let days:TimeInterval = Double((limit == nil ? 5 : limit!)*24*3600)
        let next = Date(timeIntervalSinceNow: +days)
        let predicate = Store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: next, calendars: [])
        Store.fetchReminders(matching: predicate) { reminders in
            var reminders = reminders?
                .filter { $0.dueDateComponents != nil }

            reminders = reminders!.sorted(by: { $0.dueDateComponents!.date ?? Date() < $1.dueDateComponents!.date ?? Date() })

            completion(reminders ?? [])
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

    private func maybeCalendar(withName name: String) -> EKCalendar? {
        return self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() })
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }
}
