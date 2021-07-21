# alfred-reminders-helper

A modified version of [reminders-cli](https://github.com/keith/reminders-cli) for use with [Reminders Alfred Workflow](https://github.com/rknightuk/alfred-workflows/tree/main/workflows/reminders)

## Usage:

#### Show all lists

```
$ reminders show-lists
Soon
Eventually
```

#### Show reminders on a specific list

```
$ reminders show Soon
0 Write README
1 Ship reminders-cli
```

#### Complete an item on a list

```
$ reminders complete Soon 0
Completed 'Write README'
$ reminders show Soon
0 Ship reminders-cli
```

#### Add a reminder to a list

```
$ reminders add Soon Contribute to open source
$ reminders add Soon Go to the grocery store --due-date "tomorrow 9am"
$ reminders show Soon
0: Ship reminders-cli
1: Contribute to open source
2: Go to the grocery store (in 10 hours)
```

### Installation

You don't want this, I promise you. It's only useful for the Alfred workflow.

#### Building manually

This requires a recent Xcode installation.

```
$ cd reminders-cli
$ make build-release
$ cp .build/release/reminders /usr/local/bin/reminders
```
