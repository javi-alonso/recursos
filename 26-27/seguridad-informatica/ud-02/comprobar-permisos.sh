#!/bin/bash
# comprobar-permisos.sh - Usuarios, grupos y permisos de una empresa (SEGIN-ACT11)
# Uso: bash comprobar-permisos.sh  (como root)
[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo como root"; exit 1; }
E=/srv/empresa
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
    borrar)    sudo -u "$1" rm -f "$3" ;;
  esac >/dev/null 2>&1
}
si() { id "$1" >/dev/null 2>&1 || { anota 1 "$1 PUEDE $2 $3" "no existe el usuario"; return; }
     [ -e "$3" ] || { anota 1 "$1 PUEDE $2 $3" "no existe"; return; }
     puede "$1" "$2" "$3"; anota $? "$1 PUEDE $2 $3"; }
no() { id "$1" >/dev/null 2>&1 || { anota 1 "$1 NO puede $2 $3" "no existe el usuario"; return; }
     [ -e "$3" ] || { anota 1 "$1 NO puede $2 $3" "no existe"; return; }
     ! puede "$1" "$2" "$3"; anota $? "$1 NO puede $2 $3"; }
nuevo() {   # nuevo USUARIO CARPETA GRUPO: lo que crea ese usuario es del grupo
  local f="$2/.grupo-$1" hay
  sudo -u "$1" touch "$f" 2>/dev/null
  hay=$(stat -c %G "$f" 2>/dev/null || echo "no ha podido crear"); rm -f "$f"
  [ "$hay" = "$3" ]; anota $? "lo que crea $1 en $2 es del grupo $3" "$hay"
}
duenyo() {  # duenyo RUTA USUARIO:GRUPO
  local hay; hay=$(stat -c %U:%G "$1" 2>/dev/null || echo "no existe")
  [ "$hay" = "$2" ]; anota $? "$1 es de $2" "$hay"
}
grupos() {  # grupos USUARIO grupo1 grupo2...
  local u=$1 g hay; shift; hay=$(id -nG "$u" 2>/dev/null || echo "no existe")
  for g in "$@"; do echo " $hay " | grep -q " $g " || { anota 1 "$u está en: $*" "$hay"; return; }; done
  anota 0 "$u está en: $*"
}
sombra() {  # sombra USUARIO CAMPO VALOR "descripción": campo de /etc/shadow
  local hay; hay=$(getent shadow "$1" | cut -d: -f"$2")
  [ "$hay" = "$3" ]; anota $? "$1: $4" "$hay"
}

echo "== Cuentas =="
grupos ana empleados direccion
grupos luis empleados contabilidad
grupos marta empleados contabilidad
grupos pablo empleados comercial
grupos sara empleados comercial
[ "$(getent passwd luis | cut -d: -f7)" = /bin/bash ] && [ -d /home/luis ]
anota $? "luis tiene /bin/bash y carpeta personal"

echo; echo "== Carpetas =="
duenyo $E root:empleados
duenyo $E/comun root:empleados
duenyo $E/direccion root:direccion
duenyo $E/contabilidad root:contabilidad
duenyo $E/comercial root:comercial
si sara listar $E
no sara crear $E
no nobody listar $E
si sara crear $E/comun
nuevo sara $E/comun empleados
sudo -u pablo touch $E/comun/.de-pablo 2>/dev/null
no sara borrar $E/comun/.de-pablo
rm -f $E/comun/.de-pablo
si ana crear $E/direccion
no luis listar $E/direccion
si luis crear $E/contabilidad
nuevo luis $E/contabilidad contabilidad
no pablo listar $E/contabilidad
si sara crear $E/comercial
nuevo pablo $E/comercial comercial
no luis listar $E/comercial
[ "$(stat -c %U:%G $E/contabilidad/balance.txt 2>/dev/null)" = luis:contabilidad ]
anota $? "contabilidad/balance.txt es de luis:contabilidad" "$(stat -c %U:%G $E/contabilidad/balance.txt 2>/dev/null || echo no existe)"
grep -q "Marta" $E/contabilidad/balance.txt 2>/dev/null
anota $? "balance.txt tiene la línea de Marta"
no ana leer $E/contabilidad/balance.txt
[ "$(stat -c %U $E/comun/oferta.txt 2>/dev/null)" = pablo ]
anota $? "comun/oferta.txt es de pablo" "$(stat -c %U $E/comun/oferta.txt 2>/dev/null || echo no existe)"

echo; echo "== Contraseñas =="
for u in ana luis marta pablo sara; do
  [ "$(getent shadow $u | cut -d: -f4-7)" = "1:90:7:10" ]
  anota $? "$u: contraseña de 1 a 90 días, aviso 7, gracia 10" "$(getent shadow $u | cut -d: -f4-7)"
done
grep -qE '^PASS_MAX_DAYS\s+90' /etc/login.defs && grep -qE '^PASS_MIN_DAYS\s+1' /etc/login.defs && grep -qE '^PASS_WARN_AGE\s+7' /etc/login.defs
anota $? "las cuentas nuevas nacen con 90 días, mínimo 1 y aviso 7"
grep -qE '^\s*minlen\s*=\s*12' /etc/security/pwquality.conf && grep -qE '^\s*minclass\s*=\s*3' /etc/security/pwquality.conf
anota $? "contraseñas de 12 caracteres y 3 tipos como mínimo"
p_ok=$ok; p_total=$total

echo; echo "== Reto =="
grupos elena empleados rrhh
duenyo $E/rrhh root:rrhh
si elena crear $E/rrhh
nuevo elena $E/rrhh rrhh
no luis listar $E/rrhh
no ana listar $E/rrhh
grupos practicas empleados comercial
sombra practicas 8 $(( $(date -d 2026-12-31 +%s) / 86400 )) "la cuenta caduca el 31/12/2026"
sombra practicas 3 0 "tiene que cambiar la contraseña al entrar"
si ana crear $E/comun/normativa
sudo -u ana bash -c "echo prueba > $E/comun/normativa/.de-ana" 2>/dev/null
si luis leer $E/comun/normativa/.de-ana
rm -f $E/comun/normativa/.de-ana
no luis crear $E/comun/normativa
no sara crear $E/comun/normativa
grupos marta empleados contabilidad comercial
si marta crear $E/comercial
si marta modificar $E/contabilidad/balance.txt
[ "$(passwd -S pablo | cut -d' ' -f2)" = L ]
anota $? "la cuenta de pablo está bloqueada" "$(passwd -S pablo | cut -d' ' -f2)"

echo
echo "Práctica: $p_ok de $p_total    Reto: $((ok - p_ok)) de $((total - p_total))"
echo "Nota: $ok de $total"
