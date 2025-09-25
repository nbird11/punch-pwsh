# User Stories

## [X] User Story 1: Configure Work Categories (US-0001)

**As a user, I want to be able to define, list, and remove work categories and their weekly hour allotments so that I can manage my work buckets.**

* **Acceptance Criteria:**
  * A new `punch category` command.
  * `punch category add <name> <weeklyHours>`: Adds a new category to the configuration.
  * `punch category remove <name>`: Removes a category.
  * `punch category list`: Lists all configured categories and their weekly hours.
  * Categories should be stored persistently, likely in the `punch.xml` data file.

## [X] User Story 2: Punch In with a Category (US-0002)

**As a user, I want to be able to specify a category when I punch in, so that my work time is associated with that category.**

* **Acceptance Criteria:**
  * Modify the `punch in` command to accept an optional category name (e.g., `punch in "IMS Maintenance"`).
    * i.e., `punch in [<category>]`
  * The active punch-in session should be associated with the specified category.
  * If a category is not provided, the entry will be marked as "uncategorized".
  * The data entry in `punch.xml` for the session should include the category.

## [X] User Story 3: Switch Between Categories (US-0003)

**As a user, I want to be able to switch my active category without punching out and back in, so that I can accurately track my time when context-switching between tasks.**

* **Acceptance Criteria:**
  * A new `punch switch [<category>]` command.
  * When switching, the current time entry is ended, and a new one is immediately started with the new category (either set explicitly or "uncategorized").
  * If the entry being ended is "uncategorized", the user is prompted to select a category for it from the list of available categories.
  * This provides a seamless way to transition between categorized tasks.

## [ ] User Story 4: View Weekly Progress Report (US-0004)

**As a user, I want to view a report of my time spent on each category for the current week, so I can see how I'm tracking against my weekly goals.**

* **Acceptance Criteria:**
  * A new `punch report` or enhanced `punch status` command.
  * The report should show each category, the total time spent in the current week, and the progress towards the weekly goal (e.g., "IMS Maintenance: 2.5h / 4.0h").
  * The report should calculate totals based on the current week (e.g., Monday to Sunday).

## [ ] User Story 5: Recategorize and Manage Entries (US-0005)

**As a user, I want to be able to view my past time entries and change their category, so I can correct mistakes and organize my time log.**

* **Acceptance Criteria:**
  * A new `punch log` command that lists recent time entries, showing their start time, end time, duration, and category. Each entry should have a unique identifier (e.g., an index).
  * A new `punch edit <entry_id> --category <new_category>` command to change the category of a specific entry.
  * Using a special value like `uncategorized` or providing an empty string for the category (e.g., `punch edit <entry_id> --category ""`) will mark the entry as having an undefined category.
  * The `punch.xml` entry will be updated to reflect the change.

## [ ] User Story 6: Prompt for Category on Punch Out (US-0006)

**As a user, when I punch out, I want to be prompted to categorize my session if it was uncategorized, so that my time log remains accurate.**

* **Acceptance Criteria:**
  * When `punch out` is executed, if the current time entry is "uncategorized", the system will prompt the user to choose a category from the existing list.
  * The user can select a category, and the time entry will be updated accordingly.
  * The user can choose to leave it as "uncategorized".

## [ ] User Story 7: Deprecate Break Functionality (US-0007)

**As a developer, I want to remove the existing `punch break` functionality to simplify the tool and align with the new categorized time-tracking model.**

* **Acceptance Criteria:**
  * The `punch break` command is completely removed.
  * All related code for starting and ending breaks is removed from `nbird11.Punch.psm1`.
  * The `README.md` and usage instructions are updated to remove any mention of the `break` command.
  * Breaks in the data model (nested inside entries) are no longer created, though the system should remain tolerant of old data containing them.

## [ ] User Story 8: Enhance Status with Category Progress (US-0008)

**As a user, when I check my status while punched into a category, I want to see my weekly progress for that specific category, so I have immediate context on my current task.**

* **Acceptance Criteria:**
  * The `punch status` command is modified.
  * When punched in and assigned to a category with a weekly allotment, the status output will include:
    * The total time worked for that category in the current week.
    * The remaining time needed to meet the weekly goal for that category.
  * If the current entry is "uncategorized" or the category has no weekly allotment, this extra information is not displayed.

## [ ] US-0009 - Enter Category Using Index

### Description

As a user, I want to be able to enter a category by its index when punching in, so that I can quickly categorize my time entries.

### Acceptance Criteria

* **Given** the user is punched out or switching categories,  
  **When** the system prompts for a category,  
  **Then** the user can enter either the category name _or its index number_ to select it. (e.g., entering `1` for "IMS Maintenance" if it's the first category in the list - `punch in 1` is valid).  
* **Given** the user provides an invalid index,  
  **When** the system checks the index,  
  **Then** an error message will be displayed.  
* **Given** the system prompts for a category on punch out, switch, or on entering an invalid category,
  **When** the system displays the list of categories,  
  **Then** each category will be numbered (starting from 1) for easy reference (e.g., `- {1} IMS Maintenance\n  - {2} IMS Enhancements\n...`).

## [ ] US-0010 - Reset Specific Items of Punch Data

### Description

As a user, when I reset my time data, I want to specify which components of the punch data to reset.

### Acceptance Criteria

* **Given** the user does not indicate which components to reset,
  **When** the system performs a reset,
  **Then** the system will tell the user that they have not specified which components to reset.
* **Given** the user wants to reset category data,
  **When** the user specifies `categories` during the reset command,
  **Then** the category data will be reset.
* **Given** the user wants to reset time entries,
  **When** the user specifies `entries` during the reset command,
  **Then** the time entries will be reset.
* **Given** the user wants to reset multiple components,
  **When** the user specifies a comma-separated list (e.g., `categories, entries`) during the reset command,
  **Then** all specified components will be reset.
* **Given** the user wants to see what components can be reset,
  **When** the user specifies `--list` during the reset command,
  **Then** the system will display a list of components that can be reset (e.g., `categories`, `entries`).
* **Given** the user specifies `all` during the reset command,
  **When** the system performs the reset,
  **Then** all components of the punch data will be reset.
