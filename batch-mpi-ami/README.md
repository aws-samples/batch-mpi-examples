# Batch MPI AMI

Use this directory and template to deploy a CI/CD pipeline to build an AMI that has been optimized for MPI Batch workloads.

This AMI can then be used in the compute environment or launch template for your MPI batch jobs.  Using a pre-built AMI is especially useful for decreasing job launch time as compared to performing software installs and configuration through launch template scripting (see the [/quick-start](/quick-start/), for example).

This recipe uses Packer and Ansible to build the AMI.  Look at [./packer-ami.pkr.hcl](./packer-ami.pkr.hcl) and [./inventory/group_vars/all.yml](./inventory/group_vars/all.yml) for configurable Packer and Ansible parameters, respectively.

You can deploy the CloudFormation template with this:

[Quick Create Link](https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https://aws-hpc-workshops.s3.amazonaws.com/batch-mpi-ami-template.yaml)

Once the CloudFormation is deployed, you can:
1. Find the `batch-mpi-ami` CodeCommit repository, determine if you would like to make configuration changes.
   1. Packer configuration can be found in `packer-ami.pkr.hcl`
   2. Ansible variables can be set in `inventory/group_vars/all.yml`
2. Find the `batch-mpi-ami` CodeBuild project. 
3. Select `Start Build` on the CodeBuild project.
4. On successfully completion, this will create an AMI of the form `batch-mpi-XXXX`, where `XXXX` matches the git commit hash.
5. Deploy Launch Templates or Compute Environments using this AMI, disabling the unnecessary scripted setup steps in the Launch Template.
