. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Switch Functionality' {

    BeforeEach {
        Reset-PunchData
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
}