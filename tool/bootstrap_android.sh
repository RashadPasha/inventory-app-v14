#!/usr/bin/env bash
set -euo pipefail

flutter create --platforms=android --project-name muno_inventory --org com.muno365 .

# `flutter create` nümunə widget testi yaradır. Muno Inventory öz tətbiq
# sinifindən istifadə etdiyi üçün həmin demo testi Android CI-dan çıxarırıq.
rm -f test/widget_test.dart
rmdir test 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text()
needle = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
permissions = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.CAMERA" />\n    <uses-permission android:name="android.permission.INTERNET" />'''
if 'android.permission.CAMERA' not in s:
    s = s.replace(needle, permissions)
s = s.replace('android:label="muno_inventory"', 'android:label="Muno Inventory"')
p.write_text(s)
PY

echo "Android platform hazırdır. Növbəti addım: flutter pub get && flutter run"
