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

**Requirements to Run Mos-Tempest-Runner "out of the box"**

1. Mos-tempest-runner must be run on the Fuel master node only. 
2. The Fuel master node must have Internet connection.

**How Mos-Tempest-Runner Prepares OpenStack Cloud**

In order to run Tempest against an OpenStack cloud we have to perform some 
actions on the cloud. For example, create a tenant, a user without admin role, 
some extra roles, etc. What mos-tempest-runner does:

1. Makes all Keystone endpoints public.
2. Creates tenant "demo" and user "demo".
3. Creates 5 roles: "SwiftOperator", "anotherrole", "heat_stack_user", 
"heat_stack_owner", "ResellerAdmin".
4. Assigns roles "SwiftOperator" and "anotherrole" to user "demo" in 
tenant "demo". Assigns role "admin" to user "admin" in tenant "demo".
5. Creates flavors "m1.tempest-nano" and "m1.tempest-micro".
6. Uploads a CirrOS image.

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
