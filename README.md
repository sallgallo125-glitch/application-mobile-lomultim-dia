# LO Multimédia — Flutter port (in progress)

A from-scratch Flutter port of `../mobile-app` (Expo/React Native). This
folder was written **without a local Flutter/Dart SDK available** — there
was no `flutter`/`dart` binary in the environment that generated it, so
none of this has been run through `flutter pub get`, `flutter analyze`, or
`flutter run` yet. Treat the first setup run as the real correctness check.

## First-time setup

```bash
cd flutter_app
flutter create . --platforms=android,ios   # scaffolds android/, ios/, etc. without touching lib/ or pubspec.yaml
flutter pub get
flutter analyze                            # fix anything it flags before running
flutter run
```

`flutter create .` is safe to run on an existing project directory — it
only adds the platform folders (`android/`, `ios/`, …) that are missing,
it will not overwrite `lib/`, `pubspec.yaml`, or this README.

## Scope

Only **Accueil (Home)** is fully ported — banner carousel, category grid,
flash-sales rail, best-sellers rail, services grid, footer. The other four
tabs (Boutique, Panier, Lo+, Compte) are placeholder screens so the bottom
navigation is fully wired and clickable, matching how `../mobile-app`
itself started (tab shell + one real screen).

## Architecture — mapping to the RN app

The same layering rule from `../DEVELOPMENT_RULES.md` applies here:

```
route → screen → provider (feature hook) → repository → ApiClient → mock
```

| RN / Expo (`../mobile-app`)              | Flutter (here)                                   |
|---|---|
| Zod schemas (`src/contracts/*.ts`)       | Plain classes with `fromJson` (`lib/contracts/`) — no `freezed`/`json_serializable`, since those need `build_runner` codegen this environment couldn't run |
| TanStack Query (`useQuery`)              | Riverpod `FutureProvider` (`lib/features/*/*_providers.dart`) |
| Zustand (`useFavoritesStore`, etc.)      | Not needed yet (no client-only state ported); would be a Riverpod `StateProvider`/`Notifier` when it's needed, to keep one state library covering both roles |
| `apiClient` (`src/api/client.ts`)        | `ApiClient` (`lib/api/api_client.dart`) — thin wrapper over `package:http` |
| `mockFetch.ts` (monkey-patches `fetch`)  | `MockHttpClient extends http.BaseClient` (`lib/mocks/mock_http_client.dart`) — passed into `ApiClient` explicitly instead of patching a global, since Dart has no global `fetch` to intercept |
| `expo-router` file-based routes          | `go_router` with `StatefulShellRoute.indexedStack` (`lib/navigation/`) |
| `theme/tokens.ts`                        | `lib/theme/tokens.dart` — same literal values, keep both in sync by hand |

Mock data in `lib/mocks/data/` is kept as raw `Map<String, dynamic>`
literals (not typed model instances) so it flows through the exact same
`fromJson` parsing path a real HTTP response would — mirroring how the RN
mock transport also round-trips through `JSON.stringify`/`JSON.parse` and
Zod validation, not just in-memory objects.

## Testing

`test/home_repository_test.dart` exercises `HomeRepository` against a
hand-rolled fake `http.Client` (success / HTTP error / invalid payload),
mirroring `../mobile-app/tests/integration/homeRepository.test.ts`. No
mocking package is used, since generating mocks with `mockito`/`build_runner`
wasn't possible without the Dart toolchain here.

Run with:

```bash
flutter test
```

## Known gaps / next steps

- No `android/`, `ios/`, etc. — run `flutter create .` first (see above).
- Only Accueil is built; Boutique/Panier/Lo+/Compte/Connexion and the rest
  of `../SCREENS.md` are not yet ported.
- No app icon/splash configuration — using Flutter defaults.
- Since this was written blind (no SDK to compile against), please run
  `flutter analyze` before assuming anything beyond "it reads like valid
  Dart" — package API surfaces (`go_router`, `flutter_riverpod`) can drift
  between versions in ways static reading won't catch.







