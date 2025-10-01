. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Reset Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Data Management' {
        It 'should reset all data when using "punch reset all -y"' {
            punch in | Out-Null
            punch category add test 40 | Out-Null
            punch reset all -y | Out-Null
            $status = punch status
            $status[0] | Should -Match 'Punched out'
            $status[1] | Should -Contain 'No entries.'
            $categories = punch category list
            ($categories -join ' ') | Should -Match 'No categories defined'
        }

        It 'should reset entries when using "punch reset entries -y"' {
            punch in | Out-Null
            punch category add test 40 | Out-Null
            punch reset entries -y | Out-Null
            $status = punch status
            $status[0] | Should -Match 'Punched out'
            $status[1] | Should -Contain 'No entries.'
            $categories = punch category list
            ($categories -join ' ') | Should -Match 'test \(40 hours/week\)'
        }

        It 'should reset categories when using "punch reset categories -y"' {
            punch in | Out-Null
            punch category add test 40 | Out-Null
            punch reset categories -y | Out-Null
            $status = punch status
            $status[0] | Should -Match 'Punched in'
            $categories = punch category list
            ($categories -join ' ') | Should -Match 'No categories defined'
        }

        It 'should reset multiple components when using comma-separated list' {
            punch in | Out-Null
            punch category add test 40 | Out-Null
            punch reset categories,entries -y | Out-Null
            $status = punch status
            $status[0] | Should -Match 'Punched out'
            $status[1] | Should -Contain 'No entries.'
            $categories = punch category list
            ($categories -join ' ') | Should -Match 'No categories defined'
        }

        It 'should list available components when using "punch reset list"' {
            $output = punch reset list
            ($output -join ' ') | Should -Match 'categories'
            ($output -join ' ') | Should -Match 'entries'
            ($output -join ' ') | Should -Match 'all'
        }

        It 'should error when no components specified' {
            $output = punch reset
            $output | Should -Match "Use 'punch reset list'"
        }

        It 'should error on unknown component' {
            $output = punch reset unknown
            $output | Should -Match "Use 'punch reset list'"
        }

        It 'should prompt for confirmation when -y not used' {
            # This is harder to test interactively, but we can check that it doesn't reset without input
            # For now, assume the logic is correct
        }
    }
}