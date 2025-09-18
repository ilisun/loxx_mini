# LoxxMini (iOS)

Минималистичное iOS‑приложение с MapLibre и растровыми тайлами OSM.

## Требования
- Xcode 16/17+
- iOS 15+

## Сборка
```bash
cd /Users/borovinsky.in/dev/loxx_mini
xcodegen generate
open LoxxMini.xcodeproj
```
Выберите схему `LoxxMini`, устройство `Any iOS Simulator` и запустите.

Для сборки из CLI:
```bash
xcodebuild -project LoxxMini.xcodeproj -scheme LoxxMini -destination 'generic/platform=iOS Simulator' build
```

## Функциональность
- Карта на весь экран (OSM raster).
- Кнопки «–», «Найти меня», «+» в нижнем тулбаре.
- Центрирование по текущей позиции по запросу разрешения.
- Жесты масштабирования отключены (зум только кнопками).

## Разрешения
`NSLocationWhenInUseUsageDescription` — для отображения вашего местоположения.
