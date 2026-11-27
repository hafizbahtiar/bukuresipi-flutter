/// Where a push of [type] opens (null = nowhere): the tapped push (app.dart) and its inbox row both use it. A "share
/// ready" push has no type; its shareId goes to PushController.onTap.
String? pushPath(String type, Map<String, String> data) =>
    switch ((type, data['receiptId'] ?? data['placeId'])) {
      ('sign_in', _) => '/account/sessions',
      ('family', _) => '/family',
      ('badge', _) => '/badges',
      // The owner's digest and meter alerts: the overview has every count.
      ('owner' || 'meter', _) => '/owner',
      ('einvoice', final String id) => '/receipts/$id',
      ('market', final String id) => '/places/$id',
      // The owner's message: its whole text is in the inbox.
      ('message', _) => '/notifications',
      _ => null,
    };
