import 'package:flutter/widgets.dart';

/// Spacing for the standard (base) pages, on a 4 px grid. Page side padding = [spaceM].
const spaceXs = 4.0;
const spaceS = 8.0;
const spaceM = 16.0;
const spaceL = 24.0;

/// Screen sizes (logical px). Material's window classes: under [wideFrom] = a phone held upright.
const wideFrom = 600.0;

/// Lists and forms past this width stay a centred column of it (WidePage).
const readableWidth = 720.0;

/// The map's sheet on a wide screen: a panel on the left, the map beside it.
const sidePanelWidth = 400.0;

/// The feed's narrowest card: the grid adds a column per this much width.
const feedCardMinWidth = 220.0;

/// A tablet, a desktop window or a phone on its side. Inside a WidePage the screen reads [readableWidth] wide.
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideFrom;
