# seqr-deploy
Infrastructure and deployment code for a running SEQR Kubernetes cluster on Azure

## Introduction

This repository contains the code for deploying a [seqr](https://seqr.broadinstitute.org) instance on Azure. It is intended to be used with the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) and [Terraform](https://www.terraform.io/).

The instructions below have been tested on Windows Subsystem for Linux (WSL) running Ubuntu 20.04 LTS. If you observe issues or differences on other platforms, please submit an issue.

## Deployment Overview

seqr is a web application for analyzing genomic data. It is composed of a number of services, each of which is deployed as a containerized application. The services are deployed to a Kubernetes cluster running on Azure. The Kubernetes cluster is managed by Azure Kubernetes Service (AKS). The Kubernetes cluster is deployed and configured using Terraform.

This repository does not contain the source code for the services, instead it references the seqr source via git submodule.

The following image shows the high-level architecture of the deployment:
TODO IMAGE

Deployment of a new environment is handled in the following steps:

- Deploy the Azure resources using Terraform (via `terraform apply`)
- Generate the docker images for the relevant services (via github actions)
- Deploy the seqr Kubernetes services and objects (again via `terraform apply`)

Each of these steps is discussed in more detail below.

### Github deployment model

This repository leverages [GitHub deployments](https://docs.github.com/en/actions/deployment/about-deployments) to support multiple deployments from within this repository. Different deployments are bound to branches within the repository, and have the opportunity to reference different branches of the core seqr source by modifying the git submodule reference.

This repository is currently configured such that management of all deployments is available to collaborators of the repository. For organizations that wish to restrict access to their deployments it is suggested to fork this repository and manage deployments from the fork.

### Security considerations

This infrastructure is configured to comply with ... with the following exceptions.
- Exception 1
- Exception 2

That being said, deployments based on this repository are intended for development purposes only and should not be used for production workloads. Further security review may be necessary before deploying to production.

## Making a new Deployment

The following sections walk you through the process of making a new deployment within this repository.

### Pre-requisites

In order to complete subsequent steps, the following requirements must be met:

- (GitHub) You should be a collaborator on this repository
- (Azure) You should have an Azure subscription
- (Azure) TODO, something about required roles
- (Deployment Environment) You should have a Linux environment with the Azure CLI ([instructions](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)) and Terraform ([instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)) installed
- (Deployment Environment) Login to the Azure CLI using `az login`, note the GUID for your tenant and subscription

### Deployment

1. Clone this repository

    ```bash
    git clone https://github.com/gregsmi/cpg-deploy.git
    ```

1. Create a new branch for your deployment. The naming convention for deployment branches in this repository is `env-msseqrNN`, where `NN` is a two-digit number. For example, if you are creating the 3rd deployment in this repository, you would name your branch `env-msseqr03`. Note that `msseqr03` now the name for this deployment and will be used in subsequent steps.

    ```bash
    git checkout -b env-msseqr03
    ```

1. Rename `deployment.template.env` to `deployment.env`. Populate `deployment.env` with the `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` that you collected above. Additionally, populate `deployment.env` with values for `DEPLOYMENT_NAME` (`msseqr03` in this example) and `REGION` (`eastus` in this example). This file will make information about your deployment available to Terraform and GitHub Actions.

1. Run `terraform-init.sh -c` to configure terraform to manage this deployment. This must be run from within the terraform directory. This script will first ensure that the correct Azure resources exist to store the terraform state. This includes a Resource Group (RG) that will eventually house your seqr deployment, a Storage Account (SA) within that RG, and a Container within that SA. After configuring terraform to use that SA to hold terraform state, it will then write out `terraform.tfvars` with the values derived from `deployment.env`. This file will be used by terraform to configure your deployment.

    ```bash
    cd terraform
    ./terraform-init.sh -c
    ```

1. Create `config.auto.tfvars.json` in the `terraform` directory to house other configuration variables relevant to your deployment, this includes an allow list of CIDRs that will be permitted to access the seqr application and a list of data storage accounts that TODO. The format for this file is as follows:

    ```json
        {
            "whitelisted_cidrs": "1.2.3.4/16,5.6.7.8/16",
            "data_storage_accounts":  { 
                "firstsa": "firstsa-rg",
                "secondsa": "secondsa-rg"
            }
        }    
    ```

    Where `whitelisted_cidrs` is a list of CIDR blocks that will be permitted access to the public facing IP address that is created for the seqr application. Additionally, `data_storage_accounts` is a list of SA / RG pairs that contain data that will be accessed by the seqr-loading-pipeline. The latter are included in this configuration file so that credentials necessary to access this data can be made available to k8s services.

1. Run an initial pass of `terraform apply`. As described above, this will create and configure all of the Azure resources associated with the deployment. It will also apply an initial set of configurations to the kubernetes cluster. At this point, however, terraform will not have all of the necessary information to create the kubernetes objects associated with the seqr application itself; we will revisit this later. 

    ```bash
    terraform apply
    ```

1. TODO, something about github actions

1. Rerun `terraform apply` to complete the deployment. This will create the kubernetes objects associated with the seqr application. After confirming the changes to be made, deployment will take approximately five minutes.

    ```bash
    terraform apply
    ```

1. Commit changes on your branch and publish to GitHub.
### Troubleshooting