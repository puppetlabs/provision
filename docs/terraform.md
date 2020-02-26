# Litmus Terraform Provisioner

#### Table of Contents

- [Litmus Terraform Provisioner](#litmus-terraform-provisioner)
      - [Table of Contents](#table-of-contents)
  - [Support](#support)
  - [Setup](#setup)
    - [GCP](#gcp)
  - [Default Templates](#default-templates)
    - [GCP](#gcp-1)
  - [Bolt Tasks](#bolt-tasks)
    - [GCP](#gcp-2)
    - [Usage](#usage)
      - [Provision a node](#provision-a-node)
      - [Tear down a node](#tear-down-a-node)
  - [Integration with Litmus](#integration-with-litmus)
    - [GCP](#gcp-3)

## Support

The tasks support the following cloud providers:

  * Google Cloud Platform (GCP)

## Setup

### GCP

In order to provision any infrastructure with the Google Cloud Platform it is necesary for you to provide the following setup by using the [Cloud Console](https://console.cloud.google.com/).

By default the Terraform backend will use the `litmus-compute` identifier for projects and credentials, but you can overwrite this to match your organization's needs.

**Create a Project**

* Create a project named: `litmus-compute`

**Create a Service Account to manage the Project**

* Create a service account under IAM & Admin / Service Account.
    * Service Account Name: `litmus-compute`
    * Servcie Account ID: `limtus-compute`
    * Service Account Description: `Litmus Compute Account`
* Assign the `Role Owner` role to the `litmus-compute` account.
* Create a Key in JSON format and save it under `~/.ssh/litmus-compute.json`

**Create and Register an ssh key**

Follow the instructions provided by https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys. Save your ssh key under `~/.ssh/litmus_compute` and `~/.ssh/litmus_compute.pub`

```bash
ssh-keygen -t rsa -f ~/.ssh/limtus_compute -C litmus
chmod 400 ~/.ssh/litmus_compute
```

Copy and upload your `~/.ssh/litmus_compute.pub` public key using the [Console Metadata Page](https://console.cloud.google.com/compute/metadata/sshKeys).

```bash
# copy the contents of your key file into your Clipboard
cat ~/.ssh/litmus_compute.pub| pbcopy
```

## Default Templates

The tasks provide default templates for `main.tf` and `vars.tf` . These templates are used to provision your infrastructure.

### GCP

**main.tf**

```
cat .terraform/centos-cloud_centos-7-0/main.tf
# Based on the official docs provided by
# https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
}

resource "google_compute_instance" "node" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["litmus"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key)}"
  }

  labels = {
    type       = "litmus"
    created_by = var.created_by
    owner      = var.owner
    build_url  = var.build_url
  }
}

# return a map of
# node name => public ip address
output "node" {
  value = "${
    map(
      google_compute_instance.node.name, google_compute_instance.node.network_interface.0.access_config.0.nat_ip
    )
  }"
}
```

**vars.tr**
```
# Based on the official docs provided by
# https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform

variable "credentials_file" {
  type        = string
  description = "Path to gcp credentials file"
  default     = "~/.ssh/litmus-compute.json"
}

variable "ssh_user" {
  type        = string
  description = "User used to connect via ssh"
  default     = "myuser"
}

variable "ssh_public_key" {
  type        = string
  description = "Path to ssh public key"
  default     = "~/.ssh/litmus_compute.pub"
}

variable "project" {
  type        = string
  description = "Project ID"
  default     = "litmus-compute"
}

variable "zone" {
  type        = string
  description = "Compute Zone where to create the node"
  default     = "us-central1-a"
}

variable "region" {
  type        = string
  description = "Compute Region where to create the node"
  default     = "us-central1"
}

variable "image" {
  type        = string
  description = "The image from which to initialize this disk"
  default     = "centos-cloud/centos-7"
}

variable "machine_type" {
  type        = string
  description = "Type of machine"
  default     = "n1-standard-1"
}

variable "vm_name" {
  type        = string
  description = "The vm identifier"
  default     = "litmus-test-myuser-5459613"
}

variable "created_by" {
  type        = string
  description = "name of the user that created the vm"
  default     = "myuser"
}

variable "owner" {
  type        = string
  description = "Name of the Department/Team that owns this node (optional)"
  default     = "myuser"
}

variable "build_url" {
  type        = string
  description = "URL of the CI job that created the vm (optional)"
  default     = ""
}
```


## Bolt Tasks

### GCP

### Usage

```bash
bolt task show provision::terraform_gcp

provision::terraform_gcp - Provision/Tear down a machine on Google Cloud Platform

USAGE:
bolt task run --targets <node-name> provision::terraform_gcp action=<value> platform=<value> inventory=<value> node_name=<value> credentials_file=<value> project_id=<value> region=<value> zone=<value> machine_type=<value> ssh_user=<value> ssh_private_key=<value> ssh_public_key=<value> ssh_host_key_check=<value> ssh_port=<value> owner=<value> created_by=<value> build_url=<value>
....
```

#### Provision a node

```bash
bolt task run --targets localhost provision::terraform_gcp \
  action=provision platform=centos-cloud/centos-7

Started on localhost...
Finished on localhost:
  {
    "status": "ok",
    "node_name": "litmus-test-username-c5ac93c1130bcdab",
    "node": "35.223.191.200"
  }
Successful on 1 target: localhost
Ran on 1 target in 27.3 sec
```

You can provide custom main.tf and vars.tf templates

```bash
bolt task run --targets localhost provision::terraform_gcp \
  action=provision \
  platform=centos-cloud/centos-7 \
  vm_name=foobar \
  main_template=main.tf.erb \
  vars_template=vars.tf.erb

```

#### Tear down a node

```bash
bolt task run --targets localhost provision::terraform_gcp \
  action=tear_down \
  node_name=35.223.191.200

```

## Integration with Litmus

### GCP

Provision one node in GCP using the latest Centos 7 Image.

```bash
bundle exec rake 'litmus:provision[terraform_gcp, centos-cloud/centos-7]'
```

Provision one node in GCP using a `provision.yml` file.

```bash
bundle exec rake 'litmus:provision_list[gcp]'
```

```yaml
gcp:
  provisioner: terraform_gcp
  images: ['centos-cloud/centos-7', 'centos-cloud/centos-6']
  params:
    inventory: '.'
    credentials_file: '~/.ssh/litmus-compute.json'
    project_id: 'litmus-compute'
    node_name: 'litmus-test'
    created_by: My Name
    region: 'us-central1'
    zone: 'us-central1-a'
    machine_type: 'n1-standard-1'
    ssh_user: my-ssh-user
    ssh_public_key: '~/.ssh/id_rsa.pub'
    ssh_host_key_check: false
    owner: Team Awesome
    build_url: http://my-jenkins/build/25
    ssh_port: 22
```

You can customize the templates used to initialize the Terraform project by passing the `main_template` and `vars_template` parameters.

```yaml
gcp:
  provisioner: terraform_gcp
  images: ['centos-cloud/centos-7']
  params:
    ...
    main_template: 'spec/acceptance/nodeset/centos-7.tf.erb'
    vars_template: 'spec/acceptance/nodeset/vars.tf.erb'
```

