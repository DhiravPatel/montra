import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds a route's page explicitly: go_router 18 only recognizes the
/// decoupled `material_ui` MaterialApp, so without this it would fall back
/// to transition-less pages (and no iOS back-swipe) under Flutter's own
/// `MaterialApp`.
Page<void> routePage(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, name: state.name, child: child);
