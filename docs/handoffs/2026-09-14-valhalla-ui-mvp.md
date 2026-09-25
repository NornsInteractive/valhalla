# Valhalla UI Handoff - MVP Infrastructure Integration

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

## Allowed files

- `lib/features/**`
- `lib/widgets/**`
- `lib/app/**`
- `lib/l10n/**`
- UI-specific tests

Do not modify `core/`, `data/`, `infrastructure/`, `pubspec.yaml` or non-UI tests.

## Available Providers

- `dockerCliServiceProvider`
- `processServiceProvider`
- `serviceManagerProvider`
- `systemMetricsSamplerProvider`

## Required UI work

1. Add Docker, Dashboard, Processes and Services screens using Material 3 components.
2. Integrate loading, empty, offline, permission and non-zero exit states.
3. Keep the existing Stitch visual language and responsive breakpoints:
   - compact `<600dp`: NavigationBar
   - medium `600–1024dp`: collapsed NavigationRail
   - expanded `>1024dp`: NavigationRail plus inspector
4. Move every displayed string into both `app_en.arb` and `app_zh.arb`.
5. Add Widget tests for navigation, loading/error states and dangerous-action confirmation.

The backend contracts are intentionally display-independent. Do not add fake remote data or alter their signatures without a new handoff.
