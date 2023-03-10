#!/bin/bash

source ./functions/logger.sh
source ./functions/get_winid.sh
source ./functions/prepare-tmpdir.sh
source ./functions/discord_notificator.sh

TEST_MODE=false

eval SCRIPT_LOGGING_LEVEL=`./functions/get_variable_wrapper.py SCRIPT_LOGGING_LEVEL`

eval LogDir=`./functions/get_variable_wrapper.py LogDir`
eval LogFile=`./functions/get_variable_wrapper.py LogFile`

eval spt_SpawnLogFile=`./functions/get_variable_wrapper.py spt_SpawnLogFile`

eval TmpDir=`./functions/get_variable_wrapper.py TmpDir`
     spt_TmpScrFile=`./functions/get_variable_wrapper.py spt_TmpScrFile`
     
eval spt_Sleeptime=`./functions/get_variable_wrapper.py spt_Sleeptime`

eval spt_LowerValHSV_Red=`./functions/get_variable_wrapper.py spt_LowerValHSV_Red`
eval spt_UpperValHSV_Red=`./functions/get_variable_wrapper.py spt_UpperValHSV_Red`
eval spt_BW_Treshold_Red=`./functions/get_variable_wrapper.py spt_BW_Treshold_Red`
eval spt_LowerValHSV_Green=`./functions/get_variable_wrapper.py spt_LowerValHSV_Green`
eval spt_UpperValHSV_Green=`./functions/get_variable_wrapper.py spt_UpperValHSV_Green`
eval spt_BW_Treshold_Green=`./functions/get_variable_wrapper.py spt_BW_Treshold_Green`
eval spt_BW_Treshold_White=`./functions/get_variable_wrapper.py spt_BW_Treshold_White`

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
eval spt_TmpScrFile="${spt_TmpScrFile}"


if $TEST_MODE ; then
    cp "${spt_TmpScrFile}" "${TestsDir}"
    spt_TmpScrFile=${TestsDir}"/"`basename "${spt_TmpScrFile}"`
fi

tmpScr_FileExtension=".${spt_TmpScrFile##*.}"
tmpScr_FileName=`basename "${spt_TmpScrFile}" "${tmpScr_FileExtension}"`
tmpScr_FileDir=`dirname $(readlink -f ${spt_TmpScrFile})`

tmpScrBW_RedText=${tmpScr_FileDir}"/"${tmpScr_FileName}"_red_bw"${tmpScr_FileExtension}
tmpScrBW_GreenText=${tmpScr_FileDir}"/"${tmpScr_FileName}"_green_bw"${tmpScr_FileExtension}
tmpScrBW_WhiteText=${tmpScr_FileDir}"/"${tmpScr_FileName}"_white_bw"${tmpScr_FileExtension}

tmpOCR_MobsMessages=${tmpScr_FileDir}"/OCRed_MobsMessages.txt"
tmpOCR_ChatPrompt=${tmpScr_FileDir}"/OCRed_ChatPrompt.txt"


# Workaround to perform only one call to tesseract to recognise two BW screenshots:
# few images can be passed only as file list in separate txt file. 
tmpFileList_MobsMessages=${tmpScr_FileDir}"/filesToOCR_MobsMsgs.txt"
echo $tmpScrBW_RedText    > "${tmpFileList_MobsMessages}"
echo $tmpScrBW_GreenText >> "${tmpFileList_MobsMessages}"


declare -a TriggerPhrases_Mobs
declare -a FoundMessages 

#TriggerPhrases_Mobs+=("Ultra [a-z ]* has spawned")
TriggerPhrases_Mobs+=("has spawned")
TriggerPhrases_Mobs+=("was defeated")
TriggerPhrase_ChatPrompt="Press \[ENTER\] or click here"

logger "DEBUG" "Set values of variables: TriggerPhrases_Mobs[0]=\"${TriggerPhrases_Mobs[0]}\""
logger "DEBUG" "                         TriggerPhrases_Mobs[1]=\"${TriggerPhrases_Mobs[1]}\""
logger "DEBUG" "                         TriggerPhrase_ChatPrompt=\"$TriggerPhrase_ChatPrompt\""


while true
do
    # Erase array
    FoundMessages=()

    # Get a screenshot
    if ! $TEST_MODE ; then
        # Take a screenshot
        sleep $spt_Sleeptime 

        import -silent -window $winid -gravity SouthWest -crop 25x15%+0+0 +repage "${spt_TmpScrFile}" 2> >(errAbsorb)
        screentime=`date +%Y%m%d-%H-%M-%S`
        logger "DEBUG" "A screenshot has been taken. Screentime is $screentime."
    else
        # Prepare received screen file (crop it)
        convert "${spt_TmpScrFile}" -gravity SouthWest -crop 25x15%+0+0 +repage "${spt_TmpScrFile}" 2> >(errAbsorb)
    fi

    # Convert screenshot to B/W images (extract red and green text)
    `./functions/imgTransform.py -i "${spt_TmpScrFile}" -x "${spt_LowerValHSV_Red}"   "${spt_UpperValHSV_Red}"   -b $spt_BW_Treshold_Red   -o "${tmpScrBW_RedText}"`   2> >(errAbsorb)
    `./functions/imgTransform.py -i "${spt_TmpScrFile}" -x "${spt_LowerValHSV_Green}" "${spt_UpperValHSV_Green}" -b $spt_BW_Treshold_Green -o "${tmpScrBW_GreenText}"` 2> >(errAbsorb)

    # OCR both B/W screenfiles to text
    if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ]; then 

        logger "DEBUG" "Start OCR process for tmpFileList_MobsMessages (searching phrases about spawning/dying mobs).."
        tmpvar=`(/usr/bin/time -o /dev/fd/3 -f "[%E real, %U user, %S sys  (P: %P) (M,t: %M[kb] %t[kb]) (c,w: %c %w) (W: %W) (O: %O) (F,R: %F %R) ]" \
               tesseract -l eng -c textord_min_xheight=4 -c page_separator="" "${tmpFileList_MobsMessages}" - >"${tmpOCR_MobsMessages}" quiet 3>&2 2> >(errAbsorb)  ) 2>&1` 
        logger "DEBUG" "OCR process completed: $tmpvar"

    else
        tesseract -l eng -c textord_min_xheight=4 -c page_separator="" "${tmpFileList_MobsMessages}" - >"${tmpOCR_MobsMessages}" quiet 2> >(errAbsorb)
    fi

    # Search phrases about spawning/dying mobs
    for phrase in "${TriggerPhrases_Mobs[@]}"; do
        result=`grep -iP "$phrase" "${tmpOCR_MobsMessages}"`
        if [ -n "${result}" ]; then
            readarray -t lines <<<"$result"
            for line in "${lines[@]}"; do
                FoundMessages+=("$line")
            done
        fi
    done

    if [ ${#FoundMessages[@]} -eq 0 ]; then
        logger "DEBUG" "No messages about mobs found in the current screenshot."
    fi

    for foundMsg in "${FoundMessages[@]}"; do
        # The phrase about spawning/dying mobs was found.
        # Search TriggerPhrase_ChatPrompt (Need to check the chat prompt to know if the found message about mob is new).

        logger "DEBUG" "Found a trigger phrase about a mob: \"$foundMsg\"."

        # Convert screenshot to B/W image (extract white text)
        `./functions/imgTransform.py -i "${spt_TmpScrFile}" -n $spt_BW_Treshold_White -o "${tmpScrBW_WhiteText}"` 2> >(errAbsorb)

        # Search the TriggerPhrase_ChatPrompt
        if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ]; then 

            logger "DEBUG" "Start OCR process for the tmpScrBW_WhiteText (searching the chat prompt).."
            tmpvar=`(/usr/bin/time -o /dev/fd/3 -f "[%E real, %U user, %S sys  (P: %P) (M,t: %M[kb] %t[kb]) (c,w: %c %w) (W: %W) (O: %O) (F,R: %F %R) ]" \
                   tesseract -l eng -c textord_min_xheight=4 "${tmpScrBW_WhiteText}" - >"${tmpOCR_ChatPrompt}" quiet 3>&2 2> >(errAbsorb) ) 2>&1` 
            logger "DEBUG" "OCR process completed: `echo "$tmpvar" | grep real`"

        else
            result=`tesseract -l eng -c textord_min_xheight=4 "${tmpScrBW_WhiteText}" - >"${tmpOCR_ChatPrompt}" quiet 2> >(errAbsorb) `
        fi
        foundChatPrompt=`grep -iP "${TriggerPhrase_ChatPrompt}" "${tmpOCR_ChatPrompt}"`

        # Logging the result
        if [ "${foundChatPrompt}" ]; then
            logger "DEBUG" "Found the chat prompt."

            logger "INFO"       "Found message about a mob at $screentime : $foundMsg"
            echo                "Found message about a mob at $screentime : $foundMsg" >> "${spt_SpawnLogFile}"
            echo                "Found message about a mob at $screentime : $foundMsg" 
            send_msg_to_discord "$screentime : $foundMsg"
            if ! $TEST_MODE ; then sleep 60 ; fi
        else
            logger "DEBUG" "The TriggerPhrase_ChatPrompt not found in current screenshot. Seems the found message about a mob is old."
        fi

        # Debug part
        if [ "$SCRIPT_LOGGING_LEVEL" = "DEBUG" ] && ! $TEST_MODE ; then 
            bkpDir="${LogDir}""/"$screentime"-mobs_message"
            mkdir -p "${bkpDir}"
            cp "${spt_TmpScrFile}"      "${bkpDir}""/"$screentime"-"`basename "${spt_TmpScrFile}"`
            cp "${tmpScrBW_RedText}"    "${bkpDir}""/"$screentime"-"`basename "${tmpScrBW_RedText}"`
            cp "${tmpScrBW_GreenText}"  "${bkpDir}""/"$screentime"-"`basename "${tmpScrBW_GreenText}"`
            cp "${tmpScrBW_WhiteText}"  "${bkpDir}""/"$screentime"-"`basename "${tmpScrBW_WhiteText}"`
            cp "${tmpOCR_MobsMessages}" "${bkpDir}""/"$screentime"-"`basename "${tmpOCR_MobsMessages}"`
            cp "${tmpOCR_ChatPrompt}"   "${bkpDir}""/"$screentime"-"`basename "${tmpOCR_ChatPrompt}"`
        fi
    done

    if $TEST_MODE ; then exit 0 ; fi

done
