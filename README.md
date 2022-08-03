# Terraform samples

Demo of terraform in combination with azure provider.

## Install Terraform

We will run terraform under windows subsystem linux with ubuntu.

Ubuntu distribution:

~~~ bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add –
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
~~~

## Prerequisits

You will need to make sure that you have authN and authZ to azure.
In our case we use the env variables which start with "ARM_".
to make sure the demo works we will need to ensure that certain env variable are predefined and some do not exist:

~~~ bash
unset TF_VAR_myprefix
prefix=azcptdtf
clear
~~~

## Add the right provider

You can find the terraform registry with the azure RM provider details under the following link:

~~~ bash
startedgega https://registry.terraform.io/providers/hashicorp/azurerm/latest
~~~


## Logging (OPTIONAL)

In case you like to get more detailed logging you can setup the following env variables:

~~~ bash
# add better debugging
# unset TF_LOG=TRACE
export TF_LOG
export TF_LOG_PROVIDER
export TF_LOG_PATH=tfp.log.txt
~~~

## Create baseline

If you start from scratch your folder structure should look as follow:

~~~ text
.
├── README.md
└── main.tf

0 directories, 2 files
~~~

~~~ bash
tree # check your current folder structure
code main.tf # have a look at the current main.tf
terrafrom version # check your terraform version
terraform validate # validate the current main.tf
terraform fmt # format your terraform file
terraform init # init to load azurerm provider
tree -a -I '.git*' # check your directory after tf init
~~~

Afterwards your directory should look as follow:

~~~ text
.
├── .terraform
│   └── providers
│       └── registry.terraform.io
│           └── hashicorp
│               └── azurerm
│                   └── 3.16.0
│                       └── linux_amd64
│                           └── terraform-provider-azurerm_v3.16.0_x5
├── .terraform.lock.hcl
├── README.md
└── main.tf
~~~

Have a look at the new created terraform state file:

~~~ bash
code terraform.tfstate
~~~

## Work with env variables

You can find more details about terraform and env variables here:

~~~ bash
startedgega https://www.terraform.io/language/values/variables#environment-variables # have a look at the doc´s
~~~

Let´s start by creating a first terraform plan:

~~~ bash
terraform plan -out tfplan0 # do not use ext .tf
~~~

You will receive the following message:

~~~ text
Terraform will perform the following actions:

  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + id       = (known after apply)
      + location = "eastus"
      + name     = "dummy"
      + tags     = {
          + "env" = "dev"
        }
    }
~~~

> NOTE: Our new resources will be named with the default value "dummy"

We would like to change this. Therefore we are going to define a new env variable:

~~~ bash
export TF_VAR_myprefix=$prefix
echo $TF_VAR_myprefix
# redo tf plan after setting env variable
terraform plan -out tfplan1
~~~

Now our new resources will be named with the env variable value based on the terraform plan output:

~~~ text
Terraform will perform the following actions:

  # azurerm_resource_group.rg will be created
  + resource "azurerm_resource_group" "rg" {
      + id       = (known after apply)
      + location = "eastus"
      + name     = "azcptdtf"
      + tags     = {
          + "env" = "dev"
        }
    }
~~~

Create your first azure resources:

~~~ bash
terraform apply --auto-approve tfplan1 # ~ 1 min
terraform state list # list resources in our state file
jq .resources[].instances[].attributes.id terraform.tfstate # use jq 
az group show -n $prefix --query '{"name":name, "id":id}' # verify with az cli
az network vnet list -g $prefix -o table 
code tfp.log.txt # check logs if turned on.
~~~

## modify main.tf

Modify the vnet manually by adding a new tag to the azurerm_virtual_network" resource block:

~~~ text
resource "azurerm_virtual_network" "vnet1" {
  name                = "${var.myprefix}1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    "env" = "dev"
    "dep" = "001"  <== Add this line
  }
}
~~~

~~~ bash
terraform fmt # format after editing
terraform validate
terraform plan -out tfplan2
terraform apply -auto-approve tfplan2
code tfstate
az network vnet show -g $prefix -n ${prefix}1 --query tags
tree -a -I '.git*' # check your directory after tf init
~~~

Your "az network vent show" output should look as follow:

~~~ json
{
  "dep": "001",
  "env": "dev"
}
~~~

Your directory should look as follow:

~~~ text
.
├── .terraform
│   └── providers
│       └── registry.terraform.io
│           └── hashicorp
│               └── azurerm
│                   └── 3.16.0
│                       └── linux_amd64
│                           └── terraform-provider-azurerm_v3.16.0_x5
├── .terraform.lock.hcl
├── README.md
├── main.tf
├── terraform.tfstate
├── terraform.tfstate.backup
├── tfplan0
├── tfplan1
└── tfplan2
~~~

Verify the terraform.tfstate:

~~~ bash
code terraform.tfstate
jq '.resources[]|select(.type=="azurerm_virtual_network").instances[].attributes.tags' terraform.tfstate # use jq 
~~~

JQ output should look as follow:

~~~ json
{
  "dep": "001",
  "env": "dev"
}
~~~

## Create az vnet outside tf

~~~ bash
az network vnet create -g $prefix -n ${prefix}2 --address-prefixes 10.1.0.0/16
az network vnet list -g $prefix -o table --query '[].{name:name,  rg:resourceGroup, CIDR:addressSpace.addressPrefixes[0]}'
~~~

Vnet list should look as follow:

~~~ text
Name       Rg        CIDR
---------  --------  -----------
azcptdtf1  azcptdtf  10.0.0.0/16
azcptdtf2  azcptdtf  10.1.0.0/16
~~~

Verify if this change does modify our terraform state file:

~~~ bash
jq .resources[].instances[].attributes.id terraform.tfstate # no change
terraform apply -refresh-only # try to refresh state
jq .resources[].instances[].attributes.id terraform.tfstate # no change
terraform plan -out tfplan3 # no changes
terraform apply -auto-approve tfplan3 # no changes
# delete rg via tf with out of sync vnet
terraform destroy -auto-approve # will take ~ 10 min
jq .resources[].instances[].attributes.id terraform.tfstate # tf did delete vnet
az network vnet list -g $prefix -o table # tf vnet deleted
~~~

Terraform output will recommend to add the following azurerm feature:

~~~ text
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
~~~

find more details of this feature under the following link:

~~~ bash
startedgega https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/features-block
~~~

Let´s add the feature:

~~~ bash
# Make sure you added the feature.
terraform fmt
terraform validate
# No plan or apply is needed after the change
terraform destroy -auto-approve # ~ 3 min, delete with provider feature
terraform state list
az group show -n $prefix # not found
~~~

## tf import

During the first destroy command you should have received the following error message:

~~~ text
Error: deleting Resource Group "azcptdtf": the Resource Group still contains Resources.
│ 
│ Terraform is configured to check for Resources within the Resource Group when deleting the Resource Group - and
│ raise an error if nested Resources still exist to avoid unintentionally deleting these Resources.
│ 
│ Terraform has detected that the following Resources still exist within the Resource Group:
│ 
│ * `/subscriptions/<subid>/resourceGroups/azcptdtf/providers/Microsoft.Network/virtualNetworks/azcptdtf2`
~~~

The last line does mention our virtual network resource id which has been created outside of terraform.

Terraform does also offer a way to import resources created outside of terraform.

~~~ bash
startedgega https://www.terraform.io/cli/commands/import # more details if needed.
# Create resources
terraform plan -out tfplan4
terraform apply -auto-approve tfplan4
az network vnet create -g $prefix -n ${prefix}2 --address-prefixes 10.1.0.0/16 # create once more vnet outside of terraform.
az network vnet list -g $prefix -o table
terraform state list
jq .resources[].instances[].attributes.id terraform.tfstate
vnetid=$(az network vnet show -g $prefix -n ${prefix}2 --query id -o tsv) # get azure resource id of new vnet
terraform import azurerm_virtual_network.vnet2 $vnetid
~~~

You should receive the the message to first add the resource block to main.tf.
Add vnet resource to main.tf manually.
Add the following terraform block to the end of main.tf

~~~ text
resource "azurerm_virtual_network" "vnet2" {
  name                = "${var.myprefix}1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    "env" = "dev"
    "dep" = "001"
  }
}
~~~

~~~ bash
terraform import azurerm_virtual_network.vnet2 $vnetid
terraform state list # see both vnets
jq .resources[].instances[].attributes.id terraform.tfstate
jq '.resources[]|select(.type=="azurerm_virtual_network").instances[].attributes.address_space' terraform.tfstate # use jq 
az network vnet list -g $prefix -o table --query '[].{name:name,  rg:resourceGroup, CIDR:addressSpace.addressPrefixes[0]}'
~~~

jq output should look as follow:
~~~ json
[
  "10.0.0.0/16"
]
[
  "10.1.0.0/16"
]
~~~

az network vnet list output should look as follow:

~~~ text
Name       Rg        CIDR
---------  --------  -----------
azcptdtf1  azcptdtf  10.0.0.0/16
azcptdtf2  azcptdtf  10.1.0.0/16
~~~

> IMPORTANT: TF state does match with the az network vnet output. But our terraform main.tf does use the same CIDR/address_space for both.

~~~ bash
terraform plan -out tfplan8 # will replace our new vnet
~~~

Terraform will try to destroy and recreate the vnet because CIDR cannot be modified after creation to get the settings inside main.tf in line with the real state at azure cloud.

~~~ bash
Terraform will perform the following actions:

  # azurerm_virtual_network.vnet2 must be replaced
-/+ resource "azurerm_virtual_network" "vnet2" {
      ~ address_space           = [
          - "10.1.0.0/16",
          + "10.0.0.0/16",
        ]
      ~ dns_servers             = [] -> (known after apply)
      - flow_timeout_in_minutes = 0 -> null
      ~ guid                    = "70dba8ab-9204-47d9-9ab4-b6c002f57eb3" -> (known after apply)
      ~ id                      = "/subscriptions/f474dec9-5bab-47a3-b4d3-e641dac87ddb/resourceGroups/azcptdtf/providers/Microsoft.Network/virtualNetworks/azcptdtf2" -> (known after apply)
      ~ name                    = "azcptdtf2" -> "azcptdtf1" # forces replacement
      ~ subnet                  = [] -> (known after apply)
      ~ tags                    = {
          + "dep" = "001"
          + "env" = "dev"
        }
        # (2 unchanged attributes hidden)

      - timeouts {}
    }

Plan: 1 to add, 0 to change, 1 to destroy.
~~~

This is the end of our demo. Let´s delete all azure resources.

~~~ bash
terraform destroy -auto-approve # 3 min
~~~

Tip: Tools like terraformer can help you to manage imports of multiple resources:
~~~
startedgega https://github.com/GoogleCloudPlatform/terraformer
~~~


## misc

### vscode

~~~ bash
code --diff terraform.tfstate terraform.tfstate.backup
~~~

### terraform tips and tricks

- https://www.terraform.io/internals/debugging
- https://www.terraform.io/language
- https://docs.microsoft.com/en-us/rest/api/storageservices/lease-blob

#### local variables

~~~ text
locals {
  prefix = "azcptdtf1"
}
~~~

#### Credential of provider

~~~ bash
provider "azurerm" {
  subscription_id = "..."
  client_id       = "..."
  client_secret   = "..."
  tenant_id       = "..."
}
~~~

#### Variable order:

- Environment variables
- The terraform.tfvars file, if present.
- The terraform.tfvars.json file, if present.
- Any *.auto.tfvars or *.auto.tfvars.json files, processed in lexical order of their filenames.
- Any -var and -var-file options on the command line, in the order they are provided. (This includes variables set by a Terraform Cloud workspace.)

(source https://www.terraform.io/language/values/variables#variable-definition-precedence)


### git

~~~ bash
# ignore terraform
curl https://www.toptal.com/developers/gitignore/api/terraform > .gitignore

prefix=azcptdtf
gh repo create $prefix --public
git init
git remote add origin https://github.com/cpinotossi/$prefix.git
git status
git add *
git add main.tf
git add .gitignore
git rm .gitignore
git commit -m"fine tune readme"
git push origin main 
git rm README.md # unstage
git --help
~~~