# Recursos de clase

Ficheros de partida para las prácticas y los exámenes: configuraciones, scripts de ejemplo y plantillas. Se descargan directamente en la máquina donde se trabaja, sin copiar y pegar.

## Cómo descargar un fichero

Con `curl` (o `wget`), usando la dirección *raw* del fichero:

```bash
curl -fsSLO https://raw.githubusercontent.com/javi-alonso/recursos/main/26-27/servicios-en-red/ud-01/nftables-partida.conf
```

* `-O` lo guarda con su nombre en la carpeta en la que estás. Para guardarlo con otro nombre o en otra ruta, usa `-o ruta/nombre`.
* `-f` hace que falle si la dirección no existe, en vez de guardar una página de error.

Para conseguir la dirección de cualquier fichero: ábrelo aquí, en GitHub, y pulsa **Raw**.

## Cómo está organizado

```text
<curso>/<módulo>/<unidad>/<fichero>
```

| Carpeta | Qué es |
| --- | --- |
| `26-27/` | Curso 2026-2027 |
| `servicios-en-red/` | Servicios en Red (2.º SMR) |
| `seguridad-informatica/` | Seguridad Informática (2.º SMR) |
| `redes-locales/` | Redes Locales (1.º SMR) |
| `ud-01/`, `ud-02/`… | Unidades didácticas, con el mismo código que en los apuntes y en Moodle |

En cada fichero, donde pone `X` va tu número de puesto, como en los apuntes.
