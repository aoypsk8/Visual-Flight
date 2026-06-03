# Airport data flow (offline)

Airports come from **`assets/data/airport_search_index.json`** (~7.9k IATA airports, mwgg subset). No external airport API.

## Env

```env
MAPBOX_ACCESS_TOKEN=...   # maps only
API_BASE_URL=...          # FocusFlight backend (auth), not airports
```

## Layers

```
AirportPickerSheet / FlightSearchController
  → AirportRepository
  → AirportApiService (offline)
  → AirportLocalSearch + AirportSearchIndexStore
  → airport_search_index.json
```

## Search

- User types ≥ 2 characters → fuzzy match on city, name, country, IATA/ICAO.
- Popular list on open: `kPopularPickerIata` in `lib/app/config/airport_network.dart`.

## FROM (GPS)

- Device location → `AirportLocalSearch.nearest()` (Haversine over bundled index).
- No network call.

## Updating data

Edit or regenerate `assets/data/airport_search_index.json` (e.g. mwgg GitHub export). Hot restart required.
