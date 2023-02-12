#!/usr/bin/env python3

import os
import inquirer
import time
import argparse
import sys

sys.path.insert(1, './functions')
from get_variable import get_variable 


def get_winid(OutputTmpFile):

    WindowName=get_variable('WindowName')

    windows=""
    while not windows:
        print('Searching '+WindowName+' window id...')
        time.sleep(1)
        windows = os.popen("xwininfo -tree -root | grep "+WindowName+" | awk -F: '{print $1}'").read()
    
    windows = windows.strip().split('\n',-1) # remove last '\n' from result to avoid adding an emply value in the end of list
    for i in range(0, len(windows)):
        windows[i] = str(windows[i]).strip()
    
    if len(windows) > 1:
    
        questions = [
          inquirer.List('WinID',
                        message="What window does it need to choose?",
                        choices=[ *windows ],
                    ),
        ]
        answers = inquirer.prompt(questions)
        
        winid = str(answers["WinID"]).split(' ',1)[0]
        print('Chosen '+WindowName+' window id: '+winid)
        # need to add logger later
    
    else:
        winid = str(windows[0]).split(' ',1)[0]
        print('Found '+WindowName+' window id: '+winid)
        # need to add logger later

    # returning winid
    f = open(OutputTmpFile, "w")
    f.write(winid)
    f.close()


def main():
    # construct the argument parser and parse the arguments
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--output-file", required=True, help="path to output file")
    args = vars(ap.parse_args())
    
    get_winid(args["output_file"])


if __name__ == '__main__':
    main()
