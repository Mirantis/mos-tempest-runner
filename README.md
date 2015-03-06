mos-tempest-runner
==================

**Toolkit to test Mirantis OpenStack with Tempest**

Installation and Usage
----------------------

1. Log into the Fuel master node. Make sure the Fuel master node has Internet connection before you execute the further steps.
2. Execute `yum -y install git` to install git.
3. Clone `mos-tempest-runner` repository.
4. Go into `mos-tempest-runner` directory.
5. Execute `./setup_env.sh`.
6. Execute `./rejoin.sh`.
7. Execute `run_tests <path.to.tests>`.
