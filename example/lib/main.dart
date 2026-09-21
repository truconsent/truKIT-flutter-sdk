/// Test app for validating SDK functionality
import 'package:flutter/material.dart';
import 'package:truconsent_consent_notice_flutter/truconsent_consent_banner_flutter.dart' as truconsent;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruConsent SDK Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestApp(),
    );
  }
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  final _apiKeyController = TextEditingController(
    text: 'YOUR_API_KEY',
  );
  final _organizationIdController = TextEditingController(text: 'acme-dev');
  final _bannerIdController = TextEditingController(text: 'CP102');
  final _userIdController = TextEditingController(
    text: 'test-user-id',
  );

  bool _showModal = false;
  truconsent.ConsentAction? _lastAction;

  void _handleOpenModal() {
    if (_apiKeyController.text.isEmpty ||
        _organizationIdController.text.isEmpty ||
        _bannerIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }
    setState(() {
      _showModal = true;
    });
  }

  void _handleClose(truconsent.ConsentAction action) {
    setState(() {
      _lastAction = action;
      _showModal = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Consent action: ${action.value}')),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _organizationIdController.dispose();
    _bannerIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TruConsent SDK Test App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TruConsent SDK Test App',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Flutter Example',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _apiKeyController,
                          decoration: const InputDecoration(
                            labelText: 'API Key *',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _organizationIdController,
                          decoration: const InputDecoration(
                            labelText: 'Organization ID *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _bannerIdController,
                          decoration: const InputDecoration(
                            labelText: 'Banner ID *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            labelText: 'User ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _handleOpenModal,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Open Consent Banner'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_lastAction != null)
                  Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Action:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastAction!.value,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Checklist:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        _ChecklistItem(text: 'Banner loading'),
                        _ChecklistItem(text: 'Purpose toggling'),
                        _ChecklistItem(text: 'Accept All'),
                        _ChecklistItem(text: 'Reject All'),
                        _ChecklistItem(text: 'Accept Selected'),
                        _ChecklistItem(text: 'Cookie consent flow'),
                        _ChecklistItem(text: 'Error handling'),
                        _ChecklistItem(text: 'Internationalization'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Modal overlay
          if (_showModal)
            truconsent.TruConsentModal(
              apiKey: _apiKeyController.text,
              organizationId: _organizationIdController.text,
              bannerId: _bannerIdController.text,
              userId: _userIdController.text,
              onClose: _handleClose,
            ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String text;

  const _ChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

