import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/base.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/recipe.dart';

/// A pick's name as the reader sees it: the product, or "Any Adabi" for a brand.
String pickLabel(AppLocalizations l, LinePick p) =>
    p.isBrand ? l.recipePickAny(p.name) : p.name;

/// The recipe's pick under its line: the name, then brand · maker · country small.
List<Widget> pickLines(BuildContext context, LinePick p) {
  final small = Theme.of(context).textTheme.bodySmall;
  final about = [if (!p.isBrand) ?p.brand, ?p.maker, ?p.country].join(' · ');
  return [
    Text(pickLabel(AppLocalizations.of(context), p)),
    if (about.isNotEmpty)
      Text(about, style: small?.copyWith(color: Notebook.of(context).inkSoft)),
    const SizedBox(height: 4),
  ];
}

/// A line's tags: Optional, Avoided (the reader avoids the pick), and the reader's own brand when it is not the pick.
List<Widget> pickTags(
  BuildContext context,
  LinePick? pick,
  String? myBrand, {
  bool optional = false,
}) {
  final l = AppLocalizations.of(context);
  return [
    if (optional) TagChip(TileTag(l.recipeOptional)),
    if (pick?.avoided ?? false)
      TagChip(TileTag(l.brandsAvoided, tone: TagTone.danger)),
    if (myBrand != null && myBrand != pick?.brand)
      TagChip(TileTag(l.recipeMyBrand(myBrand), tone: TagTone.good)),
  ];
}
