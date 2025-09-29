# Import the module being tested
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Punch.psm1'
Import-Module -Name $modulePath -Force

BeforeAll {
    # Create a temporary directory for test data to avoid interfering with real user data
    $script:tempDir = New-Item -Path (Join-Path $env:TEMP (New-Guid)) -ItemType Directory
    
    # Override the APPDATA environment variable for the scope of these tests
    $script:originalAppData = $env:APPDATA
    $env:APPDATA = $script:tempDir
}

AfterAll {
    # Clean up the temporary directory and restore the environment variable
    Remove-Item -Path $script:tempDir -Recurse -Force
    $env:APPDATA = $script:originalAppData
    
    # Remove the module to ensure a clean state for subsequent test runs
    Remove-Module Punch
}

Describe 'Punch Report Functionality' {
    BeforeEach {
        # Reset the punch data before each test to ensure isolation
        punch reset -y | Out-Null
    }

    Context 'Weekly Report Display' {
        It 'should show no time for empty categories' {
            punch category add "Test Cat" 5 | Out-Null
            $output = punch report | Out-String
            $output | Should -Match "Test Cat\s+0h\s+5h\s+\(0%\)"
        }

        It 'should show uncategorized time correctly' {
            # Create an entry earlier today
            punch in | Out-Null
            Start-Sleep -Milliseconds 100
            punch out | Out-Null
            
            $output = punch report | Out-String
            $output | Should -Match "uncategorized\s+0h\s+<N/A>"
        }

        It 'should calculate time for categorized entries' {
            punch category add "Work" 10 | Out-Null
            
            # Create a work entry
            punch in "Work" | Out-Null
            Start-Sleep -Milliseconds 100
            punch out | Out-Null
            
            $output = punch report | Out-String
            $output | Should -Match "Work\s+0h\s+10h\s+\(0%\)"
        }

        It 'should handle multiple categories and entries' {
            punch category add "Cat A" 5 | Out-Null
            punch category add "Cat B" 10 | Out-Null
            
            # Create entries for both categories
            punch in "Cat A" | Out-Null
            Start-Sleep -Milliseconds 100
            punch out | Out-Null
            
            punch in "Cat B" | Out-Null
            Start-Sleep -Milliseconds 100
            punch out | Out-Null
            
            $output = punch report | Out-String
            $output | Should -Match "Cat A\s+0h\s+5h\s+\(0%\)"
            $output | Should -Match "Cat B\s+0h\s+10h\s+\(0%\)"
        }

        It 'should exclude entries from previous weeks' {
            punch category add "Weekly" 10 | Out-Null
            
            # Mock an old entry by directly editing the XML
            $punchFile = punch data path
            $data = [xml](Get-Content $punchFile)
            $entries = $data.SelectSingleNode('punch/entries')
            $entry = $data.CreateElement('entry')
            $entry.SetAttribute('category', 'Weekly')
            
            $start = $data.CreateElement('start')
            $start.InnerText = (Get-Date).AddDays(-8).ToString()  # Last week
            $entry.AppendChild($start) | Out-Null
            
            $end = $data.CreateElement('end')
            $end.InnerText = (Get-Date).AddDays(-8).AddHours(2).ToString()
            $entry.AppendChild($end) | Out-Null
            
            $entries.AppendChild($entry) | Out-Null
            $data.Save($punchFile)
            
            $output = punch report | Out-String
            $output | Should -Match "Weekly\s+0h\s+10h\s+\(0%\)"  # Should not include the 2 hours from last week
        }

        It 'should correctly calculate time with break data for backward compatibility' {
            punch category add "Work" 40 | Out-Null
            
            # Create XML data with break elements (simulating old data format)
            $punchFile = punch data path
            $xml = @'
<punch>
    <entries>
        <entry category="Work">
            <start>2025-09-29 09:00:00</start>
            <breaks>
                <break>
                    <start>2025-09-29 12:00:00</start>
                    <end>2025-09-29 13:00:00</end>
                </break>
            </breaks>
            <end>2025-09-29 17:00:00</end>
        </entry>
    </entries>
    <categories>
        <category name="Work" weeklyHours="40" />
    </categories>
</punch>
'@
            Set-Content -Path $punchFile -Value $xml
            
            $output = punch report | Out-String
            # 8-hour day (9-5) minus 1-hour break should show 7 hours
            $output | Should -Match "Work\s+7h\s+40h\s+\(17\.5%\)"
        }
    }
}