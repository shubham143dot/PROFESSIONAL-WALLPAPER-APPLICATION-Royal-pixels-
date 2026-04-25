# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Serialization (important for Firestore models)
-keepattributes Signature, Exceptions, *Annotation*
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName *;
}

# Image loading (CachedNetworkImage)
-keep class com.bumptech.glide.** { *; }

# UCrop (Image Cropper)
-keep class com.yalantis.ucrop.** { *; }

# General safety
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-dontwarn com.google.mlkit.**
-dontwarn com.csdcorp.speech_to_text.**
-dontwarn com.yalantis.ucrop.**

# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }

# Photo Manager / Media
-keep class com.flutter_candies.photo_manager.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Speech to Text
-keep class com.csdcorp.speech_to_text.** { *; }

# Firebase App Check & Play Integrity
-keep class com.google.firebase.appcheck.** { *; }
-keep class com.google.android.play.core.integrity.** { *; }
-keep class com.google.android.play.core.appverify.** { *; }
