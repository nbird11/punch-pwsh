# Import the module being tested
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Punch.psm1'
Import-Module -Name $modulePath -Force

BeforeAll {
    # Create a temporary directory for test data to avoid interfering with real user data
    $script:tempDir = New-Item -Path (Join-Path $env:TEMP (New-Guid)) -ItemType Directory
    $script:punchDir = New-Item -Path (Join-Path $script:tempDir 'punch') -ItemType Directory
    
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

Describe 'Punch Core Functionality' {
    
    BeforeEach {
        # Reset the punch data before each test to ensure isolation
        punch reset -y | Out-Null
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

    Context 'Punch In and Out' {
        It 'should allow punching in' {
            $output = punch in
            $output | Should -Match 'Punched in at'
            $status = punch status
            $status[0] | Should -Match 'Punched in'
        }

        It 'should punch in with "uncategorized" by default' {
            $output = punch in
            $output | Should -Match 'Category: uncategorized'

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $lastEntry = $punchXml.punch.entries.LastChild
            $lastEntry.category | Should -Be 'uncategorized'
        }

        It 'should punch in with a specified category' {
            punch category add "Test Category" 10 | Out-Null
            $output = punch in "Test Category"
            $output | Should -Match 'Category: Test Category'

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $lastEntry = $punchXml.punch.entries.LastChild
            $lastEntry.category | Should -Be 'Test Category'
        }

        It 'should fail to punch in with an invalid category' {
            punch category add "Valid Cat" 8 | Out-Null
            $output = punch in "Invalid Cat"
            $output[0] | Should -Match "Error: Category 'Invalid Cat' not found."
            $output[2] | Should -Match "Valid Cat"

            $status = punch status
            $status[0] | Should -Match 'Punched out'
        }

        It 'should not allow punching in when already punched in' {
            punch in | Out-Null
            $output = punch in
            $output | Should -Contain 'Already punched in'
        }

        It 'should allow punching out after punching in' {
            punch in | Out-Null
            # We need a small delay to ensure there's a measurable time difference
            Start-Sleep -Milliseconds 10 
            $output = punch out
            $output[0] | Should -Match 'Punched out at'
            $output[1] | Should -Match 'Last entry: \d{2}:\d{2}:\d{2}'
        }

        It 'should punch in using category index' {
            punch category add "First Cat" 10 | Out-Null
            punch category add "Second Cat" 15 | Out-Null
            punch category add "Third Cat" 20 | Out-Null
            
            $output = punch in 2
            $output | Should -Match 'Category: Second Cat'

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $lastEntry = $punchXml.punch.entries.LastChild
            $lastEntry.category | Should -Be 'Second Cat'
        }

        It 'should fail to punch in with invalid category index' {
            punch category add "Cat One" 10 | Out-Null
            punch category add "Cat Two" 15 | Out-Null
            
            $output = punch in 5
            $output[0] | Should -Match "Error: Invalid category index '5'"
            $output[1] | Should -Match "Available categories:"
            $output[2] | Should -Match "\{1\} Cat One"
            $output[3] | Should -Match "\{2\} Cat Two"
        }
    }

    Context 'Switch Functionality' {
        BeforeEach {
            punch category add "Cat A" 10 | Out-Null
            punch category add "Cat B" 10 | Out-Null
        }

        It 'should not allow switching when punched out' {
            $output = punch switch "Cat A"
            $output | Should -Match "Not punched in."
        }

        It 'should not allow switching to an invalid category' {
            punch in "Cat A" | Out-Null
            $output = punch switch "Invalid Cat"
            $output[0] | Should -Match "Error: Category 'Invalid Cat' not found."
        }

        It 'should switch from one category to another' {
            punch in "Cat A" | Out-Null
            Start-Sleep -Milliseconds 10
            $output = punch switch "Cat B"
            $output | Should -Match "Switched to category 'Cat B'."

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $entries = $punchXml.punch.entries.entry
            $entries.Count | Should -Be 2
            $entries[0].category | Should -Be "Cat A"
            $entries[0].end | Should -Not -BeNullOrEmpty
            $entries[1].category | Should -Be "Cat B"
            $entries[1].end | Should -BeNullOrEmpty
        }

        It 'should switch to "uncategorized" if no category is provided' {
            punch in "Cat A" | Out-Null
            Start-Sleep -Milliseconds 10
            $output = punch switch
            $output | Should -Match "Switched to category 'uncategorized'."

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $entries = $punchXml.punch.entries.entry
            $entries.Count | Should -Be 2
            $entries[1].category | Should -Be "uncategorized"
        }

        It 'should switch using category index' {
            punch in "Cat A" | Out-Null
            Start-Sleep -Milliseconds 10
            $output = punch switch 2
            $output | Should -Match "Switched to category 'Cat B'."

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $entries = $punchXml.punch.entries.entry
            $entries.Count | Should -Be 2
            $entries[1].category | Should -Be "Cat B"
        }

        It 'should fail to switch with invalid category index' {
            punch in "Cat A" | Out-Null
            $output = punch switch "10"
            $output[0] | Should -Match "Error: Invalid category index '10'"
            $output[1] | Should -Match "Available categories:"
        }

        It 'should prompt to categorize when switching from "uncategorized"' {
            punch in "uncategorized" | Out-Null
            Start-Sleep -Milliseconds 10
            
            Mock _PromptForCategory { return 'Cat A' } -ModuleName 'Punch'
            
            punch switch "Cat B" | Out-Null
            # The output from the mocked function won't be captured here, so we check the result in the XML
            
            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $firstEntry = $punchXml.punch.entries.entry[0]
            $firstEntry.category | Should -Be "Cat A"
        }

        It 'should leave as uncategorized if user provides no input at prompt' {
            punch in "uncategorized" | Out-Null
            Start-Sleep -Milliseconds 10
            
            Mock _PromptForCategory { return $null } -ModuleName 'Punch'
            
            punch switch "Cat B" | Out-Null

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $firstEntry = $punchXml.punch.entries.entry[0]
            $firstEntry.category | Should -Be "uncategorized"
        }
    }

    Context 'Data Management' {
        It 'should reset the data when using "punch reset"' {
            punch in | Out-Null
            punch reset -y | Out-Null
            $status = punch status
            $status[0] | Should -Match 'Punched out'
            $status[1] | Should -Contain 'No entries.'
        }

        It 'should return the path to the data file' {
            $path = punch data path
            $expectedPath = Join-Path $script:punchDir 'punch.xml'
            $path | Should -Be $expectedPath
        }
    }

    Context 'Punch Out Prompt' {
        BeforeEach {
            punch category add "Cat A" 10 | Out-Null
            punch category add "Cat B" 10 | Out-Null
        }

        It 'should not prompt for category when punching out of a categorized session' {
            punch in "Cat A" | Out-Null
            Start-Sleep -Milliseconds 10

            # We assert that the mock is not called
            Mock _PromptForCategory { throw "Should not be called" } -ModuleName 'Punch'
            
            punch out | Out-Null

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $lastEntry = $punchXml.punch.entries.LastChild
            $lastEntry.category | Should -Be "Cat A"
        }

        It 'should prompt for category when punching out of an uncategorized session' {
            punch in "uncategorized" | Out-Null
            Start-Sleep -Milliseconds 10

            Mock _PromptForCategory { return 'Cat B' } -ModuleName 'Punch'
            
            punch out | Out-Null

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $lastEntry = $punchXml.punch.entries.LastChild
            $lastEntry.category | Should -Be "Cat B"
        }

        It 'should leave category as uncategorized if user provides no input' {
            punch in "uncategorized" | Out-Null
            Start-Sleep -Milliseconds 10

            Mock _PromptForCategory { return $null } -ModuleName 'Punch'
            
            punch out | Out-Null

            $punchFile = punch data path
            $punchXml = [xml](Get-Content $punchFile)
            $lastEntry = $punchXml.punch.entries.LastChild
            $lastEntry.category | Should -Be "uncategorized"
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
