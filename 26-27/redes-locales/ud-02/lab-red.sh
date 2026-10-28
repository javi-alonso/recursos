#!/bin/bash
# Laboratorio «¿Por qué va lenta la red?» · Redes Locales · UD 02
# Prepara un contenedor LXC Ubuntu 22.04 de Proxmox (plantilla 101):
#   - instala las herramientas de medida
#   - crea dentro del contenedor una red local (lan0, 10.66.0.0/24) con un
#     servidor en 10.66.0.2, limitada a 100 Mb/s como un enlace Fast Ethernet;
#     el tráfico de esa red no sale del contenedor
#   - deja las órdenes red-info y averia
# Uso: wget -qO- <url>/lab-red.sh | bash   (la plantilla 101 no trae curl)

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecútalo como root." >&2
    exit 1
fi

echo "==> Instalando herramientas (tarda un minuto)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq iperf3 mtr-tiny dnsutils iftop nload ethtool iproute2 psmisc > /dev/null

# Red local de laboratorio: lan0 (10.66.0.1) <-> servidor (10.66.0.2) en un
# namespace. Se crea con un servicio para que vuelva a estar tras reiniciar.
cat > /usr/local/sbin/lab-red-arranque <<'EOF'
#!/bin/bash
ip netns del servidor 2> /dev/null
ip link del lan0 2> /dev/null
ip netns add servidor
ip link add lan0 type veth peer name eth0 netns servidor
ip addr add 10.66.0.1/24 dev lan0
ip link set lan0 up
ip netns exec servidor ip link set lo up
ip netns exec servidor ip addr add 10.66.0.2/24 dev eth0
ip netns exec servidor ip link set eth0 up
tc qdisc replace dev lan0 root tbf rate 100mbit burst 128kb latency 50ms
EOF
chmod 755 /usr/local/sbin/lab-red-arranque

cat > /etc/systemd/system/lab-red.service <<'EOF'
[Unit]
Description=Laboratorio de red: red local lan0 a 100 Mb/s con un servidor
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/lab-red-arranque

[Install]
WantedBy=multi-user.target
EOF

# Dos servidores iperf3 en el servidor: el 5201 para medir, el 5202 para las averías.
cat > /etc/systemd/system/iperf3-lab@.service <<'EOF'
[Unit]
Description=Servidor iperf3 del laboratorio (puerto %i)
After=lab-red.service
Requires=lab-red.service

[Service]
ExecStart=/usr/sbin/ip netns exec servidor /usr/bin/iperf3 -s -p %i
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/bin/red-info <<'EOF'
#!/bin/bash
GW=$(ip -4 route show default | awk '{print $3; exit}')
DNS=$(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf)
VEL=$(tc qdisc show dev lan0 | grep -o 'rate [0-9]*[A-Za-z]*' | awk '{print $2}')
echo
echo "  Equipo:              $(hostname)"
echo "  ── eth0 · red del centro e Internet ──"
echo "  IP / máscara:        $(ip -4 -br addr show eth0 | awk '{print $3}')"
echo "  Puerta de enlace:    $GW"
echo "  DNS:                 $DNS"
echo "  ── lan0 · red local del laboratorio ──"
echo "  IP / máscara:        $(ip -4 -br addr show lan0 | awk '{print $3}')"
echo "  Velocidad máxima:    ${VEL:-sin límite}"
echo "  Servidor de la LAN:  10.66.0.2"
echo
EOF
chmod 755 /usr/local/bin/red-info

# Las averías van codificadas para que no se lean con un simple cat.
cat > /usr/local/bin/averia <<'EOF'
#!/bin/bash
eval "$(base64 -d <<< 'Y2FzZSAiJDEiIGluCiAgICAxKQogICAgICAgIChleGVjIC1hIGFjdHVhbGl6YWRvciBpcGVyZjMgLWMgMTAuNjYuMC4yIC1wIDUyMDIgLXQgMCAtYiA3ME0gPiAvZGV2L251bGwgMj4mMSAmKQogICAgICAgIDs7CiAgICAyKQogICAgICAgIGdyZXAgLXEgJ15uYW1lc2VydmVyIDEwLjY2LjI1NS4yNTQnIC9ldGMvcmVzb2x2LmNvbmYgfHwKICAgICAgICAgICAgc2VkIC1pICcwLC9ebmFtZXNlcnZlci9zLy9uYW1lc2VydmVyIDEwLjY2LjI1NS4yNTRcbiYvJyAvZXRjL3Jlc29sdi5jb25mCiAgICAgICAgOzsKICAgIDMpCiAgICAgICAgdGMgcWRpc2MgcmVwbGFjZSBkZXYgZXRoMCByb290IG5ldGVtIGRlbGF5IDE1MG1zIDYwbXMgbG9zcyA4JQogICAgICAgIDs7CiAgICBxdWl0YXIpCiAgICAgICAgcGtpbGwgLWYgJ15hY3R1YWxpemFkb3InIHx8IHRydWUKICAgICAgICBzZWQgLWkgJy9ebmFtZXNlcnZlciAxMC42Ni4yNTUuMjU0JC9kJyAvZXRjL3Jlc29sdi5jb25mCiAgICAgICAgdGMgcWRpc2MgZGVsIGRldiBldGgwIHJvb3QgMj4gL2Rldi9udWxsIHx8IHRydWUKICAgICAgICBlY2hvICJSZWQgY29tbyBhbCBwcmluY2lwaW8uIgogICAgICAgIGV4aXQgMAogICAgICAgIDs7CiAgICAqKQogICAgICAgIGVjaG8gIlVzbzogYXZlcmlhIDF8MnwzICAgKGF2ZXJpYSBxdWl0YXI6IGRlamEgbGEgcmVkIGNvbW8gYWwgcHJpbmNpcGlvKSIKICAgICAgICBleGl0IDEKICAgICAgICA7Owplc2FjCmVjaG8gIkF2ZXLDrWEgJDEgYWN0aXZhZGEuIE1pZGUgb3RyYSB2ZXogeSBidXNjYSBxdcOpIHBhc2EuIgo=')"
EOF
chmod 755 /usr/local/bin/averia

systemctl daemon-reload
systemctl enable -q lab-red.service iperf3-lab@5201.service iperf3-lab@5202.service
systemctl restart lab-red.service
systemctl restart iperf3-lab@5201.service iperf3-lab@5202.service

echo "==> Listo."
red-info
