# Util

This folder contains utility scripts that help with AWS Batch deployment of MPI containers.

**wireup.sh**
: This script will handle MPI wire-up in AWS Batch jobs.  See `wireup.sh help` for more details.

**docker-image-rebalance.sh**
: This (experimental) script will rebalance a Docker container into roughly equal sized layers.  This can make push/pull operations more efficient, but destroys layer history.
