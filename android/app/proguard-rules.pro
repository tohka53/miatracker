# ============================================================
# ProGuard / R8 — M.I.A Tracker
# ============================================================

# ---------- Flutter ----------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ---------- Kotlin ----------
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# ---------- Supabase / OkHttp / Ktor (supabase_flutter) ----------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ---------- mobile_scanner (ML Kit Barcode) ----------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.android.odml.**

# ML Kit descarga modelos dinámicamente; no renombrar sus clases de opciones
-keepclassmembers class com.google.mlkit.vision.barcode.** { *; }

# ---------- image_picker / FileProvider ----------
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.lifecycle.** { *; }

# ---------- pdf / printing ----------
-dontwarn com.itextpdf.**
-keep class com.shockwave.** { *; }

# ---------- permission_handler ----------
-keep class com.baseflow.permissionhandler.** { *; }

# ---------- Play Core (usado por Flutter deferred components) ----------
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ---------- Genéricos ----------
# Conserva anotaciones y firmas genéricas (necesario para deserialización JSON)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# Mantiene los nombres de los enums (Supabase los usa en los filtros/policies)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Evita que R8 rompa las clases con constructores nativos
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
