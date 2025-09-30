<# nwi.ps1 - New Work Item #>

enum WorkItemType {
  Bug
  UserStory
}

<#
Get latest number ({BG|US}-XXXX)

Checks both `backlog` and `closed` directories.
#>
function _Get-LatestOfType {
  param(
    [Parameter(Mandatory)]
    [WorkItemType]$type
  )

  $prefix = switch ($type) {
    Bug { "BG" }
    UserStory { "US" }
    default { throw "unreachable" }
  }

  $numBacklog = Get-ChildItem -Path $script:backlogDir -Filter "$prefix-*.md" | ForEach-Object {
    if ($_.BaseName -match "^$prefix-(\d+)$") {
      [int]$matches[1]
    }
  } | Sort-Object -Descending | Select-Object -First 1
  if (-not $numBacklog) {
    $numBacklog = 0
  }
  $numClosed = Get-ChildItem -Path $script:closedDir -Filter "$prefix-*.md" | ForEach-Object {
    if ($_.BaseName -match "^$prefix-(\d+)$") {
      [int]$matches[1]
    }
  } | Sort-Object -Descending | Select-Object -First 1
  if (-not $numClosed) {
    $numClosed = 0
  }
  $num = [math]::Max($numBacklog, $numClosed) + 1
  return "$prefix-$('{0:D4}' -f $num)"
}

<#
Create a new work item of the specified type.
#>
function New-WorkItem {
  param(
    [Parameter(Mandatory)]
    [WorkItemType]$type
  )

  $script:wiDir = Join-Path -Path $PSScriptRoot -ChildPath "work-items"
  if (-not (Test-Path -Path $script:wiDir)) {
    New-Item -Path $script:wiDir -ItemType Directory | Out-Null
  }

  $script:backlogDir = Join-Path -Path $script:wiDir -ChildPath "backlog"
  if (-not (Test-Path -Path $script:backlogDir)) {
    New-Item -Path $script:backlogDir -ItemType Directory | Out-Null
  }

  $script:closedDir = Join-Path -Path $script:wiDir -ChildPath "closed"
  if (-not (Test-Path -Path $script:closedDir)) {
    New-Item -Path $script:closedDir -ItemType Directory | Out-Null
  }

  switch ($type) {
    Bug {
      $bgNum = _Get-LatestOfType Bug

      # Write file
      New-Item -Path (Join-Path -Path $script:backlogDir -ChildPath "$($bgNum).md") -ItemType File -Value @"
# $($bgNum) - 

## Description


## Repro Steps

1. 

## Resolution


"@
    }
    UserStory {
      $usNum = _Get-LatestOfType UserStory

      # Write file
      New-Item -Path (Join-Path -Path $script:backlogDir -ChildPath "$($usNum).md") -ItemType File -Value @"
# $($usNum) - 

## Description



## Acceptance Criteria

* _Given_ <>
  _When_ <>
  _Then_ <>
  _And_ <>

"@
    }
    default {
      throw "unreachable"
    }
  }
}

New-WorkItem @args
