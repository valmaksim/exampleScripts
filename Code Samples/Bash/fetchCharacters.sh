#!/bin/bash

#ensuring file is clean before filling with data.
printf "" > charID_keyID_vCode_charName

#read in APIs from file. Column 1 containts keys. Column 2 contains verification codes.
while read line
do
        keyID=`echo $line | awk '{print $1}'`
        vCode=`echo $line | awk '{print $2}'`

        curl -s -A "valmaksim.gromakov@gmail.com" "https://api.eveonline.com/account/Characters.xml.aspx?keyID=${keyID}&vCode=${vCode}" | sed -n 's/allianceID="99005205"/&/p' | sed -n 's/.*name=\"\(.*\)\".*characterID="\([0-9]*\).*/\2 \1/p' > charTemp

        while read charLine
        do
                charID=`echo $charLine | awk '{print $1}'`
                charName=`echo $charLine | cut -d' ' -f2-`
                #prints a line containing each variable respectively on one line for later parsing.
                echo $charID $keyID $vCode $charName | sed -n 's/^[0-9]* [0-9]* [A-Za-z0-9]*.*$/&/p' >> charID_keyID_vCode_charName
        done < charTemp
done < API_List

while read line
do
        keyID=`echo $line | awk '{print $1}'`
        vCode=`echo $line | awk '{print $2}'`
        charName=`echo $line | cut -d' ' -f3-`
        apiAuth=`curl -s -A "email@domain.com" "https://api.eveonline.com/account/APIKeyInfo.xml.aspx?keyID=${keyID}&vCode=${vCode}" | sed -n 's/.*accessMask=\"\(.*\)\".*type=\"\(.*\)\".*expires=\"\(.*\)\".*/\1 \2 \3/p'`
        echo "apiAuth is $apiAuth"

        accessMask=`echo $apiAuth | awk '{print $1}'`
        type=`echo $apiAuth | awk '{print $2}'`
        expiration=`echo $apiAuth | awk '{print $3}'`

        if [ ! "$accessMask" = "4294967295" -o ! "$type" = "Account" -o ! -z "$expiration" ]
            then
                if [ "$accessMask" = "268435455" ]
                    then
                        echo "${charName}: This is an old style API. Must create a NEW fresh API. Must be reminded to scrub APIs as well."
                fi
                echo "${charName}: incorrect API with keyID: ${keyID} Access Mask: ${accessMask} Type: ${type} Exiration: ${expiration}" >> keyInfraction.tmp
                continue
        fi
done < API_List

if [ ! -e keyInfraction.tmp ]
    then
        exit 0
    else
        echo "*Access masks other than 4294967295 are not a full API." >> keyInfraction.tmp
        cat keyInfraction.tmp | sort > keyInfraction.tmp2; cat keyInfraction.tmp2 > keyInfraction.tmp; rm -rf keyInfraction.tmp2
        cat keyInfraction.tmp | mail -s "Improper Keys Were Found" "email@domain.com"
        rm -rf keyInfraction.tmp
fi

rm -rf charTemp
