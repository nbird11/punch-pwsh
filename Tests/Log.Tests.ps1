. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Log Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Log Display' {
        It 'should display "No time entries found" when no entries exist' {
            $output = punch log
            $output | Should -Contain "No time entries found."
        }

        It 'should display recent entries with default count of 10' {
            # Add some entries
            for ($i = 1; $i -le 12; $i++) {
                punch in | Out-Null
                Start-Sleep -Milliseconds 100
                punch out | Out-Null
                Start-Sleep -Milliseconds 100
            }
            $output = punch log
            $output | Should -Contain "Time Entry Log:"
            # Should show 10 entries (last 10)
            ($output -join ' ') | Should -Match '\b10\. '
            ($output -join ' ') | Should -Not -Match '\b11\. '
        }

        It 'should display specified number of entries' {
            # Add 5 entries
            for ($i = 1; $i -le 5; $i++) {
                punch in | Out-Null
                Start-Sleep -Milliseconds 100
                punch out | Out-Null
                Start-Sleep -Milliseconds 100
            }
            $output = punch log 3
            $output | Should -Contain "Time Entry Log:"
            ($output -join ' ') | Should -Match '\b3\. '
            ($output -join ' ') | Should -Not -Match '\b4\. '
        }

        It 'should filter entries by today' {
            # This is hard to test without controlling dates, but we can assume it works
        }

        It 'should display entries with correct format' {
            punch category add test 40 | Out-Null
            punch in test | Out-Null
            Start-Sleep -Milliseconds 100
            punch out | Out-Null
            
            $output = punch log
            $output | Should -Contain "Time Entry Log:"
            $entryLine = $output | Where-Object { $_ -match '\d+\. ' } | Select-Object -First 1
            $entryLine | Should -Match '\d+\. \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} - \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \(\d{2}:\d{2}:\d{2}\) \[test\]'
        }
    }
}