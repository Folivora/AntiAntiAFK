#!/bin/bash


TmpScrFile="/tmp/test-ocr.png"
TmpBWScrFile="/tmp/test-ocr-bw.png"
TmpTxtOcrFile="/tmp/test-ocr.txt"  
LogDir="logs/"
LogFile=$LogDir"afk_clicker.log"

logger () {
  echo `date +%Y-%m-%d\|%H:%M:%S\|`" afk-check-clicker.sh|  $1" >> $LogFile 
}
logger "Starting..."

while true
do 
  sleeptime=20
  sleep $sleeptime 

  #gnome-screenshot  -f $TmpScrFile 
  flameshot full -r > $TmpScrFile 
  screentime=`date +%Y%m%d-%H-%M-%S`
  convert $TmpScrFile -negate -threshold 40% $TmpBWScrFile
  
  TriggerPhrase="AFK Check"
  
  # Search trigger phrase
  tesseract -l eng $TmpBWScrFile - > $TmpTxtOcrFile 2> /dev/null 
  if [ `grep "$TriggerPhrase" $TmpTxtOcrFile | wc -l` -ge 1 ]; then
    # The TriggerPhrase was found
    # 
    logger "The trigger phrase \"$TriggerPhrase\" has been found (screentime $screentime). Search the coordinates is starting."
  
    cp $TmpScrFile $LogDir"/"$screentime".png"

    ################################################################
    ## Trying to find coordinates of the trigger phrase BY WIDTH. ##
    ################################################################
    
    WidthCoordinate=0 # The TriggerPhrase located to the right of this coordinate.
  
    currScrFile=$TmpBWScrFile
    currHight=`identify -format '%h' $currScrFile`
    CoordinateFound=false
    until $CoordinateFound
    do
      # Split current piece of screenshot into two
      currWidth=`identify -format '%w' $currScrFile`
      newWidth=`expr $currWidth / 2`
      currScrFile_leftside=$currScrFile"l"
      currScrFile_rightside=$currScrFile"r"
      convert $currScrFile +repage -crop `echo $newWidth"x"$currHight"+0+0"` $currScrFile_leftside
      convert $currScrFile +repage -crop `echo $newWidth"x"$currHight"+"$newWidth"+0"` $currScrFile_rightside
      #echo $currScrFile  $currWidth $newWidth $currHight
  
      # Search trigger phrase into both pieces
      found_leftside=0
      found_rightside=0
      if [ `tesseract -l eng $currScrFile_leftside  - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_leftside=1; fi
      if [ `tesseract -l eng $currScrFile_rightside - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_rightside=1; fi
  
      if   [ $found_leftside -eq "1" ] && [ $found_rightside -eq "0" ]; then
        currScrFile=$currScrFile_leftside
  
      elif [ $found_leftside -eq "0" ] && [ $found_rightside -eq "1" ]; then
        WidthCoordinate=`expr $WidthCoordinate + $newWidth`
        currScrFile=$currScrFile_rightside
  
      elif [ $found_leftside -eq "0" ] && [ $found_rightside -eq "0" ]; then
        # The trigger phrase was splited and cannot be found.
        # Crops the previus succesfull image on the right side by pixel offset utill trigger phrase will reached. 
        i=0
        PixOffset=10 # Pixel offset.  
        while true
        do
          i=`expr $i + $PixOffset` 
          currWidth=`identify -format '%w' $currScrFile`
          newWidth=`expr $currWidth - $i`
          convert $currScrFile +repage -crop `echo $newWidth"x"$currHight"+"$i"+0"` $currScrFile"o"
          if [ `tesseract -l eng $currScrFile"o"  - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase was reached.
            WidthCoordinate=`expr $WidthCoordinate + $i - $PixOffset`
            CoordinateFound=true
            break
          fi
        done
  
      elif [ $found_leftside -eq "1" ] && [ $found_rightside -eq "1" ]; then
        logger "The trigger phrase was found in two places (splitting scr by width). Exit."
        exit 0
      fi 
  
    done
    logger "WidthCoordinate is $WidthCoordinate"
  
  
    ################################################################
    ## Trying to find coordinates of the trigger phrase BY HIGHT. ##
    ################################################################
    
    HightCoordinate=0 # The TriggerPhrase is located below this coordinate.
  
    currWidth=`identify -format '%w' $currScrFile`
    CoordinateFound=false
    until $CoordinateFound
    do
      # Split current piece of screenshot into two
      currHight=`identify -format '%h' $currScrFile`
      newHight=`expr $currHight / 2`
      currScrFile_topside=$currScrFile"t"
      currScrFile_bottomside=$currScrFile"b"
      convert $currScrFile +repage -crop `echo $currWidth"x"$newHight"+0+0"`          $currScrFile_topside
      convert $currScrFile +repage -crop `echo $currWidth"x"$newHight"+0+"$newHight` $currScrFile_bottomside
      #echo $currScrFile  $currWidth $currHight $newHight
  
      # Search trigger phrase into both pieces
      found_topside=0
      found_bottomside=0
      if [ `tesseract -l eng $currScrFile_topside  - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_topside=1; fi
      if [ `tesseract -l eng $currScrFile_bottomside - quiet | grep "$TriggerPhrase" | wc -l` -ge 1 ]; then found_bottomside=1; fi
  
      if   [ $found_topside -eq "1" ] && [ $found_bottomside -eq "0" ]; then
        currScrFile=$currScrFile_topside
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "1" ]; then
        HightCoordinate=`expr $HightCoordinate + $newHight`
        currScrFile=$currScrFile_bottomside
  
      elif [ $found_topside -eq "0" ] && [ $found_bottomside -eq "0" ]; then
        # The trigger phrase was splited and cannot be found.
        # Crops the previus succesfull image on the right side by pixel offset utill trigger phrase will reached. 
        i=0
        PixOffset=10 # Pixel offset.  
        while true
        do
          i=`expr $i + $PixOffset` 
          currHight=`identify -format '%h' $currScrFile`
          newHight=`expr $currHight - $i`
          convert $currScrFile +repage -crop `echo $currWidth"x"$newHight"+0+"$i` $currScrFile"O"
          if [ `tesseract -l eng $currScrFile"O"  - quiet 2>&1 | grep "$TriggerPhrase" | wc -l` -eq 0 ]; then 
            # The trigger phrase was reached.
            HightCoordinate=`expr $HightCoordinate + $i - $PixOffset`
            CoordinateFound=true
            break
          fi
        done
  
      elif [ $found_topside -eq "1" ] && [ $found_bottomside -eq "1" ]; then
        logger "The trigger phrase was found in two places (splitting scr by hight). Exit."
        exit 0
      fi 
  
    done
    logger "HightCoordinate is $HightCoordinate"
  
    # coordinates of trigger phrase's top left corner 798x356
    # center of button 846x415
    # 
 ###while true
 ###do
    w_rndm=`seq -20 20 | shuf -n 1`
    h_rndm=`seq -3 3 | shuf -n 1`
    Width=`expr $WidthCoordinate + 45 + $w_rndm`
    Hight=`expr $HightCoordinate + 61 + $h_rndm`
    xdotool mousemove $Width $Hight  click 1
    logger "Click at position $Width"x"$Hight"
 ###done

  fi
  
  
done  

