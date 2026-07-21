/// Business owner autofill + federal K-1 → Form 1040 Schedule E Part II linkage.
///
/// This is **data routing / form automation only** — it copies identity and
/// K-1 box amounts into Schedule E Part II rows. It does not compute federal
/// or state tax liability.
library;

/// Entity prep types that issue K-1s flowing to Schedule E Part II.
const k1PassThroughPrepTypes = <String>{
  'form1065',
  'form1120S',
  'form1041',
};

/// Entity prep types that support owner autofill via the business "+" action.
const businessOwnerPrepTypes = <String>{
  'form1065',
  'form1120S',
  'form1120',
  'form1041',
};

String ownerRoleForPrep(String prep) {
  switch (prep) {
    case 'form1065':
      return 'partner';
    case 'form1120S':
      return 'shareholder';
    case 'form1120':
      return 'officer';
    case 'form1041':
      return 'beneficiary';
    default:
      return 'owner';
  }
}

String scheduleEEntityTypeForPrep(String prep) {
  switch (prep) {
    case 'form1065':
      return 'partnership';
    case 'form1120S':
      return 's_corporation';
    case 'form1041':
      return 'estate_trust';
    default:
      return 'other';
  }
}

String entityDisplayName(Map<String, dynamic> form, String prep) {
  switch (prep) {
    case 'form1065':
      return '${form['partnershipName'] ?? ''}'.trim();
    case 'form1120S':
    case 'form1120':
      return '${form['corporationName'] ?? ''}'.trim();
    case 'form1041':
      return '${form['entityName'] ?? form['trustName'] ?? ''}'.trim();
    default:
      return '${form['entityName'] ?? form['organizationName'] ?? ''}'.trim();
  }
}

String personalFullName(Map<String, dynamic> data) {
  final first = '${data['firstName'] ?? ''}'.trim();
  final mid = '${data['middleInitial'] ?? ''}'.trim();
  final last = '${data['lastName'] ?? ''}'.trim();
  final parts = <String>[
    if (first.isNotEmpty) first,
    if (mid.isNotEmpty) mid,
    if (last.isNotEmpty) last,
  ];
  return parts.join(' ');
}

String personalAddressLine(Map<String, dynamic> data) {
  final street = '${data['address'] ?? ''}'.trim();
  final apt = '${data['apartment'] ?? ''}'.trim();
  if (street.isEmpty) return apt;
  if (apt.isEmpty) return street;
  return '$street $apt';
}

/// Empty owner / partner / shareholder / officer / beneficiary row.
Map<String, dynamic> emptyEntityOwner({
  String role = 'owner',
  bool isPrimary = false,
  String? id,
}) {
  return {
    'id': id ?? 'owner-${DateTime.now().microsecondsSinceEpoch}',
    'name': '',
    'tin': '',
    'address': '',
    'city': '',
    'state': '',
    'zip': '',
    'phone': '',
    'email': '',
    'ownershipPercentage': isPrimary ? 100 : 0,
    'isPrimary': isPrimary,
    'role': role,
  };
}

/// Federal K-1 intake row (1065 / 1120-S / 1041) used for 1040 Schedule E Part II.
Map<String, dynamic> emptyFederalK1({
  String sourceForm = 'form1065',
  String? id,
}) {
  return {
    'id': id ?? 'k1-${DateTime.now().microsecondsSinceEpoch}',
    'sourceForm': sourceForm,
    'entityName': '',
    'ein': '',
    'partnerOrShareholderName': '',
    'partnerOrShareholderTIN': '',
    'ownershipPercentage': 100,
    'ordinaryIncome': 0,
    'netRentalRealEstate': 0,
    'otherNetRentalIncome': 0,
    'guaranteedPayments': 0,
    'interestIncome': 0,
    'dividends': 0,
    'royalties': 0,
    'section179Deduction': 0,
    'selfEmploymentEarnings': 0,
  };
}

/// Form 1040 Schedule E Part II row (passthrough / K-1 interest).
Map<String, dynamic> emptyScheduleEPartII({
  String entityType = 'partnership',
  String? id,
  String? sourceK1Id,
}) {
  return {
    'id': id ?? 'se-pii-${DateTime.now().microsecondsSinceEpoch}',
    'sourceK1Id': sourceK1Id ?? '',
    'entityName': '',
    'ein': '',
    'entityType': entityType,
    'ordinaryIncome': 0,
    'netRentalRealEstate': 0,
    'otherNetRentalIncome': 0,
    'guaranteedPayments': 0,
    'section179Deduction': 0,
    'selfEmploymentEarnings': 0,
  };
}

Map<String, dynamic> ownerFromPersonalInfo(
  Map<String, dynamic> data, {
  required String role,
  bool isPrimary = true,
  String? id,
}) {
  final owner = emptyEntityOwner(role: role, isPrimary: isPrimary, id: id);
  owner['name'] = personalFullName(data);
  owner['tin'] = '${data['ssn'] ?? ''}'.trim();
  owner['address'] = personalAddressLine(data);
  owner['city'] = '${data['city'] ?? ''}'.trim();
  owner['state'] = '${data['state'] ?? ''}'.trim();
  owner['zip'] = '${data['zip'] ?? ''}'.trim();
  owner['phone'] = '${data['phone'] ?? ''}'.trim();
  owner['email'] = '${data['email'] ?? ''}'.trim();
  return owner;
}

List<Map<String, dynamic>> _listMaps(dynamic raw) {
  if (raw is! List) return [];
  return [
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

num _asNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

/// Ensure [form] has a primary owner seeded from personal info when missing.
Map<String, dynamic> autofillPrimaryOwnerOnEntityForm(
  Map<String, dynamic> data,
  Map<String, dynamic> form,
  String prep, {
  bool overwritePrimary = false,
}) {
  final next = Map<String, dynamic>.from(form);
  final role = ownerRoleForPrep(prep);
  final owners = _listMaps(next['owners']);
  final primaryIdx = owners.indexWhere((o) => o['isPrimary'] == true);
  final seeded = ownerFromPersonalInfo(data, role: role, isPrimary: true);

  if (primaryIdx < 0) {
    owners.insert(0, seeded);
  } else if (overwritePrimary) {
    final existingId = '${owners[primaryIdx]['id'] ?? ''}'.trim();
    owners[primaryIdx] = {
      ...seeded,
      if (existingId.isNotEmpty) 'id': existingId,
    };
  } else {
    final current = Map<String, dynamic>.from(owners[primaryIdx]);
    void fill(String key, dynamic value) {
      final s = '$value'.trim();
      if (s.isEmpty) return;
      if ('${current[key] ?? ''}'.trim().isEmpty) current[key] = value;
    }

    fill('name', seeded['name']);
    fill('tin', seeded['tin']);
    fill('address', seeded['address']);
    fill('city', seeded['city']);
    fill('state', seeded['state']);
    fill('zip', seeded['zip']);
    fill('phone', seeded['phone']);
    fill('email', seeded['email']);
    if (_asNum(current['ownershipPercentage']) <= 0) {
      current['ownershipPercentage'] = seeded['ownershipPercentage'];
    }
    current['role'] = role;
    current['isPrimary'] = true;
    owners[primaryIdx] = current;
  }

  next['owners'] = owners;

  // Mirror primary owner onto entity-specific identity fields when empty.
  final primary = owners.firstWhere(
    (o) => o['isPrimary'] == true,
    orElse: () => owners.isNotEmpty ? owners.first : seeded,
  );
  final name = '${primary['name'] ?? ''}'.trim();
  final tin = '${primary['tin'] ?? ''}'.trim();
  final address = '${primary['address'] ?? ''}'.trim();

  if (prep == 'form1041') {
    if ('${next['fiduciaryName'] ?? ''}'.trim().isEmpty && name.isNotEmpty) {
      next['fiduciaryName'] = name;
    }
    if ('${next['fiduciaryAddress'] ?? ''}'.trim().isEmpty && address.isNotEmpty) {
      next['fiduciaryAddress'] = address;
    }
    final beneficiaries = _listMaps(next['beneficiaries']);
    if (beneficiaries.isEmpty && name.isNotEmpty) {
      next['beneficiaries'] = [
        {
          'name': name,
          'tin': tin,
          'address': address,
          'city': primary['city'] ?? '',
          'state': primary['state'] ?? '',
          'zip': primary['zip'] ?? '',
        },
      ];
    }
  }

  if (prep == 'form1065' && _asNum(next['numberOfPartners']) <= 0) {
    next['numberOfPartners'] = owners.length;
  }
  if (prep == 'form1120S' && _asNum(next['numberOfShareholders']) <= 0) {
    next['numberOfShareholders'] = owners.length;
  }

  return next;
}

/// Build or update a federal K-1 row for [prep] using entity + personal owner.
Map<String, dynamic> upsertFederalK1ForEntity(
  Map<String, dynamic> data,
  String prep, {
  String? k1Id,
}) {
  if (!k1PassThroughPrepTypes.contains(prep)) {
    return Map<String, dynamic>.from(data);
  }

  final form = Map<String, dynamic>.from((data[prep] as Map?) ?? {});
  final owners = _listMaps(form['owners']);
  final primary = owners.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['isPrimary'] == true,
        orElse: () => owners.isNotEmpty ? owners.first : null,
      ) ??
      ownerFromPersonalInfo(data, role: ownerRoleForPrep(prep));

  final k1s = _listMaps(data['federalK1Forms']);
  final matchIdx = k1Id != null && k1Id.isNotEmpty
      ? k1s.indexWhere((k) => '${k['id']}' == k1Id)
      : k1s.indexWhere((k) => '${k['sourceForm']}' == prep);

  final base = matchIdx >= 0
      ? Map<String, dynamic>.from(k1s[matchIdx])
      : emptyFederalK1(sourceForm: prep, id: k1Id);

  base['sourceForm'] = prep;
  if ('${base['entityName'] ?? ''}'.trim().isEmpty) {
    base['entityName'] = entityDisplayName(form, prep);
  }
  if ('${base['ein'] ?? ''}'.trim().isEmpty) {
    base['ein'] = '${form['ein'] ?? ''}'.trim();
  }
  if ('${base['partnerOrShareholderName'] ?? ''}'.trim().isEmpty) {
    base['partnerOrShareholderName'] = '${primary['name'] ?? ''}'.trim();
  }
  if ('${base['partnerOrShareholderTIN'] ?? ''}'.trim().isEmpty) {
    base['partnerOrShareholderTIN'] = '${primary['tin'] ?? ''}'.trim();
  }
  if (_asNum(base['ownershipPercentage']) <= 0) {
    base['ownershipPercentage'] = _asNum(primary['ownershipPercentage']) > 0
        ? _asNum(primary['ownershipPercentage'])
        : 100;
  }

  // Seed K-1 boxes from entity Schedule K amounts × ownership % when empty.
  final pct = _asNum(base['ownershipPercentage']) / 100.0;
  num alloc(String scheduleKKey) => _asNum(form[scheduleKKey]) * pct;

  void seedBox(String k1Key, String scheduleKKey) {
    if (_asNum(base[k1Key]) == 0 && _asNum(form[scheduleKKey]) != 0) {
      base[k1Key] = alloc(scheduleKKey);
    }
  }

  if (prep == 'form1065' || prep == 'form1120S') {
    seedBox('ordinaryIncome', 'scheduleK_ordinaryBusinessIncome');
    seedBox('netRentalRealEstate', 'scheduleK_netRentalIncome');
    seedBox('interestIncome', 'scheduleK_interestIncome');
    seedBox('dividends', 'scheduleK_dividends');
    seedBox('royalties', 'scheduleK_royalties');
  }

  if (matchIdx >= 0) {
    k1s[matchIdx] = base;
  } else {
    k1s.add(base);
  }

  return {
    ...data,
    'federalK1Forms': k1s,
  };
}

/// Copy federal K-1 rows into Form 1040 Schedule E Part II (replace linked rows).
Map<String, dynamic> syncK1ToScheduleEPartII(Map<String, dynamic> data) {
  final scheduleE = Map<String, dynamic>.from((data['scheduleE'] as Map?) ?? {});
  final rentals = _listMaps(scheduleE['rentalProperties']);
  final existingPartII = _listMaps(scheduleE['partII']);
  final k1s = _listMaps(data['federalK1Forms']);

  // Keep Part II rows that are not linked to a K-1 (manual entries).
  final manual = existingPartII
      .where((row) => '${row['sourceK1Id'] ?? ''}'.trim().isEmpty)
      .toList();

  final linked = <Map<String, dynamic>>[];
  for (final k1 in k1s) {
    final sourceForm = '${k1['sourceForm'] ?? ''}';
    if (!k1PassThroughPrepTypes.contains(sourceForm)) continue;

    final k1Id = '${k1['id'] ?? ''}'.trim();
    final prior = existingPartII.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r != null && '${r['sourceK1Id']}' == k1Id && k1Id.isNotEmpty,
          orElse: () => null,
        );

    linked.add({
      ...emptyScheduleEPartII(
        entityType: scheduleEEntityTypeForPrep(sourceForm),
        id: prior != null ? '${prior['id']}' : null,
        sourceK1Id: k1Id,
      ),
      'entityName': '${k1['entityName'] ?? ''}'.trim(),
      'ein': '${k1['ein'] ?? ''}'.trim(),
      'entityType': scheduleEEntityTypeForPrep(sourceForm),
      'ordinaryIncome': _asNum(k1['ordinaryIncome']),
      'netRentalRealEstate': _asNum(k1['netRentalRealEstate']),
      'otherNetRentalIncome': _asNum(k1['otherNetRentalIncome']),
      'guaranteedPayments': _asNum(k1['guaranteedPayments']),
      'section179Deduction': _asNum(k1['section179Deduction']),
      'selfEmploymentEarnings': _asNum(k1['selfEmploymentEarnings']),
    });
  }

  scheduleE['rentalProperties'] = rentals;
  scheduleE['partII'] = [...manual, ...linked];

  // Roll Part I rental net + Part II ordinary/rental into root rentalIncome cue.
  num rentalNet = 0;
  for (final r in rentals) {
    rentalNet += _asNum(r['rentReceived']) -
        _asNum(r['mortgage']) -
        _asNum(r['insurance']) -
        _asNum(r['repairs']) -
        _asNum(r['taxes']) -
        _asNum(r['utilities']) -
        _asNum(r['depreciation']) -
        _asNum(r['advertising']) -
        _asNum(r['otherExpenses']);
  }
  num partIINet = 0;
  for (final row in scheduleE['partII'] as List) {
    if (row is! Map) continue;
    partIINet += _asNum(row['ordinaryIncome']) +
        _asNum(row['netRentalRealEstate']) +
        _asNum(row['otherNetRentalIncome']) +
        _asNum(row['guaranteedPayments']);
  }

  return {
    ...data,
    'scheduleE': scheduleE,
    'rentalIncome': rentalNet + partIINet,
  };
}

/// Full "+" business pipeline: scaffold entity, autofill owner, K-1, Schedule E Part II.
///
/// When [switchPrepType] is true, sets `prepType` to [prep]. When false (default for
/// 1040 + K-1 automation), keeps the current prep type so Schedule E stays on the hub.
Map<String, dynamic> addBusinessWithOwnerAutofill(
  Map<String, dynamic> data,
  String prep, {
  Map<String, dynamic>? entityDefaults,
  bool switchPrepType = false,
  bool overwritePrimaryOwner = true,
}) {
  if (!businessOwnerPrepTypes.contains(prep)) {
    return Map<String, dynamic>.from(data);
  }

  var next = Map<String, dynamic>.from(data);
  if (switchPrepType) {
    next['prepType'] = prep;
    next['includeScheduleC'] = false;
  }

  final defaults = entityDefaults ?? const <String, dynamic>{};
  final existing = next[prep];
  Map<String, dynamic> form;
  if (existing is Map && existing.isNotEmpty) {
    form = Map<String, dynamic>.from(existing);
  } else if (defaults[prep] is Map) {
    form = Map<String, dynamic>.from(defaults[prep] as Map);
  } else {
    form = <String, dynamic>{};
  }

  form = autofillPrimaryOwnerOnEntityForm(
    next,
    form,
    prep,
    overwritePrimary: overwritePrimaryOwner,
  );
  next[prep] = form;

  // Also seed CA Schedule K-1 recipient when empty (state companion).
  final caK1 = Map<String, dynamic>.from((next['caScheduleK1'] as Map?) ?? {});
  final primaryOwners = _listMaps(form['owners']);
  final primary = primaryOwners.isNotEmpty
      ? primaryOwners.firstWhere(
          (o) => o['isPrimary'] == true,
          orElse: () => primaryOwners.first,
        )
      : ownerFromPersonalInfo(next, role: ownerRoleForPrep(prep));
  if ('${caK1['recipientName'] ?? ''}'.trim().isEmpty) {
    caK1['recipientName'] = '${primary['name'] ?? ''}'.trim();
  }
  if ('${caK1['recipientTIN'] ?? ''}'.trim().isEmpty) {
    caK1['recipientTIN'] = '${primary['tin'] ?? ''}'.trim();
  }
  if (_asNum(caK1['ownershipPercentage']) <= 0) {
    caK1['ownershipPercentage'] = _asNum(primary['ownershipPercentage']);
  }
  if ('${caK1['recipientType'] ?? ''}'.trim().isEmpty) {
    caK1['recipientType'] = 'individual';
  }
  next['caScheduleK1'] = caK1;

  if (k1PassThroughPrepTypes.contains(prep)) {
    next = upsertFederalK1ForEntity(next, prep);
    next = syncK1ToScheduleEPartII(next);
  }

  return next;
}
