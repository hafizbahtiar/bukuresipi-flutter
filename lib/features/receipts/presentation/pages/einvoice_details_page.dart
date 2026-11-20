import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/einvoice_details.dart';

/// What a shop's e-invoice form asks for, typed once: the receipt page copies each one. Kept on this phone only.
class EinvoiceDetailsPage extends StatefulWidget {
  const EinvoiceDetailsPage({super.key});

  @override
  State<EinvoiceDetailsPage> createState() => _EinvoiceDetailsPageState();
}

class _EinvoiceDetailsPageState extends State<EinvoiceDetailsPage> {
  late final _store = context.read<EinvoiceDetailsStore>();
  late final _userId = context.read<AuthController>().user?.id;
  final _name = TextEditingController();
  final _tin = TextEditingController();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId != null) {
      final d = await _store.load(userId);
      _name.text = d.name;
      _tin.text = d.tin;
      _id.text = d.idNumber;
      _email.text = d.email;
      _phone.text = d.phone;
      _address.text = d.address;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final userId = _userId;
    if (userId == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _store.save(
      userId,
      EinvoiceDetails(
        name: _name.text.trim(),
        tin: _tin.text.trim(),
        idNumber: _id.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
      ),
    );
    messenger.showSnackBar(SnackBar(content: Text(l.einvoiceDetailsSaved)));
    if (navigator.canPop()) navigator.pop();
  }

  @override
  void dispose() {
    for (final c in [_name, _tin, _id, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget field(
      String key,
      TextEditingController c,
      String label, {
      TextInputType? type,
      List<String>? hints,
      int lines = 1,
      String? help,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: spaceS),
      child: TextField(
        key: ValueKey('einvoice-$key'),
        controller: c,
        keyboardType: type,
        autofillHints: hints,
        minLines: 1,
        maxLines: lines,
        textInputAction: lines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(labelText: label, helperText: help),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.einvoiceDetailsTitle),
      ),
      body: WidePage(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  spaceM,
                  spaceS,
                  spaceM,
                  spaceL,
                ),
                children: [
                  InfoCard(
                    text: l.einvoiceDetailsHelp,
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: spaceM),
                  field(
                    'name',
                    _name,
                    l.einvoiceName,
                    hints: const [AutofillHints.name],
                    help: l.einvoiceNameHelp,
                  ),
                  field('tin', _tin, l.einvoiceTin, help: l.einvoiceTinHelp),
                  field('id', _id, l.einvoiceIdNumber),
                  field(
                    'email',
                    _email,
                    l.einvoiceEmail,
                    type: TextInputType.emailAddress,
                    hints: const [AutofillHints.email],
                  ),
                  field(
                    'phone',
                    _phone,
                    l.einvoicePhone,
                    type: TextInputType.phone,
                    hints: const [AutofillHints.telephoneNumber],
                  ),
                  field(
                    'address',
                    _address,
                    l.einvoiceAddress,
                    type: TextInputType.streetAddress,
                    hints: const [AutofillHints.fullStreetAddress],
                    lines: 3,
                  ),
                  const SizedBox(height: spaceS),
                  FilledButton(
                    key: const ValueKey('einvoice-details-save'),
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l.save),
                  ),
                ],
              ),
      ),
    );
  }
}
