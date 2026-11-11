# Flutter Wrapper & Deferred Components
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-ignorewarnings

# Native Methods Preservation
-keepclasseswithmembernames class * {
    native <methods>;
}

# WebRTC Native Bindings & Camera
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn com.cloudwebrtc.webrtc.**

# Audioplayers & Native Audio Engine
-keep class audioplayers.net.codeengine.audioplayers.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep public class android.media.MediaPlayer { *; }
-keep public class android.media.MediaPlayer* { *; }

# Torch Light Plugin
-keep class com.svprdga.torch_light.** { *; }
-dontwarn com.svprdga.torch_light.**

# Hardware Plus Plugins (Battery, Wakelock)
-keep class dev.fluttercommunity.plus.battery.** { *; }
-dontwarn dev.fluttercommunity.plus.battery.**
-keep class dev.fluttercommunity.plus.wakelock.** { *; }
-dontwarn dev.fluttercommunity.plus.wakelock.**

# Firebase & Google Play Services
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Foreground Service (flutter_foreground_task)
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# QR Scanner & ML Kit
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# General Reflection and Enum Safety
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.**
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
