 # Azure Native TypeScript Pulumi Template

 This template provides a minimal, ready-to-go Pulumi program for deploying Azure resources using the Azure Native provider in TypeScript. It establishes a basic infrastructure stack that you can use as a foundation for more complex deployments.

 ## When to Use This Template

 - You need a quick boilerplate for Azure Native deployments with Pulumi and TypeScript
 - You want to create a Resource Group and Storage Account as a starting point
 - You're exploring Pulumi's Azure Native SDK and TypeScript support

 ## Prerequisites

 - An active Azure subscription
 - Node.js (LTS) installed
 - A Pulumi account and CLI already installed and configured
 - Azure credentials available (e.g., via `az login` or environment variables)

 ## Usage

 Scaffold a new project from the Pulumi registry template:
 ```bash
 pulumi new azure-typescript
 ```

 Follow the prompts to:
 1. Name your project and stack
 2. (Optionally) override the default Azure location

 Once the project is created:
 ```bash
 cd <your-project-name>
 pulumi config set azure-native:location <your-region>
 pulumi up
 ```

 ## Project Layout

 ```
 .
 ├── Pulumi.yaml       # Project metadata & template configuration
 ├── index.ts          # Main Pulumi program defining resources
 ├── package.json      # Node.js dependencies and project metadata
 └── tsconfig.json     # TypeScript compiler options
 ```

 ## Configuration

 Pulumi configuration lets you customize deployment parameters. Set these configuration values before deployment:

 ### Azure Provider Configuration
 - **azure-native:location** (string)
   - Description: Primary Azure region to provision resources in
   - Example: `eastus`
   - Command: `pulumi config set azure-native:location eastus`

 ### ASR PMK POC Configuration
 - **pulumi-asr-pmk-poc:targetLocation** (string)
   - Description: Target Azure region for disaster recovery
   - Example: `westus`
   - Command: `pulumi config set pulumi-asr-pmk-poc:targetLocation westus`

 - **pulumi-asr-pmk-poc:resourceGroupNamePrefix** (string)
   - Description: Prefix for resource group names
   - Example: `pmkAsrPoc`
   - Command: `pulumi config set pulumi-asr-pmk-poc:resourceGroupNamePrefix pmkAsrPoc`

 - **pulumi-asr-pmk-poc:vmAdminUsername** (string)
   - Description: Administrator username for virtual machines
   - Example: `azureuser`
   - Command: `pulumi config set pulumi-asr-pmk-poc:vmAdminUsername azureuser`

 - **pulumi-asr-pmk-poc:vmAdminPassword** (string, secure)
   - Description: Administrator password for virtual machines
   - Command: `pulumi config set --secret pulumi-asr-pmk-poc:vmAdminPassword <your-secure-password>`

 - **pulumi-asr-pmk-poc:sourceVmName** (string)
   - Description: Name of the source virtual machine
   - Example: `sourcevm-pmk`
   - Command: `pulumi config set pulumi-asr-pmk-poc:sourceVmName sourcevm-pmk`

 - **pulumi-asr-pmk-poc:vmSize** (string)
   - Description: Azure VM size/SKU for virtual machines
   - Example: `Standard_DS2_v2`
   - Command: `pulumi config set pulumi-asr-pmk-poc:vmSize Standard_DS2_v2`

 ### VM Image Configuration
 - **pulumi-asr-pmk-poc:sourceVmImagePublisher** (string)
   - Description: VM image publisher
   - Example: `Canonical`
   - Command: `pulumi config set pulumi-asr-pmk-poc:sourceVmImagePublisher Canonical`

 - **pulumi-asr-pmk-poc:sourceVmImageOffer** (string)
   - Description: VM image offer
   - Example: `0001-com-ubuntu-server-jammy`
   - Command: `pulumi config set pulumi-asr-pmk-poc:sourceVmImageOffer 0001-com-ubuntu-server-jammy`

 - **pulumi-asr-pmk-poc:sourceVmImageSku** (string)
   - Description: VM image SKU
   - Example: `22_04-lts-gen2`
   - Command: `pulumi config set pulumi-asr-pmk-poc:sourceVmImageSku 22_04-lts-gen2`

 - **pulumi-asr-pmk-poc:sourceVmImageVersion** (string)
   - Description: VM image version
   - Example: `latest`
   - Command: `pulumi config set pulumi-asr-pmk-poc:sourceVmImageVersion latest`

 ### Quick Setup
 To configure all settings at once, run these commands:
 ```bash
 pulumi config set azure-native:location eastus
 pulumi config set pulumi-asr-pmk-poc:targetLocation westus
 pulumi config set pulumi-asr-pmk-poc:resourceGroupNamePrefix pmkAsrPoc
 pulumi config set pulumi-asr-pmk-poc:vmAdminUsername azureuser
 pulumi config set --secret pulumi-asr-pmk-poc:vmAdminPassword <your-secure-password>
 pulumi config set pulumi-asr-pmk-poc:sourceVmName sourcevm-pmk
 pulumi config set pulumi-asr-pmk-poc:vmSize Standard_DS2_v2
 pulumi config set pulumi-asr-pmk-poc:sourceVmImagePublisher Canonical
 pulumi config set pulumi-asr-pmk-poc:sourceVmImageOffer 0001-com-ubuntu-server-jammy
 pulumi config set pulumi-asr-pmk-poc:sourceVmImageSku 22_04-lts-gen2
 pulumi config set pulumi-asr-pmk-poc:sourceVmImageVersion latest
 ```

 ## Resources Created

 1. **Resource Group**: A container for all other resources
 2. **Storage Account**: A StorageV2 account with Standard_LRS SKU

 ## Outputs

 After `pulumi up`, the following output is exported:
 - **primaryStorageKey**: The primary access key for the created Storage Account

 Retrieve it with:
 ```bash
 pulumi stack output primaryStorageKey
 ```

 ## Next Steps

 - Extend this template by adding more Azure Native resources (e.g., Networking, App Services)
 - Modularize your stack with Pulumi Components for reusable architectures
 - Integrate with CI/CD pipelines (GitHub Actions, Azure DevOps, etc.)

 ## Getting Help

 If you have questions or run into issues:
 - Explore the Pulumi docs: https://www.pulumi.com/docs/
 - Join the Pulumi Community on Slack: https://pulumi-community.slack.com/
 - File an issue on the Pulumi Azure Native SDK GitHub: https://github.com/pulumi/pulumi-azure-native/issues