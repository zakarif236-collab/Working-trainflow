-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In plugin
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Firebase Auth credential classes used by Google Sign-In
-keep class com.google.firebase.auth.** { *; }

-keep class com.eyedeadevelopment.fluttertts.** { *; }
-keep class com.lucasjosino.on_audio_query.** { *; }
-dontwarn com.google.android.play.core.**
