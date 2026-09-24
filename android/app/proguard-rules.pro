# Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep SQLite / Drift
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Keep local_auth / biometric
-keep class androidx.biometric.** { *; }

# Keep speech_to_text
-keep class com.csdcorp.speechtotext.** { *; }

# Keep notification channels
-keep class com.dexterous.** { *; }

# Keep share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Don't warn on missing optional classes
-dontwarn com.google.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
