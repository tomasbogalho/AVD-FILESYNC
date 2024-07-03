# AVD-FILESYNC Project

## Overview

The AVD-FILESYNC project is designed to automate the deployment and configuration of Azure Virtual Desktop (AVD) environments, including the setup of file synchronization between on-premises environments and Azure. This project utilizes Terraform for infrastructure as code (IaC) to provision and manage Azure resources efficiently.

## Features

- **Resource Group Creation**: Sets up separate resource groups for AVD machines and AVD resources for organized management.
- **Virtual Network and Subnet Configuration**: Establishes a virtual network and subnet specifically for AVD, ensuring secure and isolated network space.
- **AVD Workspace and Host Pool**: Automates the creation of AVD workspace and host pool for hosting virtual desktops.
- **File Sync Setup**: Integrates Azure File Sync service to synchronize files between on-premises servers and Azure, facilitating seamless data access and backup.

## Prerequisites

- Azure subscription
- Terraform installed
- Azure CLI or PowerShell for Azure authentication

## Getting Started

1. **Clone the Repository**

   Clone this repository to your local machine to get started with the project.

   ```sh
   git clone https://github.com/your-repository/AVD-FILESYNC.git

2. **Configure Azure Authentication**

Set up your Azure authentication credentials. This project requires the following environment variables to be set:

```yml
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_SUBSCRIPTION_ID
ARM_TENANT_ID
These can be configured in your CI/CD pipeline or your local development environment.
