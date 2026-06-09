# Research: Map UI Google Maps Migration

## Google Maps Implementation

- **Decision**: Use `google_maps_flutter` package.
- **Rationale**: User requested Google Maps instead of OSM/flutter_map.
- **Alternatives considered**: Continuing with OSM, but the user explicitly rejected it.

## Navigation Bar

- **Decision**: Revert `MainShell` usage and custom `AppBottomNavBar` and fall back to the existing app's navigation bar structure.
- **Rationale**: User explicitly requested using the "navbar that exists from before".

## Map Type Toggle

- **Decision**: Add a `MapType` property to `MapState` and use the first action button in `MapFabColumn` to dispatch an event to toggle between `MapType.normal` and `MapType.satellite`.
- **Rationale**: Meets user requirements.
