# CRAFT Посты

Android-приложение (Flutter) для подготовки постов Instagram CRAFT SYSTEM:
фото из галереи → форма → AI (подпись + текст инфографики) → инфографика на главном фото,
логотип на остальных → превью → правка → «Сохранить всё» в галерею (альбом «CRAFT SYSTEM»).

## Что где
- `lib/models/post_draft.dart` — **набор полей формы** (`kInfographicFields`) и модель поста.
- `lib/services/image/template.dart` — **шаблон инфографики** и позиция логотипа (сейчас заглушка).
- `assets/logo.png` — логотип (сейчас заглушка, заменить файлом с тем же именем).
- `lib/services/ai/` — провайдеры AI (`stub`, `anthropic`, `openai`). Новый провайдер: класс `AiProvider` + строка в `ai_factory.dart`.
- В AI уходит только главное фото (≤1024 px, JPEG) и текст полей.
- Превью — 900 px; экспорт — полное разрешение, JPEG q92.

## Сборка APK
Без установки: GitHub → Actions → «Build APK (craft_post)» → Run workflow → артефакт `craft-post-apk`.

Локально (нужны Flutter и Android SDK):
```
cd craft_post
./tool/setup_android.sh      # создаёт android/ и добавляет разрешения
flutter pub get
flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk
```

## Установка на телефон
1. Скопируйте `app-release.apk` на телефон.
2. Откройте файл, разрешите «Установку из неизвестных источников».
3. Запустите «CRAFT Посты» → ⚙ Настройки → выберите провайдера и вставьте API-ключ
   (хранится в защищённом хранилище устройства). «Заглушка» работает без ключа.
