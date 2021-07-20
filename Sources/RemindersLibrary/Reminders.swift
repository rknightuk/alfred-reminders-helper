import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = DateFormatter()
private func formattedDueDate(from reminder: EKReminder) -> String? {
    let dateformat = DateFormatter()
    dateformat.dateFormat = "yyyy-MM-dd HH:mm"
    return dateformat.string(from: reminder.dueDateComponents!.date ?? Date())
}

private func format(_ reminder: EKReminder, at index: Int) -> String {
    let dateString = formattedDueDate(from: reminder).map { "\($0)" } ?? ""
    return "{ \"id\": \"\(index)\", \"title\": \"\(reminder.title ?? "?")\", \"date\": \"\(dateString)\", \"list\": \"\(reminder.calendar.title)\" }"
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

    func showUpcoming() {
        let semaphore = DispatchSemaphore(value: 0)

        self.allReminders() { reminders in
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

    func complete(itemAtIndex index: Int, onListNamed name: String?) {
        let calendar = self.maybeCalendar(withName: name ?? "")
        let semaphore = DispatchSemaphore(value: 0)
        var useSpecificList = true

        if name == "RMindAllReminders" { useSpecificList = false }

        if (useSpecificList)
        {
            self.reminders(onCalendar: calendar!) { reminders in
                guard let reminder = reminders[safe: index] else {
                    print("No reminder at index \(index) on \(name ?? "")")
                    exit(1)
                }

                do {
                    reminder.isCompleted = true
                    try Store.save(reminder, commit: true)
                    print("Completedxxx '\(reminder.title!)'")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    exit(1)
                }

                semaphore.signal()
            }
        } else {
            self.allReminders() { reminders in
                guard let reminder = reminders[safe: index] else {
                    print("No reminder at index \(index)")
                    exit(1)
                }

                do {
                    reminder.isCompleted = true
                    try Store.save(reminder, commit: true)
                    print("Completedxxx '\(reminder.title!)'")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    exit(1)
                }

                semaphore.signal()
            }
        }

        semaphore.wait()
    }

    func addReminder(string: String, toListNamed name: String, dueDate: DateComponents?) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.dueDateComponents = dueDate

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
        let predicate = Store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
        Store.fetchReminders(matching: predicate) { reminders in
            var reminders = reminders?
                .filter { $0.dueDateComponents != nil }

            reminders = reminders!.sorted(by: { $0.dueDateComponents!.date ?? Date() < $1.dueDateComponents!.date ?? Date() })

            completion(reminders ?? [])
        }
    }

    private func allReminders(completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [])
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
