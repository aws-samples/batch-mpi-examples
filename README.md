# Batch MPI Examples

This repo contains examples for running MPI using AWS Batch multi-node parallel (MNP) jobs.

The [quick-start](/quick-start/) guide is a good place to get started.

## Contents

[quick-start](/quick-start/)
: contains files needed for the Quick Start Guide.  This gets MPI up-and-running quickly, but without many known optimizations.

[container-examples](/container-examples/)
: contains several examples of containers that can be built to run on AWS Batch. We focus on providing different build patterns, rather than a comprehensive catalog of applications.

[ecs-image](/ecs-image/)
: contains a recipe to create a CI/CD pipeline build for MNP enabled AWS Batch AMIs.

[util](/util/)
: contains general utilities/scripts to implement MPI on Batch MNP.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

