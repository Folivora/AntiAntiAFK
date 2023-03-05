#!/bin/bash

source ./functions/logger.sh
source ./functions/get_winid.sh
source ./functions/prepare-tmpdir.sh

TEST_MODE=false

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable_wrapper.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable_wrapper.py LogDir`
eval LogFile=`./functions/get_variable_wrapper.py LogFile`

eval SpawnLogFile=`./functions/get_variable_wrapper.py SpawnLogFile`

eval TmpDir=`./functions/get_variable_wrapper.py TmpDir`
     SptTmpScrFile=`./functions/get_variable_wrapper.py SptTmpScrFile`
     
eval SptSleeptime=`./functions/get_variable_wrapper.py SptSleeptime`

# Override default value
#SCRIPT_LOGGING_LEVEL="INFO"

# settings can be also given as parameters
# they override default values from config

for arg in "$@"; do
    if echo "$arg" | grep -F = &>/dev/null
         then eval "$arg"
         else echo "ERROR: $arg - wrong parameter"
    fi
done


logger "INFO" "Starting..."

if ! $TEST_MODE ; then

    # Determine window id for the screenshot capturing (variable 'winid' will be defined)
    get_winid $TmpDir

else
    winid=0
fi

# Update variable $TmpDir, create dir or clear one if it exist.
prepare_tmpdir $winid

# Update var below which contain $TmpDir var in the path.
eval SptTmpScrFile=$SptTmpScrFile


if $TEST_MODE ; then
    cp "${SptTmpScrFile}" "${TestsDir}"
    SptTmpScrFile=${TestsDir}"/"`basename "${SptTmpScrFile}"`
fi

tmpFileExtension=".${SptTmpScrFile##*.}"
tmpFileName=`basename "${SptTmpScrFile}" "${tmpFileExtension}"`
tmpFileDir=`dirname $(readlink -f ${SptTmpScrFile})`

SptTmpScrFile1=${tmpFileDir}"/"${tmpFileName}"_tmp1"${tmpFileExtension}   # Remove later. See the line 87 in spawn-tracker.sh
SptTmpScrFile2=${tmpFileDir}"/"${tmpFileName}"_tmp2"${tmpFileExtension}   # Remove later. See the line 114 in spawn-tracker.sh

tmpScr_RedText_BW_File=${tmpFileDir}"/"${tmpFileName}"_red_bw"${tmpFileExtension}
tmpScr_BlackText_BW_File=${tmpFileDir}"/"${tmpFileName}"_black_bw"${tmpFileExtension}

tmpScr_RedText_txtFile=${tmpFileDir}"/"`basename "$tmpScr_RedText_BW_File"`".txt"


TriggerPhrase_Spawn="An Ultra [a-z]* has spawned"
TriggerPhrase_Chat="Press \[ENTER\] or click here"
logger "DEBUG" "Set value of variables: TriggerPhrase_Spawn=\"$TriggerPhrase_Spawn\"; TriggerPhrase_Chat=\"$TriggerPhrase_Chat\""

while true
do 
    if ! $TEST_MODE ; then
        sleep $SptSleeptime 

        import -silent -window $winid -gravity SouthWest -crop 25x10%+0+0 +repage $SptTmpScrFile 2> >(errAbsorb)
        screentime=`date +%Y%m%d-%H-%M-%S`
        logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."
    else
        convert $SptTmpScrFile -gravity SouthWest -crop 25x10%+0+0 +repage $SptTmpScrFile 2> >(errAbsorb)
    fi

    #convert $SptTmpScrFile -colorspace YCbCr -channel Red -fx "0.1" +channel \ 
    #                    -channel R -separate \ 
    #                    -brightness-contrast 0x50  $tmpScr_RedText_BW_File

    convert $SptTmpScrFile -colorspace YCbCr -channel Red -fx "0.1" +channel $SptTmpScrFile1 2> >(errAbsorb)
    convert $SptTmpScrFile1 -channel R -separate $SptTmpScrFile1 2> >(errAbsorb)
    convert $SptTmpScrFile1 -brightness-contrast 0x50 $SptTmpScrFile1 2> >(errAbsorb)
    convert $SptTmpScrFile1 -negate -threshold 60% $tmpScr_RedText_BW_File 2> >(errAbsorb)

    # Search the TriggerPhrase_Spawn
    if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ]; then 

        logger "DEBUG" "Start OCR process (searching phrase about spawning: $TriggerPhrase_Spawn) .."
        tmpvar=`(/usr/bin/time -o /dev/fd/3 -f "[%E real, %U user, %S sys  (P: %P) (M,t: %M[kb] %t[kb]) (c,w: %c %w) (W: %W) (O: %O) (F,R: %F %R) ]" \
               tesseract -l eng -c textord_min_xheight=4 $tmpScr_RedText_BW_File - >$tmpScr_RedText_txtFile quiet 3>&2 2> >(errAbsorb)  ) 2>&1` 
        logger "DEBUG" "OCR process completed: $tmpvar"

    else
        tesseract -l eng -c textord_min_xheight=4 $tmpScr_RedText_BW_File - >$tmpScr_RedText_txtFile quiet 2> >(errAbsorb)
    fi
    foundPhrase=`grep -iP "$TriggerPhrase_Spawn" $tmpScr_RedText_txtFile`

    if [ -n "${foundPhrase}" ]; then
        # The TriggerPhrase_Spawn was found.
        # Search TriggerPhrase_Chat (Chat check. Need to check the message about spawn is new).
        logger "DEBUG" "Found the TriggerPhrase_Spawn: \"$foundPhrase\"."

        convert $SptTmpScrFile -brightness-contrast 0x70 $SptTmpScrFile2 2> >(errAbsorb)
        convert $SptTmpScrFile2 -colorspace Gray -negate -threshold 70% $tmpScr_BlackText_BW_File 2> >(errAbsorb)

        if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ] && ! $TEST_MODE ; then 
            bkpDir=$LogDir"/"$screentime"-spawn"
            mkdir -p $bkpDir
            cp $SptTmpScrFile              $bkpDir"/"$screentime"-"`basename "${SptTmpScrFile}"`
            cp $SptTmpScrFile1             $bkpDir"/"$screentime"-"`basename "${SptTmpScrFile1}"`
            cp $SptTmpScrFile2             $bkpDir"/"$screentime"-"`basename "${SptTmpScrFile2}"`
            cp $tmpScr_RedText_BW_File     $bkpDir"/"$screentime"-"`basename "${tmpScr_RedText_BW_File}"`
            cp $tmpScr_BlackText_BW_File   $bkpDir"/"$screentime"-"`basename "${tmpScr_BlackText_BW_File}"`
            cp $tmpScr_RedText_txtFile     $bkpDir"/"$screentime"-"`basename "${tmpScr_RedText_txtFile}"`
        fi

        # Search the TriggerPhrase_Chat (chat check)
        if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ]; then 

            logger "DEBUG" "Start OCR process for the second image. Phrase for search: \"$TriggerPhrase_Chat\") .."
            tmpvar=`(/usr/bin/time -o /dev/fd/3 -f "[%E real, %U user, %S sys  (P: %P) (M,t: %M[kb] %t[kb]) (c,w: %c %w) (W: %W) (O: %O) (F,R: %F %R) ]" \
                   tesseract -l eng -c textord_min_xheight=4 $tmpScr_BlackText_BW_File - quiet 3>&2 2> >(errAbsorb) |  grep -i "$TriggerPhrase_Chat" | wc -l ) 2>&1` 
            logger "DEBUG" "OCR process completed: `echo "$tmpvar" | grep real`"
            result=`echo "$tmpvar" | grep -v real`

        else
            result=`tesseract -l eng -c textord_min_xheight=4 $tmpScr_BlackText_BW_File - quiet 2> >(errAbsorb) |  grep -i "$TriggerPhrase_Chat" | wc -l`
        fi

        if [ $result -ge 1 ]; then
            logger "INFO" "Ultra mob was spawned at $screentime. Found message is: $foundPhrase"
            echo          "Ultra mob was spawned at $screentime. Found message is: $foundPhrase" >> $SpawnLogFile
            echo          "Ultra mob was spawned at $screentime. Found message is: $foundPhrase" 
            if ! $TEST_MODE ; then sleep 60 ; fi
        else
            logger "DEBUG" "The TriggerPhrase_Chat not found in current screenshot. Seems the message about spawn is old."
        fi

    else
        logger "DEBUG" "The TriggerPhrase_Spawn not found in current screenshot."
    fi

    if $TEST_MODE ; then exit 0 ; fi

done
