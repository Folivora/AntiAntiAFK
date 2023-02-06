### Install  
1) Install all the requirements with your packet manager (see section bellow).
2) Install virtualenv package in your system:  
`pip3 install virtualenv`  
`source ~/.profile`  
(note for Ubuntu 21.10)  
Installation package virtualenv with `sudo apt install python3-virtualenv` was cause of error:  
> "ModuleNotFoundError: No module named 'virtualenv'"  
3) Create virtualenv project:  
`virtualenv -p python3 <dir_name> `  
4) `source <dir_name>/bin/activate`  
5) Install all the python-requirements:  
`pip3 install -r requrements.txt`  
If particular version of any packet unavailable for your os you can try install the last available version. To do this you just need to change entry `<package>==<ver>` to `<package>` in requirements.txt.

#### Requirements
- python3 
- python3-pip
- imagemagick (tested on 8:6.9.10.23 and 8:6.9.11.60)
- tesseract-ocr (tested on 4.0.0-2 and 4.1.1-2.1)
- xdotool (tested on 1:3.20160805.1-4)
- time

### Config
Config file is `./aaafk.cfg`

Make symlink to your own config in `./conf.d`  
Config `conf.d/aaafk-kern-mr-opera.cfg` can be used as an example.

Nesting userconfig files is available. Values in nested userconfig files have higher priority than its in a parent conf file.

### Running
Activation python virtual environment must be performed before running any script in this project:  
`source <virtualenv_dir>/bin/activate`  

Type `deactivate` if you need to exit from virtualenv
