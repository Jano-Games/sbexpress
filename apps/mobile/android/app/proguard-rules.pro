# google_mlkit_text_recognition: the app ships only the Latin text model, but
# the plugin's code also names the Chinese, Devanagari, Japanese and Korean
# recognizer options, which are compile-only. Let R8 drop those references.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
