
# Provision

Simple tasks to provision and tear_down containers / instances and virtual machines.

#### Table of Contents

- [Provision](#provision)
      - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Setup](#setup)
    - [Setup Requirements](#setup-requirements)
      - [Running the tasks as part of puppet_litmus](#running-the-tasks-as-part-of-puppetlitmus)
      - [Running the module stand-alone call the tasks/plans directly](#running-the-module-stand-alone-call-the-tasksplans-directly)
  - [Usage](#usage)
    - [ABS](#abs)
      - [Setting up your Token](#setting-up-your-token)
      - [Running the Commands](#running-the-commands)
        - [Setting up a new macine](#setting-up-a-new-macine)
        - [Tearing down a finished machine](#tearing-down-a-finished-machine)
    - [Docker](#docker)
    - [Vagrant](#vagrant)
      - [Synced Folders](#synced-folders)
      - [Hyper-V Provider](#hyper-v-provider)
    - [Terraform](#terraform)
    - [Vmpooler](#vmpooler)
  - [Limitations](#limitations)
  - [Development](#development)

## Description

Bolt tasks allowing a user to provision and tear down systems. It also maintains a Bolt inventory file.
Provisioners so far:

* ABS (AlwaysBeScheduling)
* Docker
* Vagrant
* Terraform
* Vmpooler (internal to puppet)

## Setup

### Setup Requirements

Bolt has to be installed to run the tasks. Each provisioner has its own requirements. From having Docker to installed or access to private infrastructure.

#### Running the tasks as part of puppet_litmus

Please follow the documentation here https://github.com/puppetlabs/puppet_litmus/wiki/Converting-a-module-to-use-Litmus#fixturesyml

#### Running the module stand-alone call the tasks/plans directly

For provisioning to work you will need to have a number of other modules available. Using bolt to install the modules for you, your puppet file https://puppet.com/docs/bolt/latest/installing_tasks_from_the_forge.html The required modules are:

```
cat $HOME/.puppetlabs/bolt/Puppetfile
mod 'puppetlabs-puppet_agent'
mod 'puppetlabs-facts'
mod 'puppetlabs-puppet_conf'
```

## Usage

There is a basic workflow for the provision tasks.

* provision - creates / initiates a platform and edits a bolt inventory file.
* tear_down - creates / initiates a system / container and edits a bolt inventory file.

For extended functionality please look at the wiki https://github.com/puppetlabs/provision/wiki

### ABS

(internal to puppet) Allows you to provision machines on puppets internal pooler. Reads the '~/.fog' file for your authentication token.

#### Setting up your Token

In order to run ABS you first require an access token stored within your '.fog' file. If you already have one you may skip this section, otherwise request one by running the following command, changing the username.


```
$ curl -X POST -d '' -u tp --url https://test-example.abs.net/api/v2/token
Enter host password for user 'tp':
{
  "ok": true,
  "token": "0pd263lej948h28493692r07"
}%
```

Now that you have your token, check that it works by running:

```
$ curl --url https://test-example.abs.net/api/v2/token/0pd263lej948h28493692r07
{
  "ok": true,
  "user": "tp",
  "created": "2019-01-04 14:25:55 +0000",
  "last_accessed": "2019-01-04 14:26:27 +0000"
}%
```

Finally all that you have left to do is to place your new token into your '.fog' file as shown below:
```
$ cat ~/.fog
:default:
  :abs_token: 0pd263lej948h28493692r07
```

#### Running the Commands

##### Setting up a new macine

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::abs --nodes localhost action=provision platform=ubuntu-1604-x86_64 inventory=/Users/tp/workspace/git/provision

Started on localhost...
Finished on localhost:
  {
    "status": "ok",
    "node_name": "yh6f4djvz7o3te6.delivery.puppetlabs.net"
  }
Successful on 1 node: localhost
Ran on 1 node in 1.44 seconds
```

##### Tearing down a finished machine

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::abs --nodes localhost  action=tear_down inventory=/Users/tp/workspace/git/provision node_name=yh6f4djvz7o3te6.delivery.puppetlabs.net

Started on localhost...
Finished on localhost:
  Removed yh6f4djvz7o3te6.delivery.puppetlabs.net
  {"status":"ok"}
  {
  }
Successful on 1 node: localhost
Ran on 1 node in 1.54 seconds
```

### Docker

Given an docker image name it will spin up that container and setup external ssh on that platform. For helpful docker tips look [here](https://github.com/puppetlabs/litmus_image/blob/master/README.md)

provision

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::docker --nodes localhost  action=provision platform=ubuntu:14.04 inventory=/Users/tp/workspace/git/provision

Started on localhost...
Finished on localhost:
  Provisioning ubuntu_14.04-2222
  {"status":"ok","node_name":"localhost"}
  {
  }
Successful on 1 node: localhost
Ran on 1 node in 33.96 seconds
```

tear_down

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::docker --nodes localhost  action=tear_down inventory=/Users/tp/workspace/git/provision node_name=localhost:2222

Started on localhost...
Finished on localhost:
  Removed localhost:2222
  {"status":"ok"}
  {
  }
Successful on 1 node: localhost
Ran on 1 node in 2.02 seconds
```

### Vagrant

Tested with vagrant images:
  * ubuntu/trusty64
  * ubuntu/xenial64
  * ubuntu/bionic64
  * debian/jessie64
  * centos/7

provision

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::vagrant --nodes localhost  action=provision platform=ubuntu/xenial64 inventory=/Users/tp/workspace/git/provision

Started on localhost...
Finished on localhost:
  {
    "status": "ok",
    "node_name": "127.0.0.1:2222"
  }
Successful on 1 node: localhost
Ran on 1 node in 51.98 seconds
```

tear_down
```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::vagrant --nodes localhost  action=tear_down inventory=/Users/tp/workspace/git/provision node_name=127.0.0.1:2222

Started on localhost...
Finished on localhost:
  Removed 127.0.0.1:2222
  {"status":"ok"}
  {
  }
Successful on 1 node: localhost
Ran on 1 node in 4.52 seconds
```

#### Synced Folders

By default the task will provision a Vagrant box with the [synced folder]() **disabled**.
To enable the synced folder you must specify the parameter `enable_synced_folder` as `true`.
Instead of passing this parameter directly you can instead specify the environment variable `LITMUS_ENABLE_SYNCED_FOLDER` as `true`.

#### Hyper-V Provider

This task can also be used against a Windows host to utilize Hyper-V Vagrant boxes.
When provisioning, a few additional parameters need to be passed:

- `hyperv_vswitch`, which specifies the Hyper-V Virtual Switch to assign the VM.
  If you do not specify one the [`Default Switch`](https://searchenterprisedesktop.techtarget.com/blog/Windows-Enterprise-Desktop/Default-Switch-Makes-Hyper-V-Networking-Dead-Simple) will be used.
- `hyperv_smb_username` and `hyperv_smb_password`, which ensure the synced folder works correctly (only neccessary is `enable_synced_folder` is `true`).
  If these parameters are omitted when provisioning on Windows and using synced folders Vagrant will try to prompt for input and the task will hang indefinitely until it finally times out.
  The context in which a Bolt task is run does not allow for mid-task input.

Instead of passing them as parameters directly they can also be passed as environment variables:

- `LITMUS_HYPERV_VSWITCH` for `hyperv_vswitch`
- `HYPERV_SMB_USERNAME` for `hyperv_smb_username`
- `HYPERV_SMB_PASSWORD` for `hyperv_smb_password`

provision

```
PS> $env:LITMUS_HYPERV_VSWITCH = 'internal_nat'
PS> bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::vagrant --nodes localhost  action=provision platform=centos/7 inventory=/Users/tp/workspace/git/provision hyperv_smb_username=tp hyperv_smb_password=notMyrealPassword

Started on localhost...
Finished on localhost:
  {
    "status": "ok",
    "node_name": "127.0.0.1:2222"
  }
Successful on 1 node: localhost
Ran on 1 node in 51.98 seconds
```

Using the `tear_down` task is the same as on Linux or MacOS.

### Terraform

Allows the user to provision the required infrastructure using [Terraform](https://www.terraform.io/).

Read more about this provisioner under [docs/terraform.md](docs/terraform.md)

### Vmpooler

*Warning* this is currently setup to work with puppet's internal infrasture, its behaviour can be modified below.
It will utilise a $home/.fog file. Have a look here https://confluence.puppetlabs.com/display/SRE/Generating+and+using+vmpooler+tokens
Check http://vcloud.delivery.puppetlabs.net/vm/ for the list of availible platforms.
Environment variables, can modify its behaviour:
VMPOOLER_HOSTNAME, will change the default hostname used to connect to the vmpooler instance.
```
export VMPOOLER_HOSTNAME=vcloud.delivery.puppetlabs.net
```

provision

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::vmpooler --nodes localhost  action=provision platform=ubuntu-1604-x86_64 inventory=/Users/tp/workspace/git/provision

Started on localhost...
Finished on localhost:
  {
    "status": "ok",
    "node_name": "gffzr8c3gipetkp.delivery.puppetlabs.net"
  }
Successful on 1 node: localhost
Ran on 1 node in 1.46 seconds
```

tear_down

```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::vmpooler --nodes localhost  action=tear_down inventory=/Users/tp/workspace/git/provision node_name=gffzr8c3gipetkp.delivery.puppetlabs.net
Started on localhost...
Finished on localhost:
  Removed gffzr8c3gipetkp.delivery.puppetlabs.net
  {"status":"ok"}
  {
  }
Successful on 1 node: localhost
Ran on 1 node in 1.45 seconds
```

## Limitations

* The docker task only supports linux
* The docker task uses port forwarding, not internal ip addresses. This is because of limitations when running on the mac.


## Development

Configure your local development environment by running one of the `provision:development` rake tasks.

```bash
$ rake -vT | grep provision:development
rake provision:development:link     # Link current module to $HOME/.puppetlabs/bolt/site-modules/
rake provision:development:setup    # Setup minimal development requirements
rake provision:development:unlink   # Unlink current module from $HOME/.puppetlabs/bolt/site-modules/provision
```

Running `rake provision::development:setup` will make the tasks included in this repository available to your console.

```bash
➜  provision git:(feature/my-feature) ✗ bolt task show | grep provision
provision::abs              Provision/Tear down a machine using abs
provision::docker           Provision/Tear down a machine on docker
provision::docker_exp       Provision/Tear down a machine on docker
provision::install_pe       Installs PE on a target
provision::run_tests        Run rspec tests against a target machine
provision::terraform_gcp    Provision/Tear down a machine on Google Cloud Platform
provision::update_node_pp   Creates a manifest file for a target node on pe server
provision::update_site_pp   Updates the site.pp on a target
provision::vagrant          Provision/Tear down a machine on vagrant
provision::vmpooler         Provision/Tear down a machine on vmpooler
```

Alternative you can execute ruby directly, you will need to pass the json parameters. Depending on how you are running (using a puppet file or as part of a puppet_litmus). The dependencies of provision will need to be availible. See the setup section above.

```
# powershell
 echo '{ "platform": "ubuntu-1604-x86_64", "action": "provision", "inventory": "c:\\workspace\\puppetlabs-motd\\" }' | bundle exec ruby .\spec\fixtures\modules\provision\tasks\vmpooler.rb
# bash / zshell ...
 echo '{ "platform": "ubuntu-1604-x86_64", "action": "provision", "inventory": "/home/tp/workspace/puppetlabs-motd/" }' | bundle exec ruby spec/fixtures/modules/provision/tasks/vmpooler.rb
```

Testing using bolt, the second step
```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::docker --nodes localhost  action=provision platform=ubuntu:14.04 inventory=/Users/tp/workspace/git/provision
```

