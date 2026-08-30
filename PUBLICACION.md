# Checklist de publicación — M.I.A Tracker

**App:** Mia Tracker · `com.techsolutions.miatracker`
**Cuenta:** TechSolutions gt (personal) · ID 6780170369569630926
**Huella de la clave de subida:** `C9:71:99:09:5A:32:F7:8C:C2:35:5F:14:15:B9:F3:26:87:8A:F1:F9:C3:12:D3:22:26:D1:3E:64:E6:04:C1:92`

---

## 🔴 Bloquea el lanzamiento a producción

### Verificación de desarrollador de Android
Fecha límite: **30 de septiembre de 2026**. Si no se completa, la app se retira de Play a nivel mundial.

- [x] Registrar nombre del paquete
- [ ] **Pestaña «Identidad»** — verificación de identidad del desarrollador

### Contenido de la app
Play Console → *Política y programas* → *Contenido de la app*

- [ ] **Política de privacidad** — la actual en `miatracker.com/privacidad` dice explícitamente que *no cubre la aplicación*. Google exige que sí la cubra. Hay que agregarle una sección sobre datos de la app: correo, inventario, fotos, cámara y ubicaciones.
- [ ] **URL de eliminación de cuenta** — subir `legal/eliminar-cuenta.html` a la carpeta `public/` del sitio y pegar `https://www.miatracker.com/eliminar-cuenta.html`
- [ ] **Seguridad de los datos** — formulario completo
- [ ] **Clasificación de contenido** — cuestionario IARC
- [ ] **Público objetivo** — mayores de 18, uso empresarial
- [ ] **Anuncios** — declarar que la app no muestra publicidad
- [ ] **Apps gubernamentales** — no
- [ ] **Funciones financieras** — revisar: hay `checkout_screen` y órdenes de marketplace. Si no se procesan pagos reales dentro de la app, se declara «no»
- [ ] **Salud** — no

> ⚠️ **Detalles de acceso.** La app exige login. Si no le das credenciales de prueba al revisor, te rechazan automáticamente porque no puede entrar. Crea una cuenta demo con inventario cargado y ponla en *Detalles de acceso*.

### Ficha de Play Store

- [ ] Icono 512×512 PNG (sin canal alfa)
- [ ] Gráfico destacado 1024×500
- [ ] Mínimo 2 capturas de teléfono (recomendado 4–8)
- [ ] Descripción breve — máx. 80 caracteres
- [ ] Descripción completa — máx. 4000 caracteres
- [ ] Categoría de la app y datos de contacto

---

## ⏱️ Ruta a producción — el cuello de botella

Cuenta **personal** creada después del 13-nov-2023 → aplica el requisito de **12 testers opted-in durante 14 días continuos en prueba cerrada**. La prueba interna **no cuenta**.

- [ ] Publicar el borrador de **prueba interna** (inmediato)
- [ ] Verificar en dispositivo real desde Play — ver sección de pruebas funcionales
- [ ] Crear **prueba cerrada** y meter 12+ personas con cuenta de Google ← **empezar cuanto antes**
- [ ] Esperar 14 días continuos (si un tester se sale y vuelve, su contador se reinicia)
- [ ] Solicitar acceso a producción
- [ ] Revisión manual de Google — unos días más

**Alternativa:** convertir a cuenta de **organización** elimina este requisito, pero necesitas número D-U-N-S (gratis, tarda de días a semanas en emitirse).

---

## 🧪 Pruebas funcionales en dispositivo real

Este es el primer build con **R8/minify activo**. Ahí es donde aparecen los errores de ProGuard.

```bash
flutter build apk --release && flutter install --release
```

- [ ] Escáner de códigos de barras y QR (`mobile_scanner` / ML Kit — el más propenso a romperse con R8)
- [ ] Cámara y selección de fotos de la galería
- [ ] Login, registro y recuperación de contraseña
- [ ] Deep link de reset password (`io.supabase.miatracker://reset-password`)
- [ ] Generación y apertura de reportes PDF
- [ ] Permisos en Android 13+ (`READ_MEDIA_IMAGES`)

---

## 🔧 Técnico pendiente

### Eliminación de cuenta — verificar antes de la revisión

La Edge Function `delete-account` llama a `admin.auth.admin.deleteUser()`. Eso **falla con error 500** si alguna tabla con FK a `auth.users` no tiene `ON DELETE CASCADE`. Las tablas nuevas (`marketplace_orders`, `supply_orders`, `notifications`, `transfer_orders`, `restock_requests`) no están en el esquema original.

```sql
SELECT c.conrelid::regclass AS tabla, c.confdeltype
FROM pg_constraint c
JOIN pg_class f ON f.oid = c.confrelid
WHERE f.relname = 'users' AND c.contype = 'f';
```

`confdeltype` debe ser `c` en todas. Si sale `a`, esa tabla rompe el borrado.

- [ ] Correr la consulta y corregir los FK que falten
- [ ] Probar el borrado end-to-end con una cuenta desechable
- [ ] Confirmar que se puede exportar el inventario desde Reportes antes de borrar (lo afirma la página de eliminación)

### Seguridad

- [ ] **Cambiar la contraseña del keystore** — se expuso en una captura de pantalla

  ```bash
  keytool -storepasswd -keystore ~/keys/miatracker-upload.jks
  keytool -keypasswd  -keystore ~/keys/miatracker-upload.jks -alias upload
  ```
  Luego actualizar `android/key.properties`.

- [ ] **Respaldar** `~/keys/miatracker-upload.jks` y su contraseña en un gestor de contraseñas. Sin ellos no puedes volver a actualizar la app.

### Limpieza del repo

- [ ] Quitar `mi_app/` — proyecto Flutter de ejemplo, 129 archivos, nada lo usa

  ```bash
  git rm -r mi_app && git commit -m "chore: remove unused scaffold project"
  ```

- [ ] Destrackear artefactos de build

  ```bash
  git rm -r --cached build .dart_tool && git commit -m "chore: untrack build artifacts"
  ```

- [ ] Revisar los `print()` en código de producción (`restock_requests_screen.dart`, entre otros)

---

## 🍎 iOS — cuando toque

La configuración ya quedó correcta: bundle ID `com.techsolutions.miatracker`, permisos declarados en `Info.plist`, `ITSAppUsesNonExemptEncryption=false`, iconos sin canal alfa, y el Podfile alineado con el deployment target 15.0.

- [ ] Membresía del Apple Developer Program (99 USD/año)
- [ ] `cd ios && pod install` para aplicar el nuevo deployment target
- [ ] Probar en dispositivo real
- [ ] La misma URL de eliminación de cuenta sirve para App Store (Guideline 5.1.1(v))

---

## ✅ Ya hecho

- Package name `com.techsolutions.miatracker` consistente en Android e iOS
- Keystore de release creado y configurado en `key.properties` (gitignored)
- `targetSdk`/`compileSdk` 36 — requisito de Play desde el 31-ago-2026
- Gradle 8.14.3 · AGP 8.11.1 · Kotlin 2.2.20
- `proguard-rules.pro` con reglas para Supabase, ML Kit, image_picker y pdf
- Manifest limpio: sin `usesCleartextTraffic`, sin `requestLegacyExternalStorage`, sin `FLASHLIGHT`, `READ_EXTERNAL_STORAGE` limitado a API 32
- `.aab` firmado y subido a prueba interna (versión 1.0, código 4)
- Nombre de paquete registrado en Verificación de desarrolladores
- Página de eliminación de cuenta redactada en `legal/eliminar-cuenta.html`
