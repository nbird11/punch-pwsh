. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Status Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Initial State' {
        It 'should show status as "Punched out"' {
            $status = punch status
            $status[0] | Should -Match 'Punched out'
        }

        It 'should not allow punching out when already punched out' {
            $output = punch out
            $output | Should -Contain 'Already punched out'
        }
    }

    Context 'Status with Category Progress' {
        It 'should show weekly progress when punched into a categorized entry with weekly goal' {
            # Add a category with weekly goal
            punch category add "Development" 40 | Out-Null

            # Create one historical entry from earlier today
            $punchFile = punch data path
            $data = [xml](Get-Content $punchFile)
            $entries = $data.SelectSingleNode('punch/entries')

            # Add a completed entry from earlier today (8 hours ago)
            $entry1 = $data.CreateElement('entry')
            $entry1.SetAttribute('category', 'Development')
            $start1 = $data.CreateElement('start')
            $start1.InnerText = (Get-Date).AddHours(-8).ToString('yyyy-MM-dd HH:mm:ss')
            $entry1.AppendChild($start1) | Out-Null
            $end1 = $data.CreateElement('end')
            $end1.InnerText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $entry1.AppendChild($end1) | Out-Null
            $entries.AppendChild($entry1) | Out-Null

            $data.Save($punchFile)

            # Punch in to the category
            punch in "Development" | Out-Null
            Start-Sleep -Milliseconds 100

            # Check status shows progress (8 hours from earlier today)
            $status = punch status
            $status | Should -Contain "Weekly progress for 'Development': 8h worked, 32h remaining of 40h goal."
        }

        It 'should not show progress when punched into uncategorized entry' {
            punch in | Out-Null
            Start-Sleep -Milliseconds 100

            $status = punch status
            $status | Should -Not -Match "Weekly progress"
        }

        It 'should not show progress when category has no weekly goal' {
            # Add a category without specifying hours (should default to no goal)
            punch category add "NoGoal" | Out-Null

            punch in "NoGoal" | Out-Null
            Start-Sleep -Milliseconds 100

            $status = punch status
            $status | Should -Not -Match "Weekly progress"
        }

        It 'should calculate clock out time based on total time worked today across multiple entries' {
            # Add the Work category first
            punch category add "Work" 40 | Out-Null

            # Create multiple entries for today
            $punchFile = punch data path
            $data = [xml](Get-Content $punchFile)
            $entries = $data.SelectSingleNode('punch/entries')

            # Add a completed entry from earlier today (9:00 AM - 12:00 PM = 3 hours)
            $entry1 = $data.CreateElement('entry')
            $entry1.SetAttribute('category', 'Work')
            $start1 = $data.CreateElement('start')
            $start1.InnerText = (Get-Date).ToString('yyyy-MM-dd') + ' 09:00:00'
            $entry1.AppendChild($start1) | Out-Null
            $end1 = $data.CreateElement('end')
            $end1.InnerText = (Get-Date).ToString('yyyy-MM-dd') + ' 12:00:00'
            $entry1.AppendChild($end1) | Out-Null
            $entries.AppendChild($entry1) | Out-Null

            # Add another completed entry (1:00 PM - 5:00 PM = 4 hours)
            $entry2 = $data.CreateElement('entry')
            $entry2.SetAttribute('category', 'Work')
            $start2 = $data.CreateElement('start')
            $start2.InnerText = (Get-Date).ToString('yyyy-MM-dd') + ' 13:00:00'
            $entry2.AppendChild($start2) | Out-Null
            $end2 = $data.CreateElement('end')
            $end2.InnerText = (Get-Date).ToString('yyyy-MM-dd') + ' 17:00:00'
            $entry2.AppendChild($end2) | Out-Null
            $entries.AppendChild($entry2) | Out-Null

            $data.Save($punchFile)

            # Punch in for a new session (already worked 7 hours today)
            punch in "Work" | Out-Null
            Start-Sleep -Milliseconds 100

            # Status should suggest clocking out in 1 hour (to reach 8 hours total)
            $status = punch status
            $expectedClockOut = (Get-Date).AddHours(1)
            $expectedTime = $expectedClockOut.ToString('hh:mm tt')
            $status | Should -Contain "Clock out at $expectedTime for an 8 hour day."
        }
    }
}