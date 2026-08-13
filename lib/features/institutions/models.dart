import 'package:flutter/foundation.dart';

@immutable
class Institution {
  const Institution({
    required this.name,
    required this.code,
    required this.status,
    required this.students,
    required this.emailDomain,
  });
  final String name;
  final String code;
  final String status; // Active/Pending/Suspended
  final int students;
  final String emailDomain;

  Institution copyWith({
    String? name,
    String? code,
    String? status,
    int? students,
    String? emailDomain,
  }) {
    return Institution(
      name: name ?? this.name,
      code: code ?? this.code,
      status: status ?? this.status,
      students: students ?? this.students,
      emailDomain: emailDomain ?? this.emailDomain,
    );
  }
}
