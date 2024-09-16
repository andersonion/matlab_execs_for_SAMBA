#!/usr/bin/env bash

lib_dir=$(find /usr/lib/ -name *ncurses* | head -1);
lib_dir="${lib_dir%\/*}/";
source=${lib_dir}libncurses.so.6;
lib_A=${lib_dir}libncurses.so.5;
lib_B=${lib_dir}libtinfo.so.5;
if [[ -e ${source} ]];then
    if [[ ! -e ${lib_A} ]];then 
    	sudo ln -s ${source} ${lib_A};
    fi
    
    if [[ ! -e ${lib_B} ]];then 
    sudo ln -s ${source} ${lib_B};
    fi
    
    echo "Finsihed attempt to fix missing library; please try running your code again to see if error persists."
else
    echo "Unable to locate the appropriate file to link to; unsure of how to fixt your error. A thousand pardons...";
    echo "File in questions: ${source}."
fi