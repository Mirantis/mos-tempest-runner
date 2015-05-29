MOS-Tempest-Runner
==================
Toolkit to run Tempest against Mirantis OpenStack

Introduction
------------

The main goal of these scripts is to prepare the OpenStack cloud for Tempest 
and run the tests by executing a few commands. 

**WARNING:  Use mos-tempest-runner to run Tempest against PRODUCTION OpenStack 
clouds at own risk! These scripts may break the OpenStack cloud! Pay attention 
that mos-tempest-runner was initially designed to run Tempest on CI and test 
OpenStack environments!**

Installation and Usage
----------------------

**How to Run All Tempest Tests**

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

**How to Run Some Group of Tempest Tests**

If you want to run some group of test cases, you should use the following 
command:

```bash
$ run_tests <path.to.test.folder.or.path.to.test.file.or.path.to.test.class>
```

For example, you would like to run some group of tests for Keystone. 
In this case you can execute the following commands:

```bash
$ run_tests tempest.api.identity
$ run_tests tempest.api.identity.admin.test_roles
$ run_tests tempest.api.identity.admin.test_roles.RolesTestJSON
```

**How to Run Single Tempest Test**

If you want to run single test case, you should use the following command:

```bash
$ run_tests <path.to.test>
```

For example, you would like to run one of the tests for Keystone. 
In this case you can execute the following command:

```bash
$ run_tests tempest.api.identity.admin.test_roles.RolesTestJSON.test_list_roles
```
