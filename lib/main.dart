
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'URL Viewer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const URLLauncherPage(),
    );
  }
}

class URLLauncherPage extends StatefulWidget {
  const URLLauncherPage({super.key});

  @override
  State<URLLauncherPage> createState() => _URLLauncherPageState();
}

class _URLLauncherPageState extends State<URLLauncherPage> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _useCustomTabs = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (_useCustomTabs && Platform.isAndroid) {
      try {
        await custom_tabs.launchUrl(
          uri,
            customTabsOptions: custom_tabs.CustomTabsOptions(
              colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
                  toolbarColor: Theme.of(context).primaryColor
              ),
              urlBarHidingEnabled: true,
              showTitle: true
          ),
        );
      } catch (e) {
        setState(() {
          _error = 'Could not launch with custom tabs: $e';
        });
      }
    } else {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        setState(() {
          _error = 'Could not launch $url';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Viewer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter URL',
                errorText: _error,
              ),
              keyboardType: TextInputType.url,
            ),
            Row(
              children: [
                Checkbox(
                  value: _useCustomTabs,
                  onChanged: (value) {
                    setState(() {
                      _useCustomTabs = value ?? false;
                    });
                  },
                ),
                const Text('Use Custom Tabs'),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
                _launchUrl(_controller.text);
              },
              child: const Text('Open URL'),
            ),
          ],
        ),
      ),
    );
  }
}
