#!/usr/bin/env python3

import sys
import os.path

def get_variable(*args):

    # Check if arg exists
    if len(args) > 0:
        ParamName=args[0]
    else:
        ParamName=""
        exit()
    
    ConfigFile='aaafk.cfg'

    cfgFiles = [ ( ConfigFile, 0) ]           # list of tuples (path_to_cfgfile, nestLvl)
    value = []
    for currCfgFile in cfgFiles:
        if not os.path.exists(currCfgFile[0]):
            #print('Config file \"'+currCfgFile[0]+'\" does not exist!') # this print() for debug only!
            continue 
        with open(currCfgFile[0], 'r') as f:
            nestLvl=currCfgFile[1]
            for line in f.readlines():
                line=line.rstrip().strip()    # remove whitespaces from the beginnings and '\n' from the end of a string
                if line.startswith(ParamName+'='):
                    res=line.split('#',1)[0]  # cut off comment
                    res=res.split('=',1)[1]
                    value.append((res,nestLvl))
                elif line.startswith('userconf'):
                    res=line.split(' ',-1)[-1] 
                    res=res.strip('\"')       # remove quotation marks
                    cfgFiles.append((res,nestLvl+1))
    
    #print(value)
    
    if value == []:
        exit()
    
    currMax=0
    param=value[currMax]
    for i in value:
        if i[1] >= currMax:
            param=i[0]
    
    return param


def main():
    del sys.argv[0]
    get_variable(*sys.argv)


if __name__ == '__main__':
    main()
