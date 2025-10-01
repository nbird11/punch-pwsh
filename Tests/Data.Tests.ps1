. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Data Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Data Management' {
        It 'should return the path to the data file' {
            $path = punch data path
            $expectedPath = Join-Path $script:punchDir 'punch.xml'
            $path | Should -Be $expectedPath
        }
    }
}