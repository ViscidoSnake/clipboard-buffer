#!/bin/bash

# variabili globali, files sarebbe un array che contiene il percorso dei due file usati come buffer, findex viene usata sempre come indice
# dell'array files, rindex sarebbe l'indice che identifica una certa stringa in uno dei file buffer. tmpfile contiene il percorso di un file
# temporaneo che serve per alcune operazioni rapide come la rimozione di stringhe dal buffer
files=("/dev/shm/cpdA.b" "/dev/shm/cpdB.b")
findex=0
rindex=1
tmpfile="/dev/shm/tmp.b"


# argomento: $rindex. La funzione converte le posizioni in indici che servono poi per ottenere l'effettiva stringa nei file
# buffer, la funzione imposta i valori delle due variabili globali findex e rindex !!!
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


################### GESTIONE degli input (glag e argomenti) attraverso struttura a switch case ###################


rposition=1
remove=false
dcommand="nothing"

while [[ $# -gt 0 ]]
do
    case "$1" in
        -i)	
        	if [ $# -lt 2 ]
        	then
				echo "-i request an argument between 0-10, default used (1)"
				shift 1
        	elif [ $2 -gt 10 ] || [ $2 -lt 0 ]
        	then
				echo "-i request an argument between 0-10, default used (1)"
				shift 2
			else
				rposition=$2
				shift 2
        	fi
            ;;
        -r)
            remove=true
            shift 1
            ;;
        -dc)	
        	if [ $# -lt 2 ]
        	then
				echo "-c request an argument: start|stop|status|restart, default used (nothing)"
        		shift 1
        	elif [ "$2" != "start" ] && [ "$2" != "stop" ] && [ "$2" != "status" ] && [ "$2" != "restart" ] 
            then
				echo "-c request an argument: start|stop|status|restart, default used (nothing)"
        		shift 2
			else
				dcommand=$2
				shift 2
			fi
            ;;
        *)
            echo "Argomento sconosciuto: $1"
            exit 0
            ;;
    esac
done
# potrei volendo uscire subito una volta processato il flag -c perche gli altri flag poi non mi servirebbero per l'elaborazione essendo
# che prevedo di fermare l'esecuzione prima che le variabili impostate da questi vengano processate però non faccio break perchè comunque
# nel while gli argomenti vengono validati quindi se viene scritto qualcosa di senza senso dopo il flag -i comunque questo viene segnalato
# e l'esecuzione termina, diciamo quindi che è più per una questione di coerenza nel senso che l'utente ha sempre lo stesso feedback da parte
# del programma per quanto riguarda la sintassi dei comandi.... 


##################################################################################################################




#### GESTIONE flag -c quindi comandi per interagire con il demone, (in realtà con systemctl che poi interviene su esso) ####
if [ "$2" = "start" ] || [ "$2" = "stop" ] || [ "$2" = "status" ] || [ "$2" = "restart" ] 
then
	echo "`systemctl --user "$dcommand" cpd`"
	exit 0
fi
















#### GESTIONE flag -i e -r quindi praticamente stampa e rimozione delle stringhe ####


# if che gestisce i casi in cui -i ha argomento 0
if [ $rposition -eq 0 ] && [ $remove == false ] # caso 0, stampa le ultime 10 stringhe in memoria però solo se in AND con remove negato
then									
	transform_ring_position_in_index 1

	# if che verifica se effettivamente ci siano elemnti da stampare, in caso contrario scrive una stringa che avverte del fatto che non 
	# siano presenti stringhe
	if [ $rindex -eq -1 ]
	then
		echo "actualy, the buffer is empty"
		exit 0
	fi 

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
	# potrebbe aver senso fare il controllo di prima cioè se non ci sono stringhe da stampare meglio uscire subito e scrivere un avviso che
	# informa del fatto che non sono state "rimosse" stringhe perche effettivamente non ce ne sono tuttavia il codice sotto non da problemi
	# anche se eseguito in questo modo quindi per ora lascio così
	`awk -v RS='\0' -v ORS='\0' '
	 	{
		    print "\x1B[1;31;49mString removed!\x1B[0m"
		    next
		}
		{
		    print
		}
		' "${files[$findex]}" > "$tmpfile" | mv "$tmpfile" "${files[$findex]}"`
		`awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
	 	{
		    print "\x1B[1;31;49mString removed!\x1B[0m"
		    next
		}
		{
		    print
		}
		' "${files[$((1-findex))]}" > "$tmpfile" | mv "$tmpfile" "${files[$((1-findex))]}"`
	exit 0
fi


# a questo punto del codice rposition è comporeso tra 1 e 10, ricavo rindex usando la funzione apposita
transform_ring_position_in_index "$rposition"

# il controllo che segue verifica il valore di rindex, se negativo significa che la posizione richiesta ancora non esiste nel buffer
# cioè deve ancora essere scritta e pertanto mi fermo, non ha senso proseguire cercando di operare su una stringa che non esiste 
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
	' "${files[$findex]}" > "$tmpfile" | mv "$tmpfile" "${files[$findex]}"`
fi
 	
 
 
 