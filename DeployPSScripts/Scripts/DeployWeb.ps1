<#
    Automates the deployment of a MERN stack web application.
#>
param(
    [switch]$Debug, # Enable debug output
    [string]$RepoPath = $null, # Path to the repository
    [switch]$Dev, # Run in development mode
    [switch]$CI                 # Indicate CI environment
)

# Import helper module
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\DeployHelper.psm1")

# Configure debug preference if Debug switch is provided
if ($Debug) { $DebugPreference = 'Continue' }

# Display current directory for debugging purposes
Write-Debug "Current Directory: $pwd"

# Validate required parameters
if ($null -eq $RepoPath) {
    Write-Host "Please provide the path to the web project directory." -ForegroundColor Red
    Write-Host "Example: .\DeployWeb.ps1 -RepoPath 'C:\Projects\Sample-MERN-Project'" -ForegroundColor Red
    exit 1
}

try {
    # Find project folders using helper function
    $projectFolders = Find-ProjectFolders -StartPath $RepoPath

    # Extract discovered paths
    $RepoPath = $projectFolders.ProjectRoot
    $frontendPath = $projectFolders.FrontendPath
    $backendPath = $projectFolders.BackendPath

    # Save current location to restore later
    Push-Location -Path $RepoPath

    # Node.js path setup (only in local environment)
    if (-not $CI) {
        $nodePath = "C:\Program Files\nodejs"
        if (-not ($env:Path -split ";" -contains $nodePath)) {
            # Add Node.js to PATH if not already present
            $env:Path += ";$nodePath"
            Write-Debug "Environment path: $env:Path"
            Write-Host "Added Node.js to the PATH for this session."
        }
    }

    # Step 1: Check if MongoDB is running (skip in CI environment)
    if (-not $CI) {
        Write-Host "Checking if MongoDB is running..."
        $mongoProcess = Get-Process -Name "mongod" -ErrorAction SilentlyContinue
        Write-Debug "MongoDB process: $mongoProcess"

        if ($mongoProcess) {
            Write-Host "MongoDB is already running."
        }
        else {
            # Create MongoDB data directory if it doesn't exist
            $mongoDbPath = "\mongodb\data"
            if (-not (Test-Path $mongoDbPath)) {
                New-Item -Path $mongoDbPath -ItemType Directory -Force | Out-Null
                Write-Host "Created MongoDB data directory: $mongoDbPath"
            }
            
            # Start MongoDB service
            Write-Host "Starting MongoDB..."
            Start-Process -FilePath "mongod" -ArgumentList "--dbpath=$mongoDbPath" -NoNewWindow
            Start-Sleep -Seconds 5  # Wait for MongoDB to start
        }
    }

    # Step 2: Build the React app
    Write-Host "Building the React app..."
    Set-Location -Path $frontendPath
    Write-Debug "Current Directory: $pwd"
    
    # Install dependencies and build
    npm install
    npm run build

    # Only start servers in local environment (not in CI mode)
    if (-not $CI) {
        # Step 3: Start the backend server
        Write-Host "Starting the backend server..."
        Set-Location -Path $backendPath
        Write-Debug "Current Directory: $pwd"
        npm install

        # Dynamic server file detection - looks for common Node.js entry point files
        $serverFiles = @("server.js", "app.js", "index.js", "main.js")
        $serverFile = $serverFiles | Where-Object { Test-Path $_ } | Select-Object -First 1

        # Validate that a server entry file was found
        if (-not $serverFile) {
            throw "No server entry file found (tried: $($serverFiles -join ', '))"
        }

        Write-Host "Launching backend using: $serverFile" -ForegroundColor Green
        Start-Process -FilePath "node" -ArgumentList $serverFile -NoNewWindow -PassThru

        # Step 4: Start the frontend development server
        Write-Host "Starting the frontend server..."
        Set-Location -Path $frontendPath
        Write-Debug "Current Directory: $pwd"
        
        # Select npm script based on Dev switch
        $startCommand = "start"
        if ($Dev) {
            Write-Host "Development mode enabled. Using 'npm run dev'."
            $startCommand = "dev"
        }
        else {
            Write-Host "Production mode enabled. Using 'npm start'."
            $startCommand = "start"
        }
        
        # Start the frontend server
        Write-Host "Starting frontend with 'npm run $startCommand'..."
        npm run $startCommand

        Write-Host "Deployment complete!"
    }
    else {
        Write-Host "Skipping Backend Deployment in CI mode."
    }
}
catch {
    # Handle errors
    Write-Error "An error occurred during deployment: $_"
    exit 1
}
finally {
    # Restore original location
    Pop-Location
    Write-Host "Script execution finished."
}