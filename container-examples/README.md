# Container Examples

This folder contains example containers for MNP Batch.  These illustrate some different patterns that can be used for container builds.

## Contents

[Gromacs with Spack Binary Cache](gromacs-spack-binary/)
: Build a Gromacs container using the Spack Binary Cache.  Includes scripting to run a standard example.

[Layered Program Environment](layered-program-environment/)
: Illustrates building a base program environment (compilers, MPI, utilities), and layering applications on top.

[OSU Micro Benchmarks](osu-micro-benchmarks/)
: Builds the OSU MPI micro benchmarks on using a 3-phase build on top of the AWS provided EFA tools.
