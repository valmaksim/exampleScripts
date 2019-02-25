#!/bin/bash
while read apis
do
        charID=`echo $apis | awk '{print $1}'`
        keyID=`echo $apis | awk '{print $2}'`
        vCode=`echo $apis | awk '{print $3}'`
        charName=`echo $apis | cut -d' ' -f4-`

        curl -s -A "email@domain.com" "https://api.eveonline.com/char/WalletTransactions.xml.aspx?characterID=${charID}&rowCount=100&keyID=${keyID}&vCode=${vCode}" | sed -n 's/.*transactionID=\"\([0-9]*\)\".*quantity=\"\([0-9]*\)\".*typeID=\"\([0-9]*\)\".*transactionType="sell".*/\3 \2 \1/p' > sellInfo

        while read info
        do
                typeID=`echo $info | awk '{print $1}'`
                quantity=`echo $info | awk '{print $2}'`
                transactionID=`echo $info | awk '{print $3}'`
                match=`cat ~corpscripts/wormholeTypeIDs | grep "${typeID}"`
                matchTypeID=`echo $match | awk '{print $1}'`
                itemName=`echo $match | cut -d' ' -f2-`
                record=`cat ~corpscripts/marketMonitoring/transactionID.history | grep -F ${transactionID}`

                if [ ! "$transactionID" = "$record" ]
                    then
                        echo $transactionID >> ~corpscripts/marketMonitoring/transactionID.history
                        if [ "$typeID" = "$matchTypeID" ]
                        then
                                if [ ! "$charName" = "$oldCharName" ]
                                then
                                        echo >> report
                                        printf "$charName sold the following illegally on the market:\n$quantity units of \"${itemName}\"\n" >> report
                                else
                                        echo "$quantity units of \"${itemName}\"" >> report
                                fi
                        else
                                continue
                        fi
                    else
                        continue
                fi
                oldCharName=`echo $charName`
        done < sellInfo
done < ~corpscripts/charID_keyID_vCode_charName

if [ ! -e report ]
    then
        echo "No Infractions This Week" | mail -s "Market Alerts for Week Ending `date +%m-%d-%Y`" "email@domain.com"
        exit 0
    else
        cat report > ~corpscripts/marketMonitoring/infractions/W.E.`date +%m-%d-%Y`.report
        cat report | mail -s "Market Alerts for Week Ending `date +%m-%d-%Y`" "email@domain.com"
fi

#The following will check for the last 35 days of transaction history and clear all data that is more than 35 days old. Wallet transaction history only reaches one month back.
#There is no need for data older than that.

rm -rf sellInfo report