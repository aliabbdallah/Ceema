import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  List<GlobalKey<NavigatorState>>? _navigatorKeys;

  void setNavigatorKeys(List<GlobalKey<NavigatorState>> keys) {
    _navigatorKeys = keys;
  }

  void push(Widget page, {int tabIndex = 0}) {
    if (_navigatorKeys == null || tabIndex >= _navigatorKeys!.length) {
      return;
    }
    _navigatorKeys![tabIndex].currentState?.push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void pop({int tabIndex = 0}) {
    if (_navigatorKeys == null || tabIndex >= _navigatorKeys!.length) {
      return;
    }
    _navigatorKeys![tabIndex].currentState?.pop();
  }

  void pushReplacement(Widget page, {int tabIndex = 0}) {
    if (_navigatorKeys == null || tabIndex >= _navigatorKeys!.length) {
      return;
    }
    _navigatorKeys![tabIndex].currentState?.pushReplacement(
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
