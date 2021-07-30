import ArgumentParser
import Foundation

private let reminders = Reminders()
private let calendarEvents = CalendarEvents()

private struct ShowLists: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the name of lists to pass to other commands")

    func run() {
        reminders.showLists()
    }
}

private struct Upcoming: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show upcoming reminders")

    @Option(
        name: .shortAndLong,
        help: "The amount of days to show")
    var limit: Int?

    func run() {
        reminders.showUpcoming(limit: self.limit)
    }
}

private struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the items on the given list")

    @Argument(
        help: "The list to print items from, see 'show-lists' for names")
    var listName: String

    func run() {
        reminders.showListItems(withName: self.listName)
    }
}

private struct Anytime: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the anytime items on the given list")

    @Argument(
        help: "The list to print items from, see 'show-lists' for names")
    var listName: String

    func run() {
        reminders.showAnytimeListItems(withName: self.listName)
    }
}

private struct AddReminder: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a reminder to a list")

    @Argument(
        help: "The list to add to, see 'show-lists' for names")
    var listName: String

    @Argument(
        parsing: .remaining,
        help: "The reminder contents")
    var reminder: [String]

    @Option(
        name: .shortAndLong,
        help: "The date the reminder is due")
    var dueDate: DateComponents?

    func run() {
        reminders.addReminder(
            string: self.reminder.joined(separator: " "),
            toListNamed: self.listName,
            dueDate: self.dueDate)
    }
}

private struct Complete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Complete a reminder")

    @Argument(
        help: "The list to complete a reminder on, see 'show-lists' for names")
    var listName: String

    @Argument(
        help: "The index of the reminder to complete, see 'show' for indexes")
    var index: Int

    @Argument(
        help: "Complete an anytime reminder")
    var anytime: Bool?

    func run() {
        reminders.complete(itemAtIndex: self.index, onListNamed: self.listName, anytime: self.anytime)
    }
}

private struct CompleteByUuid: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Complete a reminder")

    @Argument(
        help: "The uuid of the reminder to complete")
    var uuid: String

    func run() {
        reminders.completeByUuid(uuid: self.uuid)
    }
}

private struct Events: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show upcoming events")

    @Argument(
        help: "The calendar to show events from")
    var listName: String?

    @Option(
        name: .shortAndLong,
        help: "The amount of days to show")
    var limit: Int?

    func run() {
        calendarEvents.events(listName: self.listName, limit: self.limit)
    }
}

private struct Calendars: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show all calendars")

    func run() {
        calendarEvents.showCalendars()
    }
}

private struct AddEvent: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a event to a calendar")

    @Argument(
        help: "The calendar to add to, see 'calendars' for names")
    var listName: String

    @Argument(
        help: "The event title")
    var event: [String]

    @Option(
        name: .shortAndLong,
        help: "The date the event starts")
    var startDate: String

    @Option(
        name: .shortAndLong,
        help: "The date the event ends")
    var endDate: String?

    @Option(
        name: .shortAndLong,
        help: "The location of the event")
    var location: String?

    func run() {
        calendarEvents.addEvent(
            string: self.event.joined(separator: " "),
            toListNamed: self.listName,
            startDate: self.startDate,
            endDate: self.endDate,
            location: self.location
        )
    }
}

public struct CLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Interact with macOS Reminders from the command line",
        subcommands: [
            AddReminder.self,
            Complete.self,
            Show.self,
            ShowLists.self,
            Upcoming.self,
            Anytime.self,
            Calendars.self,
            Events.self,
            AddEvent.self,
            CompleteByUuid.self,
        ]
    )

    public init() {}
}
