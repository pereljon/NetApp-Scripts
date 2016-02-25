#!/bin/bash

ntap_clone () {
# Clone a NetApp LUN to a QTree on a volume and map it
    theFiler=${1}
    theLUNPath=${2}
    theInitiator=${3}
    theVolume="$(echo "${theLUNPath}" | awk -F / '{print $3};')"
    theLUN="$(echo "${theLUNPath}" | awk -F / '{print $5};')"
    theQtreeClone="/vol/${theVolume}/clones_qt"
    theLUNClone="${theQtreeClone}/${theLUN}_clone"

    # Test that LUN path exists
    testLUN="$(ssh ${theFiler} "lun show ${theLUNPath}" 2>&1)"
    if [[ $testLUN =~ "No such LUN exists" ]]; then
    # ERROR: LUN does not exist
        echo "Error: LUN does not exist: ${theLUNPath}"
        return 1
    fi

    echo "Cloning ${theLUNPath} to ${theLUNClone}"
    # Confirm
    echo -n "Continue [Y]: "
    read theInput
    if [[ $theInput != "Y" ]]; then
        return 1
    fi

    # Create snapshot named test.snap (may fail if it exists but that's ok)
    echo "Creating snapshot"
    ssh ${theFiler} "snap create ${theVolume} test.snap"
    # Create QTree named clones_qt (may fail if it exists but that's ok)
    echo "Creating qTree"
    ssh ${theFiler} "qtree create ${theQtreeClone}"

    # Test that Clone LUN path exists
    testLUN="$(ssh ${theFiler} "lun show ${theLUNClone}" 2>&1)"
    if ! [[ $testLUN =~ "No such LUN exists" ]]; then
    # Clone LUN does exist
        # Unmap old clone lun
        echo "Unmapping old clone"
        ssh ${theFiler} "lun unmap ${theLUNClone} ${theInitiator}"
        # Destroy old clone lun
        echo "Destroying old clone"
        ssh ${theFiler} "lun destroy ${theLUNClone}"
        echo "Waiting..."
        sleep 5
    fi
    # Clone lun
    echo "Cloning LUN"
    ssh ${theFiler} "lun clone create ${theLUNClone} -o noreserve -b ${theLUNPath} test.snap"
    # Map lun
    echo "Mapping initiator"
    ssh ${theFiler} "lun map ${theLUNClone} ${theInitiator}"
}

ntap_release () {
    theFiler=${1}
    theLUNPath=${2}
    theInitiator=${3}
    theVolume="$(echo "${theLUNPath}" | awk -F / '{print $3};')"
    theLUN="$(echo "${theLUNPath}" | awk -F / '{print $5};')"
    theQtreeClone="/vol/${theVolume}/clones_qt"
    theLUNClone="${theQtreeClone}/${theLUN}_clone"

    # Test that Parent LUN path exists
    testLUN="$(ssh ${theFiler} "lun show ${theLUNPath}" 2>&1)"
    if [[ $testLUN =~ "No such LUN exists" ]]; then
    # ERROR: LUN does not exist
        echo "Error: LUN does not exist: ${theLUNPath}"
        return 1
    fi

    # Test that Clone LUN path exists
    testLUN="$(ssh ${theFiler} "lun show ${theLUNClone}" 2>&1)"
    if ! [[ $testLUN =~ "No such LUN exists" ]]; then
    # Clone LUN does exist
        # Unmap old clone lun
        echo "Unmapping ${theLUNClone} from ${theInitiator}"
        ssh ${theFiler} "lun unmap ${theLUNClone} ${theInitiator}"
        # Destroy old clone lun
        echo "Destroying ${theLUNClone}"
        ssh ${theFiler} "lun destroy ${theLUNClone}"
        echo "Waiting..."
        sleep 5
    fi
    # Delete test snapshot
    echo "Deleting test snapshot from ${theVolume}"
    ssh ${theFiler} "snap delete ${theVolume} test.snap"
    
}
