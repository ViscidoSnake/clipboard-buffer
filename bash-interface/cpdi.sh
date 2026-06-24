#!/bin/bash


files=("/dev/shm/cpdA.b" "/dev/shm/cpdB.b")
findex=0
rindex=1

#index
transform_ring_position_in_index(){
	local position=$1

	local recordA=`tr -cd '\0' < "${files[0]}" | wc -c`
	local recordB=`tr -cd '\0' < "${files[1]}" | wc -c`
	
	# gestisce il caso in cui $1 assume valori tali da non avere ancora una corrispondenza nel buffer 
	if [ $position -gt $recordA ] && [ $position -gt $recordB ]
	then
		rindex=-1
		return
	fi

	#devi praticamente trovare quale sia l'ultima riga inserita (in quale file e che indice ha), a quel punto 
	# bisogna contare position posizioni indietro per arrivare alla stringa desiderata
	if [ "$recordA" -gt "$recordB" ] && [ "$recordB" -ne 10 ]
	then
		#findex=1
		if [ $recordB -ge $position ]
		then
			findex=1
			rindex=$(($recordB - $position + 1))
			return
		else
			findex=0
			if [ $recordA -lt 10 ]
			then
				rindex=$(($recordA - $position + $recordB  + 1))
			else
				rindex=$((10 - $position + $recordB  + 1))
			fi
			return
		fi
	else
		#findex=0
		if [ $recordA -ge $position ]
		then
			findex=0
			rindex=$(($recordA - $position + 1))
			return
		else
			findex=1
			if [ $recordB -lt 10 ]
			then
				rindex=$(($recordB - $position + $recordA  + 1))
			else
				rindex=$((10 - $position + $recordA  + 1))
			fi
			return
		fi
	fi
}


######

rposition=1 #valore di default
remove=false

while [[ $# -gt 0 ]]
do
    case "$1" in
        -i)	
        	if [ $# -lt 2 ]
        	then
				echo "-i request an argument between 0-10"
        		exit 1
        	fi
			if [ $2 -ge 0 ] && [ $2 -le 10 ] #ge, ricorda è maggiore uguale! 
            then
            	rposition=$2
			fi
            shift 2
            ;;
        -r)
            remove=true
            shift
            ;;
        *)
            echo "Argomento sconosciuto: $1"
            exit 1
            ;;
    esac
done



# if che gestisce i casi in cui -i ha argomento 0
if [ $rposition -eq 0 ] && [ $remove == false ] # caso 0, stampa le ultime 10 stringhe in memoria però solo se in AND con remove negato
then									
	transform_ring_position_in_index 1
	
	out=`awk -v RS='\0' '
	{
	    rec[++n] = $0
	}

	END {
	    count = 0

	    for (i = n; i >= 1 && count < 10; i--) {
	        printf "\x1B[1;31;49m%d.\x1B[0m %s\n", ++count, rec[i]
	    }
	}
	' "${files[$((1-findex))]}" "${files[$findex]}"`
	echo "$out"
	exit 0
elif [ $rposition -eq 0 ] && [ $remove == true ]
then
	`awk -v RS='\0' -v ORS='\0' '
	 	{
		    print "\x1B[1;31;49mString removed!\x1B[0m"
		    next
		}
		{
		    print
		}
		' "${files[$findex]}" > /dev/shm/tmp.b | mv /dev/shm/tmp.b "${files[$findex]}"`
		`awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
	 	{
		    print "\x1B[1;31;49mString removed!\x1B[0m"
		    next
		}
		{
		    print
		}
		' "${files[$((1-findex))]}" > /dev/shm/tmp.b | mv /dev/shm/tmp.b "${files[$((1-findex))]}"`
	exit 0
fi


# if che gestisce i casi in cui -i ha argomento comporeso tra 1 e 10
transform_ring_position_in_index "$rposition"
if [ $rindex -lt 0 ]
then
	echo "actualy, the position $rposition isn't written"
	exit 0
fi

if [ $remove = false ]
then
	# gestisci stampa su terminale, 
 	out=`awk -v RS='\0' -v idx="$rindex" 'NR==idx {print; exit}' "${files[$findex]}"`
 	echo "$out"
else
	`awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
	NR == idx {
		print "\x1B[1;31;49mString removed!\x1B[0m"
		next
	}
	{
		print
	}
	' "${files[$findex]}" > /dev/shm/tmp.b | mv /dev/shm/tmp.b "${files[$findex]}"`
fi
 	
 
 
 