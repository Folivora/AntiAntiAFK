#!/usr/bin/env python3

import sys
import os.path

ConfigFile='aaafk.cfg'

# Check if arg exists
if len(sys.argv) > 1:
    arg1=sys.argv[1]
else:
    arg1=""
    exit()

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
            if line.startswith(arg1+'='):
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

print(param)
