import 'package:equatable/equatable.dart';

import '../utils/user_name_parser.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final String? token;

  const UserModel({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
    this.token,
  });

  /// ชื่อที่แสดงใน greeting (first name ก่อน)
  String get greetingName =>
      firstName.trim().isNotEmpty ? firstName.trim() : name.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? '';
    var first = (json['firstName'] as String?)?.trim() ?? '';
    var last = (json['lastName'] as String?)?.trim() ?? '';

    if (first.isEmpty && name.isNotEmpty) {
      final parsed = parseUserDisplayName(displayName: name);
      first = parsed.firstName;
      last = parsed.lastName;
    }

    return UserModel(
      id: json['id'] as String,
      name: name.isNotEmpty ? name : first,
      firstName: first,
      lastName: last,
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'photoUrl': photoUrl,
        'token': token,
      };

  @override
  List<Object?> get props => [id, email, name];
}
