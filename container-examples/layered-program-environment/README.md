# Layered Program Environment

For many MPI container, the largest amount of time and container size are taken up by the compilers, MPI environments, and surrounding tools, i.e., the program environemnt.

In this multi-part example, we demonstrate building a base program environment and layering application containers on top of it.

Because Docker containers build in layers, and runtimes cache layer, this can lead to not only faster build times, but more efficient container loads times.

# Instructions

First, build the container in this directory as the program environment container, and push it to your container repository.

Then, build one of the example containers referring to that container.

Example containers:
**gromacs**
: builds a Gromacs MPI-enabled container.

**osu**
: builds an OSU benchmarks container.