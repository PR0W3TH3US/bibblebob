# ML Kit text recognition: only the Latin model is bundled; the other scripts are compile-only.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit finds its components by name at runtime (reflection); R8 must not strip or
# rename them, or text recognition crashes in release builds only.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# ML Kit finds its components by name at runtime (reflection); R8 must not strip or
# rename them, or text recognition crashes in release builds only.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
