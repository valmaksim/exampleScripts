#!/bin/bash

#fills contractID_issuerID file with contract IDs and character IDs
curl -s -A "valmaksim.gromakov@gmail.com" "https://api.eveonline.com/corp/Contracts.xml.aspx?keyID=5406883&vCode=yQqASdKh8maitFFG0eV7msO4QNJ6aBLadsu8pgkDBCZSFgGjqo132bBAtywSZBdd" | sed -n 's/.*contractID=\"\([0-9]*\)\".*issuerID=\"\([0-9]*\)\".*type=\"ItemExchange\".*status=\"Completed\".*price=\"0\.00\".*/\1 \2/p' > contractID_issuerID

while read contractLine
do
        getContractID=`echo $contractLine | awk '{print $1}'`
        getCharID=`echo $contractLine | awk '{print $2}'`
        getCompareID=`cat ~corpscripts/buybackProgram/contracts.history | grep -F "${getContractID}"`
        charName=`cat ~corpscripts/charID_keyID_vCode_charName | grep "$getCharID" | cut -d' ' -f4- | tr ' ' '_'`

        #if character name does not change it will not continue to do new lines. Instead, output is printed all on o$
        #This is done to make awk arithmetic easier to handle.
        #If character does not have a valid API, or none at all, it will throw away both their name and the contents$
if [ ! "$getContractID" = "$getCompareID" ]
    then
        if [ -z "$charName" ]
            then
                continue
            else
                #retrieves all items typeID and quantity.
                curl -s -A "valmaksim.gromakov@gmail.com" "https://api.eveonline.com/corp/ContractItems.xml.aspx?contractID=${getContractID}&keyID=5406883&vCode=yQqASdKh8maitFFG0eV7msO4QNJ6aBLadsu8pgkDBCZSFgGjqo132bBAtywSZBdd" | sed -n 's/.*typeID=\"\([0-9]*\)\".*quantity=\"\([0-9]*\)\".*/\1 \2/p' > tempContractInfo
                printf "$charName " >> totals
                while read info
                do
                        typeID=`echo $info | awk '{print $1}'`
                        quantity=`echo $info | awk '{print $2}'`
                        getWHLootID=`cat ~corpscripts/wormholeTypeIDs | grep -w "$typeID" | cut -d' ' -f1`
                        if [ "$getWHLootID" = "$typeID" ]
                           then
                                if [ "$typeID" = "30744" -o "$typeID" = "30745" -o "$typeID" = "30746" -o "$typeID" = "30747" ]
                                    then
                                        price=`curl -s -A "valmaksim.gromakov@gmail.com" "http://api.eve-central.com/api/marketstat?typeid=${typeID}&usesystem=30000163" | sed -n 's/.*<buy>.*<max>\([0-9]*.[0-9][0-9]\).*/\1/p'`
                                        price=`calc ${price}*${quantity}`
                                        price=`calc ${price}*0.85`
                                        price=`echo ${price}`
                                        printf "${price} " >> totals
                                    else
                                        price=`curl -s -A "valmaksim.gromakov@gmail.com" "http://api.eve-central.com/api/marketstat?typeid=${typeID}&usesystem=30000142" | sed -n 's/.*<buy>.*<max>\([0-9]*.[0-9][0-9]\).*/\1/p'`
                                        price=`calc ${price}*${quantity}`
                                        price=`calc ${price}*0.85`
                                        price=`echo ${price}`
                                        printf "${price} " >> totals
                                fi
                           else
                                price=`curl -s -A "valmaksim.gromakov@gmail.com" "http://api.eve-central.com/api/marketstat?typeid=${typeID}&usesystem=30000142" | sed -n 's/.*<buy>.*<max>\([0-9]*.[0-9][0-9]\).*/\1/p'`
                                price=`calc ${price}*${quantity}`
                                price=`calc ${price}*0.95`
                                price=`echo ${price}`
                                printf "${price} " >> totals
                        fi
                done < tempContractInfo
        printf '\n' >> totals
        fi
    else
        continue
fi
echo $getContractID >> ~corpscripts/buybackProgram/contracts.history
done < contractID_issuerID

cat totals | sort > totals.tmp
printf "" > totals

while read line
do
        charName=`echo $line | awk '{print $1}'`
        newLine=
        if [ "$charName" = "$oldCharName" ]
            then
                newLine=`echo $line | cut -d' ' -f2- | tr '\n' ' '`
                oldLine=`echo $oldLine | tr '\n' ' '`
                oldLine=$oldLine$newLine
                echo oldLine >> totals
            else
                echo $line >> totals
        fi
        oldCharName=`echo $charName`
        oldLine=`echo $newLine`
done < totals.tmp

rm -rf totals.tmp

if [ ! -e totals ]
    then
        echo "No Payout Reports This Week" | mail -s "Income Report for Payperiod Ending on: `date +%m-%d-%Y`" "valmaksim.gromakov@gmail.com"
        exit 0
    else
        cat totals > ~corpscripts/buybackProgram/incomeReports/`date +%m-%d-%Y`.report
        cat totals | mail -s "Income Report for Payperiod Ending on: `date +%m-%d-%Y`" "valmaksim.gromakov@gmail.com"
fi
rm -rf totals tempContractInfo contractID_issuerID totals.tmp contracts.history
