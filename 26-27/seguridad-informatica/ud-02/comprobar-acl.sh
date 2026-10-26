#!/bin/bash
# comprobar-acl.sh - Una política de acceso con ACL (SEGIN-ACT12)
# Uso: bash comprobar-acl.sh  (como root, desde la carpeta donde guardas los .txt)
[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo como root"; exit 1; }
E=/srv/empresa; C=$E/contabilidad; T=$C/tarifas; P=$E/proyectos
ok=0; total=0

anota() {   # anota CÓDIGO "lo que se espera" ["lo que hay"]
  total=$((total + 1))
  if [ "$1" -eq 0 ]; then ok=$((ok + 1)); echo "OK     $2"
  else echo "FALLO  $2${3:+   (hay: $3)}"; fi
}
puede() {   # puede USUARIO ACCIÓN RUTA: lo intenta de verdad como ese usuario
  case $2 in
    listar)    sudo -u "$1" ls "$3" ;;
    leer)      sudo -u "$1" cat "$3" ;;
    crear)     sudo -u "$1" touch "$3/.prueba-$1" && rm -f "$3/.prueba-$1" ;;
    modificar) sudo -u "$1" test -w "$3" ;;
  esac >/dev/null 2>&1
}
si() { id "$1" >/dev/null 2>&1 || { anota 1 "$1 PUEDE $2 $3" "no existe el usuario"; return; }
     [ -e "$3" ] || { anota 1 "$1 PUEDE $2 $3" "no existe"; return; }
     puede "$1" "$2" "$3"; anota $? "$1 PUEDE $2 $3"; }
no() { id "$1" >/dev/null 2>&1 || { anota 1 "$1 NO puede $2 $3" "no existe el usuario"; return; }
     [ -e "$3" ] || { anota 1 "$1 NO puede $2 $3" "no existe"; return; }
     ! puede "$1" "$2" "$3"; anota $? "$1 NO puede $2 $3"; }
caduca() {  # caduca USUARIO AAAA-MM-DD
  local hay; hay=$(getent shadow "$1" | cut -d: -f8)
  [ -n "$hay" ] && [ "$hay" = $(( $(date -d "$2" +%s) / 86400 )) ]
  anota $? "la cuenta de $1 caduca el $2" "$( [ -n "$hay" ] && date -d "@$((hay * 86400))" +%F || echo nunca)"
}

echo "== Práctica =="
[ -d $T ] && [ "$(stat -c %G $T)" = contabilidad ]; anota $? "$T existe y es del grupo contabilidad"
caduca auditora 2026-12-31
id auditora >/dev/null 2>&1 && ! id -nG auditora 2>/dev/null | grep -qw empleados; anota $? "auditora no está en empleados"
[ -z "$(find $E -perm /o=rwx 2>/dev/null)" ]; anota $? "el resto (other) no tiene permisos en nada de $E" "$(find $E -perm /o=rwx | head -1)"
sudo -u pablo touch $E/comun/.de-pablo 2>/dev/null
sudo -u sara rm -f $E/comun/.de-pablo 2>/dev/null
[ -e $E/comun/.de-pablo ]; anota $? "en comun sigue sin poder borrarse lo de otro (sara no borra lo de pablo)"
rm -f $E/comun/.de-pablo
# Requisito 1: dirección lee contabilidad y comercial
si ana listar $C;  si ana leer $C/balance.txt
no ana crear $C;   no ana modificar $C/balance.txt
si ana listar $E/comercial; no ana crear $E/comercial
# Requisito 2: comercial atraviesa contabilidad y lee tarifas
no sara listar $C; no sara leer $C/balance.txt
si sara listar $T; si sara leer $T/tarifas-2026.txt; no sara crear $T
# Requisito 3: auditora
no auditora listar $E; si auditora listar $C; si auditora leer $C/balance.txt
no auditora crear $C;  no auditora listar $E/comercial
# Requisito 4: becario
si becario listar $E/comercial; no becario crear $E/comercial; si sara crear $E/comercial
# Requisito 5: herencia (se crea un fichero nuevo como luis y se prueba)
sudo -u luis bash -c "echo nuevo > $C/.nuevo-luis; echo nuevo > $T/.nuevo-luis" 2>/dev/null
si ana leer $C/.nuevo-luis; si auditora leer $C/.nuevo-luis
si marta modificar $C/.nuevo-luis; si sara leer $T/.nuevo-luis
rm -f $C/.nuevo-luis $T/.nuevo-luis
[ -s acl-politica.txt ] && grep -q "$T" acl-politica.txt
anota $? "acl-politica.txt está en esta carpeta y tiene la política"
p_ok=$ok; p_total=$total

echo; echo "== Reto =="
si sara crear $P; si luis crear $P
no marta crear $P; si marta listar $P
no becario crear $P; si becario listar $P
no ana crear $P;   si ana listar $P
sudo -u sara bash -c "echo de-sara > $P/.de-sara" 2>/dev/null
sudo -u luis bash -c "echo de-luis > $P/.de-luis" 2>/dev/null
si luis modificar $P/.de-sara; si pablo modificar $P/.de-luis
si consultora leer $P/.de-sara; no consultora crear $P
rm -f $P/.de-sara $P/.de-luis
no consultora listar $E; no consultora listar $C
caduca consultora 2026-11-30
no nobody listar $P
[ -s acl-final.txt ] && grep -q "$P" acl-final.txt
anota $? "acl-final.txt está en esta carpeta y tiene proyectos"

echo
echo "Práctica: $p_ok de $p_total    Reto: $((ok - p_ok)) de $((total - p_total))"
echo "Nota: $ok de $total"
