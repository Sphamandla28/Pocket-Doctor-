// lib/app_all_in_one.dart
//
// Pocket Doctor (DR) – Single-file demo:
//  • New logo (doctor’s plus) as SVG with a preview page
//  • Offline MBTiles map (raster) via MapLibre style JSON
//  • Location page (request + read current GPS)
//  • Home page linking to everything
//
// Dependencies to add in pubspec.yaml (no build instructions here, just code):
//   dependencies:
//     flutter:
//       sdk: flutter
//     maplibre_gl: ^0.25.0         // MapLibre Flutter plugin (Android/iOS/Web) [pub.dev]
//     geolocator: ^12.0.0          // Location access (runtime permissions)
//     permission_handler: ^11.3.1  // Request runtime permissions
//     flutter_svg: ^2.0.10         // To preview the SVG logo
//     path_provider: ^2.1.3        // For local file paths
//     http: ^1.2.1                 // If you want to download MBTiles from a URL (optional)
//
// IMPORTANT: This file assumes your MBTiles is a *raster tiles* file.
//            If you have vector MBTiles, change the style source type and layers
//            (see style spec). Sources: MapLibre style spec + discussions.
//            https://maplibre.org/maplibre-style-spec/sources/   (raster/vector) [docs]
//
// References:
// • maplibre_gl plugin overview & platform notes: https://pub.dev/packages/maplibre_gl
// • MapTiler + Flutter MapLibre example (styleString usage): https://docs.maptiler.com/flutter/maplibre-gl-js/get-started/
// • MBTiles via MapLibre Native (mbtiles:// discussion): https://github.com/maplibre/maplibre-native/discussions/971
// • Style spec "sources" (raster/vector): https://maplibre.org/maplibre-style-spec/sources/

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// ---------------------------------------------------------------------------
/// 1) LOGO (doctor’s plus) – SVG in one file
/// ---------------------------------------------------------------------------
/// Save as an asset if you want, or just preview from the string below.
/// The logo is a rounded square with a white medical plus and subtle crosshair.

const String drLogoSvg = '''
<svg width="1024" height="1024" viewBox="0 0 1024 1024"
     xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Pocket Doctor Logo">
  <defs>
    <linearGradient id="grad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#1A237E"/>
      <stop offset="100%" stop-color="#3949AB"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="1024" height="1024" rx="220" fill="url(#grad)"/>
  <!-- subtle crosshair -->
  <line x1="128" y1="512" x2="896" y2="512" stroke="#FFFFFF22" stroke-width="12"/>
  <line x1="512" y1="128" x2="512" y2="896" stroke="#FFFFFF22" stroke-width="12"/>

  <!-- doctor plus (+) -->
  <rect x="432" y="256" width="160" height="512" rx="40" fill="#FFFFFF"/>
  <rect x="256" y="432" width="512" height="160" rx="40" fill="#FFFFFF"/>

  <!-- DR letters (optional accent) -->
  <text x="50%" y="915" text-anchor="middle" font-family="Inter,Arial" font-size="140"
        font-weight="700" fill="#FFFFFFAA">DR</text>
</svg>
''';

/// Simple preview widget for the logo (SVG).
class LogoPage extends StatelessWidget {
  const LogoPage({super.key});
  static const route = '/logo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DR Logo Preview')),
      body: Center(
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pocket Doctor (DR) – Logo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SvgPicture.string(
                  drLogoSvg,
                  width: 260,
                  height: 260,
                ),
                const SizedBox(height: 16),
                const Text('This SVG contains the medical plus symbol and subtle crosshair.'),
                const SizedBox(height: 8),
                const Text('You can export it to PNG (1024×1024) for launcher icons.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2) LOCATION – “another code” for getting current position
/// ---------------------------------------------------------------------------
/// This page requests runtime permissions and shows latitude/longitude.
/// The geolocator plugin does not auto-prompt; you request permissions yourself.
/// Source: maplibre_gl notes (permissions) + geolocator usage. [pub.dev]

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});
  static const route = '/location';
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String _status = 'Tap the button to get your location.';
  Position? _pos;

  Future<void> _requestPermissions() async {
    final loc = await Permission.location.request();
    if (!loc.isGranted) {
      setState(() => _status = 'Location permission denied.');
    } else {
      setState(() => _status = 'Permission granted.');
    }
  }

  Future<void> _getLocation() async {
    try {
      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _pos = p;
        _status = 'Location fetched.';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My Location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Status: $_status', style: t.bodyMedium),
          const SizedBox(height: 12),
          if (_pos != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Lat: ${_pos!.latitude}\nLng: ${_pos!.longitude}', style: t.titleMedium),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.lock_open),
            label: const Text('Request permission'),
            onPressed: _requestPermissions,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.my_location),
            label: const Text('Get current location'),
            onPressed: _getLocation,
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 3) OFFLINE MAP – MBTiles with MapLibre
/// ---------------------------------------------------------------------------
/// We build a style JSON referencing a *raster* MBTiles file via `mbtiles://`.
/// For simplicity we render a single raster layer named "offline".
///
/// IMPORTANT:
/// • Provide the path to your MBTiles raster file (PNG tiles).
/// • For a vector MBTiles, you'd set `type: "vector"` and add proper layers.
///   See MapLibre style spec "sources" + tilesets docs. [docs]
///
/// Sources:
/// • MapLibre style sources (raster/vector): https://maplibre.org/maplibre-style-spec/sources/
/// • Discussion of mbtiles:// in MapLibre Native: https://github.com/maplibre/maplibre-native/discussions/971
///
/// Optional helper is included to download an MBTiles file from a URL to app storage.

class OfflineMapPage extends StatefulWidget {
  const OfflineMapPage({super.key});
  static const route = '/offline-map';

  @override
  State<OfflineMapPage> createState() => _OfflineMapPageState();
}

class _OfflineMapPageState extends State<OfflineMapPage> {
  MaplibreMapController? _controller;
  String? _mbtilesPath; // absolute device path to your .mbtiles file
  String _status = 'Provide an MBTiles path or download one.';

  final TextEditingController _urlCtrl = TextEditingController(
    text: '', // e.g., "https://example.com/tiles-offline-raster.mbtiles"
  );

  Future<String> _defaultMbtilesPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/offline_raster.mbtiles';
  }

  /// Download MBTiles from a URL to app docs.
  /// You can skip this and copy your file manually to a known path.
  Future<void> _downloadMbtiles() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _status = 'Please enter an MBTiles URL first.');
      return;
    }
    try {
      setState(() => _status = 'Downloading MBTiles…');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        setState(() => _status = 'HTTP ${resp.statusCode}: failed to download.');
        return;
      }
      final p = await _defaultMbtilesPath();
      final f = File(p);
      await f.writeAsBytes(resp.bodyBytes);
      setState(() {
        _mbtilesPath = p;
        _status = 'MBTiles saved: $p';
      });
    } catch (e) {
      setState(() => _status = 'Download error: $e');
    }
  }

  /// Build a minimal raster style referencing mbtiles://<abs path>
  String _buildRasterStyle(String mbtilesAbsPath) {
    final style = {
      "version": 8,
      "name": "Offline Raster MBTiles",
      "sources": {
        "offline": {
          "type": "raster",
          "url": "mbtiles://$mbtilesAbsPath",
          "tileSize": 256
        }
      },
      "layers": [
        {"id": "offline", "type": "raster", "source": "offline"}
      ]
    };
    return jsonEncode(style);
  }

  Future<void> _loadOfflineStyle() async {
    if (_controller == null) return;
    final path = _mbtilesPath ?? await _defaultMbtilesPath();
    final f = File(path);
    if (!await f.exists()) {
      setState(() => _status = 'MBTiles not found at: $path');
      return;
    }
    setState(() => _status = 'Loading offline style from mbtiles://…');
    final ok = await _controller!.setStyleString(_buildRasterStyle(path));
    setState(() => _status = ok ? 'Offline style set.' : 'Failed to set style.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Map (MBTiles)')),
      body: Column(
        children: [
          Expanded(
            child: MaplibreMap(
              initialCameraPosition: const CameraPosition(
                // Start near Durban to see tiles (adjust to your tileset coverage)
                target: LatLng(-29.8587, 31.0218),
                zoom: 11,
              ),
              onMapCreated: (c) => _controller = c,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $_status', style: t.bodySmall),
                const SizedBox(height: 8),
                Text('MBTiles path: ${_mbtilesPath ?? '(none)'}', style: t.bodySmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'MBTiles URL (optional)',
                    hintText: 'https://your-server/offline-raster.mbtiles',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Download MBTiles'),
                        onPressed: _downloadMbtiles,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.layers),
                        label: const Text('Load Offline Style'),
                        onPressed: _loadOfflineStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tip: If you already have an MBTiles file on the device, '
                  'set _mbtilesPath to its absolute path and tap "Load Offline Style".',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 4) HOME – tile menu linking to Logo, Offline Map, and Location
/// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static const route = '/';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pocket Doctor (DR)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pocket Doctor (DR) – Logo, Location, and Offline Map (MBTiles) in one file.\n\n'
                '• Doctor’s plus (+) logo (SVG)\n'
                '• Location page (request + read GPS)\n'
                '• Offline raster MBTiles map via MapLibre style JSON',
                style: t.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.local_hospital),
            title: const Text('Preview Logo'),
            subtitle: const Text('Doctor’s plus (+) with crosshair'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(LogoPage.route),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Offline Map (MBTiles)'),
            subtitle: const Text('Load a raster MBTiles file via mbtiles://'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(OfflineMapPage.route),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('My Location'),
            subtitle: const Text('Request permission, read lat/lng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(LocationPage.route),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 5) APP – wire routes (all in one file)
/// ---------------------------------------------------------------------------

class PocketDoctorApp extends StatelessWidget {
  const PocketDoctorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Doctor (DR)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: HomePage.route,
      routes: {
        HomePage.route: (_) => const HomePage(),
        LogoPage.route: (_) => const LogoPage(),
        LocationPage.route: (_) => const LocationPage(),
        OfflineMapPage.route: (_) => const OfflineMapPage(),
      },
    );
  }
}

/// Entrypoint
void main() {
  runApp(const PocketDoctorApp());
}
 
