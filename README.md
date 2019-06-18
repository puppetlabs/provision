
# Provision

Simple tasks to provision and tear_down containers / instances and virtual machines.

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with provision](#setup)
    * [Setup requirements](#setup-requirements)
3. [Usage - Configuration options and additional functionality](#usage)
    * [ABS](#abs)
    * [Docker](#docker)
    * [Vagrant](#vagrant)
    * [Vmpooler](#vmpooler)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

Bolt tasks allowing a user to provision and tear down systems. It also maintains a Bolt inventory file.
Provisioners so far:
   
* ABS (AlwaysBeScheduling)
* Docker
* Vmpooler (internal to puppet)

## Setup

### Setup Requirements

Bolt to be installed to run the tasks. Each provisioner has its own requirements. From having Docker to installed or access to private infrastructure. 

## Usage

There is a basic workflow.

* provision - creates / initiates a platform and edits a bolt inventory file. 
* tear_down - creates / initiates a system / container and edits a bolt inventory file. 

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

#### Hyper-V Provider

This task can also be used against a Windows host to utilize Hyper-V Vagrant boxes.
When provisioning, a few additional parameters need to be passed:

- `hyperv_vswitch`, which specifies the Hyper-V Virtual Switch to assign the VM.
  If you do not specify one the [`Default Switch`](https://searchenterprisedesktop.techtarget.com/blog/Windows-Enterprise-Desktop/Default-Switch-Makes-Hyper-V-Networking-Dead-Simple) will be used.
- `hyperv_smb_username` and `hyperv_smb_password`, which ensure the synced folder works correctly.
  If these parameters are omitted when provisioning on Windows Vagrant will try to prompt for input and the task will hang indefinitely until it finally times out.
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

### Vmpooler

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

Testing/development using ruby,  you will need to pass the json parameters.

```
$ bundle exec ruby tasks/vmpooler.rb 
<ENTER>
{ "platform": "ubuntu-1604-x86_64", "action": "provision", "inventory": "/Users/tp/workspace/git/provision" } 
<ENTER>
<CTRL + d>
```

Testing using bolt, the second step
```
$ bundle exec bolt --modulepath /Users/tp/workspace/git/ task run provision::docker --nodes localhost  action=provision platform=ubuntu:14.04 inventory=/Users/tp/workspace/git/provision
```
