<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v3.2.0](https://github.com/puppetlabs/provision/tree/v3.2.0) - 2026-10-29

[Full Changelog](https://github.com/puppetlabs/provision/compare/v3.1.0...v3.2.0)

### Added

- Add optional per-job disk_size_gb to provision_service task [#303](https://github.com/puppetlabs/provision/pull/303) ([LukasAud](https://github.com/LukasAud))

## [v3.1.0](https://github.com/puppetlabs/provision/tree/v3.1.0) - 2026-10-23

[Full Changelog](https://github.com/puppetlabs/provision/compare/v3.0.1...v3.1.0)

### Added

- (MAINT) Add optional per-job machine_type to provision_service task [#301](https://github.com/puppetlabs/provision/pull/301) ([lynsaywright](https://github.com/lynsaywright))
- (maint) Handle puppetcore9-nightly -> puppet9-nightly collection conversion [#295](https://github.com/puppetlabs/provision/pull/295) ([span786](https://github.com/span786))
- (CAT-2590) Prepare for Puppetcore 9 [#292](https://github.com/puppetlabs/provision/pull/292) ([LukasAud](https://github.com/LukasAud))
- (PE-39952) Add PE os version [#280](https://github.com/puppetlabs/provision/pull/280) ([seamymckenna](https://github.com/seamymckenna))

### Fixed

- Remove unused legacy codecov gem from Gemfile [#299](https://github.com/puppetlabs/provision/pull/299) ([LukasAud](https://github.com/LukasAud))
- (MODULES-11965) Retry provision_service on HTTP 5xx [#298](https://github.com/puppetlabs/provision/pull/298) ([imaqsood](https://github.com/imaqsood))
- (P4DEVOPS-15381) Fix ABS priority: CI runs no longer request priority 1 [#294](https://github.com/puppetlabs/provision/pull/294) ([isaac-jha](https://github.com/isaac-jha))
- PA-7893 Update puppetserver package fetching urls [#289](https://github.com/puppetlabs/provision/pull/289) ([SugatD](https://github.com/SugatD))
- (CAT-2193): Added codename for Debian 11 & 12 [#281](https://github.com/puppetlabs/provision/pull/281) ([span786](https://github.com/span786))

## [v3.0.1](https://github.com/puppetlabs/provision/tree/v3.0.1) - 2024-10-28

[Full Changelog](https://github.com/puppetlabs/provision/compare/v3.0.0...v3.0.1)

### Fixed

- (MAINT) Install Puppet Server Task [#277](https://github.com/puppetlabs/provision/pull/277) ([coreymbe](https://github.com/coreymbe))

## [v3.0.0](https://github.com/puppetlabs/provision/tree/v3.0.0) - 2024-10-28

[Full Changelog](https://github.com/puppetlabs/provision/compare/v2.1.1...v3.0.0)

### Changed

- (CAT-1264) - Drop Support for EOL Windows 2008 R2, Debian 8 + Ubuntu 16.04 [#231](https://github.com/puppetlabs/provision/pull/231) ([jordanbreen28](https://github.com/jordanbreen28))

### Added

- (MAINT) Support for Puppet Server on Ubuntu 22.04 [#273](https://github.com/puppetlabs/provision/pull/273) ([coreymbe](https://github.com/coreymbe))
- (CAT-372) - add var support to vagrant provisioner [#264](https://github.com/puppetlabs/provision/pull/264) ([jordanbreen28](https://github.com/jordanbreen28))
- Uncouple from the puppet_litmus gem [#260](https://github.com/puppetlabs/provision/pull/260) ([h0tw1r3](https://github.com/h0tw1r3))
- tasks require path to inventory yaml [#259](https://github.com/puppetlabs/provision/pull/259) ([h0tw1r3](https://github.com/h0tw1r3))
- LXD provisoner support [#251](https://github.com/puppetlabs/provision/pull/251) ([h0tw1r3](https://github.com/h0tw1r3))
- (CAT-1264) - Add Support for CentOS 8, RHEL 8/9, Debian 10/11, Ubuntu 18/20/22, Windows 16/19/22 [#232](https://github.com/puppetlabs/provision/pull/232) ([jordanbreen28](https://github.com/jordanbreen28))
- docker context and DOCKER_HOST env support [#200](https://github.com/puppetlabs/provision/pull/200) ([h0tw1r3](https://github.com/h0tw1r3))

### Fixed

- (bug) - Fix empty inventory [#271](https://github.com/puppetlabs/provision/pull/271) ([jordanbreen28](https://github.com/jordanbreen28))
- (CAT-1958) - Fix 404 on teardown of abs node [#270](https://github.com/puppetlabs/provision/pull/270) ([jordanbreen28](https://github.com/jordanbreen28))
- fix tear_down from puppet_litmus [#268](https://github.com/puppetlabs/provision/pull/268) ([h0tw1r3](https://github.com/h0tw1r3))
- fix provision on dnf only platforms [#261](https://github.com/puppetlabs/provision/pull/261) ([h0tw1r3](https://github.com/h0tw1r3))
- fix bolt tasks with docker_exp transport [#258](https://github.com/puppetlabs/provision/pull/258) ([h0tw1r3](https://github.com/h0tw1r3))
- fix redhat distribution not supported [#255](https://github.com/puppetlabs/provision/pull/255) ([h0tw1r3](https://github.com/h0tw1r3))
- fix sles ssh setup in docker if ssh already installed [#254](https://github.com/puppetlabs/provision/pull/254) ([h0tw1r3](https://github.com/h0tw1r3))
- (CAT-1688) - Pin rubocop to `~> 1.50.0` [#249](https://github.com/puppetlabs/provision/pull/249) ([LukasAud](https://github.com/LukasAud))
- Fix docker remote host support [#247](https://github.com/puppetlabs/provision/pull/247) ([seanmil](https://github.com/seanmil))

### Other

- Add additional Docker provisioner OS support [#244](https://github.com/puppetlabs/provision/pull/244) ([seanmil](https://github.com/seanmil))
- Add flexible Linux box support for Vagrant [#242](https://github.com/puppetlabs/provision/pull/242) ([seanmil](https://github.com/seanmil))

## [v2.1.1](https://github.com/puppetlabs/provision/tree/v2.1.1) - 2023-07-27

[Full Changelog](https://github.com/puppetlabs/provision/compare/v2.1.0...v2.1.1)

### Fixed

- (CAT-1253) - Fixes undefined variable in vagrant provisioner [#228](https://github.com/puppetlabs/provision/pull/228) ([jordanbreen28](https://github.com/jordanbreen28))

## [v2.1.0](https://github.com/puppetlabs/provision/tree/v2.1.0) - 2023-07-25

[Full Changelog](https://github.com/puppetlabs/provision/compare/v2.0.0...v2.1.0)

### Added

- (maint) - Add connect-timeout to transport [#216](https://github.com/puppetlabs/provision/pull/216) ([jordanbreen28](https://github.com/jordanbreen28))

### Fixed

- (CONT-1241) - Retrying when response body is nil or empty but response code is 200 [#221](https://github.com/puppetlabs/provision/pull/221) ([Ramesh7](https://github.com/Ramesh7))

## [v2.0.0](https://github.com/puppetlabs/provision/tree/v2.0.0) - 2023-05-04

[Full Changelog](https://github.com/puppetlabs/provision/compare/v1.0.0...v2.0.0)

### Changed

- (CONT-809) Add Puppet 8 support [#205](https://github.com/puppetlabs/provision/pull/205) ([GSPatton](https://github.com/GSPatton))

## [v1.0.0](https://github.com/puppetlabs/provision/tree/v1.0.0) - 2023-05-03

[Full Changelog](https://github.com/puppetlabs/provision/compare/254ad83d7bea85d163c3a6399dc86025af733cd3...v1.0.0)
