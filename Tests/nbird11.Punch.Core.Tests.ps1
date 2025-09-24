# Import the module being tested
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'nbird11.Punch.psm1'
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
    Remove-Module nbird11.Punch
}

Describe 'nbird11.Punch Core Functionality' {
    
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
    }

    Context 'Break Functionality' {
        BeforeEach {
            punch in | Out-Null
        }

        It 'should allow starting a break' {
            $output = punch break start
            $output | Should -Match 'Break started at'
            $status = punch status
            $status[0] | Should -Match 'On break'
        }

        It 'should not allow starting a break when already on break' {
            punch break start | Out-Null
            $output = punch break start
            $output | Should -Contain 'Already on a break.'
        }

        It 'should allow ending a break' {
            punch break start | Out-Null
            Start-Sleep -Milliseconds 10
            $output = punch break end
            $output | Should -Match 'Break ended at'
            $status = punch status
            $status[0] | Should -Match 'Punched in'
        }

        It 'should not allow punching out while on break' {
            punch break start | Out-Null
            $output = punch out
            $output | Should -Contain 'Still on break'
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
}
