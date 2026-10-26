#!/bin/bash
# comprobar-acl.sh - Una política de acceso con ACL (SEGIN-ACT12)
# Uso: bash comprobar-acl.sh  (como root, desde la carpeta donde guardas los .txt)
[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo como root"; exit 1; }
E=/srv/empresa; C=$E/contabilidad; V=$E/comercial; P=$E/proyectos
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
grupos() {  # grupos USUARIO grupo1 grupo2...
  local u=$1 g hay; shift; hay=$(id -nG "$u" 2>/dev/null || echo "no existe")
  for g in "$@"; do echo " $hay " | grep -q " $g " || { anota 1 "$u está en: $*" "$hay"; return; }; done
  anota 0 "$u está en: $*"
}

echo "== Preparación =="
[ -z "$(find $E -perm /o=rwx 2>/dev/null)" ]
anota $? "el resto no tiene permisos en nada de $E" "$(find $E -perm /o=rwx 2>/dev/null | head -1)"
sudo -u pablo touch $E/comun/.de-pablo 2>/dev/null
sudo -u sara rm -f $E/comun/.de-pablo 2>/dev/null
[ -e $E/comun/.de-pablo ]; anota $? "en comun nadie borra lo de otro (sara no borra lo de pablo)"
rm -f $E/comun/.de-pablo
grupos becario empleados comercial
hay=$(getent shadow auditora | cut -d: -f8)
[ -n "$hay" ] && [ "$hay" = $(( $(date -d 2026-12-31 +%s) / 86400 )) ]
anota $? "la cuenta de auditora caduca el 2026-12-31" "$( [ -n "$hay" ] && date -d "@$((hay * 86400))" +%F || echo nunca)"
id auditora >/dev/null 2>&1 && ! id -nG auditora | grep -qw empleados
anota $? "auditora no está en empleados"

echo; echo "== Requisito 1: dirección lee contabilidad =="
si ana listar $C;  si ana leer $C/balance.txt
no ana crear $C;   no ana modificar $C/balance.txt

echo; echo "== Requisito 2: el becario solo lee en comercial =="
si becario listar $V; no becario crear $V
si sara crear $V

echo; echo "== Requisito 3: la auditora lee contabilidad =="
no auditora listar $E; si auditora listar $C; si auditora leer $C/balance.txt
no auditora crear $C;  no auditora listar $V

echo; echo "== Lo que se cree después =="
sudo -u luis bash -c "echo nuevo > $C/.nuevo-luis" 2>/dev/null
si ana leer $C/.nuevo-luis; si auditora leer $C/.nuevo-luis
si marta modificar $C/.nuevo-luis
rm -f $C/.nuevo-luis
sudo -u sara bash -c "echo nuevo > $V/.nuevo-sara" 2>/dev/null
no becario modificar $V/.nuevo-sara
rm -f $V/.nuevo-sara
[ -s acl-politica.txt ] && grep -q "$C" acl-politica.txt
anota $? "acl-politica.txt está en esta carpeta y tiene la política"
p_ok=$ok; p_total=$total

echo; echo "== Reto =="
si sara crear $P; si luis crear $P
sudo -u sara bash -c "echo de-sara > $P/.de-sara" 2>/dev/null
sudo -u luis bash -c "echo de-luis > $P/.de-luis" 2>/dev/null
si luis modificar $P/.de-sara; si pablo modificar $P/.de-luis
si ana leer $P/.de-sara; no ana crear $P
rm -f $P/.de-sara $P/.de-luis
no auditora listar $P
[ -s acl-final.txt ] && grep -q "$P" acl-final.txt
anota $? "acl-final.txt está en esta carpeta y tiene proyectos"

echo
echo "Práctica: $p_ok de $p_total    Reto: $((ok - p_ok)) de $((total - p_total))"
echo "Nota: $ok de $total"
