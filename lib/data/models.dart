import 'package:oons/core/format.dart';

class UserMe {
  UserMe({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.initials,
    required this.area,
    required this.addresses,
    this.instructions = const [],
    this.savedIds = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.photo,
    this.nationalId,
    this.idPhotoUrl,
    this.paidBookingCount = 0,
  });
  final String id;
  final String phone;
  final Loc firstName;
  final Loc lastName;
  final Loc initials;
  final String area;
  final List<Address> addresses;
  final List<Instruction> instructions;
  final List<String> savedIds;
  final double rating;
  final int reviewCount;
  final String? photo;
  final String? nationalId;
  final String? idPhotoUrl;
  final int paidBookingCount;

  String name(String lang) => '${firstName.of(lang)} ${lastName.of(lang)}';

  bool get hasPhoto => photo != null && photo!.trim().isNotEmpty;
  bool get hasIdPhoto => idPhotoUrl != null && idPhotoUrl!.trim().isNotEmpty;
  bool get hasNationalId => nationalId != null && nationalId!.trim().isNotEmpty;
  bool get identityComplete => hasPhoto && hasIdPhoto && hasNationalId;
  /// True when the client has already paid at least once — identity is now required for next booking.
  bool get needsIdentityCompletion => paidBookingCount > 0 && !identityComplete;

  factory UserMe.fromJson(Map j) => UserMe(
        id: '${j['id']}',
        phone: '${j['phone']}',
        firstName: Loc.fromJson(j['firstName']),
        lastName: Loc.fromJson(j['lastName']),
        initials: Loc.fromJson(j['initials']),
        area: '${j['area'] ?? 'zamalek'}',
        addresses: ((j['addresses'] as List?) ?? []).map((e) => Address.fromJson(e)).toList(),
        instructions: ((j['instructions'] as List?) ?? []).map((e) => Instruction.fromJson(e as Map)).toList(),
        savedIds: ((j['savedIds'] as List?) ?? []).map((e) => '$e').toList(),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
        photo: j['photo'] == null || '${j['photo']}'.isEmpty ? null : '${j['photo']}',
        nationalId: j['nationalId'] == null || '${j['nationalId']}'.isEmpty ? null : '${j['nationalId']}',
        idPhotoUrl: j['idPhotoUrl'] == null || '${j['idPhotoUrl']}'.isEmpty ? null : '${j['idPhotoUrl']}',
        paidBookingCount: (j['paidBookingCount'] as num?)?.toInt() ?? 0,
      );
}

class Instruction {
  Instruction({required this.id, required this.title, required this.body});
  final String id;
  final String title;
  final String body;
  factory Instruction.fromJson(Map j) => Instruction(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
      );
}

class Address {
  Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.area,
    required this.city,
    required this.isDefault,
    this.reachNotes = const Loc('', ''),
    this.lat = 0,
    this.lng = 0,
  });
  final String id;
  final Loc label;
  final Loc line1;
  final Loc reachNotes;
  final String area;
  final Loc city;
  final bool isDefault;
  final double lat;
  final double lng;
  factory Address.fromJson(Map j) => Address(
        id: '${j['id']}',
        label: Loc.fromJson(j['label'] ?? j['Label'] ?? {'en': 'Home', 'ar': 'البيت'}),
        line1: Loc.fromJson(j['line1']),
        reachNotes: j['reachNotes'] is Map ? Loc.fromJson(j['reachNotes'] as Map) : const Loc('', ''),
        area: '${j['area']}',
        city: Loc.fromJson(j['city']),
        isDefault: j['isDefault'] == true,
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );
}

class ProviderP {
  ProviderP({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.initials,
    required this.service,
    required this.specialty,
    required this.areas,
    required this.years,
    required this.rating,
    required this.reviewCount,
    required this.priceFrom,
    required this.items,
    this.photo,
    this.portfolio = const [],
    this.bio,
    this.legalName,
    this.nationalId,
    this.payoutHandle,
    this.phone,
    this.birthDate,
    this.residenceLine,
    this.idPhotoUrl,
    this.fishPhotoUrl,
    this.fishValidated = false,
    this.vetted = false,
    this.workDays = const [],
    this.slotHours = const [],
    this.slug,
    this.slugAliases = const [],
    this.customDomains = const [],
  });
  final String id;
  final Loc firstName;
  final Loc lastName;
  final Loc initials;
  final String service;
  final Loc specialty;
  final String? photo;
  final List<String> areas;
  final int years;
  final double rating;
  final int reviewCount;
  final int priceFrom;
  final List<ServiceItem> items;
  final List<String> portfolio;
  final Loc? bio;
  final String? legalName;
  final String? nationalId;
  final String? payoutHandle;
  final String? phone;
  final String? birthDate;
  final String? residenceLine;
  final String? idPhotoUrl;
  final String? fishPhotoUrl;
  final bool fishValidated;
  final bool vetted;
  final List<int> workDays;
  final List<String> slotHours;
  final String? slug;
  final List<String> slugAliases;
  final List<ProviderDomain> customDomains;

  String name(String lang) => '${firstName.of(lang)} ${lastName.of(lang)}';

  String? get liveCustomDomain {
    for (final d in customDomains) {
      if (d.status == 'verified' && d.tlsStatus == 'active') return d.host;
    }
    return null;
  }

  factory ProviderP.fromJson(Map j) => ProviderP(
        id: '${j['id']}',
        firstName: Loc.fromJson(j['firstName']),
        lastName: Loc.fromJson(j['lastName']),
        initials: Loc.fromJson(j['initials']),
        service: '${j['service']}',
        specialty: Loc.fromJson(j['specialty']),
        photo: j['photo'] as String?,
        areas: ((j['areas'] as List?) ?? []).map((e) => '$e').toList(),
        years: (j['years'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
        priceFrom: (j['priceFrom'] as num?)?.toInt() ?? 0,
        items: ((j['items'] as List?) ?? []).map((e) => ServiceItem.fromJson(e)).toList(),
        portfolio: ((j['portfolio'] as List?) ?? []).map((e) => '$e').toList(),
        bio: j['bio'] is Map ? Loc.fromJson(j['bio']) : null,
        legalName: j['legalName'] as String?,
        nationalId: j['nationalId'] as String?,
        payoutHandle: j['payoutHandle'] as String?,
        phone: j['phone'] as String?,
        birthDate: j['birthDate'] as String?,
        residenceLine: j['residenceLine'] as String?,
        idPhotoUrl: j['idPhotoUrl'] as String?,
        fishPhotoUrl: j['fishPhotoUrl'] as String?,
        fishValidated: _vettedAt(j['fishValidatedAt']),
        vetted: _vettedAt(j['vettedAt']),
        workDays: ((j['workDays'] as List?) ?? []).map((e) => (e as num).toInt()).toList(),
        slotHours: ((j['slotHours'] as List?) ?? []).map((e) => '$e').toList(),
        slug: j['slug'] as String?,
        slugAliases: ((j['slugAliases'] as List?) ?? []).map((e) => '$e').toList(),
        customDomains: ((j['customDomains'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => ProviderDomain.fromJson(e))
            .toList(),
      );
}

class ProviderDomain {
  ProviderDomain({
    required this.host,
    required this.status,
    this.verifyToken = '',
    this.tlsStatus = '',
    this.tlsError = '',
  });
  final String host;
  final String status;
  final String verifyToken;
  final String tlsStatus;
  final String tlsError;

  factory ProviderDomain.fromJson(Map j) => ProviderDomain(
        host: '${j['host'] ?? ''}',
        status: '${j['status'] ?? ''}',
        verifyToken: '${j['verifyToken'] ?? ''}',
        tlsStatus: '${j['tlsStatus'] ?? ''}',
        tlsError: '${j['tlsError'] ?? ''}',
      );
}

bool _vettedAt(dynamic v) {
  if (v == null) return false;
  final t = DateTime.tryParse('$v');
  return t != null && t.year >= 2020;
}

class ServiceItem {
  ServiceItem({
    required this.id,
    required this.name,
    required this.duration,
    required this.price,
    this.categoryId,
    this.catalogItemId,
    this.kind = 'standard',
    this.active = true,
    this.travelFee = 0,
    this.sizeFromSqm = 0,
    this.sizeToSqm,
    this.workerCount = 0,
    this.excludedTaskIds = const [],
    this.approvalState = '',
  });
  final String id;
  final Loc name;
  final int duration;
  final int price;
  final String? categoryId;
  final String? catalogItemId;
  final String kind;
  final bool active;
  final int travelFee;
  final int sizeFromSqm;
  final int? sizeToSqm;
  final int workerCount;
  final List<String> excludedTaskIds;
  // Server-owned: "" / "approved" = live, "pending" = awaiting staff
  // activation, "rejected" = declined. Never sent back to the server.
  final String approvalState;

  bool get isCleaning => kind == 'cleaning';
  bool get isPendingApproval => approvalState == 'pending';

  factory ServiceItem.fromJson(Map j) => ServiceItem(
        id: '${j['id']}',
        name: Loc.fromJson(j['name']),
        duration: (j['durationMin'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.toInt() ?? 0,
        categoryId: j['categoryId']?.toString(),
        catalogItemId: j['catalogItemId']?.toString(),
        kind: '${j['kind'] ?? 'standard'}',
        active: j['active'] != false,
        travelFee: (j['travelFee'] as num?)?.toInt() ?? 0,
        sizeFromSqm: (j['sizeFromSqm'] as num?)?.toInt() ?? 0,
        sizeToSqm: (j['sizeToSqm'] as num?)?.toInt(),
        workerCount: (j['workerCount'] as num?)?.toInt() ?? 0,
        excludedTaskIds: ((j['excludedTaskIds'] as List?) ?? const [])
            .map((e) => '$e')
            .where((e) => e.isNotEmpty)
            .toList(),
        approvalState: '${j['approvalState'] ?? ''}',
      );

  Map<String, dynamic> toPatchJson() => {
        'id': int.tryParse(id) ?? id,
        'name': {'en': name.en, 'ar': name.ar},
        'durationMin': duration,
        'price': price,
        if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
        if (catalogItemId != null && catalogItemId!.isNotEmpty) 'catalogItemId': catalogItemId,
        'kind': isCleaning ? 'cleaning' : 'standard',
        'active': active,
        if (travelFee > 0) 'travelFee': travelFee,
        if (isCleaning) ...{
          'sizeFromSqm': sizeFromSqm,
          if (sizeToSqm != null) 'sizeToSqm': sizeToSqm,
          'workerCount': workerCount,
          'excludedTaskIds': excludedTaskIds,
        },
      };
}

class BookingBundle {
  BookingBundle({
    required this.booking,
    required this.provider,
    required this.preview,
    this.replacement,
    required this.poll,
    this.clientName,
    this.clientArea,
    this.clientPhone,
    this.clientPhoneMasked,
    this.clientRating,
    this.clientReviewCount,
    this.clientLocked = false,
    this.settlement,
    this.processingFees = const {},
  });
  final Booking booking;
  final ProviderP? provider;
  final CancelPreview preview;
  final Replacement? replacement;
  final bool poll;
  final Loc? clientName;
  final String? clientArea;
  final String? clientPhone;
  final String? clientPhoneMasked;
  final double? clientRating;
  final int? clientReviewCount;
  final bool clientLocked;
  final Map<String, dynamic>? settlement;
  /// Paymob surcharge estimates by method key (`card` / `instapay`), piastres.
  final Map<String, int> processingFees;

  int processingFeeFor(String method) => processingFees[method] ?? 0;

  factory BookingBundle.fromJson(Map j) {
    final b = j['booking'] is Map ? j['booking'] as Map : j;
    Loc? clientName;
    String? clientArea;
    String? clientPhone;
    String? clientPhoneMasked;
    double? clientRating;
    int? clientReviewCount;
    if (j['client'] is Map) {
      final c = j['client'] as Map;
      clientName = Loc.fromJson(c['firstName']);
      clientArea = '${c['area'] ?? ''}';
      final ph = '${c['phone'] ?? ''}'.trim();
      clientPhone = ph.isEmpty ? null : ph;
      final pm = '${c['phoneMasked'] ?? ''}'.trim();
      clientPhoneMasked = pm.isEmpty ? null : pm;
      clientRating = (c['rating'] as num?)?.toDouble();
      clientReviewCount = (c['reviewCount'] as num?)?.toInt();
    }
    final feesRaw = j['processingFees'];
    final fees = <String, int>{};
    if (feesRaw is Map) {
      for (final e in feesRaw.entries) {
        if (e.key == 'passThrough') continue;
        final n = e.value;
        if (n is num) fees['${e.key}'] = n.toInt();
      }
    }
    return BookingBundle(
      booking: Booking.fromJson(b),
      provider: j['provider'] is Map ? ProviderP.fromJson(j['provider'] as Map) : null,
      preview: CancelPreview.fromJson(j['cancelPreview'] as Map? ?? {}),
      replacement: j['replacement'] is Map ? Replacement.fromJson(j['replacement'] as Map) : null,
      poll: j['poll'] == true,
      clientName: clientName,
      clientArea: clientArea,
      clientPhone: clientPhone,
      clientPhoneMasked: clientPhoneMasked,
      clientRating: clientRating,
      clientReviewCount: clientReviewCount,
      clientLocked: j['clientLocked'] == true,
      settlement: j['settlement'] is Map ? Map<String, dynamic>.from(j['settlement'] as Map) : null,
      processingFees: fees,
    );
  }

  BookingBundle withLocation(double lat, double lng) => BookingBundle(
        booking: booking.withLocation(lat, lng),
        provider: provider,
        preview: preview,
        replacement: replacement,
        poll: poll,
        clientName: clientName,
        clientArea: clientArea,
        clientPhone: clientPhone,
        clientPhoneMasked: clientPhoneMasked,
        clientRating: clientRating,
        clientReviewCount: clientReviewCount,
        clientLocked: clientLocked,
        settlement: settlement,
        processingFees: processingFees,
      );
}

class BookingGuestItem {
  BookingGuestItem({
    required this.id,
    required this.guestLabel,
    required this.serviceItemId,
    required this.serviceName,
    required this.durationMin,
    required this.price,
    this.guestPhone,
    this.guestNotes,
    this.count = 1,
  });
  final String id;
  final String guestLabel;
  final String? guestPhone;
  final String? guestNotes;
  final String serviceItemId;
  final Loc serviceName;
  final int durationMin;
  final int price;
  final int count;

  int get lineTotal => price * (count < 1 ? 1 : count);

  factory BookingGuestItem.fromJson(Map j) => BookingGuestItem(
        id: '${j['id'] ?? ''}',
        guestLabel: '${j['guestLabel'] ?? ''}'.trim(),
        guestPhone: j['guestPhone'] == null || '${j['guestPhone']}'.trim().isEmpty ? null : '${j['guestPhone']}'.trim(),
        guestNotes: j['guestNotes'] == null || '${j['guestNotes']}'.trim().isEmpty ? null : '${j['guestNotes']}'.trim(),
        serviceItemId: '${j['serviceItemId'] ?? ''}',
        serviceName: Loc.fromJson(j['serviceName']),
        durationMin: (j['durationMin'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.toInt() ?? 0,
        count: ((j['count'] as num?)?.toInt() ?? 1).clamp(1, 99),
      );
}

class Booking {
  Booking({
    required this.id,
    required this.ref,
    required this.status,
    required this.slotStart,
    required this.total,
    required this.escrow,
    required this.serviceName,
    required this.lineItems,
    required this.timeline,
    this.items = const [],
    this.kind,
    this.fawryCode,
    this.fawryExpiresAt,
    this.paymentMethod,
    this.paymentHoldUntil,
    this.notes,
    this.address,
    this.clientCheckIn,
    this.providerCheckIn,
    this.checkedOutAt,
    this.refundAmount,
    this.rescheduleUsed = false,
    this.lastLat,
    this.lastLng,
    this.releasedAt,
    this.entryPhotoUrl,
    this.rated = false,
    this.clientRated = false,
    this.trustFeeAmount = 0,
    this.commissionAmount = 0,
    this.relationshipTier,
  });
  final String id;
  final String ref;
  final String status;
  final DateTime slotStart;
  final int total;
  final String escrow;
  final Loc serviceName;
  final List<BookingGuestItem> items;
  final String? kind;
  final List<LineItem> lineItems;
  final List<TimelineEv> timeline;
  final String? fawryCode;
  final DateTime? fawryExpiresAt;
  final String? paymentMethod;
  final DateTime? paymentHoldUntil;
  final String? notes;
  final Address? address;
  final DateTime? clientCheckIn;
  final DateTime? providerCheckIn;
  final DateTime? checkedOutAt;
  final int? refundAmount;
  final bool rescheduleUsed;
  final double? lastLat;
  final double? lastLng;
  final DateTime? releasedAt;
  final String? entryPhotoUrl;
  final bool rated;
  final bool clientRated;
  final int trustFeeAmount;
  final int commissionAmount;
  final String? relationshipTier;

  bool get canReleasePay => status == 'completed' && escrow == 'held' && releasedAt == null;
  bool get isGroup => kind == 'group' || items.length > 1;

  /// Guest label → services for that guest (preserves booking order).
  Map<String, List<BookingGuestItem>> get itemsByGuest {
    final out = <String, List<BookingGuestItem>>{};
    for (final it in items) {
      final key = it.guestLabel.isEmpty ? 'Guest' : it.guestLabel;
      out.putIfAbsent(key, () => []).add(it);
    }
    return out;
  }

  /// Provider take-home: post-commission for relationship pricing; legacy transport+Amana otherwise.
  int get serviceEarning {
    final hasTrust = lineItems.any((li) => li.key == 'trust_fee') || relationshipTier != null && relationshipTier!.isNotEmpty;
    if (hasTrust || trustFeeAmount > 0 || commissionAmount > 0) {
      final trust = trustFeeAmount > 0
          ? trustFeeAmount
          : lineItems.where((li) => li.key == 'trust_fee').fold<int>(0, (n, li) => n + li.amount);
      final service = total - trust;
      final earn = service - commissionAmount;
      return earn < 0 ? 0 : earn;
    }
    var transport = 6000;
    var amana = 4000;
    for (final li in lineItems) {
      if (li.key == 'transport' && li.amount > 0) transport = li.amount;
      if (li.key == 'amana' && li.amount > 0) amana = li.amount;
    }
    final e = total - transport - amana;
    return e < 0 ? 0 : e;
  }

  factory Booking.fromJson(Map j) => Booking(
        id: '${j['id']}',
        ref: '${j['ref']}',
        status: '${j['status']}',
        slotStart: DateTime.tryParse('${j['slotStart']}')?.toLocal() ?? DateTime.now(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        escrow: '${j['escrow'] ?? 'held'}',
        serviceName: Loc.fromJson(j['serviceName']),
        items: ((j['items'] as List?) ?? []).whereType<Map>().map((e) => BookingGuestItem.fromJson(e)).toList(),
        kind: j['kind'] == null || '${j['kind']}'.isEmpty ? null : '${j['kind']}',
        lineItems: ((j['lineItems'] as List?) ?? []).map((e) => LineItem.fromJson(e as Map)).toList(),
        timeline: ((j['timeline'] as List?) ?? []).map((e) => TimelineEv.fromJson(e)).toList(),
        fawryCode: j['fawryCode'] as String?,
        fawryExpiresAt: DateTime.tryParse('${j['fawryExpiresAt'] ?? ''}'),
        paymentMethod: j['paymentMethod'] == null || '${j['paymentMethod']}'.isEmpty ? null : '${j['paymentMethod']}',
        paymentHoldUntil: DateTime.tryParse('${j['paymentHoldUntil'] ?? ''}'),
        notes: j['notes'] as String?,
        address: j['address'] is Map ? Address.fromJson(j['address'] as Map) : null,
        clientCheckIn: DateTime.tryParse('${j['clientCheckIn'] ?? ''}'),
        providerCheckIn: DateTime.tryParse('${j['providerCheckIn'] ?? ''}'),
        checkedOutAt: DateTime.tryParse('${j['checkedOutAt'] ?? ''}'),
        refundAmount: (j['refundAmount'] as num?)?.toInt(),
        rescheduleUsed: j['rescheduleUsed'] == true,
        lastLat: (j['lastLat'] as num?)?.toDouble(),
        lastLng: (j['lastLng'] as num?)?.toDouble(),
        releasedAt: DateTime.tryParse('${j['releasedAt'] ?? ''}'),
        entryPhotoUrl: j['entryPhotoUrl'] as String?,
        rated: j['rating'] != null,
        clientRated: j['clientRating'] != null,
        trustFeeAmount: (j['trustFeeAmount'] as num?)?.toInt() ?? 0,
        commissionAmount: (j['commissionAmount'] as num?)?.toInt() ?? 0,
        relationshipTier: j['relationshipTier'] == null || '${j['relationshipTier']}'.isEmpty
            ? null
            : '${j['relationshipTier']}',
      );

  Booking withLocation(double lat, double lng) => Booking(
        id: id,
        ref: ref,
        status: status,
        slotStart: slotStart,
        total: total,
        escrow: escrow,
        serviceName: serviceName,
        items: items,
        kind: kind,
        lineItems: lineItems,
        timeline: timeline,
        fawryCode: fawryCode,
        fawryExpiresAt: fawryExpiresAt,
        paymentMethod: paymentMethod,
        paymentHoldUntil: paymentHoldUntil,
        notes: notes,
        address: address,
        clientCheckIn: clientCheckIn,
        providerCheckIn: providerCheckIn,
        checkedOutAt: checkedOutAt,
        refundAmount: refundAmount,
        rescheduleUsed: rescheduleUsed,
        lastLat: lat,
        lastLng: lng,
        releasedAt: releasedAt,
        entryPhotoUrl: entryPhotoUrl,
        rated: rated,
        clientRated: clientRated,
        trustFeeAmount: trustFeeAmount,
        commissionAmount: commissionAmount,
        relationshipTier: relationshipTier,
      );
}

class LineItem {
  LineItem({required this.label, required this.amount, this.key});
  final Loc label;
  final int amount;
  final String? key;
  factory LineItem.fromJson(Map j) => LineItem(
        label: Loc.fromJson(j['label']),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        key: j['key'] == null ? null : '${j['key']}',
      );
}

class TimelineEv {
  TimelineEv({required this.key, this.at, required this.done});
  final String key;
  final DateTime? at;
  final bool done;
  factory TimelineEv.fromJson(Map j) => TimelineEv(
        key: '${j['key']}',
        at: DateTime.tryParse('${j['at'] ?? ''}'),
        done: j['done'] == true,
      );
}

class CancelPreview {
  CancelPreview({required this.tier, required this.refundAmount, required this.walletInstant, required this.cardDays});
  final String tier;
  final int refundAmount;
  final bool walletInstant;
  final String cardDays;
  factory CancelPreview.fromJson(Map j) => CancelPreview(
        tier: '${j['tier'] ?? 'full'}',
        refundAmount: (j['refundAmount'] as num?)?.toInt() ?? 0,
        walletInstant: j['walletInstant'] != false,
        cardDays: '${j['cardDays'] ?? '5–9'}',
      );
}

class Replacement {
  Replacement({required this.provider, required this.delta});
  final ProviderP provider;
  final Loc delta;
  factory Replacement.fromJson(Map j) => Replacement(
        provider: ProviderP.fromJson(j['provider'] as Map),
        delta: Loc.fromJson(j['delta']),
      );
}

class Txn {
  Txn({required this.label, required this.amount, required this.createdAt, required this.kind});
  final Loc label;
  final int amount;
  final DateTime createdAt;
  final String kind;
  factory Txn.fromJson(Map j) => Txn(
        label: Loc.fromJson(j['label']),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        kind: '${j['kind']}',
      );
}
