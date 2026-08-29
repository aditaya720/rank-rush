# ============================================================================
# Rank Rush — R8 / ProGuard rules for release builds (minifyEnabled = true).
# Most libraries ship their own consumer rules; the entries below are safe
# insurance for the specific stack this app uses.
# ============================================================================

# --- Flutter embedding ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Google Play Core (referenced by Flutter's deferred-components code path;
#     absent unless you use split installs — silence the R8 warnings). ---
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# --- Firebase (Auth, Firestore, Functions, Messaging, App Check, Crashlytics,
#     Analytics). The SDKs bundle consumer rules; keep model/annotations safe. ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics: keep line numbers + source file for readable stack traces, and
# preserve the annotation used to strip the original names in mappings.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Firestore uses reflection to (de)serialize model classes.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <methods>;
    @com.google.firebase.firestore.PropertyName <fields>;
}

# --- Google Sign-In ---
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**

# --- Kotlin / coroutines metadata ---
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn kotlin.**
-dontwarn kotlinx.**

# --- Keep annotations used for JSON/reflection generally ---
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
