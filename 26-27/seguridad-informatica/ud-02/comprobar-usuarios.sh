#!/bin/bash
# comprobar-usuarios.sh - Usuarios, grupos y contraseñas de una empresa (SEGIN-ACT11)
# Uso: bash comprobar-usuarios.sh  (como root)
[ "$(id -u)" -eq 0 ] || { echo "Ejecútalo como root"; exit 1; }
ok=0; total=0

anota() {   # anota CÓDIGO "lo que se espera" ["lo que hay"]
  total=$((total + 1))
  if [ "$1" -eq 0 ]; then ok=$((ok + 1)); echo "OK     $2"
  else echo "FALLO  $2${3:+   (hay: $3)}"; fi
}
grupos() {  # grupos USUARIO grupo1 grupo2...
  local u=$1 g hay; shift; hay=$(id -nG "$u" 2>/dev/null || echo "no existe")
  for g in "$@"; do echo " $hay " | grep -q " $g " || { anota 1 "$u está en: $*" "$hay"; return; }; done
  anota 0 "$u está en: $*"
}
cuenta() {  # cuenta USUARIO "Nombre completo": bash, carpeta personal y descripción
  local hay; hay=$(getent passwd "$1" | cut -d: -f5-7)
  [ "$hay" = "$2:/home/$1:/bin/bash" ] && [ -d "/home/$1" ]
  anota $? "$1 tiene carpeta personal, bash y la descripción «$2»" "${hay:-no existe}"
}
sombra() {  # sombra USUARIO CAMPO VALOR "descripción": campo de /etc/shadow
  local hay; hay=$(getent shadow "$1" | cut -d: -f"$2")
  [ "$hay" = "$3" ]; anota $? "$1: $4" "$hay"
}
estado() {  # estado USUARIO P|L "descripción": lo que dice passwd -S
  local hay; hay=$(passwd -S "$1" 2>/dev/null | cut -d' ' -f2)
  [ "$hay" = "$2" ]; anota $? "$1: $3" "${hay:-no existe}"
}

echo "== Cuentas =="
for g in empleados direccion contabilidad comercial; do
  getent group $g >/dev/null; anota $? "existe el grupo $g"
done
grupos ana empleados direccion
grupos luis empleados contabilidad
grupos marta empleados contabilidad
grupos pablo empleados comercial
grupos sara empleados comercial
cuenta ana "Ana Directora"
cuenta luis "Luis Contable"
cuenta marta "Marta Contable"
cuenta pablo "Pablo Comercial"
cuenta sara "Sara Comercial"
for u in ana marta sara; do estado $u P "tiene contraseña"; done

echo; echo "== Contraseñas =="
for u in ana luis marta pablo sara; do
  [ "$(getent shadow $u | cut -d: -f4-7)" = "1:90:7:10" ]
  anota $? "$u: contraseña de 1 a 90 días, aviso 7, gracia 10" "$(getent shadow $u | cut -d: -f4-7)"
done
grep -qE '^PASS_MAX_DAYS\s+90' /etc/login.defs && grep -qE '^PASS_MIN_DAYS\s+1' /etc/login.defs && grep -qE '^PASS_WARN_AGE\s+7' /etc/login.defs
anota $? "las cuentas nuevas nacen con 90 días, mínimo 1 y aviso 7"
grep -qE '^\s*minlen\s*=\s*12' /etc/security/pwquality.conf && grep -qE '^\s*minclass\s*=\s*3' /etc/security/pwquality.conf
anota $? "contraseñas de 12 caracteres y 3 tipos como mínimo"
[ "$(getent shadow luis | cut -d: -f3)" -gt 0 ] 2>/dev/null
anota $? "luis ha cambiado ya la contraseña que le obligaste a cambiar" "$(getent shadow luis | cut -d: -f3)"
estado sara P "la cuenta está desbloqueada"
p_ok=$ok; p_total=$total

echo; echo "== Reto =="
grupos elena empleados rrhh
cuenta elena "Elena RRHH"
grupos practicas empleados comercial
sombra practicas 8 $(( $(date -d 2026-12-31 +%s) / 86400 )) "la cuenta caduca el 31/12/2026"
sombra practicas 3 0 "tiene que cambiar la contraseña al entrar"
grupos marta empleados contabilidad comercial
estado pablo L "la cuenta está bloqueada"
[ -d /home/pablo ]; anota $? "pablo conserva su carpeta personal"

echo
echo "Práctica: $p_ok de $p_total    Reto: $((ok - p_ok)) de $((total - p_total))"
echo "Nota: $ok de $total"
