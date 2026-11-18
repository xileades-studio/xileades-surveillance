#!/usr/bin/env bash
# Contrôle de disponibilité : pages publiques, certificats, DNS et messagerie des domaines.
# Aucun secret, aucune adresse interne (décision du 18/11/2026, Central_Dogma 06-decisions/2026-11-18).
# Usage : controle.sh "hote1 hote2" "domaine1 domaine2" ["nom=https://…/sante …"]
# Le 3e argument (facultatif) : pages de santé des bases (couche 2, 18/11/2026).
# Elles rendent 200 {"etat":"ok"} ou 503 {"etat":"ko"} ; tout autre code est une panne.
set -uo pipefail
HOTES="$1"; DOMAINES="$2"; SANTE="${3:-}"
SEUIL_LENT=8        # secondes : au-delà, la page est jugée trop lente
SEUIL_CERT=14       # jours : un certificat qui expire plus tôt est en alerte
echec=0
ligne() { printf '| %s | %s | %s |\n' "$1" "$2" "$3"; }
echo "| Contrôle | Résultat | Détail |"; echo "|---|---|---|"
for h in $HOTES; do
  r=$(curl -sS -o /dev/null -w '%{http_code} %{time_total}' --max-time 20 --retry 2 --retry-delay 5 "https://$h/" 2>&1) || r="000 0"
  code=${r%% *}; t=${r##* }
  if [[ "$code" =~ ^(2|3) ]] && awk -v t="$t" -v s="$SEUIL_LENT" 'BEGIN{exit !(t<s)}'; then ligne "$h" "ok" "HTTP $code en ${t}s"
  else ligne "$h" "**KO**" "HTTP $code en ${t}s"; echec=1; fi
  fin=$(echo | timeout 15 openssl s_client -servername "$h" -connect "$h:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -n "$fin" ]; then
    jours=$(( ( $(date -d "$fin" +%s) - $(date +%s) ) / 86400 ))
    if [ "$jours" -ge "$SEUIL_CERT" ]; then ligne "$h (certificat)" "ok" "expire dans $jours j"
    else ligne "$h (certificat)" "**KO**" "expire dans $jours j"; echec=1; fi
  else ligne "$h (certificat)" "**KO**" "illisible"; echec=1; fi
done
for d in $DOMAINES; do
  # Résolution par DNS sur HTTPS (dns.google) : indépendante du résolveur du runner.
  doh() { curl -fsS --max-time 15 "https://dns.google/resolve?name=$1&type=$2" 2>/dev/null; }
  mx=$(doh "$d" MX | grep -o '"data":"[^"]*"' | head -1 | cut -d'"' -f4)
  spf=$(doh "$d" TXT | grep -c 'v=spf1'); dmarc=$(doh "_dmarc.$d" TXT | grep -c 'v=DMARC1')
  if [ -n "$mx" ] && [ "$spf" -ge 1 ] && [ "$dmarc" -ge 1 ]; then ligne "$d (messagerie)" "ok" "MX, SPF et DMARC présents"
  else ligne "$d (messagerie)" "**KO**" "MX=${mx:-absent} SPF=$spf DMARC=$dmarc"; echec=1; fi
done
for u in $SANTE; do
  nom=${u%%=*}; u=${u#*=}
  # Pas de --retry de curl ici : il rejoue aussi un 503, et le rejeu vers -o /dev/null sort en
  # erreur 23 (constaté le 18/11/2026). On ne rejoue que l'absence de réponse.
  for essai in 1 2 3; do
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$u" 2>/dev/null) || code=000
    [ "$code" != "000" ] && break; sleep 5
  done
  if [ "$code" = "200" ]; then ligne "base $nom (santé)" "ok" "tâches planifiées et appels sortants sans erreur sur 30 min"
  elif [ "$code" = "503" ]; then ligne "base $nom (santé)" "**KO**" "la base signale une anomalie : voir les journaux de la fonction sante"; echec=1
  else ligne "base $nom (santé)" "**KO**" "page de santé injoignable (HTTP $code)"; echec=1; fi
done
exit $echec
