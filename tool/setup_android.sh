#!/usr/bin/env bash
# Генерирует android/ (его нет в git) и добавляет нужные разрешения.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d android ] || flutter create --platforms=android --org kz.craftsystem --project-name craft_post .
M=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$M"; then
  python3 - "$M" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
perms='''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
'''
s=s.replace('<application',perms+'    <application',1)
s=s.replace('android:label="craft_post"','android:label="CRAFT Посты"')
open(p,'w',encoding='utf-8').write(s)
PY
fi
# gal требует minSdk 21+ (в Flutter по умолчанию уже так).

# Постоянная подпись release-сборки: берётся из android/key.properties
# (его пишет CI из секретов). Без него — временный debug-ключ.
G=android/app/build.gradle.kts
if ! grep -q 'keystoreProperties' "$G"; then
  python3 - "$G" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
s='import java.util.Properties\n\n'+s
s=s.replace('android {','''val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.containsKey("storeFile")

android {''',1)
s=s.replace('    buildTypes {','''    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storeType = "pkcs12"
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {''',1)
s=s.replace('signingConfig = signingConfigs.getByName("debug")',
  'signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")',1)
open(p,'w',encoding='utf-8').write(s)
PY
fi
