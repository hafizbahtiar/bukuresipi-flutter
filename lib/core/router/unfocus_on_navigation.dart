import 'package:flutter/widgets.dart';

/// Drops keyboard focus whenever the route stack changes. A page kept in the stack (login -> register ->
/// back) must not put the keyboard back on the field that was focused before the push.
class UnfocusOnNavigation extends NavigatorObserver {
  UnfocusOnNavigation();

  static void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _unfocus();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unfocus();
    // The revealed page can claim focus again during the pop frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unfocus());
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _unfocus();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _unfocus();
}
