import '../json_read.dart';

class FlyerSummary {
  const FlyerSummary({
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.cnPhone,
    required this.bdPhone,
    required this.university,
    required this.batch,
    required this.program,
    required this.wechat,
    required this.docStudentId,
    required this.docVisa,
    required this.docAdmission,
    required this.documentCount,
    required this.verifiedDocumentCount,
    required this.archivedAt,
  });

  final String name;
  final String firstName;
  final String lastName;
  final String cnPhone;
  final String bdPhone;
  final String university;
  final String batch;
  final String program;
  final String wechat;
  final bool docStudentId;
  final bool docVisa;
  final bool docAdmission;
  final int documentCount;
  final int verifiedDocumentCount;
  final String? archivedAt;

  bool get archived => archivedAt != null;

  factory FlyerSummary.fromJson(Map<String, Object?> json) {
    return FlyerSummary(
      name: requiredString(json, 'name'),
      firstName: requiredString(json, 'firstName'),
      lastName: requiredString(json, 'lastName'),
      cnPhone: requiredString(json, 'cnPhone'),
      bdPhone: requiredString(json, 'bdPhone'),
      university: requiredString(json, 'university'),
      batch: requiredString(json, 'batch'),
      program: requiredString(json, 'program'),
      wechat: requiredString(json, 'wechat'),
      docStudentId: requiredBool(json, 'docStudentId'),
      docVisa: requiredBool(json, 'docVisa'),
      docAdmission: requiredBool(json, 'docAdmission'),
      documentCount: requiredInt(json, 'documentCount'),
      verifiedDocumentCount: requiredInt(json, 'verifiedDocumentCount'),
      archivedAt: requiredNullableString(json, 'archivedAt'),
    );
  }
}

class FlyerFlight {
  const FlyerFlight({
    required this.code,
    required this.date,
    required this.depTime,
    required this.arrTime,
    required this.spaceKg,
    required this.bookedKg,
    required this.status,
    required this.statusLabel,
  });

  final String code;
  final String date;
  final String depTime;
  final String arrTime;
  final int spaceKg;
  final double bookedKg;
  final String status;
  final String statusLabel;

  factory FlyerFlight.fromJson(Map<String, Object?> json) {
    return FlyerFlight(
      code: requiredString(json, 'code'),
      date: requiredString(json, 'date'),
      depTime: requiredString(json, 'depTime'),
      arrTime: requiredString(json, 'arrTime'),
      spaceKg: requiredInt(json, 'spaceKg'),
      bookedKg: requiredDouble(json, 'bookedKg'),
      status: requiredString(json, 'status'),
      statusLabel: requiredString(json, 'statusLabel'),
    );
  }
}

class FlyerDetail extends FlyerSummary {
  const FlyerDetail({
    required super.name,
    required super.firstName,
    required super.lastName,
    required super.cnPhone,
    required super.bdPhone,
    required super.university,
    required super.batch,
    required super.program,
    required super.wechat,
    required super.docStudentId,
    required super.docVisa,
    required super.docAdmission,
    required super.documentCount,
    required super.verifiedDocumentCount,
    required super.archivedAt,
    required this.cnAddress,
    required this.homeAddress,
    required this.emergencyContact,
    required this.totalKg,
    required this.flights,
    required this.nextFlight,
  });

  final String cnAddress;
  final String homeAddress;
  final String emergencyContact;
  final double totalKg;
  final List<FlyerFlight> flights;
  final FlyerFlight? nextFlight;

  factory FlyerDetail.fromJson(Map<String, Object?> json) {
    final base = FlyerSummary.fromJson(json);
    final next = json['nextFlight'];
    return FlyerDetail(
      name: base.name,
      firstName: base.firstName,
      lastName: base.lastName,
      cnPhone: base.cnPhone,
      bdPhone: base.bdPhone,
      university: base.university,
      batch: base.batch,
      program: base.program,
      wechat: base.wechat,
      docStudentId: base.docStudentId,
      docVisa: base.docVisa,
      docAdmission: base.docAdmission,
      documentCount: base.documentCount,
      verifiedDocumentCount: base.verifiedDocumentCount,
      archivedAt: base.archivedAt,
      cnAddress: requiredString(json, 'cnAddress'),
      homeAddress: requiredString(json, 'homeAddress'),
      emergencyContact: requiredString(json, 'emergencyContact'),
      totalKg: requiredDouble(json, 'totalKg'),
      flights: [for (final row in requiredMapList(json, 'flights')) FlyerFlight.fromJson(row)],
      nextFlight: next == null ? null : FlyerFlight.fromJson(asJsonMap(next, 'nextFlight')),
    );
  }
}

class FlyerDocument {
  const FlyerDocument({
    required this.reference,
    required this.kind,
    required this.name,
    required this.contentType,
    required this.size,
    required this.createdAt,
    required this.uploadedByName,
    required this.verifiedAt,
    required this.verifiedByName,
  });

  final String reference;
  final String kind;
  final String name;
  final String contentType;
  final int size;
  final String createdAt;
  final String uploadedByName;
  final String? verifiedAt;
  final String? verifiedByName;

  bool get verified => verifiedAt != null;
  bool get isPdf => contentType.toLowerCase().contains('pdf') || name.toLowerCase().endsWith('.pdf');

  factory FlyerDocument.fromJson(Map<String, Object?> json) {
    return FlyerDocument(
      reference: requiredString(json, 'reference'),
      kind: requiredString(json, 'kind'),
      name: requiredString(json, 'name'),
      contentType: requiredString(json, 'contentType'),
      size: requiredInt(json, 'size'),
      createdAt: requiredString(json, 'createdAt'),
      uploadedByName: requiredString(json, 'uploadedByName'),
      verifiedAt: requiredNullableString(json, 'verifiedAt'),
      verifiedByName: requiredNullableString(json, 'verifiedByName'),
    );
  }
}

class FlyerDocumentList {
  const FlyerDocumentList({required this.configured, required this.documents});

  final bool configured;
  final List<FlyerDocument> documents;

  factory FlyerDocumentList.fromJson(Map<String, Object?> json) {
    return FlyerDocumentList(
      configured: requiredBool(json, 'configured'),
      documents: [for (final row in requiredMapList(json, 'documents')) FlyerDocument.fromJson(row)],
    );
  }
}

const flyerDocumentKinds = <String, String>{
  'student_id': 'স্টুডেন্ট আইডি',
  'visa': 'ভিসা',
  'admission': 'অ্যাডমিশন',
  'passport': 'পাসপোর্ট',
  'nid': 'NID',
  'ticket': 'টিকিট',
  'other': 'অন্যান্য',
};

class FlyerDraft {
  const FlyerDraft({
    required this.firstName,
    required this.lastName,
    this.cnPhone,
    this.bdPhone,
    this.university,
    this.batch,
    this.program,
    this.wechat,
    this.emergencyContact,
  });

  final String firstName;
  final String lastName;
  final String? cnPhone;
  final String? bdPhone;
  final String? university;
  final String? batch;
  final String? program;
  final String? wechat;
  final String? emergencyContact;

  Map<String, Object?> toJson() {
    final body = <String, Object?>{'firstName': firstName, 'lastName': lastName};
    void put(String key, String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) body[key] = text;
    }

    put('cnPhone', cnPhone);
    put('bdPhone', bdPhone);
    put('university', university);
    put('batch', batch);
    put('program', program);
    put('wechat', wechat);
    put('emergencyContact', emergencyContact);
    return body;
  }
}
