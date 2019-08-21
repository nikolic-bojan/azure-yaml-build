

$global:buildQueueVariable = ""
$global:buildSeparator = ";"

Function AppendQueueVariable([string]$folderName)
{
	$folderNameWithSeparator = -join($folderName, $global:buildSeparator)

	if ($global:buildQueueVariable -notmatch $folderNameWithSeparator)
	{
        $global:buildQueueVariable = -join($global:buildQueueVariable, $folderNameWithSeparator)
	}
}

if ($env:buildQueueInit)
{
	Write-Host "Build Queue Init: $env:buildQueueInit"
	Write-Host "##vso[task.setvariable variable=buildQueue;isOutput=true]$env:buildQueueInit"
	exit 0
}

# Get all files that were changed
$editedFiles = git diff HEAD HEAD~ --name-only

# Check each file that was changed and add that Service to Build Queue
$editedFiles | ForEach-Object {	
    Switch -Wildcard ($_ ) {		
        "service1/*" { 
			Write-Host "Service 1 changed"
			AppendQueueVariable "service1"
		}
        "service2/*" { 
			Write-Host "Service 2 changed" 
			AppendQueueVariable "service2"
		}
		"service3/*" { 
			Write-Host "Service 3 changed" 
			AppendQueueVariable "service3"
			AppendQueueVariable "service2"
		}
        # The rest of your path filters
    }
}

Write-Host "Build Queue: $global:buildQueueVariable"
Write-Host "##vso[task.setvariable variable=buildQueue;isOutput=true]$global:buildQueueVariable"