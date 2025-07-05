# nbird11.Punch

A simple command-line punch clock for PowerShell.

## Installation

1. Clone this repository or download the files.
2. Place the `nbird11.Punch` directory in one of your PowerShell module paths. You can find your module paths by running `$env:PSModulePath` in PowerShell. A common location is `$env:USERPROFILE\Documents\PowerShell\Modules`.
3. (Optional): Import the module into your PowerShell session:

    ```powershell
    Import-Module nbird11.Punch
    ```

    > [!NOTE]
    > If you've placed the module in a standard PowerShell module path PowerShell will automatically load the module the first time you run a command from it.

## Usage

The primary command is `punch`.

### Punch In

To start your work session, punch in.

```powershell
punch in
```

### Punch Out

To end your work session, punch out. This will display the total time worked for the session.

```powershell
punch out
```

### Breaks

You can start and end breaks during a work session.

#### Start a break

```powershell
punch break start
```

#### End a break

```powershell
punch break end
```

### Check Status

Check your current status (punched in, punched out, or on break) and the time elapsed in your current session.

```powershell
punch status
```

### View Data

The punch data is stored in an XML file.

#### Show XML content

```powershell
punch xml
```

#### Show path to data file

```powershell
punch xml --path
```

### Reset Data

This will erase all your punch clock data. You will be prompted for confirmation.

```powershell
punch reset
```

To skip the confirmation prompt:

```powershell
punch reset -y
```

### Help

To see the usage information:

```powershell
punch -h
# or
punch --help
```

## Data File

Your punch clock data is stored in `punch.xml` located in `%APPDATA%\punch`.
