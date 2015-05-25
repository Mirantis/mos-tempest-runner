MOS-Tempest-Runner
==================
Toolkit to run Tempest against Mirantis OpenStack

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

If you want to run some group of test cases, you should execute the following 
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
