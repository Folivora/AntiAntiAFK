#!/bin/bash
dir_samples=screensamples
dir_results=calibration

# settings can be also given as parameters
# they override above defaults

for arg in "$@"; do
    if echo "$arg" | grep -F = &>/dev/null
         then eval "$arg"
         else echo "ERROR: $arg - wrong parameter"
    fi
done

mkdir -p $dir_results

for fname in $dir_samples/*.png; do
  bfname=`basename "$fname"`
  echo "=> $fname"
  ./afk-check-clicker.sh CALIBRATION=true TmpScrFile="$fname" CalibrationFile="$dir_results/$bfname"
done
