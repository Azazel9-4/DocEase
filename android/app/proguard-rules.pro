# ML Kit Text Recognition - Ignore missing optional language libraries
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# General ML Kit ignore rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**