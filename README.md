# Countdown Indicator (WIP)

Author: Ian Caio

## Description

Just a simple regressive countdown indicator, translated from C to Ruby as a way to practice.
Work still in progress.

## Configuration file

The configuration file consists of comments (preceded by "//") and the parameters with their
values.

- NOTIFY DELAY=<number> being number in the range 60-1200 seconds
- ENABLE NOTIFY=TRUE/FALSE anything other than that means false.
- INITIAL TIMER=<number> the initial countdown timer
- PERSISTENT TIMER=TRUE/FALSE anything other than that means false.

No spaces are allowed between the parameter name, the "=" character and the value associated with the parameter.
The parameters name must exactly match the ones above in uppercase.
Any line that doesn't follow the above sintax will be ignored.
If any bad parameters are given, the default values will be used:

NOTIFY DELAY=300
ENABLE NOTIFY=FALSE
INITIAL TIMER=30
PERSISTENT TIMER=FALSE

## How-to use

- Set the configurations in the ./Config/CountdownI.config file.
- Run `ruby ./CountdownI.rb &` from the project folder to start the program in the background.
- If you're running with "DEBUG=true" it's recommended to run it on foregroun in the
shell to be able to read the debugging output.
- Click on the indicator on the panel and then "Quit" to leave the program.

## Requirements

Gems required:
- ruby-libappindicator
