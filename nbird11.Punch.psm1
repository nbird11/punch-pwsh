function _Usage {
    Write-Output @"
Usage: punch <command> [subcommand] [options...]
Porcelain:
in                  - Punch in
out                 - Punch out
break {start | end} - Start or end a break
status              - Show current status

Plumbing:
reset [-y]          - Reset the punch data storage
xml                 - Show the contents of the punch data storage
  path              - Output the path to the xml file
  edit              - Edit the xml data directly in default editor

Options:
-h, --help          - Show this help message
-d, --debug         - Show debug information
-y,                 - No confirmation for reset
"@
}

function _Status {
    param (
        [switch]$now
    )

    $state = $stateNode.InnerText
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
  <state>out</state>
  <entries>
  </entries>
</punch>
'@
    }

    <#################################################
    # Punch data format:
    # <punch>
    #   <state>{in | out | break}</state>
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
    # </punch>
    #################################################>
    $data = [System.Xml.XmlDocument]::new()
    $data.Load($punch_file)
    Write-Debug "data = $($data.OuterXml)"
    $punch = $data.SelectSingleNode('punch')
    Write-Debug "punch = $($punch.OuterXml)"
    
    if ($null -eq $punch) {
        $punch = $data.CreateElement('punch')
        $stateNode = $data.CreateElement('state')
        $stateNode.InnerText = 'out'
        $punch.AppendChild($stateNode) | Out-Null
        $entriesNode = $data.CreateElement('entries')
        $punch.AppendChild($entriesNode) | Out-Null
        $data.AppendChild($punch) | Out-Null
        $data.Save($punch_file)
    }

    $stateNode = $punch.SelectSingleNode('state')
    $state = $stateNode.InnerText
    $entries = $punch.SelectSingleNode('entries')

    Write-Debug "stateNode = $($stateNode.OuterXml)"
    Write-Debug "state = $state"
    Write-Debug "entries = $($entries.OuterXml)"

    switch ($args[0]) {
        'in' {
            if ($state -eq 'out') {
                $entry = $data.CreateElement('entry')
                $start = $data.CreateElement('start')
                $start.InnerText = (Get-Date).ToString()
                $entry.AppendChild($start) | Out-Null
                $entries.AppendChild($entry) | Out-Null

                $stateNode.InnerText = 'in'
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
                
                $stateNode.InnerText = 'out'
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

                        $stateNode.InnerText = 'break'
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

                        $stateNode.InnerText = 'in'
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
  <state>out</state>
  <entries>
  </entries>
</punch>
'@
            Write-Output "Punch file has been reset."
        }
        'xml' {
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
