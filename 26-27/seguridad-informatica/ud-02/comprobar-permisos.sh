#!/bin/bash
# comprobar-permisos.sh - Carpetas y permisos de una empresa (SEGIN-ACT19)
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

echo "== Carpetas =="
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
p_ok=$ok; p_total=$total

echo; echo "== Reto =="
duenyo $E/rrhh root:rrhh
si elena crear $E/rrhh
nuevo elena $E/rrhh rrhh
no luis listar $E/rrhh
no ana listar $E/rrhh
si ana crear $E/comun/normativa
sudo -u ana bash -c "echo prueba > $E/comun/normativa/.de-ana" 2>/dev/null
si luis leer $E/comun/normativa/.de-ana
rm -f $E/comun/normativa/.de-ana
no luis crear $E/comun/normativa
no sara crear $E/comun/normativa
hay=$(su - ana -c umask 2>/dev/null)
[ "$hay" = 0007 ]; anota $? "ana entra con umask 007" "${hay:-no existe}"
su - ana -c "touch $E/direccion/.umask-ana" 2>/dev/null
hay=$(stat -c %a $E/direccion/.umask-ana 2>/dev/null || echo "no ha podido crear"); rm -f $E/direccion/.umask-ana
[ "$hay" = 660 ]; anota $? "lo que crea ana al entrar nace con 660" "$hay"

echo
echo "Práctica: $p_ok de $p_total    Reto: $((ok - p_ok)) de $((total - p_total))"
echo "Nota: $ok de $total"
