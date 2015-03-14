MOS-Tempest-Runner - Toolkit to run Tempest against Mirantis OpenStack
======================================================================

Installation and Usage
----------------------
Log into the Fuel master node. Make sure the Fuel master node has 
Internet connection before you execute the further steps:

```bash
$ yum -y install git
$ git clone https://github.com/Mirantis/mos-tempest-runner.git
$ cd mos-tempest-runner
$ ./setup_env.sh
$ ./rejoin.sh
$ run_tests
```
