import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsScreen extends StatelessWidget {
  final List<Map<String, String>> contacts = [
    {
      'name': 'Daniel',
      'number': '0913-343-3245',
      'image': 'assets/images/avatar1.png',
    },
    {
      'name': 'Juliane',
      'number': '0913-343-3245',
      'image': 'assets/images/avatar2.png',
    },
    {
      'name': 'Simone',
      'number': '0913-343-3245',
      'image': 'assets/images/avatar3.png',
    },
  ];

  ContactsScreen({super.key});

  void _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showEmergencyCallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Emergency Call'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Call emergency services?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call 911'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  // For demo, just close dialog
                  Navigator.of(context).pop();
                  // In production, use url_launcher to dial 911
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmergencyCallDialog(context),
        backgroundColor: Colors.red,
        child: const Icon(Icons.call),
        tooltip: 'Emergency Call',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue[50],
            child: ListTile(
              leading: const Icon(
                Icons.add_circle,
                color: Colors.blue,
                size: 36,
              ),
              title: const Text('Add New'),
              onTap: () {}, // Non-functional for now
            ),
          ),
          const SizedBox(height: 12),
          ...contacts.map(
            (contact) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage(contact['image']!),
                  radius: 28,
                ),
                title: Text(
                  contact['name']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(contact['number']!),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () => _callNumber(contact['number']!),
                    ),
                    PopupMenuButton<String>(
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                      onSelected: (value) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
