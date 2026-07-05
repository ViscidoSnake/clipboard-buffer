#!/bin/bash

trap 'exit_status=$?; exit_log $exit_status' EXIT

# variabili globali, files sarebbe un array che contiene il percorso dei due file usati come buffer, findex viene usata sempre come indice
# dell'array files, rindex sarebbe l'indice che identifica una certa stringa in uno dei file buffer. tmpfile contiene il percorso di un file
# temporaneo che serve per alcune operazioni rapide come la rimozione di stringhe dal buffer
files=("/run/user/1000/clipboard-buffer/cpdA.b" "/run/user/1000/clipboard-buffer/cpdB.b")
findex=0
rindex=1
tmpfile="/run/user/1000/clipboard-buffer/tmp.b"

logmsg=""

rposition=1
remove=false
load=false
verbose=false

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


exit_log(){
	local exitmsg=""
	case "$1" in
	0)
		exitmsg="All good, no error occurred"
		;;
	2)
		exitmsg="Unexpecting flag used"
		;;
	3)
		exitmsg="Buffer files aren't found, watch if daemon is running!"
		;;
	4)
		exitmsg="Actually, the buffer is empty"
		;;
	5)
		exitmsg="Actually, the position specified isn't written"
		;;
	*)
		exitmsg="Unexpected exit code, unknown status"
		;;
	esac
	
	logmsg="${logmsg}\n${exitmsg}"
	
	if [ $verbose = true ]
	then	
		echo -e "$logmsg"
	fi
}


# Funzione ausiliaria per gestire la stampa/caricamento dell'output
# Evita la duplicazione tra echo e xclip
dispatch_output() {
    local content="$1"
    if [ "$load" = true ]; then
        # Usa -rmlastnl per evitare che xclip aggiunga una newline extra se non voluta
        echo -n "$content" | xclip -sel clip
		
		sleep 0.01
		
        transform_ring_position_in_index 1
		awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
		NR == idx {
			print "String removed!"
			next
		}
		{ print }
		' "${files[$findex]}" > "$tmpfile" && mv "$tmpfile" "${files[$findex]}"

		logmsg="${logmsg}\nSpecified strings have been loaded in clipboard"
    else
    	echo "$content"
    fi
}


################### GESTIONE degli input (glag e argomenti) attraverso struttura a switch case ###################

while [[ $# -gt 0 ]]
do
    case "$1" in
        -i)	
        	if [ $# -lt 2 ]
        	then
        		logmsg="${logmsg}\n-i request an argument between 0-10, default used (1)"
				shift 1
        	elif [ $2 -gt 10 ] || [ $2 -lt 0 ]
        	then
        		logmsg="${logmsg}\n-i request an argument between 0-10, default used (1)"
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
        -l)
            load=true
            shift 1
            ;;
        -v)
        	verbose=true
            shift 1
            ;;
        *)
            exit 2
            ;;
    esac
done


##################################################################################################################

# da questo punto in poi si usano comandi che vogliono accedere al contenuto dei file buffer per questo motivo serve allora un
# un controllo sul fatto che questi esistano oppure no, farlo ora evita di dover gestire poi errori strani che possono verificarsi
# successivamente e rimanere occulti. NOTA: ricorda che il fatto che i file non esistano è un forte segnale che il demone non sta
# venendo eseguito perchè il .service, al momento dell'avvio crea sempre questi file.
# Verifica che i file esistano (rimuovi il commento se necessario)
if [ ! -f "${files[0]}" ] || [ ! -f "${files[1]}" ]; then
    exit 3
fi



# --- CASO 1: Posizione 0 (Mostra o svuota tutto) ---
if [ "$rposition" -eq 0 ]; then
    transform_ring_position_in_index 1

    if [ "$rindex" -eq -1 ]; then
        exit 4
    fi 

    if [ "$remove" = false ]; then
        # Mostra le ultime 10 stringhe
        # Passiamo la variabile 'load' dentro ad awk tramite -v
        out=$(awk -v RS='\0' -v is_load="$load" '
            { rec[++n] = $0 }
            END {
                count = 0
                for (i = n; i >= 1 && count < 10; i--) {
                    if (is_load == "true") {
                        # Output pulito per xclip: solo il testo grezzo
                        printf "%s\n", rec[i]
                        ++count
                    } else {
                        # Output formattato per il terminale: numeri rossi
                        printf "\x1B[1;31;49m%d.\x1B[0m \t%s\n", ++count, rec[i]
                    }
                }
            }
        ' "${files[$((1-findex))]}" "${files[$findex]}")
    	
    	logmsg="${logmsg}\nAll strings as captured!"
        dispatch_output "$out"
        exit 0
    else
        # Rimuove tutto il contenuto da ENTRAMBI i file (svuota il buffer)
        awk -v RS='\0' -v ORS='\0' '{ print "String removed!" }' "${files[$findex]}" > "$tmpfile" && mv "$tmpfile" "${files[$findex]}"
        awk -v RS='\0' -v ORS='\0' '{ print "String removed!" }' "${files[$((1-findex))]}" > "$tmpfile" && mv "$tmpfile" "${files[$((1-findex))]}"
        
        logmsg="${logmsg}\nAll strings as removed!"
        exit 0
    fi
fi



# --- CASO 2: Posizione specifica (1-10) ---
transform_ring_position_in_index "$rposition"

if [ "$rindex" -lt 0 ]; then
    exit 5
fi

# Estraiamo la stringa target (serve sia per la stampa semplice, sia se facciamo remove+load)
target_string=$(awk -v RS='\0' -v idx="$rindex" -v is_load="$load" -v n="$rposition" '
    NR == idx {
        if (is_load == "true") {
            print $0  # Stampa pulita per xclip
        } else {
            # Stampa formattata con numero rosso per il terminale
            printf "\x1B[1;31;49m%d.\x1B[0m \t%s\n", n, $0
        }
        exit
    }
' "${files[$findex]}")


if [ "$remove" = true  ]
then
	# Rimozione della stringa specifica
    awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
        NR == idx {
            print "String removed!"
            next
        }
        { print }
    ' "${files[$findex]}" > "$tmpfile" && mv "$tmpfile" "${files[$findex]}"

    logmsg="${logmsg}\nSpecified string removed"
fi

dispatch_output "$target_string"
exit 0


# if [ "$remove" = false ]; then
    # Solo lettura/load
    # dispatch_output "$target_string"
    # exit 0
# else
    # Rimozione della stringa specifica
    # awk -v RS='\0' -v ORS='\0' -v idx="$rindex" '
        # NR == idx {
            # print "String removed!"
            # next
        # }
        # { print }
    # ' "${files[$findex]}" > "$tmpfile" && mv "$tmpfile" "${files[$findex]}"
    # 
    # Se l'utente ha chiesto SIA -r SIA -l, carichiamo comunque la stringa rimossa in xclip
    # dispatch_output "$target_string"
    # exit 0
# fi 
 
 