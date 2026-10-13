import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../widgets/common.dart';
import 'contact_card_screen.dart';

/// Opened when someone's tag or card link launches the app. The card is inside
/// the link, so saving it works without internet.
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key, required this.link});
  final Uri link;

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save() async {
    final contact = await AppScope.of(context).receiver.receive(widget.link);
    if (!mounted) return;
    if (contact == null) {
      setState(() => _broken = true);
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => ContactCardScreen(contactId: contact.id!, justReceived: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _broken
          ? EmptyState(
              icon: Icons.link_off,
              title: 'This card link is broken',
              text: 'The tag or link is incomplete or was changed. Ask the owner to share their card again.',
              action: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
