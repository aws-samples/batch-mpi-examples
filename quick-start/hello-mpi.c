// This is an MPI test code to demonstrate basic MPI functionality.
//
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
//
// Authors: J. Lowell Wofford <jlowellw@amazon.com>

#include <mpi.h>
#include <stdio.h>
#include <unistd.h>
#include <limits.h>

int main(int argc, char** argv) {
    MPI_Init(NULL, NULL);

    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    MPI_Comm ncomm;
    MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, 0, MPI_INFO_NULL, &ncomm);
    int local_rank;
    MPI_Comm_rank(ncomm, &local_rank);
    
    char hostname[HOST_NAME_MAX+1];
    gethostname((char *)&hostname, HOST_NAME_MAX);

    printf("Hello from rank %d of %d, local rank %d on host %s. Sleeping for 60s.\n",
           world_rank, world_size, local_rank, hostname);
    
    sleep(60);
    MPI_Finalize();
}