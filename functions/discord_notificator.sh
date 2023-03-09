#!/bin/bash

send_msg_to_discord(){

    eval local userprefix=`./functions/get_variable_wrapper.py dn_userprefix`
    local MESSAGE="$userprefix: $1"
    local URI="https://discord.com/api/webhooks/1083416472174469200/YkYqPbL7JSbjW3NaUg3IoX_v34p5pXgWOkHyqMX-sCkpiEfMAGUWk9Kzn-ox_ngAr4gT"
    
    if [ ! "$MESSAGE" ]; then return 0; fi
    
    curl $URI \
    -H "User-Agent: LinuxBashBot" \
    -H "Content-type: application/x-www-form-urlencoded" \
    -d "content=$MESSAGE" 

}
