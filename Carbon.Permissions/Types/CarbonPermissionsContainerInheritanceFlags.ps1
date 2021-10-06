
[Flags()] enum CarbonPermissionsContainerInheritanceFlags {
    #Apply permission to the container.
    Container = 1

    #Apply permissions to all sub-containers.
    SubContainers = 2

    #Apply permissions to all leaves.
    Leaves = 4

    #Apply permissions to child containers.
    ChildContainers = 8

    #Apply permissions to child leaves.
    ChildLeaves = 16

    #Apply permission to the container and all sub-containers.
    #Container|SubContainer = 1 -bor 2 = 3
    ContainerAndSubContainers = 3

    #Apply permissionto the container and all leaves.
    #Container|Leaves = 1 -bor 4 = 5
    ContainerAndLeaves = 5

    #Apply permission to all sub-containers and all leaves.
    #SubContainerAndLeaves = 2 -bor 4 = 6
    SubContainersAndLeaves = 6

    #Apply permission to container and child containers.
    #Container|ChildContainers = 1 -bor 8 = 9
    ContainerAndChildContainers = 9

    #Apply permission to container and child leaves.
    #Container|ChildLeaves = 1 -bor 16 = 17
    ContainerAndChildLeaves = 17

    #Apply permission to container, child containers, and child leaves.  
    #Container|ChildContainers|ChildLeaves = 1 -bor 8 -bor 16 = 25
    ContainerAndChildContainersAndChildLeaves = 25

    #Apply permission to container, all sub-containers, and all leaves.
    #Container|SubContainers|Leaves = 1 -bor 2 -bor 4 = 7
    ContainerAndSubContainersAndLeaves = 7

    #Apply permission to child containers and child leaves.
    #ChildContainers|ChildLeaves = 8 -bor 16 = 24
    ChildContainersAndChildLeaves = 24
}