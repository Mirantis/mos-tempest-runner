MOS-Tempest-Runner
==================
Toolkit to run Tempest against Mirantis OpenStack

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

If you want to run sigle test class or single test case, you can
specify name of this test case as parameter for 'run_tests' command:

```bash
$ run_tests test_update_user_password
```

If you want to run single test case in debug mode to use pdb python debugger,
you can use the following command:

```bash
$ ./tempest/run_tempest.sh --debug tempest.api.identity.admin.v3.test_users.UsersV3TestJSON.test_update_user_password
```
