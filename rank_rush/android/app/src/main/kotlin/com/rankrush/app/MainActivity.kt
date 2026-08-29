package com.rankrush.app

import io.flutter.embedding.android.FlutterActivity

/**
 * Single-Activity host for the Flutter engine.
 *
 * Rank Rush keeps all game logic in Dart (and, authoritatively, in Cloud
 * Functions), so no platform channels are registered here. FlutterActivity
 * wires up the embedding, plugins, and lifecycle automatically.
 */
class MainActivity : FlutterActivity()
