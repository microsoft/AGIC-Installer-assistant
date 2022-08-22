# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.



#powershell function to list a virtual machine scale set's instances

function Get-AzureRmVmssInstance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$VMScaleSetName
    )
    $vmss = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSetName
    $vmss.Instances
}

#powershell function that asks for a value
[string[]]$ValidOptions = @("1","2")
function Get-Input
{
  param (
  [string]$Prompt
  )

    do {
      $value = Read-Host $Prompt
      if ($value -in $ValidOptions) {
        return $value
      }else{
        Write-Host "You must enter a valid value! " $ValidOptions -ForegroundColor red
      }

    } until (  $value -in $ValidOptions )
}

#powershell function that asks if the user wants to log in again
function loginagain {
    $loginagain = Read-Host "Do you want me to log you in to Azure ? (y/n)"
    if ($loginagain -eq "y") {
        Az Login
    }
    else {
        write-host "we will try to continue without logging in..."
    }
}

#function that returns the list of availabile aks clusters
function Get-AksClusters {
    $aksclusters = Get-AzureRmResource -ResourceType "Microsoft.ContainerService/ManagedClusters" -ResourceGroupName $resourcegroupname |  formartable -Property ResourceName,ResourceGroupName,Location,ResourceType
    return $aksclusters
}



function Get-AzureSubscriptions {

    $subscriptions = Get-AzureRmSubscription
    $subscriptions | Select-Object SubscriptionName, SubscriptionId, TenantId
    return $subscriptions
}



#function to show  the aks clusters in the subscription
#it has 2 parameters
#1. subscription id
#2. resource group name

function  Get-AksClusters  {
  $aksclusters =  Get-AzureRmResource | Where-Object ResourceType -eq "Microsoft.ContainerService/managedClusters" |  Select-Object  -Property Name, ResourceGroupName, Location, SubscriptionId
  return $aksclusters
}

function getaksclusters {


}
#function to return the PrincipalId property of an aks cluster
#it has 2 parameters
#1. subscription id
#2. resource group name
function  Get-AksClusterPrincipalId  {
     param  (
        [string]$subscriptionId,
        [string]$resourceGroupName,
        [string]$clusterName
    )
     $cluster  =  Get-AzResource  -ResourceType Microsoft.ContainerService/managedClusters -ResourceGroupName $resourceGroupName -Name $clusterName -SubscriptionId $subscriptionId
     $cluster.Properties.ServicePrincipalProfile.PrincipalId
}

function show-aksclusters {
    $aksclusters = az aks list --query "[].{Name:name,ResourceGroup:resourceGroup,Location:location,Version:kubernetesVersion}" -o table
    $aksclusters
}

function emptyLine() {
  Write-Host "                                                                 "
}
Clear-Host
#test in a new branch
#$LATEST_CHART_VERSION="1.5.2 "
#test
#$RUN = $true
$NUMBER_OF_ATTEMPTS_FOR_ASSIGNING_ROLES=1
$TIME_TO_WAIT_SECONDS=60
$GLOBAL_MC_RG_NODE_NAME=""
$GLOBAL_AKS_CLUSTER_NAME=""
$GLOBAL_NODE_AKS_RG=""
#$GLOBAL_AGW_IDENTITY_NAME=""
$GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID=""


function installAgic {
clear-host
write-host "VERY IMPORTANT: IF YOU WANT TO INSTALL THE HELM OPTION" -ForegroundColor Red
write-host "AND YOUR CLUSTER IS PRIVATE, YOU NEED TO ENSURE THIS  SCRIPT EXECUTION CONTEXT HAS LINE OF SIGHT TO THE CLUSTER"-ForegroundColor Red
Read-Host -Prompt '--> Finish the program if you are not sure if you have cluster visiblity (try kubectl get pods) '

#$loggedin = Read-Host -Prompt '--> Make sure you are logged in to azure!  Are you logged in? y/n '

$ValidOptions = @("y","n")
$loggedin=Get-Input("Do you want me to log you in to Azure? y/n ")
if ($loggedin -eq "y") {
  az login

}else{
  $loggedin="y"
  write-host "We will try to continue without logging in..."
}
Write-Host "Below are all the subscriptions you have access to "
az account list -o table

$SUBSCRIPTION_ID=Read-Host -Prompt '--> Paste the subscription selected. We will set this subscription as the active one '

Write-Host "The selected subscription id is: "$SUBSCRIPTION_ID
Write-Host "Setting the above subscription as active.."
az account set --subscription $SUBSCRIPTION_ID

Write-Host "Below you can see your availabile tenants (based on the logged user) " -ForegroundColor Cyan

az account tenant list -o table

do {
  $TENANT_ID = Read-Host -Prompt '--> Enter the Tenant id you want to operate with: '
  if ($TENANT_ID -eq "") {
    Write-Host "You need to select a Tenant id" -ForegroundColor Red
  }
} until ($TENANT_ID -ne "" )



if ($loggedin -eq "y") {
  write-host "Finding AKS clusters in this subscription ..." -ForegroundColor Cyan

  az aks list -o table



  do {
    $AKS_CLUSTER_NAME = Read-Host -Prompt '--> Enter the cluster name where you want AGIC installed: '
    if ($AKS_CLUSTER_NAME -eq "") {
      Write-Host "You need to select a cluster name" -ForegroundColor Red
    }
  } until ($AKS_CLUSTER_NAME -ne "" )

  $GLOBAL_AKS_CLUSTER_NAME = $AKS_CLUSTER_NAME # TO USE IT FOR OTHER PROGRAM OPTIONS

  Write-host "You have selected to install AGIC on the cluster: " $AKS_CLUSTER_NAME  -ForegroundColor Green
  Write-Host "Getting the resource group name for the cluster..."
  $NODE_AKS_RG=$(az aks list --query "[?contains(name, '$AKS_CLUSTER_NAME')].[resourceGroup]" --output tsv)
  $GLOBAL_NODE_AKS_RG=$NODE_AKS_RG # TO USE IT FOR OTHER PROGRAM OPTIONS
  Write-Host "This is the resource Group" $NODE_AKS_RG -ForegroundColor Green
  Write-host " "
  Write-host "Checking if the cluster has AGIC add-on enabled..."
  "addonProfiles.ingressApplicationGateway.enabled"
  $AGIC_ENABLED=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query addonProfiles.ingressApplicationGateway.enabled  -o tsv
  if ($AGIC_ENABLED -eq "true") {
    Write-host "This cluster has the AGIC add-on already enabled..."  -ForegroundColor red
    Write-host "Please, Disable the add-on. Exiting the program"  -ForegroundColor red
    Exit 333
  }else {Write-Host "The cluster does not have AGIC add-on enabled" -ForegroundColor Green }
    Write-Host "We are getting credentials to this cluster..."  -ForegroundColor cyan

#checking if the cluster has local accounts enabled

$AKS_LOCAL_ACCOUNTS_ENABLED=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query disableLocalAccounts  -o tsv
emptyLine
$ASK_TO_DISABLE_LOCAL_ACCOUNTS = $false
if ($AKS_LOCAL_ACCOUNTS_ENABLED -eq "false")
{
  write-host "This cluster has local accounts enabled so we connect through the local admin" -ForegroundColor Green
  az aks get-credentials --resource-group $NODE_AKS_RG --name $AKS_CLUSTER_NAME --admin
  $DECISION ="n" #to avoid the installation of local accountes in the next step

}else{


  write-host "This cluster has local accounts disabled " -ForegroundColor Green
  write-host "If your logged user does not have rights to operate the cluster (and the dependent services),  " -ForegroundColor Yellow
  write-host "The Helm installation might fail once you authenticate   " -ForegroundColor Yellow
  write-host "If you are not sure, enable local accounts. After the installation you can disable this manually   " -ForegroundColor Yellow
  $DECISION = Read-Host -Prompt '--> (RECOMMENDED OPTION y) Do you want to enable access to local accounts? y/n '
  if ($DECISION -eq "y") {
    write-host "Enabling local accounts to this cluster... " -ForegroundColor blue
    write-host "Warning, this process can take several minutes (up to 10) " -ForegroundColor Yellow
    az aks update -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --enable-local
    write-host "This cluster has NOW local accounts enabled so we connect through the local admin" -ForegroundColor Green
    az aks get-credentials --resource-group $NODE_AKS_RG --name $AKS_CLUSTER_NAME --admin
    $ASK_TO_DISABLE_LOCAL_ACCOUNTS = $true
  }else{
    write-host "This cluster has  local accounts disabled so we connect with the user running this process" -ForegroundColor Green
    az aks get-credentials --resource-group $NODE_AKS_RG --name $AKS_CLUSTER_NAME
  }
  }

  #we should check if the cluster has CNI set up
  #networkPlugin azure
  #$NETWORKING_PLUGIN=azure
  $NETWORKING_PLUGIN=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query networkProfile.networkPlugin  -o tsv
  if ($NETWORKING_PLUGIN -ne "azure") {
    Write-Host "AGIC controller is only availabile for a CNI plugin enabled AKS cluster" -ForegroundColor Red
    Exit 111
  }else{
    Write-Host "CNI networking configuration detected. We can move forward" -ForegroundColor Green

  }

  Write-host "------------------------------------------------------------------------------------ "
  Write-Host "Select one of the below AGIC methods for the installation: "
  Write-Host "1.- Install AGIC as an Add-on"
  Write-Host "2.- Install AGIC using Helm (Advanced!)" -ForegroundColor Red
  Write-Host "x.- I want to research :-) , so that I can take a wise decision (terminate program!)"
  Write-host "------------------------------------------------------------------------------------ "

  $DECISION = "empty"
  while ($DECISION -ne 1 -xor $DECISION -ne 2 -xor $DECISION -ne "x") {
    $DECISION = Read-Host -Prompt '--> Select a method 1,2 or x: '
    if ($DECISION -ne 1 -xor $DECISION -ne 2 -xor $DECISION -ne "x") {
      Write-Host "You need to select a valid option!" -ForegroundColor Red
    }
  }

  if ($DECISION -eq 1) {
#***************************
#installing AGIC with Add-on
#***************************



    Write-host ""
    Write-Host "Getting the application gateways availabile in this subscription..." -ForegroundColor Cyan
    try {
      az network application-gateway list -o table
    }
    catch {
      write-host "I could not get the application gateways because "  $_
    }

    do {
      $APPGW_NAME = Read-Host -Prompt '--> Enter the Application Gateway name that AGIC controller will use: '
      if ($APPGW_NAME -eq "") {
        Write-Host "You need to select a Application Gateway  name" -ForegroundColor Red
      }
    } until ($APPGW_NAME -ne "" )
    Write-Host "Getting the resource group for the application Gateway ..." -ForegroundColor Cyan
    $APPG_RG=$(az network application-gateway list --query "[?contains(name, '$APPGW_NAME')].[resourceGroup]" --output tsv)
    Write-Host "This is the resource Group " $APPG_RG -ForegroundColor Green
    Write-Host "Getting the resource Id for the Application Gateway ..." -ForegroundColor Cyan
    $AGW_ID=$(az network application-gateway show -n $APPGW_NAME -g $APPG_RG -o tsv --query "id")

    Write-Host "This is Application Gateway Id $AGW_ID" -ForegroundColor Green
    Write-Host ""
    Write-Host "                                                                                                               "
    Write-Host "---------------------------------------------------------------------------------------------------------------"
    Write-Host "In the Add-On version, the selected Application Gateway  cannot be shared "
    Write-Host "As a consequence of this, the add-on will take full ownership of your application gateway "
    Write-Host "and it will remove all the Application Gateway configuration! " -ForegroundColor red
    Write-Host "We recomend that you export the configuration of your application gateway before moving forward."
    Write-Host "---------------------------------------------------------------------------------------------------------------"
    $ValidOptions = @("y", "n")
    $EXPORT_APPGW_CONFIG = Get-input("--> Do you want to export the Application Gateway configuration? y/n ")
    if ($EXPORT_APPGW_CONFIG -eq "y") {
      az group export --resource-group $APPG_RG --resource-ids $AGW_ID > ExportedAppGWConfig.json
      Write-Host "The Application Gateway configuration has been exported to the file ExportedAppGWConfig.json" -ForegroundColor Green
    }

    #Read-Host -Prompt '--> Please, confirmm that you are aware of this and that you have saved the configuration of the application gateway... '

    Write-Host "Trying to enable the AGIC Add-on on the AKS cluster $AKS_CLUSTER_NAME  using the $APPGW_NAME Application Gateway..."

    Write-Host "Warning: This process can take UP TO 10mins, depending on the size of your cluster" -ForegroundColor Yellow
    try {
      #az aks addon enable --name MyManagedCluster --resource-group MyResourceGroup --addon ingress-appgw --appgw-subnet-cidr 10.2.0.0/16 --appgw-name gateway
      $OUTPUT=az aks enable-addons -n $AKS_CLUSTER_NAME -g $NODE_AKS_RG -a ingress-appgw --appgw-id $AGW_ID -o tsv | ConvertFrom-Json
      if (!$OUTPUT)
      {
        Write-Error "Error adding AGIC "
      }
    }
    catch {
      write-host "I could not enable the AGIC add-on in the cluster because "  $_
    }

    Write-host "Installation of the AGIC ADdon has concluded!."
    Write-host "If you have any issues, please review the documentation at https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-new"
    Read-host -Prompt  "Press any key to continue to main menu" -ForegroundColor Green
#***************************
#installing AGIC with Helm:
#***************************
  }elseif ($DECISION -eq 2) {
    # installing with Helm
    Write-host ""
    Write-Host "********Warning!" -ForegroundColor Yellow
    Write-host "This option will delete any previous Helm configuration (and AKS ingress controller pods and ingresses) you might have previously applied to your cluster"
    Write-Host "Press CTRL + C Twice to abort. ENTER to continue"
    Read-Host -Prompt '--> '
    Write-host ""

    #Write-Host "We recomend that you export the configuration of your application gateway before moving forward." -ForegroundColor Yellow
    #Write-Host "---------------------------------------------------------------------------------------------------------------"
    #Read-Host -Prompt '--> Please, confirmm that you are aware of this and that you have saved the configuration of the application gateway... '
    #Write-host ""
    Write-Host "AAD Pod Identity is a controller, similar to AGIC, which also runs on your AKS. "
    Write-Host "It binds Azure Active Directory identities to your Kubernetes pods."
    Write-Host "Making sure that Pod Identity feature is enabled for your subscription..."

    try {
      #az aks addon enable --name MyManagedCluster --resource-group MyResourceGroup --addon ingress-appgw --appgw-subnet-cidr 10.2.0.0/16 --appgw-name gateway
      $OUTPUT=az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
      if (!$OUTPUT)
      {
        Write-Error "Error activating the Pod Idenity feature"
      }
    }
    catch {
      write-host "I could not enable the AGIC add-on in the cluster because "  $_
    }
    write-Host "Registering the Microsoft.ContaintersService provider " -ForegroundColor Cyan
    az provider register -n Microsoft.ContainerService
    write-Host "Installing the aks-preview extension " -ForegroundColor Cyan
    #Read-Host -Prompt '--> # Installing the aks-preview extension... Press enter to activate '
    az extension add --name aks-preview
    az extension update --name aks-preview


    #detecting if pod identity is enabled in the cluster...
    #podIdentityProfile
    $POD_IDENTITY_ENABLED=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query podIdentityProfile
    if ($POD_IDENTITY_ENABLED -eq $null)
    {
      Write-host "Enabling pod Identity in the cluster $AKS_CLUSTER_NAME ... " -ForegroundColor Cyan
      Write-Host "Warning: This process can take UP TO 10mins, depending on the size of your cluster" -ForegroundColor Yellow
      az aks update -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --enable-pod-identity
    }else
    {
      Write-host "Pod Itenity has been detected, no need to install it $ ... " -ForegroundColor green
    }

#selecting the  Application Gateway
    Write-Host "Getting the application gateways availabile in this subscription..." -ForegroundColor Cyan
    try {
      az network application-gateway list -o table
    }
    catch {
      write-host "I could not get the application gateways because "  $_
    }

    do {
      $APPGW_NAME = Read-Host -Prompt '--> Enter the Application Gateway name that AGIC controller will use: '
      if ($APPGW_NAME -eq "") {
        Write-Host "You need to select a Application Gateway  name" -ForegroundColor Red
      }
    } until ($APPGW_NAME -ne "" )
    Write-Host "Getting the resource group for the application Gateway ..." -ForegroundColor Cyan
    $APPG_RG=$(az network application-gateway list --query "[?contains(name, '$APPGW_NAME')].[resourceGroup]" --output tsv)
    Write-Host "This is the resource Group " $APPG_RG -ForegroundColor Green
    Write-Host "Getting the resource Id for the Application Gateway ..." -ForegroundColor Cyan
    $AGW_ID=$(az network application-gateway show -n $APPGW_NAME -g $APPG_RG -o tsv --query "id")

    Write-Host "This is Application Gateway Id $AGW_ID" -ForegroundColor Green
    Write-Host ""
    Write-Host "                                                                                                               "
    Write-Host "---------------------------------------------------------------------------------------------------------------"
    Write-Host "IMPORTANT: We recomend that you export the configuration of your application gateway before moving forward."  -ForegroundColor red
    Write-Host "---------------------------------------------------------------------------------------------------------------"
    $ValidOptions = @("y", "n")
    $EXPORT_APPGW_CONFIG = Get-input("--> Do you want to export the Application Gateway configuration? y/n ")
    if ($EXPORT_APPGW_CONFIG -eq "y") {
      az group export --resource-group $APPG_RG --resource-ids $AGW_ID > ExportedAppGWConfig.json
      Write-Host "The Application Gateway configuration has been exported to the file ExportedAppGWConfig.json" -ForegroundColor Green
    }


    write-Host "INFO: AGIC communicates with the Kubernetes API server and the Azure Resource Manager. It requires an identity to access these APIs. " -ForegroundColor Cyan
    do {
      $AGW_IDENTITY_NAME = Read-Host -Prompt '--> Enter the name of the Manage Identity that will be created for AGIC: '
      if ($AGW_IDENTITY_NAME -eq "") {
        Write-Host "You need to Introduce a valid Identity name, be careful as it must be fully supported by Azure" -ForegroundColor Red
      }
    } until ($AGW_IDENTITY_NAME -ne "" )
    $GLOBAL_AGW_IDENTITY_NAME=$AGW_IDENTITY_NAME
    Write-Host "Creating the identity $AGW_IDENTITY_NAME in the AKS resource group $NODE_AKS_RG..."   -ForegroundColor cyan
    $AGW_MANAGED_IDENTITY_OBJECT=az identity create -g $NODE_AKS_RG -n $AGW_IDENTITY_NAME | ConvertFrom-Json
    Write-Host "Identity $AGW_IDENTITY_NAME created in $NODE_AKS_RG..."  -ForegroundColor cyan

    $AGW_MANAGED_IDENTITY_ID=$AGW_MANAGED_IDENTITY_OBJECT.id
    $AGW_MANAGED_IDENTITY_CLIENTID=$AGW_MANAGED_IDENTITY_OBJECT.clientId
    $AGW_MANAGED_IDENTITY_SP_ID =$AGW_MANAGED_IDENTITY_OBJECT.principalId

    $GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID = $AGW_MANAGED_IDENTITY_ID #this is to run the other options of the program

    #az aks show -n $AKS_CLUSTER_NAME -g $RG_AKS --query "addonProfiles.ingressApplicationGateway.identity.resourceId" -o tsv

    $AKS_RG_ID=az group show --resource-group $NODE_AKS_RG  --query id -o tsv
    $MC_RG_NODE_NAME=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query nodeResourceGroup -o tsv
    $GLOBAL_MC_RG_NODE_NAME =$MC_RG_NODE_NAME #this is to run the other options of the program

    $MC_RG_NODE_ID=az group show --resource-group $MC_RG_NODE_NAME --query id -o tsv

    Write-Host "INFO: The AKS resource group Id is: $AKS_RG_ID" -ForegroundColor Cyan
    Write-Host "INFO: The MC AKS resource group is: $MC_RG_NODE_NAME" -ForegroundColor Cyan
    Write-Host "INFO: The MC AKS resource group Id is: $MC_RG_NODE_ID" -ForegroundColor Cyan

    Write-Host "We are waiting for $TIME_TO_WAIT_SECONDS seconds to make sure Identity is properly registered in Azure AD " -ForegroundColor Yellow

    Start-Sleep -Seconds $TIME_TO_WAIT_SECONDS

    $COUNT_ATTEMPTS=1
    do {
      #it seems that creating the identity takes some time to propagate changes so

      Write-Host "INFO: Creating a manage identity takes some time to refresh the metadata en AD."  -ForegroundColor Cyan
      Write-Host "We are attempting several times. It is normal to see errors"
      Write-Host "Attempt number  $COUNT_ATTEMPTS"

        # Create the assignment (note that you might need to wait if you got "no matches in graph database")
      Write-Host "Adding the AGIC identity the Reader role to the AKS Resource Group " -ForegroundColor Cyan
      az role assignment create --role Reader --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $AKS_RG_ID
      Write-Host "Adding the AGIC identity the Reader role to the Management AKS Resource Group " -ForegroundColor Cyan
      az role assignment create --role Reader --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $MC_RG_NODE_ID
      Write-Host "Adding the AGIC identity the Contributoir Role to the Application Gateway " -ForegroundColor Cyan
      az role assignment create --role Contributor --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $AGW_ID

      $COUNT_ATTEMPTS++
    } until ($COUNT_ATTEMPTS -gt ($NUMBER_OF_ATTEMPTS_FOR_ASSIGNING_ROLES))

    Write-Host "INFO: Checking the Idetity method of the cluster $AKS_CLUSTER_NAME" -ForegroundColor Cyan
    #WE GET THE indentity information and as it can be dinamic we do not have an esy way to get the information
    #so we convert it to string and look for the clientId property and get the value by position.
    $IDENTITY_INFORMATION_AKS=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query identity.userAssignedIdentities | Out-String
    # we find the initial position of the "clientId Property":

    $CLIENT_ID_POSITION=$IDENTITY_INFORMATION_AKS.IndexOf("clientId")
    if ($CLIENT_ID_POSITION -eq -1) {
      #this is probably a Service Principal enabled cluster and not an Identity one.

    }else
    {
      #the cluster was created with Managed Identity
      $CLIENT_ID_VALUE_INITIAL_POSITION = $IDENTITY_INFORMATION_AKS.IndexOf(":",$CLIENT_ID_POSITION) + 3
      $CLIENT_ID_VALUE_FINAL_POSITION = $IDENTITY_INFORMATION_AKS.IndexOf(",",$CLIENT_ID_POSITION) -1
      $LENGHT_OF_VALUE = $CLIENT_ID_VALUE_FINAL_POSITION - $CLIENT_ID_VALUE_INITIAL_POSITION
      $AKS_IDENTITY_CLIENT_ID=$IDENTITY_INFORMATION_AKS.Substring($CLIENT_ID_VALUE_INITIAL_POSITION,$LENGHT_OF_VALUE)

      $PRINCIPAL_ID_POSITION=$IDENTITY_INFORMATION_AKS.IndexOf("principalId")  #now we get the principalID:
      $PRINCIPAL_ID_VALUE_INITIAL_POSITION = $IDENTITY_INFORMATION_AKS.IndexOf(":",$PRINCIPAL_ID_POSITION) + 3
      $PRINCIPAL_ID_VALUE_FINAL_POSITION = $IDENTITY_INFORMATION_AKS.IndexOf("}",$PRINCIPAL_ID_POSITION) -5
      $LENGHT_OF_VALUE = $PRINCIPAL_ID_VALUE_FINAL_POSITION - $PRINCIPAL_ID_VALUE_INITIAL_POSITION
      $AKS_IDENTITY_PRINCIPAL_ID=$IDENTITY_INFORMATION_AKS.Substring($PRINCIPAL_ID_VALUE_INITIAL_POSITION,$LENGHT_OF_VALUE)
    }


    Write-Host "The Client Id of the cluster Identity is $AKS_IDENTITY_CLIENT_ID" -ForegroundColor Cyan
    Write-Host "The Principal Id of the cluster Identity is $AKS_IDENTITY_PRINCIPAL_ID" -ForegroundColor Cyan

    #Write-Host "Adding the AGIC identity the Managed Identity Operator Role to manipulate the AKS Identity " -ForegroundColor Cyan
    az role assignment create --role "Managed Identity Operator" --assignee $AKS_IDENTITY_PRINCIPAL_ID --scope $AGW_MANAGED_IDENTITY_ID
    az role assignment create --role "Managed Identity Operator" --assignee $AKS_IDENTITY_PRINCIPAL_ID --scope $AGW_MANAGED_IDENTITY_SP_ID


    Write-Host "Creating the Helm repo for AGIC custom implementation..." -ForegroundColor Cyan
    helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
    helm repo update


    $AGIC_CONFIG_FILE_URL="https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/sample-helm-config.yaml "

    Write-Host "Downloading the Agic configuration file from : $AGIC_CONFIG_FILE_URL" -ForegroundColor Cyan
    Read-Host -Prompt "Make Sure that that location is reacheable before moving forward... Pres a key to continue when ready... "
    Invoke-WebRequest $AGIC_CONFIG_FILE_URL -OutFile agic-helm-config.yaml

    #now we capture the custom settings for the helm implementation
    #shared:-------------------------------------------------------

    $DECISION = "x"
    while ($DECISION -ne "y" -xor $DECISION -ne "n") {
      $DECISION = Read-Host -Prompt '--> Do you want your Application Gateway to be dedicated excusively by the AGIC controller?  y/n '
      if ($DECISION -ne "y" -xor $DECISION -ne "n") {
        Write-Host "You need to select a valid option! y/n" -ForegroundColor Red
      }
    }

    $SHARED=$true
    if ($DECISION -eq "y") {
      $SHARED=$false
    }
    #namespaces:-------------------------------------------------------
    $DECISION = ""
    Write-Host  "What namespace should AGIC montitor "
    Write-Host  "Option 1  All namespaces (Type 1)"
    Write-Host  "Option 2  Default  (Type 2)"
    Write-Host  "Option 3: Type one or more custom namespaces separated by a colon, For example: Development,Production  "
    Write-Host  "if you leave it empy it will be considered as Option 1 (All namespaces) " -ForegroundColor  Yellow

    $DECISION = Read-Host -Prompt '--> Enter Namespaces  '
    if ($DECISION -eq "1")
    {
      $NAMESPACES_TO_MONITOR=""
    }elseif($DECISION -eq "2")
    {
      $NAMESPACES_TO_MONITOR="default"
    }else
    {
      $NAMESPACES_TO_MONITOR = $DECISION
    }

    $DECISION = "x"
    while ($DECISION -ne "y" -xor $DECISION -ne "n") {
      $DECISION = Read-Host -Prompt '--> Do you want your the AGIC controller using the private Ip of the Gateway?  y/n '
      if ($DECISION -ne "y" -xor $DECISION -ne "n") {
        Write-Host "You need to select a valid option! y/n" -ForegroundColor Red
      }
    }

    $PRIVATE_IP=$true
    if ($DECISION -eq "n") {
      $PRIVATE_IP=$false
    }

    Write-Host "checking if your cluster has RBAC enabled..." -ForegroundColor Cyan

    #$ENABLE_RBAC=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --query enableRBAC -o tsv
    #for some reason the rbac property is not accesible using the az cli --query command.
    #trying to look through the string version of the az aks show command:
    $AKS_SHOW_OUTPUT=az aks show -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME | Out-String
    $VALUE=$AKS_SHOW_OUTPUT.IndexOf('enableAzureRbac": true')

    $ENABLE_RBAC = $false
    if ($VALUE -gt 0) {
      #it means we found the string  enableAzureRbac": true
      $ENABLE_RBAC = $true
    }

    Write-Host "INFO RBAC enabled for your cluster:$ENABLE_RBAC" -ForegroundColor Cyan

    #armAuth:
    #type: aadPodIdentity
    #identityResourceID: <identityResourceId>
    #identityClientID:  <identityClientId>
    Write-Host "Inserting a Prohibitied Target for Contoso.com"

$myYaml = @'
apiVersion: "appgw.ingress.k8s.io/v1"
kind: AzureIngressProhibitedTarget
metadata:
  name: prod-contoso-com
spec:
  hostname: prod.contoso.com
'@

kubectl apply -f $myYaml
#kubectl apply -f "https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/ae695ef9bd05c8b708cedf6ff545595d0b7022dc/crds/AzureIngressProhibitedTarget.yaml"


Write-Host "Enabling AGIC with the information provided... " -ForegroundColor Cyan
Write-Host "This process might ask you singing to your subscription again to acess the AKS cluster... " -ForegroundColor Yellow

#upgrade
#file version:




if ($SHARED -eq $True) {
  <# Action to perform if the condition is true #>
   $SHARED_STRING="true"
}else {
  $SHARED_STRING="false"
}

if ($ENABLE_RBAC -eq $True) {
  <# Action to perform if the condition is true #>
   $ENABLE_RBAC="true"
}else {
  $ENABLE_RBAC="false"
}



$yamlFile_for_helm = @"
verbosityLevel: 3
appgw:
    subscriptionId: $SUBSCRIPTION_ID
    resourceGroup: $APPG_RG
    name: $APPGW_NAME
    usePrivateIP: false
    shared: $SHARED_STRING
kubernetes:
    watchNamespace: $NAMESPACES_TO_MONITOR
armAuth:
    type: aadPodIdentity
    identityResourceID: $AGW_MANAGED_IDENTITY_ID
    identityClientID:  $AGW_MANAGED_IDENTITY_CLIENTID
rbac:
    enabled: $ENABLE_RBAC
"@

    #$ScriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
    $yamlFile_for_helm | out-File agic-helm-config.yaml
    #delete previous configurations:
    helm delete ingress-azure

    kubectl delete IngressClass azure-application-gateway

    helm repo update
    #Helm install ingress-azure -f agic-helm-config.yaml application-gateway-kubernetes-ingress/ingress-azure
    helm upgrade --install ingress-azure -f agic-helm-config.yaml application-gateway-kubernetes-ingress/ingress-azure #--version $LATEST_CHART_VERSION
    #Helm install ingress-azure -f agic-helm-config.yaml application-gateway-kubernetes-ingress/ingress-azure
    write-host "Waitting 20 seconds to let AGIC finish the configuration..." -ForegroundColor Yellow
    Start-Sleep -Seconds 20
    write-host "Listing the AGIC ingress pods:"
    #get all the pods in a specific label


    kubectl get pods -l aadpodidbinding=ingress-azure  -A
    write-host "The READY field should show 1/1:"
    write-host "if the logs of this pod shows Identity not found exception, run this program with menu option number 3:"
    write-host "If you are facing the Identity not found issue, that is documented here:
    https://azure.github.io/application-gateway-kubernetes-ingress/troubleshootings/troubleshooting-agic-addon-identity-not-found/,
    this program offers you an option to fix this problem (OPTION 3 IN THE MENU). However,
    It is recommended that you open a support case with Microsoft as changing the VM scalesets directly can leave your cluster as non-supported.
    Performing this action, without the approval of the Microsoft Support team, is not supported." -ForegroundColor Yellow

    #helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure `
    #     --namespace default `
    #     --debug  `
    #     --set appgw.name=$APPGW_NAME `
    #     --set appgw.resourceGroup=$APPG_RG `
    #     --set appgw.subscriptionId=$SUBSCRIPTION_ID `
    #     --set appgw.usePrivateIP=$PRIVATE_IP `
    #     --set appgw.shared=$SHARED `
    #     --set armAuth.type=aadPodIdentity `
    #     --set armAuth.identityResourceID=$AGW_MANAGED_IDENTITY_ID `
    #     --set armAuth.identityClientID=$AGW_MANAGED_IDENTITY_CLIENTID `
    #     --set rbac.enabled=$ENABLE_RBAC `
    #     --set verbosityLevel=3 `
    #     --set kubernetes.watchNamespace=$NAMESPACES_TO_MONITOR

    #solving the identity not found error:

    #if we enabled the local accounts, we ask to disable the local accounts
    if ($ASK_TO_DISABLE_LOCAL_ACCOUNTS ) {
      Write-Host ""
      $answer = Read-Host -Prompt "We enabled local accounts in a previous step, do you want to disable the local accounts? (y/n) (default y)" -DefaultAnswer y
      if ($answer -eq "y") {
        az aks update -g $NODE_AKS_RG -n $AKS_CLUSTER_NAME --disable-local-accounts
        write-host "Local accounts disabled"
      }
    }
    Write-Host "helm installation completed... TEST the AGIC CONTROLLER" -ForegroundColor Cyan
    Read-Host -Pompt "Press ENTER to go to main menu"


      }else {
        Write-Host "happy research!" -ForegroundColor Green
      }

    } else {
        Write-Host "you need to log in!"
    }


}

function fixNoIdentityError() {
  #This fixes the no identity error wich is a known bug of the AGIC Controller
  #first we get the differente node pools as we need to apply the fix per node pool:

  write-host "If you are facing the Identity not found issue, that is documented here:
  https://azure.github.io/application-gateway-kubernetes-ingress/troubleshootings/troubleshooting-agic-addon-identity-not-found/,
  this option offers you a fix this problem. However,
  It is recommended that you open a support case with Microsoft as changing the VM scalesets directly can leave your cluster as non-supported.
  Performing this action, without the approval of the Microsoft Support team, is not supported." -ForegroundColor Yellow
  Read-Host

  loginagain

  if (! $GLOBAL_MC_RG_NODE_NAME -eq "") {
    #if this variable is not empty it means that we already went throuthg the AGIC installation through Helm so we already have all the data we need
    #$GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID

  } else
  {
    # we need to get the required values before moving forward
    #write-host "Finding AKS clusters in this subscription ..." -ForegroundColor Cyan

    #az aks list -o table
    #$AKS_CLUSTER_NAME=Get-AksClusters | Out-GridView -Title "Select the AKS cluster you want to fix " -OutputMode Single | Select-Object -ExpandProperty name | Out
    #AKS_CLUSTER_NAME=Get-AksClusters | Out-GridView -Title "Select the AKS cluster you want to fix " -OutputMode Multiple | Select-Object -ExpandProperty name | Out-String
    #$AKS_CLUSTER=Get-AksClusters | Out-GridView -Title "Select the AKS cluster you want to fix " -OutputMode Single #| Select-Object -ExpandProperty name
    write-host "Finding AKS clusters in this subscription ..." -ForegroundColor Cyan

    az aks list -o table



    do {
      $AKS_CLUSTER_NAME = Read-Host -Prompt '--> Enter the cluster name where you want AGIC installed: '
      if ($AKS_CLUSTER_NAME -eq "") {
        Write-Host "You need to select a cluster name" -ForegroundColor Red
      }
    } until ($AKS_CLUSTER_NAME -ne "" )

    #$AKS_CLUSTER_NAME=$AKS_CLUSTER.Name
    #$NODE_AKS_RG=$aks_cluster.ResourceGroupName
    #$GLOBAL_NODE_AKS_RG=$NODE_AKS_RG
    write-Host "You have selected $AKS_CLUSTER_NAME as the cluster name" -ForegroundColor Green
    Write-Host "This is the resource Group" $NODE_AKS_RG -ForegroundColor Green
    $GLOBAL_AKS_CLUSTER_NAME = $AKS_CLUSTER_NAME
    $GLOBAL_AKS_CLUSTER_NAME = $AKS_CLUSTER_NAME # TO USE IT FOR OTHER PROGRAM OPTIONS

    Write-host "You have selected to install AGIC on the cluster: " $AKS_CLUSTER_NAME  -ForegroundColor Green
    Write-Host "Getting the resource group name for the cluster..."
    $NODE_AKS_RG=$(az aks list --query "[?contains(name, '$AKS_CLUSTER_NAME')].[resourceGroup]" --output tsv)
    $GLOBAL_NODE_AKS_RG=$NODE_AKS_RG # TO USE IT FOR OTHER PROGRAM OPTIONS
    Write-Host "This is the resource Group" $NODE_AKS_RG -ForegroundColor Green
    Write-host " "
    #do {
    #  $AKS_CLUSTER_NAME = Read-Host -Prompt '--> Enter the cluster name where you want AGIC installed: '
    #  if ($AKS_CLUSTER_NAME -eq "") {
    #    Write-Host "You need to select a cluster name" -ForegroundColor Red
    #  }
    #} until ($AKS_CLUSTER_NAME -ne "" )

   #write-Host "You have selected $AKS_CLUSTER_NAME as the cluster name" -ForegroundColor Green
    #$GLOBAL_AKS_CLUSTER_NAME = $AKS_CLUSTER_NAME # TO USE IT FOR OTHER PROGRAM OPTIONS
    #Write-Host "Getting the resource group name for the cluster..." -ForegroundColor cyan
    #$NODE_AKS_RG=$(az aks list --query "[?contains(name, '$AKS_CLUSTER_NAME')].[resourceGroup]" --output tsv)
    #$GLOBAL_NODE_AKS_RG=$NODE_AKS_RG # TO USE IT FOR OTHER PROGRAM OPTIONS
    #Write-Host "This is the resource Group" $NODE_AKS_RG -ForegroundColor Green

     do {
      $AGW_IDENTITY_NAME = Read-Host -Prompt '--> Enter the name of the Manage Identity used to set up this AGIC (not the AKS cluster): '
      if ($AGW_IDENTITY_NAME -eq "") {
        Write-Host "You need to Introduce a valid Identity name" -ForegroundColor Red
      }
    } until ($AGW_IDENTITY_NAME -ne "" )

    $GLOBAL_AGW_IDENTITY_NAME=$AGW_IDENTITY_NAME
    $AGW_MANAGED_IDENTITY_OBJECT=az identity show -g $NODE_AKS_RG -n $AGW_IDENTITY_NAME | ConvertFrom-Json
    Write-Host "Identity $AGW_IDENTITY_NAME found in $NODE_AKS_RG..."  -ForegroundColor cyan

    $AGW_MANAGED_IDENTITY_ID=$AGW_MANAGED_IDENTITY_OBJECT.id
    $AGW_MANAGED_IDENTITY_CLIENTID=$AGW_MANAGED_IDENTITY_OBJECT.clientId
    $AGW_MANAGED_IDENTITY_SP_ID =$AGW_MANAGED_IDENTITY_OBJECT.principalId
    #$AGW_MANAGED_IDENTITY_RESOURCE_ID =$AGW_MANAGED_IDENTITY_OBJECT.resourceId
    #Write-host "id $AGW_MANAGED_IDENTITY_ID  clientID $AGW_MANAGED_IDENTITY_CLIENTID SP_id $AGW_MANAGED_IDENTITY_SP_ID Resource Id $AGW_MANAGED_IDENTITY_RESOURCE_ID"

    $GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID = $AGW_MANAGED_IDENTITY_ID #this is to run the other options of the program

  }

  $NODE_RESOURCE_GROUP=$(az aks show -n $GLOBAL_AKS_CLUSTER_NAME -g $GLOBAL_NODE_AKS_RG --query "nodeResourceGroup" -o tsv)
  Write-Host "Getting the resource AGIC identity for the cluster..." -ForegroundColor cyan


  #$GLOBAL_AGIC_RESOURCE_ID=$(az aks show -n $AKS_CLUSTER_NAME -g $GLOBAL_NODE_AKS_RG --query "addonProfiles.ingressApplicationGateway.identity.resourceId" -o tsv)
  write-Host "The associated Resource id of the identity for AGIC is :" $GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID -ForegroundColor Green
  $VMSS=(az vmss list -g $NODE_RESOURCE_GROUP -o json)| ConvertFrom-Json #getting the VMSS

  Write-Host "Patching the identity not found problem per VMSS found"
  Write-Host "*******Warning it is normal to see the  error: are  ***not associated with***" -ForegroundColor Yellow
  Write-Host "This is part of the known issue" -ForegroundColor red
  Read-Host -Prompt '--> Press ENTER to continue... '
  Write-host ""

  foreach ($vms in $VMSS) {
    write-host "Patching for the VMSS:" $vms.Id
    az vmss identity remove --ids $vms.Id --identities $GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID #we delete the previous identity
    az vmss identity assign --ids $vms.Id --identities $GLOBAL_AGW_MANAGED_IDENTITY_RESOURCE_ID #this is the fix
    Write-host ""
  }

  write-host "The fix has been deployed." -ForegroundColor green
  write-host "Waitting 20 seconds to let AGIC finish the configuration..." -ForegroundColor Yellow
  Start-Sleep -Seconds 20
  write-host "Listing the AGIC ingress pods:"
  kubectl get pods -l aadpodidbinding=ingress-azure -A
  write-host "The READY field should show 1/1:"
  Read-Host -Prompt '--> Press ENTER to go to the main menu... '

}


$MENU_OPTION = 0
do {
  clear-host
  Write-host "---------------------------------------------------------------------------------------------- "
  Write-Host "                                    Options"
  Write-host "---------------------------------------------------------------------------------------------"
  Write-Host "1.- Install AGIC"
  Write-Host "2.- COMMING SOON! Remove a previous Helm installation of the AGIC Controller (Installed with this program)"
  Write-Host "3.- Fix No Identity Issue (Warning!)" -ForegroundColor Red
  Write-Host "4.- Terminate program"
  Write-host "---------------------------------------------------------------------------------------------"
  Write-Host ""
  $MENU_OPTION= Read-Host -Prompt '--> Select an option '
  switch ($MENU_OPTION) {
    1 {installAgic}
    2 {}
    3 {fixNoIdentityError}
    4 {Clear-Host;Write-Host "Bye!";Exit 0}
    Default {}
  }

} until ($MENU_OPTION -eq "4")
