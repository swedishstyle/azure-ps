<#
.HISTORY
    01/06/2021 - 1.0 - Initial release - David Alzamendi - https://techtalkcorner.com
.SYNOPSIS
    Create Azure Resources
.DESCRIPTION
    This script creates a selection of Azure resources using the following cmdlets
    Pre-requirements:
                    AzModule ----> Install-Module -Name Az.Synapse
                    Be connected to Azure ----> Connect-AzAccount 
    Module descriptions are in https://docs.microsoft.com/en-us/powershell/module/az.synapse/new-azsynapseworkspace?view=azps-4.4.0
.EXAMPLE
    SQL Server
        Create-AzResource -ResourceGroupName "MyRG" -Name "MySQLServer" -ResourceType "SQLServer" 
        Create-AzResource -ResourceGroupName "MyRG" -Name "MySQLServer" -ResourceType "SQLServer"      
            -DefaultTags -TagEnvironment "MyEnv" -TagCostCenter "MyCost" -TagAppName "MyApp" -TagOwner "Me" -TagImpact "High"


    Synapse Pool
        Create-AzResource -ResourceGroupName "MyRG" -Name "MyPool" -ResourceType "SynapsePool" -WorkspaceName "MyWorkspace" -PerformanceLevel "S0"
        Create-AzResource -ResourceGroupName "MyRG" -Name "MyPool" -ResourceType "SynapsePool" -WorkspaceName "MyWorkspace" -PerformanceLevel "S0" 
            -DefaultTags -TagEnvironment "MyEnv" -TagCostCenter "MyCost" -TagAppName "MyApp" -TagOwner "Me" -TagImpact "High"

    Data Lake
        Create-AzResource -ResourceGroupName "MyRG" -Name "MyDataLake" -ResourceType "DataLake" -Location "AustraliaEast" -SKUName "Hot"
        Create-AzResource -ResourceGroupName "MyRG" -Name "MyDataLake" -ResourceType "DataLake" -Location "AustraliaEast" -SKUName "Hot"
            -DefaultTags -TagEnvironment "MyEnv" -TagCostCenter "MyCost" -TagAppName "MyApp" -TagOwner "Me" -TagImpact "High"

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [string]$Location,

    [Parameter(Mandatory=$true)]
    [ValidateSet('SQLServer', 'SynapsePool', 'DataLake')]
    [string]$ResourceType,

    #Tags
    [switch]$DefaultTags,

    [string]$TagEnvironment,
    [string]$TagCostCenter,

    [string]$TagAppName = "",
    [string]$TagOwner = "",
    [string]$TagImpact = ""
)
 
DynamicParam {
    # Define parameter attributes
    $paramAttributes = New-Object -Type System.Management.Automation.ParameterAttribute
    $paramAttributes.Mandatory = $true

    # Create collection of the attributes
    $ParamAttributesCollect = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
    $ParamAttributesCollect.Add($paramAttributes)

    $ParamDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
    switch ($ResourceType) {
        'SQLServer' {
            # Create parameter with name, type, and attributes
            $SQLParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("AdminSqlLogin", [string], $ParamAttributesCollect)
            $SQLParam2 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("AdminSqlPwd", [string], $ParamAttributesCollect)
    
            $ParamDictionary.Add("AdminSqlLogin", $SQLParam1)
            $ParamDictionary.Add("AdminSqlPwd", $SQLParam2)
            return $paramDictionary
        }
        'SynapsePool' {
            # Create parameter with name, type, and attributes
            $SynapseParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("WorkspaceName", [string], $ParamAttributesCollect)
            $SynapseParam2 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("PerformanceLevel", [string], $ParamAttributesCollect)

            # Add parameter to parameter dictionary and return the object
            #$ParamDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
            $ParamDictionary.Add("WorkspaceName", $SynapseParam1)
            $ParamDictionary.Add("PerformanceLevel", $SynapseParam2)
            return $ParamDictionary
        }
        'DataLake' {
            # Create parameter with name, type, and attributes
            $DLParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("SKUName", [string], $ParamAttributesCollect)
    
            # Add parameter to parameter dictionary and return the object
            #$ParamDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
            $ParamDictionary.Add("SKUName", $DLParam1)
            return $ParamDictionary
        }
        default {
            Write-Error "Something is wrong"
        }
    }
}

Begin {
    Write-Output "Starting creation of $ResourceType $Name on $(Get-Date)"

    $AllTags = @{
        "CostCenter" = $TagCostCenter.Trim()
        "Environment" = $TagEnvironment.Trim()
    }

    if($DefaultTags.IsPresent) {
        Write-Output "Adding extra tags"

        #Check if values have been defined
        if(($TagEnvironment -eq "") -or  ($TagCostCenter -eq "")) {
            throw "Values for the default tags TagEnvironment and TagCostCenter need to be defined"
        }

        #Get User Account
        $TagCreatedBy = Get-AzContext | Select-Object Account | Format-Table -HideTableHeaders | Out-String
            
        #Define tags
        $AllTags += @{
            "CreatedBy" = $TagCreatedBy.Trim()
            "AppName" = $TagAppName.Trim()
            "Owner" = $TagOwner.Trim()
            "Impact" = $TagImpact.Trim()
        }
    }

    $AzureResourceParams = @{
        "ResourceGroupName" = $ResourceGroupName
        "Name" = $Name
        "Location" = $Location
        "Tags" = $AllTags
    }

    switch($ResourceType) {
        'SQLServer' {
            $AzureResourceParams += @{
                #Have to use this style with dynamic parameters
                "AdminSQLLogin" = $PSBoundParameters['AdminSQLLogin']
                "AdminSqlPwd" = $PSBoundParameters['AdminSqlPwd']
            }
        }
        'SynapsePool' {
            $AzureResourceParams += @{
                "WorkspaceName" = $PSBoundParameters['WorkspaceName']
                "PerformanceLevel" = $PSBoundParameters['PerformanceLevel']
            }
        }
        'DataLake' {
            $AzureResourceParams += @{
                "SKUName" = $PSBoundParameters['SKUName']
            }
        }
        default {
            Write-Error "WTF"
        }
    }
}

Process {
    switch($ResourceType) {
        'SQLServer' {
            #Check if exists
            $GetExisting = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -Name $Name

            if($GetExisting) {
                Throw "$ResourceType $Name already exists"
            } else {
                New-AzSqlServer @AzureResourceParams
            }
        }
        'SynapsePool' {
            #Check if exists
            $GetExisting = Get-AzSynapseSqlPool -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Name $Name

            if($GetExisting) {
                Throw "$ResourceType $Name already exists"
            } else {
                New-AzSynapseSqlPool @AzureResourceParams
            }
        }
        'DataLake' {
            #Check if exists
            $GetExisting = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $Name

            if($GetExisting) {
                Throw "$ResourceType $Name already exists"
            } else {
                New-AzStorageAccount @AzureResourceParams
            }
        }
        default {
            Write-Error "WTF"
        }
    }
    
} 

End {
    Write-Output "Finished on $(Get-Date)"
}