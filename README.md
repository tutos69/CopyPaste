# CopyPaste 📋

**El portapapeles de Windows, en tu Mac.** Gratis y de código abierto.

- **Capturas directo al portapapeles**: ⌘⇧4 (recorte) y ⌘⇧3 (pantalla completa) copian la imagen, igual que `Win + Shift + S`. Solo pegas con ⌘V.
- **Historial del portapapeles con ⌘⇧V**, igual que `Win + V`: textos e imágenes que copiaste, listos para volver a pegar.
- **Copia el texto de la pantalla con ⌘⇧2**: recorta cualquier zona (una imagen, un video, un PDF escaneado) y obtienes el texto para pegarlo. Lee español e inglés, sin internet.

Es una app pequeña de la barra de menú: sin cuentas, sin internet, sin anuncios. El historial se guarda solo en tu Mac.

---

## Instalación

### Opción 1: un solo comando (recomendada)

Abre la app **Terminal**, pega esto y pulsa Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/tutos69/CopyPaste/main/install.sh | bash
```

### Opción 2: descarga manual

1. Descarga **CopyPaste.zip** desde [Releases](https://github.com/tutos69/CopyPaste/releases/latest).
2. Descomprímelo y mueve **CopyPaste.app** a la carpeta **Aplicaciones**.
3. La primera vez, haz **clic derecho → Abrir → Abrir**. macOS lo pide porque la app no está firmada con una cuenta de pago de Apple. Si aun así no abre, ve a Ajustes del Sistema → Privacidad y seguridad y pulsa **"Abrir de todos modos"**.

### Después de instalar

1. Aparece un ícono 📋 en la barra de menú, arriba a la derecha.
2. macOS te pedirá el permiso de **Accesibilidad** (Ajustes del Sistema → Privacidad y seguridad → Accesibilidad → CopyPaste). Sirve para que, al elegir algo del historial, se **pegue solo**. Sin el permiso, igual se copia y lo pegas tú con ⌘V.
3. La primera vez que uses ⌘⇧2, macOS pedirá el permiso de **Grabación de pantalla** (Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla → CopyPaste). Sin él, la captura no ve el contenido de las ventanas. Después de darlo, cierra y vuelve a abrir CopyPaste.
4. En el menú del ícono, activa **"Abrir al iniciar sesión"** para que arranque sola cada vez que enciendas la Mac.

Requisitos: macOS 14 (Sonoma) o posterior. Funciona en Mac con Apple Silicon y con Intel.

---

## Cómo se usa

| Acción | Atajo |
|---|---|
| Captura de un recorte al portapapeles | ⌘⇧4 |
| Captura de pantalla completa al portapapeles | ⌘⇧3 |
| Copiar el texto de una zona de la pantalla | ⌘⇧2 |
| Abrir/cerrar el historial | ⌘⇧V |
| Moverse por el historial | ↑ ↓ |
| Pegar el elemento seleccionado | ↩ o clic |
| Pegar el texto que hay dentro de una imagen | ⌥↩ o botón 🔍 |
| Pegar uno de los 9 primeros | 1 – 9 |
| Borrar el elemento seleccionado | ⌫ |
| Cerrar | esc |

- 📌 **Anclar**: pasa el mouse sobre un elemento y pulsa el pin. Los anclados no se borran con "Borrar todo".
- Guarda hasta **50** elementos. Los más viejos se borran solos.
- No guarda lo que se copia desde gestores de contraseñas (1Password, Bitwarden, etc.).
- ¿Quieres volver a guardar las capturas como archivo? Desmarca **"Capturas (⌘⇧3 / ⌘⇧4) al portapapeles"** en el menú.

> Nota: en algunas apps (Notas, Pages), ⌘⇧V también es "Pegar y adaptar estilo". Mientras CopyPaste está abierta, ese atajo abre el historial.

---

## Desinstalar

1. En el menú del ícono, desmarca "Capturas al portapapeles" y elige **Salir**.
2. Borra **CopyPaste.app** de Aplicaciones.
3. Opcional: borra el historial guardado con `rm -rf ~/Library/Application\ Support/CopyPaste`.

---

## Compilar desde el código

Solo necesitas las Command Line Tools de Apple (`xcode-select --install`); no hace falta Xcode.

```bash
git clone https://github.com/tutos69/CopyPaste.git
cd CopyPaste
./build.sh --install     # compila, instala en /Aplicaciones y abre
./build.sh --release     # crea build/CopyPaste.zip para publicar
```

Estructura:

- `Sources/CopyPaste/ClipboardStore.swift`: vigila el portapapeles y guarda el historial.
- `Sources/CopyPaste/HistoryPanel.swift`: el panel del historial (⌘⇧V).
- `Sources/CopyPaste/AppDelegate.swift`: menú de la barra, atajo global y ajuste de capturas.
- `Sources/CopyPaste/HotKey.swift`: registro de los atajos globales.
- `Sources/CopyPaste/OCR.swift`: reconocimiento de texto con Vision de Apple, en la propia Mac.
- `Sources/CopyPaste/Toast.swift`: el aviso corto que aparece en pantalla.

## Contribuir

¡Las contribuciones son bienvenidas! Abre un *issue* con ideas o errores, o envía un *pull request*.

## Licencia

[MIT](LICENSE): libre para usar, copiar, modificar y compartir.
