# ============================================================================
# Regras ProGuard/R8 para o Pre-Venc
# ============================================================================

# --- ML Kit Text Recognition ---
# O app usa apenas o reconhecedor Latin (português).
# As classes dos reconhecedores de chinês, japonês, coreano e devanágari
# não são incluídas no build de release, então o R8 precisa ignorá-las.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Mantém as classes do ML Kit que são usadas em runtime (via reflexão)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# --- Flutter Local Notifications ---
# Necessário para o funcionamento das notificações agendadas e interativas
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- Supabase / OkHttp (usado pelo supabase_flutter) ---
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# --- Mobile Scanner (usado para leitura de códigos de barras) ---
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**
