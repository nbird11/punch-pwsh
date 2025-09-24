function _Usage {
    Write-Output @"
Usage: punch <command> [subcommand] [options...]
Porcelain:
in                         - Punch in
out                        - Punch out
break {start|end}          - Start or end a break
status                     - Show current status
category {add|remove|list} - Manage categories

Plumbing:
reset [-y]          - Reset the punch data storage
data                - Show the contents of the punch data storage
  path              - Output the path to the data file
  edit              - Edit the data directly in default editor

Options:
-h, --help          - Show this help message
-d, --debug         - Show debug information
-y,                 - No confirmation for reset
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
        $breaks = $entry.SelectSingleNode('breaks')
        if ($null -ne $breaks -and $breaks.ChildNodes.Count -gt 0) {
            $lastBreak = $breaks.LastChild
            if ($null -eq $lastBreak.SelectSingleNode('end')) {
                return 'break'
            }
        }
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
    if ($state -ne 'break') {
        Write-Output "Punched $state$(if ($now) { " at $(Get-Date)" } else { '' })."
    }
    else {
        Write-Output "On break."
    }
    
    $entry = $entries.LastChild
    if ($null -eq $entry) {
        Write-Output "No entries."
        return
    }

    $start = $entry.start
    $end = if ($null -eq $entry.end) { (Get-Date).ToString() } else { $entry.end }
    $breaks = $entry.SelectSingleNode('breaks')

    $total_break_time = [TimeSpan]::Zero
    if ($null -ne $breaks) {
        foreach ($break in $breaks.SelectNodes('break')) {
            $bStart = $break.start
            $bEnd = if ($null -eq $break.end) { (Get-Date).ToString() } else { $break.end }
            $total_break_time += ([DateTime]$bEnd - [DateTime]$bStart)
        }
    }

    $total_time = ([DateTime]$end - [DateTime]$start) - $total_break_time

    if ($state -eq 'out') {
        Write-Output "Last entry: $total_time"
    }
    else {
        Write-Output "Time so far this entry: $total_time"
        $eight_hours = [TimeSpan]::FromHours(8)
        if ($total_time -ge $eight_hours) {
            Write-Output "You have already worked 8 hours today, log off soon!"
        }
        else {
            $remaining_time = $eight_hours - $total_time
            $clock_out_time = (Get-Date) + $remaining_time
            Write-Output "Clock out at $($clock_out_time.ToString('hh:mm:ss tt')) for an 8 hour day."
        }
        Write-Output $total_time
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
  <entries>
  </entries>
  <categories>
  </categories>
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
    #       <category name="IMS Maintenance" weeklyHours="4.0" />
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

    switch ($args[0]) {
        'in' {
            if ($state -eq 'out') {
                $entry = $data.CreateElement('entry')
                $start = $data.CreateElement('start')
                $start.InnerText = (Get-Date).ToString()
                $entry.AppendChild($start) | Out-Null
                $entries.AppendChild($entry) | Out-Null

                $data.Save($punch_file) | Out-Null
                Write-Output "Punched in at $(Get-Date)"
            }
            else {
                Write-Output "Already punched in"
            }
        }
        'out' {
            if ($state -eq 'in') {
                $entry = $entries.LastChild
                $end = $data.CreateElement('end')
                $end.InnerText = (Get-Date).ToString()
                $entry.AppendChild($end) | Out-Null
                
                $data.Save($punch_file) | Out-Null
                # Write-Output "Punched out at $(Get-Date)"
                _Status -now
            }
            else {
                if ($state -eq 'out') { Write-Output "Already punched out" }
                else { Write-Output "Still on break" }  # TODO: Maybe just set break end to now and punch out?
            }
        }
        'break' {
            if ($args.Length -lt 2) {
                Write-Output "Usage: punch break {start | end}"
                Write-Output "Use -h or --help to show full help"
                return
            }
            switch ($args[1]) {
                'start' {
                    if ($state -eq 'in') {
                        if ($null -eq $entries) { Write-Error "AssertionError: $entries is null. "; exit 1 }
                        $entry = $entries.LastChild
                        $breaks = $entry.SelectSingleNode('breaks')
                        if ($null -eq $breaks) {
                            $breaks = $data.CreateElement('breaks')
                            $entry.AppendChild($breaks) | Out-Null
                            $breaks = $entry.SelectSingleNode('breaks')
                        }
                        
                        $break = $data.CreateElement('break')
                        $start = $data.CreateElement('start')
                        $start.InnerText = (Get-Date).ToString()
                        $break.AppendChild($start) | Out-Null
                        $breaks.AppendChild($break) | Out-Null

                        $data.Save($punch_file) | Out-Null
                        Write-Output "Break started at $(Get-Date)"
                    }
                    else {
                        if ($state -eq 'break') { Write-Output "Already on a break." }
                        else { Write-Output "Not punched in." }
                    }
                }
                'end' {
                    if ($state -eq 'break') {
                        if ($null -eq $entries) { Write-Error "AssertionError: $entries is null. "; exit 1 }
                        $entry = $entries.LastChild
                        $break = $entry.breaks.LastChild
                        
                        $end = $data.CreateElement('end')
                        $end.InnerText = (Get-Date).ToString()
                        $break.AppendChild($end) | Out-Null

                        $data.Save($punch_file) | Out-Null
                        Write-Output "Break ended at $(Get-Date). You are now punched in."
                    }
                    else {
                        if ($state -eq 'in') { Write-Output "Not on a break." }
                        else { Write-Output "Not punched in." }
                    }
                }
                default {
                    Write-Output "Usage: punch break {start | end}"
                    Write-Output "Use -h or --help to show full help"
                    return
                }
            }
        }
        'status' {
            _Status
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
                    foreach ($cat in $allCategories) {
                        $name = $cat.GetAttribute('name')
                        $hours = $cat.GetAttribute('weeklyHours')
                        Write-Output "  - $name ($hours hours/week)"
                    }
                }
                default {
                    _Usage
                }
            }
        }
        'reset' {
            $doReset = if ($args -notcontains '-y') {
                Read-Host "$(if ($state -ne 'out') { "You are still punched in; data for current session will be lost.`n" } else { '' })Are you sure you want to reset punch data? [y/N]"
            }
            else {
                'y'
            }

            if ($doReset -ne 'y') {
                Write-Output "Reset cancelled."
                return
            }
            

            Set-Content -Path $punch_file -Value @'
<punch>
  <entries>
  </entries>
  <categories>
  </categories>
</punch>
'@
            Write-Output "Punch file has been reset."
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
