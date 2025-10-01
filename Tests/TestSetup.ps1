# Common test setup and utilities for Punch module tests

# Import the module being tested
$modulePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Punch.psm1'
Import-Module -Name $modulePath -Force

BeforeAll {
    # Create a temporary directory for test data to avoid interfering with real user data
    $script:tempDir = New-Item -Path (Join-Path $env:TEMP (New-Guid)) -ItemType Directory
    $script:punchDir = New-Item -Path (Join-Path $script:tempDir 'punch') -ItemType Directory -ErrorAction SilentlyContinue
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

function global:Reset-PunchData {
    $punchFile = Join-Path $env:APPDATA 'punch\punch.xml'
    $xml = @'
<punch>
    <entries />
    <categories />
</punch>
'@
    Set-Content -Path $punchFile -Value $xml
}
