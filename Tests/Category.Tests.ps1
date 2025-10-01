. $PSScriptRoot\TestSetup.ps1

Describe 'Punch Category Functionality' {
    
    BeforeEach {
        Reset-PunchData
    }

    Context 'Category Management' {
        It 'should start with no categories defined' {
            $output = punch category list
            $output | Should -Contain 'No categories defined.'
        }

        It 'should allow adding a new category' {
            $output = punch category add "Test Category" 5.5
            $output | Should -Match "Category 'Test Category' added with a weekly allotment of 5.5 hours."
            
            $listOutput = punch category list
            $listOutput[1] | Should -Match "\{1\} Test Category \(5.5 hours/week\)"
        }

        It 'should allow removing an existing category' {
            punch category add "Temp Category" 8 | Out-Null
            $removeOutput = punch category remove "Temp Category"
            $removeOutput | Should -Match "Category 'Temp Category' removed."

            $listOutput = punch category list
            $listOutput | Should -Contain 'No categories defined.'
        }

        It 'should handle removing a non-existent category gracefully' {
            $output = punch category remove "NonExistent"
            $output | Should -Match "Category 'NonExistent' not found."
        }

        It 'should list multiple categories correctly' {
            punch category add "Cat 1" 10 | Out-Null
            punch category add "Cat 2" 2.5 | Out-Null

            $listOutput = punch category list
            $listOutput | Should -HaveCount 3 # "Defined Categories:" + 2 category lines
            $listOutput[1] | Should -Match "\{1\} Cat 1 \(10 hours/week\)"
            $listOutput[2] | Should -Match "\{2\} Cat 2 \(2.5 hours/week\)"
        }

        It 'should show usage for incomplete add command' {
            $output = punch category add "MissingHours"
            $output | Should -Match "Usage: punch category add <name> <weeklyHours>"
        }

        It 'should show usage for incomplete remove command' {
            $output = punch category remove
            $output | Should -Match "Usage: punch category remove <name>"
        }

        It 'should not add a category that already exists' {
            punch category add "Duplicate" 4 | Out-Null
            $output = punch category add "Duplicate" 6
            $output | Should -Match "Category 'Duplicate' already exists."
        }
    }
}
