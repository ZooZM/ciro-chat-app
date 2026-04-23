import 'package:flutter/material.dart';

class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // TODO: Handle group name input
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 10, // TODO: Replace with actual contacts list
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text('Contact ${index + 1}'),
                    value: false, // TODO: Manage selected state
                    onChanged: (bool? value) {
                      // TODO: Handle contact selection
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement group creation logic
              },
              child: const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
