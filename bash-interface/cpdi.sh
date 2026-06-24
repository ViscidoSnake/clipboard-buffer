#!/bin/bash


files=("/dev/shm/cpdA.b" "/dev/shm/cpdB.b")
findex=0
rindex=1

#index, $recordA, $recordB
transform_ring_position_in_index(){
	local position=$1
	local recordA=$2
	local recordB=$3
	
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


#$recordA, $recordB
print_last_10_rows(){
	
	transform_ring_position_in_index 1 "$1" "$2" #imposto implicitamente findex e rindex del primo record
	
	local out=`awk -v RS='\0' '
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

# cerco quale è il file che contiene le stringhe più recenti, per fare ciò basta prendere quello che ha meno \0, notare che se uno dei
# due ha 10 righe allora le stringhe più recenti saranno nell'altro file, è tuttavia utile contare anche quante
# stringhe contine l'altro file perchè anche questo serve per definire in quale file prendere la stringa richiesta dall'utente  
recordA=`tr -cd '\0' < "${files[0]}" | wc -c`
recordB=`tr -cd '\0' < "${files[1]}" | wc -c`


# gestisce il caso in cui $rposition assume valori tali da non avere ancora una corrispondenza nel buffer 
if [ $rposition -gt $recordA ] && [ $rposition -gt $recordB ]
then
	echo "actually the position $rposition isn't written"
	exit 0
fi


if [[ $rposition -eq 0 && ! $remove == true ]] # caso 0, stampa le ultime 10 stringhe in memoria però solo se in AND con remove negato
then									
	print_last_10_rows "$recordA" "$recordB"
	exit 0
else
	transform_ring_position_in_index "$rposition" "$recordA" "$recordB"
fi


if [ $remove = false ]
then
	# gestisci stampa su terminale, 
 	out=`awk -v RS='\0' -v idx="$rindex" 'NR==idx {print; exit}' "${files[$findex]}"`
 	echo "$out"
else
	# gestisci rimozione
	if [ $rposition -eq 0 ]
	then
		`awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
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



	# `awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
	# NR == idx {
	    # print "\x1B[1;31;49mStringa rimossa!\x1B[0m"
	    # next
	# }
	# {
	    # print
	# }
	# ' "${files[$findex]}" > /dev/shm/tmp.b | mv /dev/shm/tmp.b "${files[$findex]}"`


	
fi
 	
 
 
 
 
	

# 
# 
# 
# if [ "$remove" = false ]
# then
	# out=""
	# if [ $index -eq 0 ]
	# then
		# startIndex=-1 
		# if [ ${records[$findex]} -eq 0 ]
		# then
			# startIndex=1
		# else
			# startIndex=$(( ${records[$findex]} + 1))
		# fi
		# findex=$(( 1 - findex ))
		# 
		# out=`awk -v RS='\0' -v start="$startIndex" '
		# BEGIN {
		    # label = 10
		# }
# 
		# function save_record(text)
		# {
		    # records[label] = text
		    # label--
		# }
# 
		# FILENAME == ARGV[1] {
		    # if (FNR >= start && label > 0) {
		        # save_record($0)
		    # }
		    # next
		# }
# 
		# FILENAME == ARGV[2] {
		    # if (label > 0) {
		        # save_record($0)
		    # }
		# }
# 
		# END {
		    # for (i = 1; i <= 10; i++) {
		        # if (i in records)
		            # printf "%d. %s\n", i, records[i]
		    # }
		# }
		# ' "${files[$findex]}" "${files[$((1-$findex))]}" | sort -t'.' -k1,1n`
	# else
		# out=`awk -v RS='\0' -v idx="$index" 'NR==idx {print; exit}' "${files[$findex]}"`
	# fi
	# echo "$out"
# fi