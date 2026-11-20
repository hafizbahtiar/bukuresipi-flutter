import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_constant.dart';

/// Under an owner's edit page's bar: says, the whole time, that Save changes what every user sees (no mode to
/// switch: the owner's edits are always for everyone; a user's are always their own).
class OwnerStrip extends StatelessWidget implements PreferredSizeWidget {
  const OwnerStrip(this.text, {super.key});

  final String text;

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      key: const ValueKey('owner-strip'),
      height: 32,
      color: nb.kunyit.withValues(alpha: 0.22),
      padding: const EdgeInsets.symmetric(horizontal: spaceM),
      child: Row(
        children: [
          Icon(Icons.public, size: 16, color: nb.ink),
          const SizedBox(width: spaceS),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner's delete dialogs (their content): who this delete reaches, so a delete for every user is never mistaken
/// for one from their own book. Not a choice: each delete button does one of the two.
class DeleteScopeCard extends StatelessWidget {
  const DeleteScopeCard({
    super.key,
    required this.everyone,
    required this.text,
  });

  final bool everyone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = everyone ? scheme.error : nb.pandanDeep;
    return Container(
      key: ValueKey(everyone ? 'delete-scope-everyone' : 'delete-scope-mine'),
      margin: const EdgeInsets.only(top: spaceM),
      padding: const EdgeInsets.all(spaceS + 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            everyone ? Icons.public : Icons.person_outline,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: spaceS),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: nb.ink),
            ),
          ),
        ],
      ),
    );
  }
}
