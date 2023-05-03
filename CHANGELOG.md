# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v1.0.0](https://github.com/puppetlabs/provision/tree/v1.0.0) (2023-05-03)

[Full Changelog](https://github.com/puppetlabs/provision/compare/254ad83d7bea85d163c3a6399dc86025af733cd3...v1.0.0)

### Changed

- \(feat\) move to v2 of the bolt inventory file [\#93](https://github.com/puppetlabs/provision/pull/93) ([tphoney](https://github.com/tphoney))

### Added

- Docker SSH forwarding port allocations [\#183](https://github.com/puppetlabs/provision/pull/183) ([hsnodgrass](https://github.com/hsnodgrass))
- \(IAC-1751/IAC-1752\) Add support for Rocky and AlmaLinux 8 to the docker provision task [\#179](https://github.com/puppetlabs/provision/pull/179) ([david22swan](https://github.com/david22swan))
- \(feat\) - Add updated Server/Agent setup plans to provision [\#175](https://github.com/puppetlabs/provision/pull/175) ([david22swan](https://github.com/david22swan))
- Allow provision service dev box provisioning with github token [\#174](https://github.com/puppetlabs/provision/pull/174) ([carabasdaniel](https://github.com/carabasdaniel))
- Add Vagrant provisioner compatibility for additional distros [\#169](https://github.com/puppetlabs/provision/pull/169) ([seanmil](https://github.com/seanmil))
- Add vagrant options [\#168](https://github.com/puppetlabs/provision/pull/168) ([seanmil](https://github.com/seanmil))
- Improve puppetserver install task [\#163](https://github.com/puppetlabs/provision/pull/163) ([adrianiurca](https://github.com/adrianiurca))
- Add install\_puppetserver task [\#158](https://github.com/puppetlabs/provision/pull/158) ([adrianiurca](https://github.com/adrianiurca))
- README.md: update link to Litmus documentation; spelling corrections [\#149](https://github.com/puppetlabs/provision/pull/149) ([kenyon](https://github.com/kenyon))
- \(feat\) allow abs to provision multiple of machines [\#146](https://github.com/puppetlabs/provision/pull/146) ([tphoney](https://github.com/tphoney))
- Add propagating the honeycomb trace context to the provision calls [\#145](https://github.com/puppetlabs/provision/pull/145) ([DavidS](https://github.com/DavidS))
- \(feat\) Allow for passing docker runtime options [\#143](https://github.com/puppetlabs/provision/pull/143) ([jarretlavallee](https://github.com/jarretlavallee))
- Add target\_names to bolt response for connectivity check [\#141](https://github.com/puppetlabs/provision/pull/141) ([DavidS](https://github.com/DavidS))
- \(feat\) allow ABS to accept bolt vars [\#126](https://github.com/puppetlabs/provision/pull/126) ([tphoney](https://github.com/tphoney))
- pdksync - \(IAC-973\) - Update travis/appveyor to run on new default branch `main` [\#124](https://github.com/puppetlabs/provision/pull/124) ([david22swan](https://github.com/david22swan))
- Make use of ABS Priority Queuing [\#123](https://github.com/puppetlabs/provision/pull/123) ([sanfrancrisko](https://github.com/sanfrancrisko))
- \(feat\) add in amazonlinux 2 compatibility [\#121](https://github.com/puppetlabs/provision/pull/121) ([tphoney](https://github.com/tphoney))
- Allow abs provider task to get token from fog file and set priority [\#115](https://github.com/puppetlabs/provision/pull/115) ([carabasdaniel](https://github.com/carabasdaniel))
- Add task to fix sudo's secure\_path [\#113](https://github.com/puppetlabs/provision/pull/113) ([tom-krieger](https://github.com/tom-krieger))
- docker: support podman; improve handling of OS distribution/version for non-litmusimage images [\#112](https://github.com/puppetlabs/provision/pull/112) ([reenberg](https://github.com/reenberg))
- Add vars support to the docker provisioner [\#96](https://github.com/puppetlabs/provision/pull/96) ([rtib](https://github.com/rtib))
- \(MODULES-10415\) add params for vagrant: provider, cpus & memory [\#91](https://github.com/puppetlabs/provision/pull/91) ([zoojar](https://github.com/zoojar))
- Clean up SSH setup on docker provisioning [\#77](https://github.com/puppetlabs/provision/pull/77) ([ekohl](https://github.com/ekohl))
- Support EL8 for Docker provisioning [\#72](https://github.com/puppetlabs/provision/pull/72) ([treydock](https://github.com/treydock))

### Fixed

- \(CONT-953\) Fix bad include method [\#210](https://github.com/puppetlabs/provision/pull/210) ([GSPatton](https://github.com/GSPatton))
- Fixed: tasks/docker.rb [\#209](https://github.com/puppetlabs/provision/pull/209) ([shaun-rutherford](https://github.com/shaun-rutherford))
- \(Maint\) - remove deb family system volume [\#203](https://github.com/puppetlabs/provision/pull/203) ([jordanbreen28](https://github.com/jordanbreen28))
- \(GH-187\) Fixes abs failing provision if inventory file exists [\#190](https://github.com/puppetlabs/provision/pull/190) ([jpartlow](https://github.com/jpartlow))
- \(maint\) Fix Rocky and AlmaLinux support [\#180](https://github.com/puppetlabs/provision/pull/180) ([david22swan](https://github.com/david22swan))
- \[SEC-892 \] Remove hard-coded passwords from abs provision task [\#177](https://github.com/puppetlabs/provision/pull/177) ([carabasdaniel](https://github.com/carabasdaniel))
- \(REPLATS-169\) Add a timestamp to abs job\_id [\#166](https://github.com/puppetlabs/provision/pull/166) ([jpartlow](https://github.com/jpartlow))
- \(GH-380\) Moving inventory.yaml to /spec/fixtures/litmus\_inventory.yaml [\#161](https://github.com/puppetlabs/provision/pull/161) ([pmcmaw](https://github.com/pmcmaw))
- Fix typo from rubocop fixes in docker provisioner [\#150](https://github.com/puppetlabs/provision/pull/150) ([DavidS](https://github.com/DavidS))
- misc provision\_service improvements [\#140](https://github.com/puppetlabs/provision/pull/140) ([DavidS](https://github.com/DavidS))
- \(MAINT\) Update Docker provisioner image name gsub with '.' [\#136](https://github.com/puppetlabs/provision/pull/136) ([sanfrancrisko](https://github.com/sanfrancrisko))
- \(maint\) - Fix for Docker Oracle Linux 6 [\#135](https://github.com/puppetlabs/provision/pull/135) ([david22swan](https://github.com/david22swan))
- \(IAC-1229\) - Fix for Docker Oracle Linux [\#134](https://github.com/puppetlabs/provision/pull/134) ([david22swan](https://github.com/david22swan))
- \(IAC-1227\) fallback to imagename-based platform calculation for images that don't have `/etc/os-release` [\#133](https://github.com/puppetlabs/provision/pull/133) ([david22swan](https://github.com/david22swan))
- Fix amazonlinux detection [\#132](https://github.com/puppetlabs/provision/pull/132) ([DavidS](https://github.com/DavidS))
- Fix typo in readme [\#120](https://github.com/puppetlabs/provision/pull/120) ([DavidS](https://github.com/DavidS))
- Keep Job ID unique and output received messages from ABS [\#119](https://github.com/puppetlabs/provision/pull/119) ([carabasdaniel](https://github.com/carabasdaniel))
- \(IAC-822\) Improve robustness of ABS API retry loop [\#116](https://github.com/puppetlabs/provision/pull/116) ([sanfrancrisko](https://github.com/sanfrancrisko))
- \(bugfix\) change the server url for pe [\#107](https://github.com/puppetlabs/provision/pull/107) ([tphoney](https://github.com/tphoney))
- \(MAINT\) Fix vagrant provision on Windows [\#104](https://github.com/puppetlabs/provision/pull/104) ([michaeltlombardi](https://github.com/michaeltlombardi))
- Fix vagrant provisioner to run with spaces in arguments [\#101](https://github.com/puppetlabs/provision/pull/101) ([ghost](https://github.com/ghost))
- Error reporting and centos:6 handling [\#92](https://github.com/puppetlabs/provision/pull/92) ([DavidS](https://github.com/DavidS))
- \(bugfix\) update\_node\_pp, will append to the manifest file [\#88](https://github.com/puppetlabs/provision/pull/88) ([tphoney](https://github.com/tphoney))
- Fix quoting on centos docker provisioning. Solves "unexpected EOF while looking for matching `''" error on Windows 10 [\#86](https://github.com/puppetlabs/provision/pull/86) ([JohnEricson](https://github.com/JohnEricson))
- \(maint\) force rebuild of rpmdb [\#85](https://github.com/puppetlabs/provision/pull/85) ([DavidS](https://github.com/DavidS))
- \(maint\) remove ESM apt source for ubuntu 14.04 [\#84](https://github.com/puppetlabs/provision/pull/84) ([DavidS](https://github.com/DavidS))
- \(MODULES-10045\) Add check/alert for vagrant version [\#81](https://github.com/puppetlabs/provision/pull/81) ([michaeltlombardi](https://github.com/michaeltlombardi))
- \(maint\) Use a default for inventory location [\#79](https://github.com/puppetlabs/provision/pull/79) ([glennsarti](https://github.com/glennsarti))
- use the latest pe [\#76](https://github.com/puppetlabs/provision/pull/76) ([tphoney](https://github.com/tphoney))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- \(MAINT\) Support Puppet 8 [\#208](https://github.com/puppetlabs/provision/pull/208) ([coreymbe](https://github.com/coreymbe))
- Add ENV var for ABS Polling Duration [\#201](https://github.com/puppetlabs/provision/pull/201) ([seamymckenna](https://github.com/seamymckenna))
- add snyk [\#196](https://github.com/puppetlabs/provision/pull/196) ([LivingInSyn](https://github.com/LivingInSyn))
- \(SUP-2952\) \(Issue \#193\) - Retry if provisioning target returns a 500  [\#194](https://github.com/puppetlabs/provision/pull/194) ([BartoszBlizniak](https://github.com/BartoszBlizniak))
- \(maint\) Allow setting of abs subdomain [\#189](https://github.com/puppetlabs/provision/pull/189) ([jpartlow](https://github.com/jpartlow))
- \(maint\) Change references to facter\_task to be provision [\#188](https://github.com/puppetlabs/provision/pull/188) ([jpartlow](https://github.com/jpartlow))
- \(maint\) Add a spec case for the provision::abs task [\#186](https://github.com/puppetlabs/provision/pull/186) ([jpartlow](https://github.com/jpartlow))
- \(bug\) Fix abs checkout when 'ABS\_SSH\_PRIVATE\_KEY' is unset [\#185](https://github.com/puppetlabs/provision/pull/185) ([MikaelSmith](https://github.com/MikaelSmith))
- \(feat\) Add ssh key support to abs ssh transport [\#182](https://github.com/puppetlabs/provision/pull/182) ([jpartlow](https://github.com/jpartlow))
- \(maint\) Update default PE to 2019.8 [\#153](https://github.com/puppetlabs/provision/pull/153) ([da-ar](https://github.com/da-ar))
- \(CISC-973\) Handle vars in gcp provisioner [\#152](https://github.com/puppetlabs/provision/pull/152) ([HelenCampbell](https://github.com/HelenCampbell))
- Docker run opts [\#151](https://github.com/puppetlabs/provision/pull/151) ([hajee](https://github.com/hajee))
- Update to puppet-module-gems 1.0, pdk-templates and new rubocop [\#148](https://github.com/puppetlabs/provision/pull/148) ([DavidS](https://github.com/DavidS))
- Bolt task for provision service [\#131](https://github.com/puppetlabs/provision/pull/131) ([carabasdaniel](https://github.com/carabasdaniel))
- \[IAC-882\] - remove puts from abs::provision function [\#128](https://github.com/puppetlabs/provision/pull/128) ([adrianiurca](https://github.com/adrianiurca))
- Improve tagging in ABS provisioner [\#118](https://github.com/puppetlabs/provision/pull/118) ([DavidS](https://github.com/DavidS))
- Feature/ssh with vagrant [\#103](https://github.com/puppetlabs/provision/pull/103) ([ghost](https://github.com/ghost))
- Strip slashes from directories [\#94](https://github.com/puppetlabs/provision/pull/94) ([dylanratcliffe](https://github.com/dylanratcliffe))
- \(MAINT\) Downcase platform for windows regex check [\#90](https://github.com/puppetlabs/provision/pull/90) ([michaeltlombardi](https://github.com/michaeltlombardi))
- Add vars support to the docker\_exp provisioner [\#80](https://github.com/puppetlabs/provision/pull/80) ([Sharpie](https://github.com/Sharpie))
- Dont exit when a command returns a non-0 exit code [\#78](https://github.com/puppetlabs/provision/pull/78) ([da-ar](https://github.com/da-ar))
- \(FM-8344\) Error on exlusive params [\#73](https://github.com/puppetlabs/provision/pull/73) ([michaeltlombardi](https://github.com/michaeltlombardi))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
