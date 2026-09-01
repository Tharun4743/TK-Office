# Proguard / R8 rules for TK Office
-keepattributes *Annotation*
-keepclassmembers class * {
    @org.jetbrains.annotations.** *;
}
