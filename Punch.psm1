function _Usage {
    Write-Output @"
Usage: punch <command> [subcommand] [options...]
Porcelain:
in [category]              - Punch in, optionally assigning to a category
out                        - Punch out
switch [<category>]        - Switch to a new category
status                     - Show current status
report                     - Show weekly progress report
log [<count>] [options]    - View time entry log (default count: 10)
  --period <period>          - Filter by period: today, week, month, all
  --date <YYYY-MM-DD>        - Filter by specific date
category {add|remove|list} - Manage categories

Plumbing:
reset {list|[<component>[,<component> ...]]} [options]
                    - Reset specific components of the punch data storage
  -y,                 - No confirmation for reset
data                - Show the contents of the punch data storage
  path                - Output the path to the data file
  edit                - Edit the data directly in default editor

Options:
-h, --help          - Show this help message
-d, --debug         - Show debug information
"@
}

function _GetState {
    param ()

    # global $entries

    if ($null -eq $entries -or $entries.ChildNodes.Count -eq 0) {
        return 'out'
    }

    $entry = $entries.LastChild
    if ($null -eq $entry.SelectSingleNode('end')) {
        return 'in'
    }
    else {
        return 'out'
    }
}

function _Status {
    param (
        [switch]$now
    )

    # global $entries

    $state = _GetState
    Write-Output "Punched $state$(if ($now) { " at $(Get-Date)" } else { '' })."
    
    $entry = $entries.LastChild
    if ($null -eq $entry) {
        Write-Output "No entries."
        return
    }

    $start = $entry.start
    $end = if ($null -eq $entry.end) { (Get-Date).ToString() } else { $entry.end }
    
    # Calculate total break time for backward compatibility with old data
    $totalBreakTime = [TimeSpan]::Zero
    $breaks = $entry.SelectSingleNode('breaks')
    if ($null -ne $breaks) {
        foreach ($break in $breaks.SelectNodes('break')) {
            $bStart = $break.start
            $bEnd = if ($null -eq $break.end) { (Get-Date).ToString() } else { $break.end }
            $totalBreakTime += ([DateTime]$bEnd - [DateTime]$bStart)
        }
    }
    
    $total_time = ([DateTime]$end - [DateTime]$start) - $totalBreakTime

    if ($state -eq 'out') {
        Write-Output "Last entry: $($total_time.ToString('hh\:mm\:ss'))"
    }
    else {
        Write-Output "Time so far this entry: $($total_time.ToString('hh\:mm\:ss'))"
        
        # Calculate total time worked today across all entries
        $today = Get-Date
        $todayStart = $today.Date
        $todayEnd = $todayStart.AddDays(1)
        
        $totalTimeToday = [TimeSpan]::Zero
        foreach ($dayEntry in $entries.SelectNodes('entry')) {
            $entryStart = [DateTime]$dayEntry.start
            $entryEnd = if ($null -eq $dayEntry.end) { Get-Date } else { [DateTime]$dayEntry.end }
            
            # Only count entries that started today
            if ($entryStart -ge $todayStart -and $entryStart -lt $todayEnd) {
                # Calculate break time for this entry (Backward compatibility [breaks deprecated])
                $entryBreakTime = [TimeSpan]::Zero
                $breaks = $dayEntry.SelectSingleNode('breaks')
                if ($null -ne $breaks) {
                    foreach ($break in $breaks.SelectNodes('break')) {
                        $breakStart = [DateTime]$break.start
                        $breakEnd = if ($null -eq $break.end) { Get-Date } else { [DateTime]$break.end }
                        $entryBreakTime += ($breakEnd - $breakStart)
                    }
                }
                
                $totalTimeToday += ($entryEnd - $entryStart) - $entryBreakTime
            }
        }
        
        Write-Output "Total time worked today: $($totalTimeToday.ToString('hh\:mm\:ss'))"
        
        $eight_hours = [TimeSpan]::FromHours(8)
        if ($totalTimeToday -ge $eight_hours) {
            Write-Output "You have already worked 8 hours today, log off soon!"
        }
        else {
            $remaining_time = $eight_hours - $totalTimeToday
            $clock_out_time = (Get-Date) + $remaining_time
            Write-Output "Clock out at $($clock_out_time.ToString('hh:mm tt')) for an 8 hour day."
        }

        # Show category progress if punched into a categorized entry with weekly goal
        $category = $entry.GetAttribute('category')
        if ($null -ne $category -and $category -ne 'uncategorized') {
            $categoriesNode = $punch.SelectSingleNode('categories')
            if ($null -ne $categoriesNode) {
                $catNode = $categoriesNode.SelectSingleNode("category[@name='$category']")
                if ($null -ne $catNode) {
                    $weeklyGoal = [double]$catNode.GetAttribute('weeklyHours')
                    
                    # Calculate total time worked this week for this category
                    $today = Get-Date
                    $startOfWeek = $today.Date.AddDays(-([int]$today.DayOfWeek - 1))
                    $endOfWeek = $startOfWeek.AddDays(7)
                    
                    $weeklyTime = [TimeSpan]::Zero
                    foreach ($weekEntry in $entries.SelectNodes('entry')) {
                        $entryCategory = $weekEntry.GetAttribute('category')
                        if ($entryCategory -eq $category) {
                            $entryStart = [DateTime]$weekEntry.start
                            $entryEnd = if ($null -eq $weekEntry.end) { Get-Date } else { [DateTime]$weekEntry.end }
                            
                            # Skip entries outside current week
                            if ($entryStart -lt $startOfWeek -or $entryStart -gt $endOfWeek) {
                                continue
                            }
                            
                            # Calculate break time for this entry
                            $entryBreakTime = [TimeSpan]::Zero
                            $breaks = $weekEntry.SelectSingleNode('breaks')
                            if ($null -ne $breaks) {
                                foreach ($break in $breaks.SelectNodes('break')) {
                                    $breakStart = [DateTime]$break.start
                                    $breakEnd = if ($null -eq $break.end) { Get-Date } else { [DateTime]$break.end }
                                    $entryBreakTime += ($breakEnd - $breakStart)
                                }
                            }
                            
                            $weeklyTime += ($entryEnd - $entryStart) - $entryBreakTime
                        }
                    }
                    
                    $remainingHours = [math]::Max(0, $weeklyGoal - $weeklyTime.TotalHours)
                    Write-Output "Weekly progress for '$category': $([math]::Round($weeklyTime.TotalHours, 1))h worked, $([math]::Round($remainingHours, 1))h remaining of ${weeklyGoal}h goal."
                }
            }
        }
        # Write-Output $total_time
    }
}

function _PromptForCategory {
    param(
        [string[]]$validCategories
    )

    if ($validCategories.Count -eq 0) {
        return $null
    }

    Write-Host "The last session was 'uncategorized'."
    $i = 1
    $validCategories | ForEach-Object { Write-Host "{$i} $_"; $i++ }
    
    while ($true) {
        $choice = Read-Host "Choose a category for the last session (number), or press Enter to leave as 'uncategorized'"
        
        if ([string]::IsNullOrEmpty($choice)) {
            return $null
        }

        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $validCategories.Count) {
            $chosenCategory = $validCategories[[int]$choice - 1]
            Write-Host "Last session categorized as '$chosenCategory'."
            return $chosenCategory
        }
        
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    }
}

function punch {
    if ('-d' -in $args -or '--debug' -in $args) {
        $DebugPreference = 'Continue'
    }

    if ('-h' -in $args -or '--help' -in $args) {
        _Usage
        return
    }

    if ($args.Length -eq 0) {
        _Usage
        return
    }

    $punch_dir = "$env:APPDATA\punch"
    if (-not (Test-Path -Path $punch_dir)) {
        New-Item -Path $punch_dir -ItemType Directory | Out-Null
    }
    $punch_file = "$punch_dir\punch.xml"
    if (-not (Test-Path -Path $punch_file)) {
        New-Item -Path $punch_file -ItemType File | Out-Null
        Set-Content -Path $punch_file -Value @'
<punch>
  <entries />
  <categories />
</punch>
'@
    }

    <#################################################
    # Punch data format:
    # <punch>
    #   <entries>
    #     <entry>
    #       <start>2025-01-01 09:00:00</start>
    #       <breaks>
    #         <break>
    #           <start>2025-01-01 12:00:00</start>
    #           <end>2025-01-01 13:00:00</end>
    #         </break>
    #         [...]
    #       </breaks>
    #       <end>2025-01-01 17:00:00</end>
    #     </entry>
    #     [...]
    #   </entries>
    #   <categories>
    #     <category name="IMS Maintenance" weeklyHours="4.0" />
    #     [...]
    #   </categories>
    # </punch>
    #################################################>
    $data = [System.Xml.XmlDocument]::new()
    $data.Load($punch_file)
    Write-Debug "data = $($data.OuterXml)"
    $punch = $data.SelectSingleNode('punch')
    Write-Debug "punch = $($punch.OuterXml)"
    
    if ($null -eq $punch) {
        $punch = $data.CreateElement('punch')
        $entriesNode = $data.CreateElement('entries')
        $punch.AppendChild($entriesNode) | Out-Null
        $data.AppendChild($punch) | Out-Null
        $data.Save($punch_file)
    }
    
    $entries = $punch.SelectSingleNode('entries')
    Write-Debug "entries = $($entries.OuterXml)"

    $state = _GetState $entries
    Write-Debug "state = $state"

    function _GetWeeklyReport {
        # Get the start and end of the current week (Monday to Sunday)
        $today = Get-Date
        $startOfWeek = $today.Date.AddDays(-([int]$today.DayOfWeek - 1))
        $endOfWeek = $startOfWeek.AddDays(7)

        # Get all categories with their weekly hours
        $categoriesNode = $punch.SelectSingleNode('categories')
        $categories = @{}
        $categoryHours = @{}
        if ($null -ne $categoriesNode) {
            foreach ($cat in $categoriesNode.SelectNodes('category')) {
                $name = $cat.GetAttribute('name')
                $hours = [double]$cat.GetAttribute('weeklyHours')
                $categories[$name] = [TimeSpan]::Zero
                $categoryHours[$name] = $hours
            }
        }
        $categories['uncategorized'] = [TimeSpan]::Zero

        # Calculate time spent in each category this week
        foreach ($entry in $entries.SelectNodes('entry')) {
            $entryStart = [DateTime]$entry.start
            $entryEnd = if ($null -eq $entry.end) { Get-Date } else { [DateTime]$entry.end }
            $category = $entry.GetAttribute('category')

            # Skip entries outside current week
            if ($entryStart -lt $startOfWeek -or $entryStart -gt $endOfWeek) {
                continue
            }

            # Calculate total break time for this entry (for backward compatibility with old data)
            $totalBreakTime = [TimeSpan]::Zero
            $breaks = $entry.SelectSingleNode('breaks')
            if ($null -ne $breaks) {
                foreach ($break in $breaks.SelectNodes('break')) {
                    $breakStart = [DateTime]$break.start
                    $breakEnd = if ($null -eq $break.end) { Get-Date } else { [DateTime]$break.end }
                    $totalBreakTime += ($breakEnd - $breakStart)
                }
            }

            # Add the time to the category total
            $timeSpent = ($entryEnd - $entryStart) - $totalBreakTime
            $categories[$category] += $timeSpent
        }

        # Generate the report header
        Write-Output "Weekly Progress Report (Week of $($startOfWeek.ToString('MM/dd/yyyy')))"
        Write-Output "-------------------------------------------"

        # Create objects for each category
        $reportData = foreach ($cat in $categories.Keys | Sort-Object) {
            $time = $categories[$cat]
            $hours = [math]::Round($time.TotalHours, 1)
            
            if ($cat -eq 'uncategorized') {
                [PSCustomObject]@{
                    Category = $cat
                    Time     = "{0,5}h" -f $hours
                    Goal     = " <N/A>"
                    Progress = ""
                }
            } else {
                $goal = $categoryHours[$cat]

                $percentage = [math]::Round(($time.TotalHours / $goal) * 100, 1)
                [PSCustomObject]@{
                    Category = $cat
                    Time     = "{0,5}h" -f $hours
                    Goal     = "{0,5}h" -f $goal
                    Progress = "($percentage%)"
                }
            }
        }

        # Output the data using Format-Table with auto-sizing columns
        $reportData | Format-Table -AutoSize
    }

    switch ($args[0]) {
        'in' {
            if ($state -eq 'out') {
                $category = if ($args.Length -gt 1) { $args[1] } else { "uncategorized" }

                if ($category -ne "uncategorized") {
                    $categoriesNode = $punch.SelectSingleNode('categories')
                    $validCategories = @()
                    if ($null -ne $categoriesNode) {
                        $validCategories = $categoriesNode.SelectNodes('category') | ForEach-Object { $_.GetAttribute('name') }
                    }

                    # Check if input is a number (index)
                    if ($category -match '^\d+$') {
                        $index = [int]$category - 1
                        if ($index -ge 0 -and $index -lt $validCategories.Count) {
                            $category = $validCategories[$index]
                        } else {
                            Write-Output "Error: Invalid category index '$($args[1])'. Please use a number between 1 and $($validCategories.Count)."
                            if ($validCategories.Count -gt 0) {
                                Write-Output "Available categories:"
                                $i = 1
                                $validCategories | ForEach-Object { Write-Output "  {$i} $_"; $i++ }
                            }
                            return
                        }
                    }
                    elseif ($category -notin $validCategories) {
                        Write-Output "Error: Category '$category' not found."
                        if ($validCategories.Count -gt 0) {
                            Write-Output "Available categories:"
                            $i = 1
                            $validCategories | ForEach-Object { Write-Output "  {$i} $_"; $i++ }
                        } else {
                            Write-Output "No categories have been defined yet. Use 'punch category add ...'"
                        }
                        return
                    }
                }

                $entry = $data.CreateElement('entry')
                $entry.SetAttribute('category', $category)

                $start = $data.CreateElement('start')
                $start.InnerText = (Get-Date).ToString()
                $entry.AppendChild($start) | Out-Null
                $entries.AppendChild($entry) | Out-Null

                $data.Save($punch_file) | Out-Null
                Write-Output "Punched in at $(Get-Date) (Category: $category)"
            }
            else {
                Write-Output "Already punched in"
            }
        }
        'switch' {
            if ($state -ne 'in') {
                Write-Output "Not punched in. Use 'punch in <category>' to start."
                return
            }
            
            $newCategory = if ($args.Length -gt 1) { $args[1] } else { "uncategorized" }

            # Validate the new category if it's not uncategorized
            if ($newCategory -ne "uncategorized") {
                $categoriesNode = $punch.SelectSingleNode('categories')
                $validCategories = @()
                if ($null -ne $categoriesNode) {
                    $validCategories = $categoriesNode.SelectNodes('category') | ForEach-Object { $_.GetAttribute('name') }
                }
                
                # Check if input is a number (index)
                if ($newCategory -match '^\d+$') {
                    $index = [int]$newCategory - 1
                    if ($index -ge 0 -and $index -lt $validCategories.Count) {
                        $newCategory = $validCategories[$index]
                    } else {
                        Write-Output "Error: Invalid category index '$($args[1])'. Please use a number between 1 and $($validCategories.Count)."
                        if ($validCategories.Count -gt 0) {
                            Write-Output "Available categories:"
                            $i = 1
                            $validCategories | ForEach-Object { Write-Output "  {$i} $_"; $i++ }
                        }
                        return
                    }
                }
                elseif ($newCategory -notin $validCategories) {
                    Write-Output "Error: Category '$newCategory' not found."
                    if ($validCategories.Count -gt 0) {
                        Write-Output "Available categories:"
                        $i = 1
                        $validCategories | ForEach-Object { Write-Output "  {$i} $_"; $i++ }
                    } else {
                        Write-Output "No categories have been defined yet. Use 'punch category add ...'"
                    }
                    return
                }
            }

            # Punch out the current entry
            $currentEntry = $entries.LastChild
            $end = $data.CreateElement('end')
            $end.InnerText = (Get-Date).ToString()
            $currentEntry.AppendChild($end) | Out-Null
            
            # Prompt to categorize if the current entry is uncategorized
            if ($currentEntry.GetAttribute('category') -eq 'uncategorized') {
                $categoriesNode = $punch.SelectSingleNode('categories')
                $validCategories = @()
                if ($null -ne $categoriesNode) {
                    $validCategories = $categoriesNode.SelectNodes('category') | ForEach-Object { $_.GetAttribute('name') }
                }
                
                $chosenCategory = _PromptForCategory -validCategories $validCategories
                if ($null -ne $chosenCategory) {
                    $currentEntry.SetAttribute('category', $chosenCategory)
                }
            }

            # Punch in the new entry
            $newEntry = $data.CreateElement('entry')
            $newEntry.SetAttribute('category', $newCategory)
            $start = $data.CreateElement('start')
            $start.InnerText = (Get-Date).ToString()
            $newEntry.AppendChild($start) | Out-Null
            $entries.AppendChild($newEntry) | Out-Null

            $data.Save($punch_file) | Out-Null
            Write-Output "Switched to category '$newCategory'."
        }
        'out' {
            if ($state -eq 'in') {
                $entry = $entries.LastChild

                # Prompt to categorize if the current entry is uncategorized
                if ($entry.GetAttribute('category') -eq 'uncategorized') {
                    $categoriesNode = $punch.SelectSingleNode('categories')
                    $validCategories = @()
                    if ($null -ne $categoriesNode) {
                        $validCategories = $categoriesNode.SelectNodes('category') | ForEach-Object { $_.GetAttribute('name') }
                    }
                    
                    $chosenCategory = _PromptForCategory -validCategories $validCategories
                    if ($null -ne $chosenCategory) {
                        $entry.SetAttribute('category', $chosenCategory)
                    }
                }

                $end = $data.CreateElement('end')
                $end.InnerText = (Get-Date).ToString()
                $entry.AppendChild($end) | Out-Null
                
                $data.Save($punch_file) | Out-Null
                # Write-Output "Punched out at $(Get-Date)"
                _Status -now
            }
            else {
                Write-Output "Already punched out"
            }
        }
        'status' {
            _Status
        }
        'report' {
            _GetWeeklyReport
        }
        'log' {
            $logArgs = @($args | Where-Object { $_ -ne 'log' })
            
            $count = 10
            $period = $null
            $specificDate = $null
            
            $i = 0
            while ($i -lt $logArgs.Count) {
                $arg = $logArgs[$i]
                if ($arg -eq '--period') {
                    if ($i + 1 -lt $logArgs.Count) {
                        $period = $logArgs[$i + 1]
                        $i += 2
                    } else {
                        Write-Output "Error: --period requires a value (today, week, month, all)"
                        return
                    }
                } elseif ($arg -eq '--date') {
                    if ($i + 1 -lt $logArgs.Count) {
                        $specificDate = $logArgs[$i + 1]
                        $i += 2
                    } else {
                        Write-Output "Error: --date requires a date value (YYYY-MM-DD)"
                        return
                    }
                } elseif ($arg -match '^\d+$') {
                    $count = [int]$arg
                    $i++
                } else {
                    Write-Output "Error: Unknown argument '$arg'"
                    return
                }
            }
            
            $allEntries = $entries.SelectNodes('entry')
            if ($allEntries.Count -eq 0) {
                Write-Output "No time entries found."
                return
            }
            
            # Filter entries
            $filteredEntries = @()
            foreach ($entry in $allEntries) {
                $startTime = [DateTime]$entry.start
                $include = $true
                
                if ($specificDate) {
                    try {
                        $date = [DateTime]::Parse($specificDate)
                        if ($startTime.Date -ne $date.Date) {
                            $include = $false
                        }
                    } catch {
                        Write-Output "Error: Invalid date format '$specificDate'. Use YYYY-MM-DD."
                        return
                    }
                } elseif ($period) {
                    $now = Get-Date
                    switch ($period) {
                        'today' {
                            if ($startTime.Date -ne $now.Date) { $include = $false }
                        }
                        'week' {
                            $weekStart = $now.Date.AddDays(-[int]$now.DayOfWeek)
                            $weekEnd = $weekStart.AddDays(6)
                            if ($startTime.Date -lt $weekStart -or $startTime.Date -gt $weekEnd) { $include = $false }
                        }
                        'month' {
                            if ($startTime.Year -ne $now.Year -or $startTime.Month -ne $now.Month) { $include = $false }
                        }
                        'all' {
                            # Include all
                        }
                        default {
                            Write-Output "Error: Invalid period '$period'. Use today, week, month, or all."
                            return
                        }
                    }
                }
                
                if ($include) {
                    $filteredEntries += $entry
                }
            }
            
            # Take the last $count entries
            $entriesToShow = $filteredEntries | Select-Object -Last $count
            
            if ($entriesToShow.Count -eq 0) {
                Write-Output "No time entries found for the specified criteria."
                return
            }
            
            # Display entries
            Write-Output "Time Entry Log:"
            Write-Output ""
            
            $index = 1
            foreach ($entry in $entriesToShow) {
                $start = [DateTime]$entry.start
                $end = if ($entry.end) { [DateTime]$entry.end } else { Get-Date }
                $category = $entry.GetAttribute('category')
                if (-not $category) { $category = 'uncategorized' }
                
                # Calculate duration
                $duration = $end - $start
                
                # Subtract breaks
                $breaks = $entry.SelectSingleNode('breaks')
                if ($breaks) {
                    foreach ($break in $breaks.SelectNodes('break')) {
                        $bStart = [DateTime]$break.start
                        $bEnd = if ($break.end) { [DateTime]$break.end } else { Get-Date }
                        $duration = $duration - ($bEnd - $bStart)
                    }
                }
                
                $durationStr = "{0:hh\:mm\:ss}" -f $duration
                $startStr = $start.ToString("yyyy-MM-dd HH:mm:ss")
                $endStr = if ($entry.end) { $end.ToString("yyyy-MM-dd HH:mm:ss") } else { "ongoing" }
                
                Write-Output ("{0,3}. {1} - {2} ({3}) [{4}]" -f $index, $startStr, $endStr, $durationStr, $category)
                $index++
            }
        }
        'category' {
            if ($args.Length -lt 2) {
                _Usage
                return
            }
            $categoriesNode = $punch.SelectSingleNode('categories')
            if ($null -eq $categoriesNode) {
                $categoriesNode = $data.CreateElement('categories')
                $punch.AppendChild($categoriesNode) | Out-Null
            }

            switch ($args[1]) {
                'add' {
                    if ($args.Length -ne 4) {
                        Write-Output "Usage: punch category add <name> <weeklyHours>"
                        return
                    }
                    $name = $args[2]
                    $hours = $args[3]

                    if ($categoriesNode.SelectSingleNode("category[@name='$name']")) {
                        Write-Output "Category '$name' already exists."
                        return
                    }
                    
                    $category = $data.CreateElement('category')
                    $category.SetAttribute('name', $name)
                    $category.SetAttribute('weeklyHours', $hours)
                    $categoriesNode.AppendChild($category) | Out-Null
                    $data.Save($punch_file)
                    Write-Output "Category '$name' added with a weekly allotment of $hours hours."
                }
                'remove' {
                    if ($args.Length -ne 3) {
                        Write-Output "Usage: punch category remove <name>"
                        return
                    }
                    $name = $args[2]
                    $categoryToRemove = $categoriesNode.SelectSingleNode("category[@name='$name']")
                    if ($null -ne $categoryToRemove) {
                        $categoriesNode.RemoveChild($categoryToRemove) | Out-Null
                        $data.Save($punch_file)
                        Write-Output "Category '$name' removed."
                    } else {
                        Write-Output "Category '$name' not found."
                    }
                }
                'list' {
                    $allCategories = $categoriesNode.SelectNodes('category')
                    if ($allCategories.Count -eq 0) {
                        Write-Output "No categories defined."
                        return
                    }
                    Write-Output "Defined Categories:"
                    $i = 1
                    foreach ($cat in $allCategories) {
                        $name = $cat.GetAttribute('name')
                        $hours = $cat.GetAttribute('weeklyHours')
                        Write-Output "  {$i} $name ($hours hours/week)"
                        $i++
                    }
                }
                default {
                    _Usage
                }
            }
        }
        'reset' {
            $resetArgs = @($args | Where-Object { $_ -ne 'reset' })
            
            if ($resetArgs.Count -gt 0 -and $resetArgs[0] -eq 'list') {
                Write-Output "Available components to reset:"
                Write-Output "  categories - Reset all category definitions"
                Write-Output "  entries    - Reset all time entries"
                Write-Output "  all        - Reset all components"
                return
            }
            
            $components = $resetArgs | Where-Object { $_ -ne '-y' }
            if ($components.Count -eq 0) {
                Write-Output "Error: No components specified for reset. Use 'punch reset list' to see available components."
                return
            }
            
            $resetCategories = $false
            $resetEntries = $false
            
            if ($components -contains 'all') {
                $resetCategories = $true
                $resetEntries = $true
            } else {
                foreach ($comp in $components) {
                    $parts = $comp -split ','
                    foreach ($part in $parts) {
                        $part = $part.Trim()
                        if ($part -eq 'categories') {
                            $resetCategories = $true
                        } elseif ($part -eq 'entries') {
                            $resetEntries = $true
                        } else {
                            Write-Output "Error: Unknown component '$part'. Use 'punch reset list' to see available components."
                            return
                        }
                    }
                }
            }
            
            if (-not $resetCategories -and -not $resetEntries) {
                Write-Output "Error: No valid components specified for reset."
                return
            }
            
            $doReset = if ($resetArgs -notcontains '-y') {
                $componentList = @()
                if ($resetCategories) { $componentList += 'categories' }
                if ($resetEntries) { $componentList += 'entries' }
                $componentStr = $componentList -join ' and '
                Read-Host "$(if ($state -ne 'out') { "You are still punched in; data for current session will be lost.`n" } else { '' })Are you sure you want to reset $($componentStr)? [y/N]"
            }
            else {
                'y'
            }

            if ($doReset -ne 'y') {
                Write-Output "Reset cancelled."
                return
            }
            
            # Load current data
            [xml]$data = Get-Content $punch_file
            $punch = $data.punch
            
            if ($resetEntries) {
                $entriesNode = $punch.SelectSingleNode('entries')
                if ($null -ne $entriesNode) {
                    $entriesNode.RemoveAll()
                }
            }
            
            if ($resetCategories) {
                $categoriesNode = $punch.SelectSingleNode('categories')
                if ($null -ne $categoriesNode) {
                    $categoriesNode.RemoveAll()
                }
            }
            
            $data.Save($punch_file)
            
            $componentList = @()
            if ($resetCategories) { $componentList += 'Categories' }
            if ($resetEntries) { $componentList += 'Entries' }
            $componentStr = $componentList -join ' and '
            Write-Output "$componentStr have been reset."
        }
        'data' {
            if ($args -contains 'path') {
                Write-Output $punch_file
            }
            elseif ($args -contains 'edit') {
                try {
                    code $punch_file
                } catch {
                    Write-Error "Could not open '$punch_file' with VSCode."
                }
            }
            else {
                Get-Content -Path $punch_file
            }
        }
        default {
            _Usage
            return
        }
    }
}
