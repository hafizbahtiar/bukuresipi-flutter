// Standard app UI (Material 3, styled by app_theme.dart), replacing the notebook look page by page. Auth pages
// keep the notebook cover. Moving a page over:
//   NotebookPage            -> nothing (the Scaffold body as is)
//   NotebookTitle(t)        -> kept: page titles stay handwritten (the app's title font)
//   NotebookRow             -> ListTile in a plain list, or BaseTile for items that need telling apart
//   NotebookHeading(t)      -> SectionHeader(t)
//   NotebookSegmented       -> SegmentedButton
//   NotebookPinnedBar       -> PinnedBar
//   showBaseSheet       -> showBaseSheet (floating: false for a long picker or form)
//   showNotebookPicker      -> showBasePicker
//   showBaseDialog      -> showBaseDialog (same arguments)
//   notebookGutter + 10     -> spaceM (app_theme_constant.dart)

export 'base/dialog.dart';
export 'base/menus.dart';
export 'base/owner.dart';
export 'base/picker.dart';
export 'base/sheets.dart';
export 'base/tabs.dart';
export 'base/tiles.dart';
