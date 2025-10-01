. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Out Functionality' {

    BeforeEach {
        Reset-PunchData
    }

    Context 'Punch Out' {
        It 'should allow punching out after punching in' {
            punch in | Out-Null
            # We need a small delay to ensure there's a measurable time difference
            Start-Sleep -Milliseconds 10
            $output = punch out
            $output[0] | Should -Match 'Punched out at'
            $output[1] | Should -Match 'Last entry: \d{2}:\d{2}:\d{2}'
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
}