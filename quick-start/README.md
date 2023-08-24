# Batch MNP-MPI Quick-Start

This example contains what you need to get a quick multi-node parallel (MNP) MPI job running on Batch.

In this example, we deploy a minimal AWS Batch stack to run a simple `hello-mpi` application to demonstrate basic MPI functionality in MNP Batch jobs.  

## What's included

**Dockerfile**
: This sample Dockerfile prescribes the container for the example.  It also can be used a template for containers built on top of the AWS EFA software release.  For more container examples, see [container examples](/containers-examples).

**entrypoint.sh**
: This simple script handles loading the environment and launching the task every time the container is started.

**hello-mpi.c**
: This simple test program demonstrates MPI functionality by performing `MPI_Init` and reporting on local and global MPI ranks.

**parameters.json**
: This JSON file can be modified to provide input parameters for the CloudFormation stack.

**README.md**
: (this file) provides basic instructions for using this example.

**template.yaml**
: This is a CloudFormation template to deploy the basic infrastructure needed to run multi-node parallel MPI jobs on Batch.

**wireup.sh (included from /util)**
: This script handles MPI wire-up communications for MNP AWS Batch jobs.  For more details, run `bash wireup.sh help`.

## Instructions

1. Deploy the Batch resources using the following CloudFormation link:

   ### [Quick Create Link](https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https://aws-hpc-workshops.s3.amazonaws.com/batch-mpi-template.yaml)

   1. Edit the Parameters with values for your environment:

      **Vpc**
      : (required) the VPC ID to deploy in.
      
      **Subnets**
      : (required) the subnets to deploy in. Batch supports multiple subnets across multiple Availability Zones.  This subnet can be private.
      
      **Image**
      : (optional, default to latest Amazon Linux 2 image) the AMI ID to use for the compute environment.  Typically, this should be the latest Amazon Linux 2 image.
      
      **KeyName**
      : (optional, default none) ec2 keypair name to use when launching instances.  Use this if you'd like to be able to SSH to compute environment instances.  Ability to SSH to compute environment instances is not required for jobs to function.
      
      **MinvCpus**
      : (optional, default 0) set the min/desired vCPUs for the compute environment.
      
      **MaxvCpus**
      : (optional, default 72) set the max vCPUs for the compute environment.
      
      **InstanceTypes**
      : (optional, default c5n.18xlarge,c5n.9xlarge,c6i.32xlarge) set the instance type for the compute environment.  To use EFA, this needs to be an EFA-supported type.

      **EcrUrl**
      : (optional, default create a new repository) you can pass an existing ECR repository for the container image if you have created one. By default, a new repository will be created for you.

    2. Alternatively, download [template.yaml](template.yaml) and deploy the using the aws cli:

       ```bash
       aws cloudformation create-stack --stack-name BatchMPI --template-body file://template.yaml --parametes file://parameters.json --capabilities CAPABILITY_NAMED_IAM
       ```
       Alternatively, this stack can be deployed through the AWS Console, or using AWS Serverless Application Management (SAM).

    3. Once stack is deployed, you should see an `BatchMPI-MNPBatch-Queue` queue in AWS Batch.
2. Build and upload the sample container:
   1. Get your ECR repository URI.  CloudFormation will report the ECR repository it create as an output. Look for an entry like:
      ```
       <account_id>.dkr.ecr.us-east-2.amazonaws.com/batch-mnp-XXXX
      ```
      You can also query known ECR repoisitories with:
      ```
      aws ecr describe-repositories
      ```
   2. Build the docker image:
      ```bash
      docker build . -t <repository_uri>:latest
      ```
   3. Login to ECR:
      ```bash
      aws ecr get-login-password | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
      ```
   4. Push the image to ECR:
      ```bash
      docker push <repository_uri>:latest
      ```
3. Run a job: 
   1. Locate your JobDefinition and JobQueue names. The CloudFormation template will have automatically create a AWS Batch JobQueue and JobDefinition. These values will be in the CloudFormation outputs.  The JobDefinition will have the same name as the stack name, default `BatchMPI`.  The JobQueue will have the name `<StackName>-Queue`, default `BatchMPI-Queue`.
   
      You can also query job definitions with:
      ```
      aws batch describe-job-definitions
      ```
      And the job queues with:
      ```
      aws batch describe-job-queues
      ```
   2. Submit a job:
      ```
      aws batch submit-job --job-name hello-mpi --job-queue <job_queue_name> --job-definition <job_definition_name>:1
      ```
      If you have used the defaults, this will be:
      ```
      aws batch submit-job --job-name hello-mpi --job-queue BatchMPI-Queue --job-definition BatchMPI:1
      ```

   3. You should see that the job runs and completes.  On the cloudwatch logs for the main node, you should see output from the the `hello-mpi` task, reporting on global and local MPI ranks.

      Note: the job may take a few minutes to leave the `RUNNABLE` state.  This is normal.

## Next steps

Some container definitions describing different build patterns as well as real application builds can be found in [container examples](/container-examples).

This example can be modified to deploy real jobs for your Batch environment, however, there are a few shortcomings of this simple deployment. There are some considerations before deploying production workloads, including: 

**Improved security**
:  The quick-start example embeds SSH keys in the container image and uses them, however the wireup script is capable of using SSM Parameter secrets to more securely manage SSH keys. This is accomplished by loading a secret in the SSM Parameter store, and passing the name of the secret to `wireup.sh` as `WIREUP_SSM_SSH_KEY`.  Be sure the execution role allows access to the SSM secret.  See `wireup.sh help` for more details.

**Custom Compute Environment AMI**
: [/batch-mpi-ami](/batch-mpi-ami) contains a pipeline to build AMIs to be used in the Batch compute environment.  The quick start uses a launch template script to install and configure necessary dependencies, but this adds to job launch time because each time an instance boots it must complete these steps.  Pre-building AMIs can lead to more efficient job launch times.

**CI/CD Pipeline for Container Images and Job Definitions**
: It is a best practice to use CI/CD pipelines to build and deploy the MPI container image(s) and manage AWS Batch Job Definitions.
