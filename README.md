
# waffle_provision

Simple tasks to provision and tear_down containers / instances and virtual machines.

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with waffle_provision](#setup)
    * [Setup requirements](#setup-requirements)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

Bolt tasks allowing a user to provision and tear down systems. It also maintains a Bolt inventory file.
Provisioners so far:
   
* Docker
* Vmpooler (internal to puppet)

## Setup

### Setup Requirements

Bolt to be installed to run the tasks. Each provisioner has its own requirements. From having Docker to installed or access to private infrastructure. 

## Usage

There is a basic workflow.

* provision - creates / initiates a platform and edits a bolt inventory file. 
* tear_down - creates / initiates a system / container and edits a bolt inventory file. 

### Docker

Given an docker image name it will spin up that container and setup external ssh on that platform. 

provision

```
bundle exec bolt --modulepath /Users/tp/ task run waffle_provision::docker --nodes localhost action=provision platform=ubuntu:14.04 inventory=/Users/tp/
```

tear_down

```
bundle exec bolt --modulepath /Users/tp/workspace/git/ task run waffle_provision::docker --nodes localhost  action=tear_down inventory=/Users/tp/workspace/git/waffle_provision node_name=localhost:2222
```

### Vmpooler

Check http://vcloud.delivery.puppetlabs.net/vm/ for the list of availible platforms. 

```
 bundle exec bolt --modulepath /Users/tp/workspace/git/ task run waffle_provision::vmpooler --nodes localhost  action=provision platform=ubuntu-1604-x86_64 inventory=/Users/tp/
```

## Limitations

* The docker task only supports linux
* The docker task uses port forwarding, not internal ip addresses. This is because of limitations when running on the mac.


## Development

Testing/development using ruby,  you will need to pass the json parameters.

```
bundle exec ruby tasks/vmpooler.rb 
<ENTER>
{ "platform": "ubuntu-1604-x86_64", "action": "provision", "inventory": "/Users/tp/workspace/git/waffle_provision" } 
<ENTER>
<CTRL + d>
```

Testing using bolt, the second step
```
bundle exec bolt --modulepath /Users/tp/workspace/git/ task run waffle_provision::docker --nodes localhost  action=provision platform=ubuntu:14.04 inventory=/Users/tp/workspace/git/waffle_provision
```
