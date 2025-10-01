. $PSScriptRoot\TestSetup.ps1

Describe 'Punch In Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Punch In' {
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
}