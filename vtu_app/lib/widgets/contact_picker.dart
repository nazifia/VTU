import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../config/theme.dart';

/// Shows a bottom sheet to pick a phone number from device contacts.
/// Returns the selected phone number string or null if cancelled.
Future<String?> pickContactPhone(BuildContext context) async {
  final status = await FlutterContacts.permissions.request(PermissionType.read);
  final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
  if (!granted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission denied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }

  final contacts = await FlutterContacts.getAll(
    properties: {ContactProperty.name, ContactProperty.phone},
  );
  contacts.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));

  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactPickerSheet(contacts: contacts),
  );
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _query = '';
  List<Contact> get _filtered => widget.contacts
      .where((c) => (c.displayName ?? '').toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.contacts_rounded,
                      color: AppTheme.primaryIndigo),
                  const SizedBox(width: 10),
                  Text('Select Contact',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            // Contact list
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 56,
                              color: Colors.grey.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No contacts found',
                              style: TextStyle(
                                  color: Colors.grey.withValues(alpha: 0.6))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        final phones = c.phones
                            .map((p) => p.number.replaceAll(RegExp(r'\s+'), ''))
                            .toList();
                        if (phones.isEmpty) return const SizedBox.shrink();

                        return Column(
                          children: phones.map((phone) {
                            // Normalise Nigerian numbers
                            String display = phone;
                            if (display.startsWith('+234')) {
                              display = '0${display.substring(4)}';
                            }
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryIndigo
                                    .withValues(alpha: 0.12),
                                child: Text(
                                  (c.displayName?.isNotEmpty ?? false)
                                      ? c.displayName![0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppTheme.primaryIndigo,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(c.displayName ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(display),
                              onTap: () => Navigator.pop(context, display),
                            );
                          }).toList(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
