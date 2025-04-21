<#
Helper Module for MERN Stack Deployment Scripts
#>

# Function to find project folders based on common naming conventions
function Find-ProjectFolders {
    param(
        [string]$StartPath
    )

    # Common frontend folder names (order indicates priority)
    $frontendNames = @('frontend', 'client', 'web', 'app', 'ui')
    
    # Common backend folder names (order indicates priority)
    $backendNames = @('backend', 'server', 'api', 'service')

    # Find first matching frontend folder by searching recursively
    $frontendPath = $frontendNames | ForEach-Object {
        Get-ChildItem -Path $StartPath -Directory -Recurse -Filter $_ -ErrorAction SilentlyContinue | 
        Select-Object -First 1 -ExpandProperty FullName
    } | Where-Object { $_ } | Select-Object -First 1

    # Find first matching backend folder by searching recursively
    $backendPath = $backendNames | ForEach-Object {
        Get-ChildItem -Path $StartPath -Directory -Recurse -Filter $_ -ErrorAction SilentlyContinue | 
        Select-Object -First 1 -ExpandProperty FullName
    } | Where-Object { $_ } | Select-Object -First 1

    # Validate that both folders were found
    if (-not $frontendPath) {
        Write-Host "Could not find frontend folder (tried: $($frontendNames -join ', '))" -ForegroundColor Red
        exit 1
    }

    if (-not $backendPath) {
        Write-Host "Could not find backend folder (tried: $($backendNames -join ', '))" -ForegroundColor Red
        exit 1
    }

    # Output discovered paths
    Write-Host "Found frontend at: $frontendPath" -ForegroundColor Green
    Write-Host "Found backend at: $backendPath" -ForegroundColor Green

    # Return paths as a hashtable
    return @{
        FrontendPath = $frontendPath
        BackendPath  = $backendPath
        ProjectRoot  = Split-Path $frontendPath -Parent  # Assume common parent directory
    }
}

# Function to handle Git operations for GitHub Actions setup
function Push-ToGitHub {
    param(
        [string]$BranchName,
        [string]$CommitMessage,
        [string]$RelativeDeployScriptPath,
        [string]$RelativeModulePath
    )

    try {
        # Check if the workflow file exists and ensure it's tracked by Git
        $workflowFilePath = ".github/workflows/deploy$BranchName.yml"
        if (Test-Path $workflowFilePath) {
            $gitStatus = git status --porcelain $workflowFilePath
            git add -f $workflowFilePath  # Force add to ensure it's tracked
        }

        git add -f $RelativeDeployScriptPath  # Force add to ensure it's tracked
        git add -f $RelativeModulePath

        # Commit changes with the provided message
        git commit -m $CommitMessage

        # Push to repository
        git push origin $BranchName

        Write-Host "Successfully pushed workflow to repository, branch $BranchName" -ForegroundColor Green
    }
    catch {
        Write-Host "Error during git push: $_" -ForegroundColor Red
        exit 1
    }
}

# Export functions to make them available when the module is imported
Export-ModuleMember -Function Find-ProjectFolders, Push-ToGitHub