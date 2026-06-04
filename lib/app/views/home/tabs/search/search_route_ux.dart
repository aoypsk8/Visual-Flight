/// Which route endpoint the user is placing via map tap.
enum MapPinPickTarget { from, to }

/// Search tab route-building steps for copy and UI state.
enum SearchRouteUxStep {
  findingOrigin,
  chooseDestination,
  routeReady,
}

extension SearchRouteUxStepX on SearchRouteUxStep {
  String get hint {
    switch (this) {
      case SearchRouteUxStep.findingOrigin:
        return 'Getting your location…';
      case SearchRouteUxStep.chooseDestination:
        return 'Tap below to choose where you are flying';
      case SearchRouteUxStep.routeReady:
        return 'Your route is ready — pick a seat when you are';
    }
  }

  String get primaryLabel {
    switch (this) {
      case SearchRouteUxStep.findingOrigin:
        return 'Please wait';
      case SearchRouteUxStep.chooseDestination:
        return 'Choose destination';
      case SearchRouteUxStep.routeReady:
        return 'Select seat';
    }
  }

  bool get primaryEnabled {
    switch (this) {
      case SearchRouteUxStep.findingOrigin:
        return false;
      case SearchRouteUxStep.chooseDestination:
      case SearchRouteUxStep.routeReady:
        return true;
    }
  }
}
