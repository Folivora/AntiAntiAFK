#!/bin/bash

source ./functions/logger.sh

CALIBRATION=false

TriggerPhrase="AFK Check"

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable.py LogDir`
eval LogFile=`./functions/get_variable.py LogFile`
eval TmpDir=`./functions/get_variable.py TmpDir`

eval CalibrationFile=`./functions/get_variable.py CalibrationFile`
eval TmpBWScrFile=`./functions/get_variable.py TmpBWScrFile`

eval acc_ScrDepth=`./functions/get_variable.py acc_ScrDepth`
eval sleeptime=`./functions/get_variable.py sleeptime`

eval resolutOffsetW=`./functions/get_variable.py resolutOffsetW`
eval resolutOffsetH=`./functions/get_variable.py resolutOffsetH`
eval w_rndm_max=`./functions/get_variable.py w_rndm_max`
eval h_rndm_max=`./functions/get_variable.py h_rndm_max`

eval WindowName=`./functions/get_variable.py WindowName`
eval work_with_windows=`./functions/get_variable.py work_with_windows`

# Override default value 
SCRIPT_LOGGING_LEVEL="DEBUG"

# settings can be also given as parameters
# they override default values from config

for arg in "$@"; do
    if echo "$arg" | grep -F = &>/dev/null
         then eval "$arg"
         else echo "ERROR: $arg - wrong parameter"
    fi
done

TmpDir=$TmpDir`basename $0`
if [ ! -d "$TmpDir" ]; then 
    mkdir -p "$TmpDir"
else
    rm ${TmpDir}/*.png 2> >(errAbsorb)
fi


logger "INFO" "Starting..."

if ! $CALIBRATION ; then
  # Determine window id for the screenshot capturing
  until [ -n "${winid}" ]
  do
    echo "Searching \"$WindowName\" window id..."
    sleep 1 
    winid=`xwininfo -tree -root | grep "$WindowName" | awk '{print $1}' | head -n1`
  done
  logger "INFO" "\"$WindowName\" window id is $winid"
  echo          "\"$WindowName\" window id is $winid"
fi

logger "DEBUG" "TriggerPhrase=\"$TriggerPhrase\""

arrScr=()
while true
do 
  if ! $CALIBRATION ; then
    sleep $sleeptime

    screentime=`date +%Y%m%d-%H-%M-%S`
    TmpScrFile=$TmpDir"/"$screentime".png"
    arrScr+=($TmpScrFile)

    if [ ${#arrScr[*]} -gt $acc_ScrDepth ]; then
        rm ${arrScr[0]}  
        unset arrScr[0]
        arrScr=("${arrScr[@]}")  # Reindex array after unset.
    fi

    import -silent -window $winid $TmpScrFile 2> >(errAbsorb)
    logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."
  fi

  # prepare image for OCR process
  convert $TmpScrFile -negate -threshold 30% $TmpBWScrFile 2> >(errAbsorb)
  
  # OCR image, search TriggerPhrase & get coordinates of the first word of trigger phrase
  if [ "$SCRIPT_LOGGING_LEVEL" == "DEBUG" ]; then

    logger "DEBUG" "Start OCR process.."
    if $CALIBRATION ; then
      tmpvar=`(/usr/bin/time -f "[%E real, %U user, %S sys  (P: %P) (M,t: %M[kb] %t[kb]) (c,w: %c %w) (W: %W) (O: %O) (F,R: %F %R) ]" \
             ./functions/get_coordinates.py  -i $TmpBWScrFile -c 50 -p "$TriggerPhrase" -d $CalibrationFile"_detail") 2>&1`
    else
      tmpvar=`(/usr/bin/time -f "[%E real, %U user, %S sys  (P: %P) (M,t: %M[kb] %t[kb]) (c,w: %c %w) (W: %W) (O: %O) (F,R: %F %R) ]" \
             ./functions/get_coordinates.py  -i $TmpBWScrFile -c 50 -p "$TriggerPhrase") 2>&1`
    fi
    eval result=`echo "$tmpvar" | grep -v real`
    logger "DEBUG" "OCR process completed: `echo "$tmpvar" | grep real`"

  else

    if $CALIBRATION ; then
      eval result=`./functions/get_coordinates.py  -i $TmpBWScrFile -c 50 -p "$TriggerPhrase" -d $CalibrationFile"_detail"`
    else
      eval result=`./functions/get_coordinates.py  -i $TmpBWScrFile -c 50 -p "$TriggerPhrase"`
    fi

  fi

  coordinateWidth=0  # The TriggerPhrase is located to the right of this coordinate.
  coordinateHeight=0 # The TriggerPhrase is located to the bottom of this coordinate.
  if [ ! -z $result ]; then
    # The TriggerPhrase was found
    # 
    logger "INFO" "The trigger phrase \"$TriggerPhrase\" has been found (screentime $screentime)."

    cp $TmpScrFile $LogDir"/"$screentime".png"

    coordinateWidth=${result[0]}
    coordinateHeight=${result[1]}

    if $CALIBRATION ; then cp $TmpScrFile $CalibrationFile ; fi
    for i in {1..25} 
    do
       if $CALIBRATION ; then
         winCoordinateW=0
         winCoordinateH=0
       else
         winCoordinateW=`xwininfo -id $winid | grep "Absolute upper-left X:" | awk '{print $4}'`
         winCoordinateH=`xwininfo -id $winid | grep "Absolute upper-left Y:" | awk '{print $4}'`
       fi
    
       w_rndm=`seq -$w_rndm_max $w_rndm_max | shuf -n 1`
       h_rndm=`seq -$h_rndm_max $h_rndm_max | shuf -n 1`
       Width=`expr $winCoordinateW + $coordinateWidth + $resolutOffsetW + $w_rndm`
       Height=`expr $winCoordinateH + $coordinateHeight + $resolutOffsetH + $h_rndm`

       logger "DEBUG" "coordinateWidth is $coordinateWidth. coordinateHeight is $coordinateHeight."
       logger "DEBUG" " resolutOffsetW is $resolutOffsetW.  resolutOffsetH is $resolutOffsetH."
       logger "DEBUG" " winCoordinateW is $winCoordinateW.  winCoordinateH is $winCoordinateH."
       logger "DEBUG" "         w_rndm is $w_rndm.          h_rndm is $h_rndm."
       logger "INFO" "Click at position $Width"x"$Height (Relative coordinates `expr $Width - $winCoordinateW`x`expr $Height - $winCoordinateH`)"

       if $CALIBRATION ; then
         convert $CalibrationFile -fill red -stroke black -draw "circle $Width,$Height `expr $Width + 2`,`expr $Height + 2`" $CalibrationFile 2> >(errAbsorb)
       else
         if $work_with_windows ; then
            currentwindowid=`xdotool getactivewindow` 2> >(errAbsorb)
            xdotool  windowactivate $winid  2> >(errAbsorb)    # it didn't work properly if it was 1 command instead of 2 (xdotool bug?)

            # `xdotool getactivewindow` will not work with Wayland (Ubuntu) properly.
            if [ ! -z $currentwindowid ]; then
                xdotool  mousemove $Width $Height  click 1  mousemove restore  windowactivate $currentwindowid  2> >(errAbsorb)
            else
                xdotool  mousemove $Width $Height  click 1  mousemove restore  2> >(errAbsorb)
            fi
         else
            xdotool  mousemove $Width $Height  click 1  mousemove restore  2> >(errAbsorb)
         fi
         break
       fi

    done

    if $CALIBRATION ; then exit 0 ; fi

  else

    if $CALIBRATION ; then 
      echo "The trigger phrase not found."
      exit 0 
    fi

  fi
  
  
done  
