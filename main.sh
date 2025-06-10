#!/bin/bash

# Configuration
URL="https://api-public.lesgrandsbuffets.com/v1/context/availabilities"
GET_URL="https://api-public.lesgrandsbuffets.com/v1/context/available-times-and-rooms"
HEADERS=(
    -H "Host: api-public.lesgrandsbuffets.com"
    -H "User-Agent: "
    -H "Accept: application/json"
    -H "Accept-Language: fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3"
    -H "Accept-Encoding: gzip, deflate, br, zstd"
    -H "X-AUTH-TOKEN: "
    -H "Origin: https://reservation.lesgrandsbuffets.com"
    -H "DNT: 1"
    -H "Connection: keep-alive"
    -H "Referer: https://reservation.lesgrandsbuffets.com/"
    -H "Sec-Fetch-Dest: empty"
    -H "Sec-Fetch-Mode: cors"
    -H "Sec-Fetch-Site: same-site"
    -H "Sec-GPC: 1"
    -H "Pragma: no-cache"
    -H "Cache-Control: no-cache"
    -H "TE: trailers"
    -H "Priority: u=4"
)
APPRISE_URL="tgram://"
TITLE="GRANDS BUFFETS DE NARBONNE"
INPUT_FILE="/home/maho/grandsbuffetslist_dates.csv"

echo "Date d'exécution : $(date +"%d/%m/%Y à %Hh%M")"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Erreur : Fichier $INPUT_FILE introuvable !"
    exit 1
fi

response=$(curl -s -o response.json -w "%{http_code}" "$URL" "${HEADERS[@]}")
echo "HTTP Return Code (POST) : $response"

if [ "$response" -ne 200 ]; then
    message_body="Erreur dans l'exécution du script (Code HTTP: $response)"
    echo "$message_body"
    docker exec apprise apprise -vv -t "$TITLE" -b "$message_body" "$APPRISE_URL"
    rm -f response.json
    exit 1
fi

while IFS=";" read -r date service nbpersonnes; do
    if ! [[ "$nbpersonnes" =~ ^[0-9]+$ ]]; then
        echo "Erreur : '$nbpersonnes' n'est pas un nombre valide."
        continue
    fi

    moment="noon"
    if [ "$service" = "soir" ]; then
        moment="evening"
    fi

    echo "?? Vérification pour $date ($service) - $nbpersonnes personne(s)..."
    date_json=$(jq -r --arg date "$date" '.[$date] // {}' response.json)

    if [ -n "$date_json" ] && echo "$date_json" | jq -e --arg nbpersonnes "$nbpersonnes" --arg service "$service" '.[$nbpersonnes | tostring][$service] == true' > /dev/null; then
        GET_URL_ENCODED="${GET_URL}?booking%5Bdate%5D=$date&booking%5Bmoment%5D=$moment&booking%5BpaxCount%5D=$nbpersonnes"
        GET_RESPONSE=$(curl -s -o get_response.json -w "%{http_code}" "$GET_URL_ENCODED" "${HEADERS[@]}")
        echo "HTTP Return Code (GET) : $GET_RESPONSE"

        if [ "$GET_RESPONSE" -ne 200 ] || [ ! -s get_response.json ]; then
            message_body="Erreur dans l'exécution du script (Code HTTP: $GET_RESPONSE)"
            echo "$message_body"
            docker exec apprise apprise -vv -t "$TITLE" -b "$message_body" "$APPRISE_URL"
            rm -f get_response.json
        else
            feedback=$(jq -r '.feedback' get_response.json)
            if [[ "$feedback" == *"Nous sommes au regret de vous informer que le restaurant est complet"* ]]; then
                echo "? FEEDBACK : Le restaurant est complet pour ce service ($date - $service)."
            else
                message_body="? Une table pour $nbpersonnes personne(s) est disponible le $date ($service)"
                echo "$message_body"
                docker exec apprise apprise -vv -t "$TITLE" -b "$message_body" "$APPRISE_URL"
            fi
        fi
        rm -f get_response.json
    else
        echo "? Pas de table disponible pour $nbpersonnes personne(s) le $date ($service)"
    fi
done < "$INPUT_FILE"

rm -f response.json
