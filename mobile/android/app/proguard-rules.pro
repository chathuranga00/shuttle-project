# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Mobile Scanner
-keep class com.zxing.** { *; }
-keep class com.google.mlkit.** { *; }

# Keep models for JSON serialization if needed
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
