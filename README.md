[![Build Status](https://dev.azure.com/bojannikolic/yaml-build/_apis/build/status/nikolic-bojan.azure-yaml-build?branchName=master)](https://dev.azure.com/bojannikolic/yaml-build/_build/latest?definitionId=3&branchName=master)

# Azure DevOps YAML build for Mono Repository with multiple projects 

I will show you how I setup the YAML build in Azure DevOps for our Mono repository that contains multiple (20-ish) Services that are part of one Product.

> TL;DR; 
> Visit Git repository https://github.com/nikolic-bojan/azure-yaml-build
> It contains a working sample of YAML build for 3 services.

# Move to Mono repository
We have ~20 different Services (REST APIs), with a Gateway in front of them that routes calls to those services and orchestrations. You can call it micro-service architecture or not, but let's not get into that discussion now.

It was organized like this:
- Each Service had it's own repository
- Each Model NuGet (that contained shared request/response classes) for inter-service communication had it's repository

So, around 40 repositories and same number of Build definitions that were created and maintained. Plus, we did GitFlow as a small team. Nightmare!

When I finally got time, I know where we should go - Mono repository. I do not want to convince you it is for everybody, but if you are already (or on your way) there and need some help, keep on reading.

This is the `short` story how it was done.


## New repository
Creating a new repository is easy, but what about moving the code? Copy/paste - no way, we lose all the Git history. I found a few good articles online and with a bit help of Sourcetree (I am not Git console guy. Yet) and Git console (you can't avoid it), here are the steps I did **for each** project. Of course, make sure you are in the new repository's master branch:

1. Add Remote repository in Sourcetree pointing to your **old** project's repository and call it **repo**
2. Execute following GIT command `git merge repo/master --allow-unrelated-histories`. Of course, chose to move from master or any other old repo's branch.
Very important to use allow-unrelated-histories or it will not work.
3. Create in new repository a folder for your Service. You do not want to have all projects in same folder, right?
4. Move all files to a new folder.
5. Resolve conflicts, if any.
6. Push changes.
7. Lock old repository's branches to prevent some developer to continue working there.

If you have some feature branches (not all new code is on master), you can create new branch on a New Repository and just copy files from Old repository to that Service's folder. Git will figure that out like changes and you can push them. You will loose some commit history on that feature branch, but you can live with that.

This way I moved all my Services to a new repository, but after these 7 steps I also did few more related to Build definition for each Service. Do not rush into moving all at once. Move Service by Service.


## Build definition changes
Everything is now in the same repository. Also, all Services are in their new folders. Now we come to the problem - we need to change our build definition, depending on how it was made, of course.

What I had to do is next:
- Allowed trigger only on **master** and only for a folder where Service is. I just wanted to see builds work with the New Repository.
- Change all the steps/variables that point to *.sln or *.csproj files to follow new folder structure in order to build just what you want, not the whole darn thing.
- Try the build. Build Service, push it on some lower environment and hit it with regression tests. All needs to be in perfect order.
- Now you can migrate next Service.


## Model NuGets
Remember I was mentioning those? Those were simple .NET Standard 2.0 projects that contain just POCO models. I decided to move them to a Service's solution as they represent the **interface** for that Service.

All other Services that need them also (that call that Service) have them also referenced directly. It is the same Repository!

I wasn't trying there to keep the history. Copy/paste did the thing. But it is possible as we did with the Services.

Regressions were all green after this. That was the most important.



# One Build to rule them all
I wasn't very happy with having build triggers only on **master**. I could have put triggers on all branches, but I wanted more control. 

What if I wanted to build 2 or 3 Services when code in one changes (remember those Model projects?). I know, that is not clean separation, but after all, the point of having things in one repository is because they are - connected.

I wasn't keen on maintaining 20+ builds also. I wanted control in one place. 


## PowerShell + YAML to the resque!
It would be very nasty to setup CI through UI to know when to trigger and which Services to build. Yes, I said "Services", not Service. That is due to how I want things to work. If I make changes to several Services at once, I want all of them build. Sometimes if I make change to 1 Service, I want 2 of them to build.

Good thing is that all our Builds had same steps and we parameterized one build, so it can be easily cloned and specialized for particular Service using Variables.

First, create a new Build definition. You need to select YAML build. There you should enter following:

```yaml
trigger:
  branches:
    include:
    - '*'

resources:
- repo: self

jobs:
- job: Build_Queue
  steps:  
  - task: powershell@2
    name: setBuildQueue
    inputs:
      targetType: filePath
      filePath: ./build/get-service-queue.ps1
    displayName: 'Get Service Build Queue'    

- template: build-template.yml
  parameters:
    name: Service_01
    solutionFolder: 'service1'
    projectFile: '/service1.api/service1.api.csproj'

- template: build-template.yml
  parameters:
    name: Service_02
    solutionFolder: 'service2'
    projectFile: '/service2.api/service2.api.csproj'

- template: build-template.yml
  parameters:
    name: Service_03
    solutionFolder: 'service3'
    projectFile: '/service3.api/service3.api.csproj'

# Add more template jobs with parameters for other Services
```
OK, what I just did was:
1. Set the trigger on **all** branches.
2. Set repository to itself.
3. Created a PowerShell Job to get list of services to build.
4. Defined to run build template for each of my services (here just 3)

What will happen is that a PowerShell Script will determine which services should be built (custom logic) and output that as a list of semi-colon (;) separated Service folder names (not perfect, still polishing that one, my PowerShell is beginner level).

```powershell
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

if ($env:BUILDQUEUEINIT)
{
	Write-Host "Build Queue Init: $env:BUILDQUEUEINIT"
	Write-Host "##vso[task.setvariable variable=buildQueue;isOutput=true]$env:BUILDQUEUEINIT"
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
```
This is the logic:
1. I first check if anyone set **buildQueueInit** variable on build. I want to have option to set which services to build manually. If yes, I set **buildQueue** output (very important to be **output**) variable and skip the part with GIT diff.
2. If **buildQueueInit** was not set, I will do GIT diff, pickup files that were changed in last commit and figure out in which folders they are, so I can make a list of changed Services. Then I set **buildQueue** output variable with that value.

That GIT diff magic was picked up from Taul's answer and gets all files that were changed in last commit
https://stackoverflow.com/questions/53227343/triggering-azure-devops-builds-based-on-changes-to-sub-folders/53837840#53837840

## Build template
OK, last piece of the puzzle - Build template. I grabbed it by clicking on **View YAML** button of my existing build pipeline. Then I had to adjust it a bit. Here is how the first part of it looks (I just kept the Restore task for sample):
```yaml
parameters:
    name: '--'
    BuildConfiguration: 'Release'
    BuildPlatform: 'any cpu'
    solutionFolder: '--'
    projectFile: '/Api/Api.csproj'
    RestoreBuildProjects: '$(project.file)'    

jobs:
- job: ${{ parameters.name }}
  dependsOn: Build_Queue
  continueOnError: true
  variables:
    BuildConfiguration: ${{ parameters.BuildConfiguration }}
    BuildPlatform: ${{ parameters.BuildPlatform }}
    project.file: ${{ parameters.solutionFolder }}${{ parameters.projectFile }}
    Parameters.RestoreBuildProjects: ${{ parameters.RestoreBuildProjects }}
    myBuildQueue: $[ dependencies.Build_Queue.outputs['setBuildQueue.buildQueue'] ]
  condition: and(succeeded(), contains(dependencies.Build_Queue.outputs['setBuildQueue.buildQueue'], '${{ parameters.solutionFolder }}'))
  steps:
  - task: powershell@2
    inputs:
      targetType: inline
      script: 'Write-Host "Build Queue init: $(buildQueueInit) and from parameters $(myBuildQueue)"'

  - task: DotNetCoreCLI@2
    displayName: Restore
    inputs:
      command: restore
      projects: '$(Parameters.RestoreBuildProjects)'
```
Parameters are input parameters for the template. You remember we used **name** and **solutionFolder**?

Variables are for the Job and we read some of the input parameters in order to set them up.

Important here is **myBuildQueue** that contains entire list of all Services that should be built.
Even more important is the **condition** that checks if this entire Job should be executed. It checks if **solutionFolder** is in that semi-colon separated list that was populated in that crazy PowerShell script.

If it matches - Tasks in this Job will be ran. If not, it will just skip this entire Job.

In the PowerShell script, you can define that Services have dependencies, so you can say that if there is a change in Service 3, you should also build Service 2. That is what I did for Service 3 in this part of the script.
```powershell
Switch -Wildcard ($_ ) {
        "service3/*" { 
			Write-Host "Service 3 changed" 
			AppendQueueVariable "service3"
			AppendQueueVariable "service2"
		}
```

That is it! You can setup some interesting rules within the scripts in order to define what should be built on which change.

Now, you have just one Build to maintain!



# Queue build manually with a list of Services to buils
Remember when I mentioned **buildQueueInit** and you setup a Variable. Here are the steps to do it in Azure DevOps:
1. Go to your Pipeline -> Builds and select your YAML build
2. Click to Edit build and you will see a button Variables
3. Click on it and then to + to create new one
4. Set it's name to **buildQueueInit** and check **Let users override this value when running this pipeline** box


Now, when you manually queue a build, you can add a value in it, e.g. **service1;service2;** and Service 1 and 2 will be built for you.

One scenario where you do want this is maybe for some Release branches, where you do not want stuff to be auto-triggered based on just last commit. You want to decide "those Services will be released after this Sprint".

Thanks for reading!
