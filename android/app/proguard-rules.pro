# ──────────────────────────────────────────────────────────────
# ProGuard / R8 — CuniGest (V2.5)
# ──────────────────────────────────────────────────────────────

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# mobile_scanner (ML Kit)
-keep class com.google.mlkit.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# JSON / Serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
