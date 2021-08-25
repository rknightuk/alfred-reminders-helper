import Darwin
import RemindersLibrary

if Reminders.requestAccess() && CalendarEvents.requestAccess() {
    CLI.main()
} else {
    print("You need to grant reminders access")
    exit(1)
}
