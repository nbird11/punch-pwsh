# Bugs

## [ ] BG-0001 - 'Clock Out At' only takes into account the most recent punch entry

### Description

The 'clock out at' feature should be calculated based on all the punch entries for today's date, not just the most recent entry. This means that if a user has multiple punch-ins and punch-outs throughout the day, the system should sum up all the worked hours to determine the correct clock out time.

### Repro Steps

1. Punch in at 9:00 AM.
2. Punch out at 12:00 PM.
3. Punch in at 1:00 PM.
4. Punch out at 5:00 PM.
5. Use the `punch status` command to check the 'clock out at' time.
