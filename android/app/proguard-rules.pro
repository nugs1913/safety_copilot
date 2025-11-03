# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Camera
-keep class androidx.camera.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# Preserve line number information for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
