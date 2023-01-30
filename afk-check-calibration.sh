#!/bin/bash
dir_samples=screensamples
dir_results=calibration

mkdir -p $dir_results

for fname in $dir_samples/*.png; do
  bfname=`basename "$fname"`
  echo "=> $fname"
  ./afk-check-clicker.sh CALIBRATION=true TmpScrFile="$fname" CalibrationFile="$dir_results/$bfname"
done
