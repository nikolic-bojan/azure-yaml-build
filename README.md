[![Build Status](https://dev.azure.com/bojannikolic/yaml-build/_apis/build/status/nikolic-bojan.azure-yaml-build?branchName=master)](https://dev.azure.com/bojannikolic/yaml-build/_build/latest?definitionId=3&branchName=master)

# Introduction 
Azure DevOps YAML Build Pipeline for Mono repository with multiple solutions (Services).

This is a sample of how can you put several (or many) of your projects/services located in a Floder in one Mono repository and get a better control over the build process. Idea is that a change within one Folder will trigger just builds of specific projects.

You are in control of how it will work! You can say that change in one Floder doesn't trigger a thing or it triggers several builds.
That part is located in build/get-service-queue.ps1 file.

For a detailed story on this solution, please read following article I wrote.

https://dev.to/nikolicbojan/azure-devops-yaml-build-for-mono-repository-with-multiple-projects-146g
