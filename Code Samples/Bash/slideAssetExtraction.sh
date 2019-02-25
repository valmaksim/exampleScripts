#!/bin/bash


ls | grep "pptx" > fileList


while read file

do
    
    directoryName=`echo $file | sed -n 's/\(.*\)\(.pptx\)/\1/p'` #take off .pptx for directory name

    mkdir "$directoryName" #Creates a folder named after the pptx file

    cp -a "$file" "${directoryName}"/"${file}".zip #Copies the pptx to a dir named after the pptx and adds the .zip extension

    tar -xvf "${directoryName}"/"${file}".zip -C "${directoryName}" #unpacks the .zip so the assets can be accessed.

done < fileList
rm -rf fileList
