# Abrir la orden desde el correo — en web, Android e iOS

Los botones de los correos ya apuntan a:

```
https://www.miatracker.com/app/#/restock-management?request=<ID>
```

**Web ya funciona** con solo desplegar. Lo de abajo es lo que falta para que ese
mismo enlace abra la **app instalada** en el celular (App Links en Android,
Universal Links en iOS) en vez del navegador.

No se usa un esquema propio tipo `miatracker://`: un enlace `https` normal abre
la app si está instalada y el navegador si no. Un solo botón para los tres casos.

---

## Paso 0 — Desplegar el sitio (esto solo ya arregla la web)

En el repo `miatrackerweb` ya quedaron:

- `public/.well-known/apple-app-site-association`
- `public/.well-known/assetlinks.json`
- `vercel.json` — el rewrite catch-all ahora **excluye** `/.well-known/...`
  (antes se lo comía y devolvía el HTML de Angular)
- `angular.json` — se agregó un glob explícito para `.well-known/**`, porque el
  glob `**/*` de Angular **no copia carpetas que empiezan con punto**

Después de desplegar, verificar que devuelven JSON y no HTML:

```bash
curl -i https://www.miatracker.com/.well-known/apple-app-site-association
curl -i https://www.miatracker.com/.well-known/assetlinks.json
```

Ambos deben responder `200` con `Content-Type: application/json`.

---

## Paso 1 — Datos que faltan

### Android: el SHA-256 del keystore

`android/app/build.gradle.kts` firma release con la **clave de debug**:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Para el APK que estás distribuyendo hoy, el fingerprint es el de debug:

```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | grep SHA256
```

Copiá ese valor (formato `AB:CD:EF:...`) dentro de
`miatrackerweb/public/.well-known/assetlinks.json`, en
`sha256_cert_fingerprints`.

> Si en algún momento subís a Google Play, Play **re-firma** el APK: hay que
> agregar además el SHA-256 que aparece en
> *Play Console → Setup → App integrity → App signing key certificate*.
> El array acepta varios fingerprints.

### Android: el applicationId sigue siendo `com.example.miatracker`

Es el ID de ejemplo que genera Flutter. Funciona para App Links, pero
**Google Play rechaza cualquier package que empiece con `com.example.`**.

Cambiarlo ahora rompe la actualización sobre las instalaciones existentes
(Android lo trata como otra app: hay que desinstalar y reinstalar). Si vas a
publicar, es mejor cambiarlo **antes** de la primera subida:

- `android/app/build.gradle.kts` → `namespace` y `applicationId`
- mover `android/app/src/main/kotlin/com/example/miatracker/MainActivity.kt`
  al paquete nuevo y actualizar su `package`
- actualizar `package_name` en `assetlinks.json`

Sugerido para que coincida con iOS: `com.techsolutionsgt.miatracker`.

### iOS: bundle ID inconsistente

En `ios/Runner.xcodeproj/project.pbxproj` hay **tres** valores distintos según
la configuración:

| Línea | `PRODUCT_BUNDLE_IDENTIFIER`        |
|-------|------------------------------------|
| 510   | `miatracker`                       |
| 698   | `com.techsolutionsgt.miatracker`   |
| 721   | `com.example.miatracker`           |

El `apple-app-site-association` que quedó escrito asume
`G728P7G244.com.techsolutionsgt.miatracker` (el Team ID `G728P7G244` sí está
consistente en el proyecto). Hay que **unificar los tres a un solo bundle ID**;
si no, la configuración de Debug/Profile no va a validar el Universal Link.

---

## Paso 2 — Android: `AndroidManifest.xml`

Dentro de `<activity android:name=".MainActivity">`, junto al intent-filter que
ya existe para `io.supabase.miatracker`:

```xml
<!-- App Links: https://www.miatracker.com/app/... abre la app -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="www.miatracker.com"
        android:pathPrefix="/app" />
</intent-filter>

<!-- Entrega el enlace al Navigator de Flutter (lo resuelve MiaLinks.parseRoute) -->
<meta-data
    android:name="flutter_deeplinking_enabled"
    android:value="true" />
```

Verificar la asociación después de desplegar y de instalar el APK:

```bash
adb shell pm verify-app-links --re-verify com.example.miatracker
adb shell pm get-app-links com.example.miatracker
# debe decir: www.miatracker.com: verified
```

---

## Paso 3 — iOS: entitlement + `Info.plist`

1. En Xcode: target **Runner** → *Signing & Capabilities* → **+ Capability** →
   **Associated Domains**, y agregar:

   ```
   applinks:www.miatracker.com
   ```

   Eso crea `ios/Runner/Runner.entitlements` (hoy no existe).

2. En `ios/Runner/Info.plist`, agregar:

   ```xml
   <key>FlutterDeepLinkingEnabled</key>
   <true/>
   ```

3. El App ID en el Apple Developer Portal necesita el capability
   **Associated Domains** habilitado, y hay que regenerar el provisioning
   profile.

---

## ⚠️ Probar el reset de contraseña después de activar esto

`FlutterDeepLinkingEnabled` / `flutter_deeplinking_enabled` cambian **quién**
recibe los enlaces entrantes: pasan por el `Navigator` en vez de ir directo al
plugin. La app usa `io.supabase.miatracker://reset-password` para recuperar
contraseña, y ese flujo lo maneja `supabase_flutter` por su cuenta.

`main.dart` ya atiende ese caso primero en `_handleDeepLinks` (antes de la
lógica nueva de correos), así que debería seguir funcionando — pero **es el
único flujo que puede romperse con este cambio**. Probá "olvidé mi contraseña"
en un dispositivo real antes de publicar.

---

## Cómo queda el flujo, ya configurado

| Dónde se abre el correo | Qué pasa |
|---|---|
| Navegador (desktop o móvil sin la app) | Carga `miatracker.com/app/` y navega a la solicitud |
| Android con la app instalada | Abre la app directo en Restock Requests |
| iOS con la app instalada | Abre la app directo en Restock Requests |

**Limitación conocida:** si al abrir el enlace no hay sesión iniciada, la app
manda al login y **se pierde el destino** — después del login cae en el home,
no en la orden. Guardar la ruta pendiente y consumirla tras el login es un
cambio en `AuthWrapper` que no se hizo acá.
