# Flutter & Firebase safe shrink rules for production

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Play services / Firebase components that use reflection
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep Kotlin metadata and coroutines (avoid reflective removals)
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**

# If using serialization/JSON via gson or kotlinx, uncomment as needed:
# -keep class com.google.gson.** { *; }
# -dontwarn com.google.gson.**
# -keep class kotlinx.serialization.** { *; }

# Keep generated provider registrars (plugins)
-keep class **GeneratedPluginRegistrant { *; }

# Reduce log spam in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}


