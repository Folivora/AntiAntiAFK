#!/bin/bash

CALIBRATION=false

CalibrationFile="./calibration.png"
TmpScrFile="/tmp/test-ocr.png"
TmpBWScrFile="/tmp/test-ocr-bw.png"
LogDir="logs/"
LogFile=$LogDir"afk_clicker.log"

logger () {
  echo `date +%Y-%m-%d\|%H:%M:%S\|`" afk-check-clicker.sh|  $1" >> $LogFile 
}
logger "Starting..."

# Determine window id for the screenshot capturing
until [ -n "${winid}" ]
do
  echo "Search florr.io window id.."
  sleep 1 
  winid=`xwininfo -tree -root | grep "florr.io" | awk '{print $1}' | head -n1`
done
logger "florr.io window id is $winid"
echo   "florr.io window id is $winid"


while true
do 
  sleeptime=20
  if ! $CALIBRATION ; then sleep $sleeptime ; fi

  #flameshot full -r > $TmpScrFile 
  import -silent -window $winid $TmpScrFile
  screentime=`date +%Y%m%d-%H-%M-%S`
  convert $TmpScrFile -negate -threshold 40% $TmpBWScrFile
  
  TriggerPhrase="AFK Check"
  
  # Search trigger phrase
  result=`tesseract -l eng $TmpBWScrFile - quiet |  grep "$TriggerPhrase" | wc -l`

  if [ $result -ge 1 ]; then
    # The TriggerPhrase was found
    # 
    cp $TmpScrFile $LogDir"/"$screentime".png"

    if [ $result -ge 2 ]; then
      logger "The trigger phrase \"$TriggerPhrase\" has been found in $result places (screentime $screentime). Exit."
      exit 0
    fi

    logger "The trigger phrase \"$TriggerPhrase\" has been found (screentime $screentime). Search the coordinates is starting."
  

    ################################################################
    ## Trying to find coordinates of the trigger phrase BY WIDTH. ##
    ################################################################

    coordinateWidth=0 # The TriggerPhrase is located to the right of this coordinate.
  
    currScrFile=$TmpBWScrFile
    currHeight=`identify -format '%h' $currScrFile`
    CoordinateFound=false
    until $CoordinateFound
    do
      # Split current part of screenshot into two
      currWidth=`identify -format '%w' $currScrFile`
      midWidth=`expr $currWidth / 2`

      # Cut off left half and search trigger phrase
      found_leftside=0; found_rightside=0
      currScrFile_leftside=$currScrFile"l"
      convert $currScrFile +repage -crop $midWidth"x"$currHeight"+0+0" $currScrFile_leftside
      if [ `tesseract -l eng $currScrFile_leftside  - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_leftside=1; 

      else # If phrase is not found in left half
        # Cut off right half and check trigger phrase here.
        currScrFile_rightside=$currScrFile"r"
        convert $currScrFile +repage -crop $midWidth"x"$currHeight"+"$midWidth"+0" $currScrFile_rightside
        if [ `tesseract -l eng $currScrFile_rightside - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_rightside=1; fi

      fi
  
      if   [ $found_leftside -eq "1" ] && [ $found_rightside -eq "0" ]; then
        currScrFile=$currScrFile_leftside
  
      elif [ $found_leftside -eq "0" ] && [ $found_rightside -eq "1" ]; then
        coordinateWidth=`expr $coordinateWidth + $midWidth`
        currScrFile=$currScrFile_rightside
  
      elif [ $found_leftside -eq "0" ] && [ $found_rightside -eq "0" ]; then
        # The trigger phrase was splitted and cannot be found by OCR.
        # Crops the previous succesful part of screenshot to the right of the middle. 
        currPixOffset=0; step=75
        if [ `expr $midWidth + $step` -lt $currWidth  ]; then 
          while true
          do 
            currPixOffset=`expr $currPixOffset + $step`


            convert $currScrFile +repage -crop\
                    `expr $midWidth + $currPixOffset`"x"$currHeight"+"`expr $midWidth - $currPixOffset`"+0"   $currScrFile"o"


            if [ `tesseract -l eng $currScrFile"o"  - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 1 ]; then 
              # The trigger phrase can be recognized by OCR now.
              currScrFile=$currScrFile"o"
              coordinateWidth=`expr $coordinateWidth + $midWidth - $currPixOffset`
              break
            fi
          done
        fi

        # Iteratively crop the right part of currScrFile until the trigger phrase is no longer recognized by OCR. 
        currPixOffset=0; step=10
        while true
        do
          currPixOffset=`expr $currPixOffset + $step`
          currWidth=`identify -format '%w' $currScrFile`

          convert $currScrFile +repage -crop\
                  `expr $currWidth - $step`"x"$currHeight"+"$step"+0"   $currScrFile"O"

          if [ `tesseract -l eng $currScrFile"O" - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase can't be recognized now.
            coordinateWidth=`expr $coordinateWidth + $currPixOffset - $step`
            CoordinateFound=true

            break
          fi
          currScrFile=$currScrFile"O"
        done
  
      fi 
  
    done
    logger "coordinateWidth is $coordinateWidth"
  

    #################################################################
    ## Trying to find coordinates of the trigger phrase BY HEIGHT. ##
    #################################################################

    coordinateHeight=0 # The TriggerPhrase is located below this coordinate.
  
    currWidth=`identify -format '%w' $currScrFile`
    CoordinateFound=false

    until $CoordinateFound
    do
      # Split current part of screenshot into two
      currHeight=`identify -format '%h' $currScrFile`
      midHeight=`expr $currHeight / 2`

      # Cut off the top half and search trigger phrase
      found_topside=0; found_bottomside=0
      currScrFile_topside=$currScrFile"t"
      convert $currScrFile +repage -crop $currWidth"x"$midHeight"+0+0"          $currScrFile_topside
      if [ `tesseract -l eng $currScrFile_topside  - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_topside=1; 

      else # If phrase is not found in the top half
        # Cut off the bottom half and check trigger phrase here.
        currScrFile_bottomside=$currScrFile"b"
        convert $currScrFile +repage -crop $currWidth"x"$midHeight"+0+"$midHeight $currScrFile_bottomside
        if [ `tesseract -l eng $currScrFile_bottomside - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_bottomside=1; fi

      fi

      if   [ $found_topside -eq "1" ] && [ $found_bottomside -eq "0" ]; then
        currScrFile=$currScrFile_topside
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "1" ]; then
        coordinateHeight=`expr $coordinateHeight + $midHeight`
        currScrFile=$currScrFile_bottomside
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "0" ]; then
        # The trigger phrase was splitted and cannot be found by OCR.
        # Crops the previous succesful part of screenshot to the top of the middle. 
        currPixOffset=0; step=35
        if [ `expr $midHeight + $step` -lt $currHeight  ]; then 
          while true
          do 
            currPixOffset=`expr $currPixOffset + $step`

            convert $currScrFile +repage -crop\
                    $currWidth"x"`expr $midHeight + $currPixOffset`"+0+"`expr $midHeight - $currPixOffset`  $currScrFile"o"


            if [ `tesseract -l eng $currScrFile"o"  - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 1 ]; then 
              # The trigger phrase can be recognized by OCR now.
              currScrFile=$currScrFile"o"
              coordinateHeight=`expr $coordinateHeight + $midHeight - $currPixOffset`
              break
            fi
          done
        fi

        # Iteratively crop the top part of currScrFile until the trigger phrase is no longer recognized by OCR. 
        currPixOffset=0; step=8
        while true
        do
          currPixOffset=`expr $currPixOffset + $step`
          currHeight=`identify -format '%h' $currScrFile`

          convert $currScrFile +repage -crop\
                  $currWidth"x"`expr $currHeight - $step`"+0+"$step   $currScrFile"O"

          if [ `tesseract -l eng $currScrFile"O" - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase can't be recognized now.
            coordinateHeight=`expr $coordinateHeight + $currPixOffset - $step`
            CoordinateFound=true
            break
          fi
          currScrFile=$currScrFile"O"
        done
  
      fi 
  
    done
    logger "coordinateHeight is $coordinateHeight"
  

    if $CALIBRATION ; then cp $TmpScrFile $CalibrationFile ; fi
    for i in {1..25} 
    do
       wOffset=`xwininfo -id $winid | grep "Relative upper-left X:" | awk '{print $4}'`
       hOffset=`xwininfo -id $winid | grep "Relative upper-left Y:" | awk '{print $4}'`
    
       w_rndm=`seq -20 20 | shuf -n 1`
       h_rndm=`seq -3 3 | shuf -n 1`
       Width=`expr $wOffset + $coordinateWidth + 45 + $w_rndm`
       Height=`expr $hOffset + $coordinateHeight + 61 + $h_rndm`

       logger "Click at position $Width"x"$Height"

       if $CALIBRATION ; then
         convert $CalibrationFile -fill red -stroke black -draw "circle $Width,$Height `expr $Width + 2`,`expr $Height + 2`" $CalibrationFile
       else 
         xdotool mousemove $Width $Height  click 1
         break
       fi
    
    done

    if $CALIBRATION ; then exit 0 ; fi

  fi
  
  
done  
