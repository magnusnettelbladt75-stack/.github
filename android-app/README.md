# MinApp

En minimal Android-app skriven i Kotlin med Jetpack Compose och Material 3.
Appen visar en räknare med två knappar: "Klicka" och "Nollställ".

## Krav

- [Android Studio](https://developer.android.com/studio) (Ladybug eller nyare)
- JDK 17 (Android Studio levereras med en)
- Android SDK 35 (installeras via SDK Manager)

## Kom igång

1. Öppna mappen `android-app` i Android Studio (**File → Open**).
2. Vänta tills Gradle synkat klart.
3. Starta en emulator eller anslut en telefon med USB-felsökning påslagen.
4. Klicka på **Run ▶**.

Alternativt från terminalen, efter att du kört `gradle wrapper` i mappen:

```bash
./gradlew assembleDebug
```

APK:n hamnar i `app/build/outputs/apk/debug/`.

## Struktur

```
android-app/
├── build.gradle.kts              # Plugin-versioner
├── settings.gradle.kts           # Repon och modulen :app
├── gradle.properties
└── app/
    ├── build.gradle.kts          # Beroenden, minSdk 26, targetSdk 35
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/example/minapp/MainActivity.kt
        └── res/values/           # Strängar (svenska) och tema
```

## Anpassa

- **Paketnamn:** byt `com.example.minapp` i `app/build.gradle.kts` (`namespace` och `applicationId`) och flytta källfilerna till motsvarande mapp.
- **Texter:** redigera `app/src/main/res/values/strings.xml`.
