import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'URL Viewer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: URLLauncherPage(),
    );
  }
}

class URLLauncherPage extends StatefulWidget {
  const URLLauncherPage({super.key});

  @override
  _URLLauncherPageState createState() => _URLLauncherPageState();
}

class _URLLauncherPageState extends State<URLLauncherPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _isCheckingPermissions = false;

  bool _isValidHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.scheme == 'https';
  }

  Future<Map<Permission, PermissionStatus>>
  _requestAndCheckPermissions() async {
    setState(() => _isCheckingPermissions = true);

    try {
      Map<Permission, PermissionStatus> statuses = {};

      List<Permission> permissions = [
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.locationWhenInUse,
      ];

      // First, check current statuses
      for (Permission permission in permissions) {
        PermissionStatus status = await permission.status;
        statuses[permission] = status;
        print(
          'Initial ${permission.toString().split('.').last} status: $status',
        );
      }

      // Check if any permission is permanently denied
      bool hasPermanentlyDenied = statuses.values.any(
        (status) => status == PermissionStatus.permanentlyDenied,
      );

      if (hasPermanentlyDenied) {
        print('Some permissions are permanently denied');
        return statuses;
      }

      // Request permissions that are not granted
      List<Permission> toRequest = [];
      for (var entry in statuses.entries) {
        if (entry.value != PermissionStatus.granted &&
            entry.value != PermissionStatus.permanentlyDenied) {
          toRequest.add(entry.key);
        }
      }

      if (toRequest.isNotEmpty) {
        print(
          'Requesting permissions: ${toRequest.map((p) => p.toString().split('.').last).join(', ')}',
        );

        // Request all permissions at once
        Map<Permission, PermissionStatus> requestResults = await toRequest
            .request();

        // Update statuses with new results
        statuses.addAll(requestResults);

        // Log final results
        statuses.forEach((perm, status) {
          print('Final ${perm.toString().split('.').last} status: $status');
        });
      }

      return statuses;
    } finally {
      setState(() => _isCheckingPermissions = false);
    }
  }

  bool _areAllPermissionsGranted(Map<Permission, PermissionStatus> statuses) {
    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  void _showPermissionDeniedDialog(Map<Permission, PermissionStatus> statuses) {
    List<String> deniedPermissions = [];
    List<String> permanentlyDeniedPermissions = [];
    List<String> restrictedPermissions = [];

    statuses.forEach((permission, status) {
      String permissionName = permission.toString().split('.').last;
      switch (status) {
        case PermissionStatus.permanentlyDenied:
          permanentlyDeniedPermissions.add(permissionName);
          break;
        case PermissionStatus.restricted:
          restrictedPermissions.add(permissionName);
          break;
        case PermissionStatus.denied:
          deniedPermissions.add(permissionName);
          break;
        default:
          break;
      }
    });

    bool hasPermanentlyDenied = permanentlyDeniedPermissions.isNotEmpty;
    bool hasRestricted = restrictedPermissions.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This app requires permissions to function properly:'),
              SizedBox(height: 12),

              if (deniedPermissions.isNotEmpty) ...[
                Text(
                  'Denied permissions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...deniedPermissions.map(
                  (perm) => Text('• ${perm.toUpperCase()}'),
                ),
                SizedBox(height: 8),
              ],

              if (restrictedPermissions.isNotEmpty) ...[
                Text(
                  'Restricted permissions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                ...restrictedPermissions.map(
                  (perm) => Text('• ${perm.toUpperCase()}'),
                ),
                SizedBox(height: 8),
              ],

              if (permanentlyDeniedPermissions.isNotEmpty) ...[
                Text(
                  'Permanently denied permissions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ...permanentlyDeniedPermissions.map(
                  (perm) => Text('• ${perm.toUpperCase()}'),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'To enable permanently denied permissions:\n'
                    '1. Go to device Settings\n'
                    '2. Find this app\n'
                    '3. Enable the required permissions\n'
                    '4. Restart the app',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          if (hasPermanentlyDenied || hasRestricted)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: Text('Open Settings'),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _onOpenPressed(); // Retry
              },
              child: Text('Try Again'),
            ),
        ],
      ),
    );
  }

  Future<void> _launchInChromeCustomTab(String url) async {
    try {
      await custom_tabs.launchUrl(
        Uri.parse(url),
        customTabsOptions: custom_tabs.CustomTabsOptions(
          colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
            toolbarColor: Theme.of(context).primaryColor,
          ),
          urlBarHidingEnabled: true,
          showTitle: true,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch custom tab: $e')),
      );
    }
  }

  Future<void> _launchInExternalBrowser(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch URL')));
    }
  }

  void _showLaunchOptions(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open With'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.chrome_reader_mode),
              title: Text('In App Browser'),
              onTap: () {
                Navigator.pop(context);
                _launchInChromeCustomTab(url);
              },
            ),
            ListTile(
              leading: Icon(Icons.web),
              title: Text('WebView'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InAppWebViewPage(url: url),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser),
              title: Text('External Browser'),
              onTap: () {
                Navigator.pop(context);
                _launchInExternalBrowser(url);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _onOpenPressed() async {
    if (_isCheckingPermissions) return;

    final url = _controller.text.trim();

    if (!_isValidHttps(url)) {
      setState(() => _error = 'Please enter a valid HTTPS URL');
      return;
    }

    setState(() => _error = null);

    // Request and check permissions
    final permissionStatuses = await _requestAndCheckPermissions();

    // Check if all permissions are granted
    if (_areAllPermissionsGranted(permissionStatuses)) {
      // All permissions granted, show launch options
      _showLaunchOptions(url);
    } else {
      // Some permissions denied, show error dialog
      _showPermissionDeniedDialog(permissionStatuses);
    }
  }

  // Debug widget to show current permission statuses
  Widget _buildPermissionDebugCard() {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, size: 16),
                SizedBox(width: 4),
                Text(
                  'Debug Info',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            FutureBuilder<Map<String, PermissionStatus>>(
              future: _getPermissionStatuses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('Loading permission statuses...');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snapshot.data!.entries.map((entry) {
                    Color statusColor = _getStatusColor(entry.value);
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.key}: ${entry.value.toString().split('.').last}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() {}), // Refresh the debug info
              child: Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, PermissionStatus>> _getPermissionStatuses() async {
    return {
      'Camera': await Permission.camera.status,
      'Microphone': await Permission.microphone.status,
      'Location': await Permission.location.status,
      'Location When In Use': await Permission.locationWhenInUse.status,
    };
  }

  Color _getStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
        return Colors.purple;
      case PermissionStatus.limited:
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('URL Viewer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter HTTPS URL',
                errorText: _error,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isCheckingPermissions ? null : _onOpenPressed,
              child: _isCheckingPermissions
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Checking Permissions...'),
                      ],
                    )
                  : Text('Open URL'),
            ),
            SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Required Permissions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Camera - For video calls and camera access'),
                    Text('• Microphone - For audio calls and recording'),
                    Text('• Location - For location-based services'),
                    SizedBox(height: 8),
                    Text(
                      'All permissions must be granted to open URLs.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildPermissionDebugCard(),
          ],
        ),
      ),
    );
  }
}

class InAppWebViewPage extends StatefulWidget {
  final String? url;
  final int? windowId;

  const InAppWebViewPage({super.key, this.url, this.windowId});

  @override
  _InAppWebViewPageState createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verifyPermissionsOnLoad();
  }

  Future<void> _verifyPermissionsOnLoad() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.locationWhenInUse,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );

    if (!allGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Permissions revoked. Please grant all permissions to continue.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  void _testPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    final locationStatus = await Permission.location.status;
    final locationWhenInUseStatus = await Permission.locationWhenInUse.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Camera: $cameraStatus'),
            Text('Microphone: $micStatus'),
            Text('Location: $locationStatus'),
            Text('Location When In Use: $locationWhenInUseStatus'),
            SizedBox(height: 16),
            Text('Troubleshooting tips:'),
            Text('• Try reloading the page'),
            Text('• Clear app data and restart'),
            Text('• Check console logs for errors'),
            if (Platform.isIOS) ...[
              SizedBox(height: 8),
              Text('iOS specific:'),
              Text('• Check app settings in iOS Settings'),
              Text('• Restart the app after changing permissions'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _webViewController?.reload();
            },
            child: Text('Reload WebView'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('In-App WebView'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            windowId: widget.windowId,
            initialUrlRequest: widget.url != null
                ? URLRequest(url: WebUri(widget.url!))
                : null,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              javaScriptCanOpenWindowsAutomatically: true,
              mediaPlaybackRequiresUserGesture: false,
              useHybridComposition: true,
              supportMultipleWindows: true,
              allowsInlineMediaPlayback: true,
            ),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              android: AndroidInAppWebViewOptions(
                useHybridComposition: true,
                supportMultipleWindows: true,
              ),
              ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onCreateWindow: (controller, createWindowRequest) async {
              print("onCreateWindow called");
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InAppWebViewPage(
                      windowId: createWindowRequest.windowId,
                    ),
                  ),
                );
              }
              return true;
            },
            onCloseWindow: (controller) async {
              print("Child WebView requested close. Popping screen...");
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);
              await controller.evaluateJavascript(
                source: """
                // JavaScript for debugging media and permission
                window.testWebViewPermissions = function() {
                  console.log('Testing getUserMedia permissions');
                  navigator.mediaDevices.getUserMedia({video: true, audio: true})
                    .then(stream => {
                      console.log('Permission granted');
                      stream.getTracks().forEach(track => track.stop());
                    })
                    .catch(err => {
                      console.error('Permission denied', err);
                    });
                };
              """,
              );
            },
            onConsoleMessage: (controller, consoleMessage) {
              print(
                "WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}",
              );
            },
            onReceivedError: (controller, request, error) {
              print("WebView Error: ${error.description}");
            },
            onPermissionRequest: (controller, request) async {
              print("Permission request for: ${request.resources}");

              // Check individual permission statuses
              var camera = await Permission.camera.status;
              var mic = await Permission.microphone.status;
              var location = await Permission.location.status;
              var locationWhenInUse = await Permission.locationWhenInUse.status;
              print(
                "Camera: $camera, Microphone: $mic, Location: $location, "
                "Location When In Use: $locationWhenInUse",
              );

              // Check if all required permissions are granted
              bool allGranted =
                  camera == PermissionStatus.granted &&
                  mic == PermissionStatus.granted &&
                  location == PermissionStatus.granted &&
                  locationWhenInUse == PermissionStatus.granted;

              if (!allGranted) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Required permissions not granted"),
                      backgroundColor: Colors.red,
                      action: SnackBarAction(
                        label: 'Settings',
                        onPressed: () => openAppSettings(),
                      ),
                    ),
                  );
                }
                return PermissionResponse(
                  resources: [],
                  action: PermissionResponseAction.DENY,
                );
              }

              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              var status = await Permission.location.status;
              print("Geolocation permission status: $status");

              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: status == PermissionStatus.granted,
                retain: true,
              );
            },
            androidOnPermissionRequest: (controller, origin, resources) async {
              var camera = await Permission.camera.status;
              var mic = await Permission.microphone.status;
              var location = await Permission.location.status;
              var locationWhenInUse = await Permission.locationWhenInUse.status;

              bool granted =
                  camera == PermissionStatus.granted &&
                  mic == PermissionStatus.granted &&
                  location == PermissionStatus.granted &&
                  locationWhenInUse == PermissionStatus.granted;

              return PermissionRequestResponse(
                resources: granted ? resources : [],
                action: granted
                    ? PermissionRequestResponseAction.GRANT
                    : PermissionRequestResponseAction.DENY,
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading WebView...'),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testPermissions,
        tooltip: 'Test Permissions',
        child: Icon(Icons.bug_report),
      ),
    );
  }
}
