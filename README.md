# AGIC Installation assistant
This is a PowerShell script that will guide you through the installation of the AGIC controller for AKS (Brownfield deployment only)

Installing the AGIC Controller, specially using Helm, can be hard work! The AKS AGIC Installation assistant focuses on expediting customers onboarding of Azure Kubernetes Service Ingres Controller based on the Application Gateway.

This project unifies guidance provided by the AGIC controller deployment guide here: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-existing/

## About the Project
Keep in mind that this is a work-in-progress, I will continue to contribute to it when I can.

All constructive feedback is welcomed 🙏

## Getting Started

### Prerequisites
The AGIC installation assistant assumes you already have the following tools and infrastructure installed:
- AKS with Advanced Networking enabled (CNI). The script has been tested only with CNI networking configuration and it and will not let you continue if you have Kubenet.
- App Gateway v2 in the same virtual network as AKS (App Gateway in different VNET has not been tested using this script yet).
- AAD Pod Identity installed on your AKS cluster. The assitant will check this and enable it.
- The script will create a Mange Identity and it requires Contributor rights over your AD Tenant.
- Make sure your Azure Cloud Shell has the below elements installed:
  -   Az CLI,
  -   kubectl,
  -   Helm 3.0


Before running the powershell script, we recommend that you peform the following actions:
  - This is a PowerShell script. It will only run on the Azure Cloud Powershell shell:
![image](https://user-images.githubusercontent.com/41587804/185116965-95541326-1cc0-4527-9d88-20f3060152ec.png)

  - Az Login with a user that has Owner/Contributor rights on the subscription/RG of the AKS cluster and App Gateway
  - Although the powershell script will get credentials to your cluster, it is recommended that you do it before (just to make sure you are on the right context!)
  - Run Kubectl get pods -A this will make sure you have access to your cluster.


### IMPORTANT! Please backup your App Gateway's configuration before installing AGIC:
This script will ask you if you want to export (ARM) your application gateway configuration. Still we recommend you to export the configuration manually:
1. Using Azure Portal navigate to your App Gateway instance
2. From Export template click Download

### VERY IMPORTANT!
If you are facing the Identity not found issue, that is documented here:
https://azure.github.io/application-gateway-kubernetes-ingress/troubleshootings/troubleshooting-agic-addon-identity-not-found/, this program offers you an option to fix this problem (OPTION 3 IN THE MENU). However, It is recommended that you open a support case with Microsoft as changing the VM scalesets directly can leave your cluster as non-supported.
Performing this action, without the approval of the Microsoft Support team, is not supported.


### Basic
If this is the first time you're using the project, follow these steps:

1. Download the agicInstaller.ps1 file from this repo (or clone the repo)
2. Upload the agicInstaller.ps1 file to the Azure Powershell Cloud Shell:

![image](https://user-images.githubusercontent.com/41587804/185117995-09237cb4-a2fa-43b0-bef1-fdc8fe82f80d.png)

3. Execute the ./agicInstaller.ps1
4. The assistant will guide your through the rest of the process

This is how the main menu looks like:

![image](https://user-images.githubusercontent.com/41587804/185781425-8c0bda8e-13a5-48a7-b06f-c9ebeb56a2c1.png)


### Troubleshooting
Please, refer to  : https://azure.github.io/application-gateway-kubernetes-ingress/troubleshootings/ if you find issues once the AGIC Controller is installed.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
