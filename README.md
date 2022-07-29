# Terraform samples

## Install Terraform

MacOS:

~~~ bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
~~~

Ubuntu distribution:

~~~ bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add –
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
~~~

Windows:

~~~ powershell
choco install terraform
~~~

## Create a RG

~~~ bash
terraform {
    required_version = “~>v0.13.0”
    required_providers {
    azurerm = {
      version = "~> 2.36.0"
      source = "hashicorp/azurerm"
    }
  }
}
~~~