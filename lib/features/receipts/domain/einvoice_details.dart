/// What a shop's e-invoice form asks for, typed once by the user and kept on this phone only (never sent to us): the
/// receipt page offers each as a copy button while the form is open.
class EinvoiceDetails {
  const EinvoiceDetails({
    this.name = '',
    this.tin = '',
    this.idNumber = '',
    this.email = '',
    this.phone = '',
    this.address = '',
  });

  /// As on the IC (or the company's registered name).
  final String name;

  /// LHDN tax identification number.
  final String tin;

  /// IC or passport number.
  final String idNumber;
  final String email;
  final String phone;
  final String address;

  bool get isEmpty => [
    name,
    tin,
    idNumber,
    email,
    phone,
    address,
  ].every((v) => v.trim().isEmpty);

  Map<String, String> toJson() => {
    'name': name,
    'tin': tin,
    'idNumber': idNumber,
    'email': email,
    'phone': phone,
    'address': address,
  };

  factory EinvoiceDetails.fromJson(Map<String, dynamic> j) => EinvoiceDetails(
    name: j['name'] as String? ?? '',
    tin: j['tin'] as String? ?? '',
    idNumber: j['idNumber'] as String? ?? '',
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    address: j['address'] as String? ?? '',
  );
}

/// Per account ([userId]), so another account signed in on the same phone never sees them.
abstract interface class EinvoiceDetailsStore {
  Future<EinvoiceDetails> load(String userId);
  Future<void> save(String userId, EinvoiceDetails details);
}
