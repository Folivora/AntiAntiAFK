#!/bin/bash

# this script must be "sourced" after logger.sh
#source ./functions/logger.sh

prepare_tmpdir () {
    pWinId=$1

    TmpDir=$TmpDir"/"`basename $0`"/$pWinId/"
    if [ ! -d "$TmpDir" ]; then 
        mkdir -p "$TmpDir"
    else
        if [ "$(ls ${TmpDir})" ]; then
           rm ${TmpDir}/*.png 2> >(errAbsorb)
        fi
    fi

}
