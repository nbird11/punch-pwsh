. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Reset Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Data Management' {
        It 'should reset the data when using "punch reset"' {
            punch in | Out-Null
            punch reset -y | Out-Null
            $status = punch status
            $status[0] | Should -Match 'Punched out'
            $status[1] | Should -Contain 'No entries.'
        }
    }
}