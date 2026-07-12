// lib/shared/models/app_user.dart

enum UserRole { headManager, employee, rider, lender }

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.headManager:
        return 'head_manager';
      case UserRole.employee:
        return 'employee';
      case UserRole.rider:
        return 'rider';
      case UserRole.lender:
        return 'lender';
    }
  }

  bool get isStaff => this == UserRole.headManager || this == UserRole.employee;
  bool get isMobile => this == UserRole.rider || this == UserRole.lender;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'head_manager':
        return UserRole.headManager;
      case 'employee':
        return UserRole.employee;
      case 'rider':
        return UserRole.rider;
      case 'lender':
      default:
        return UserRole.lender;
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final bool forcePasswordChange;
  final bool isActive;
  final String? address;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.forcePasswordChange = false,
    this.isActive = true,
    this.address,
    required this.createdAt,
    this.updatedAt,
  });

  String get fullName => [firstName, middleName, lastName]
      .where((p) => p != null && p.isNotEmpty)
      .join(' ');

  String get displayName => '$firstName $lastName';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        middleName: json['middle_name'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        role: UserRoleX.fromString(json['role'] as String?),
        forcePasswordChange: json['force_password_change'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        address: json['address'] as String?,
        createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        ),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'middle_name': middleName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role.value,
        'force_password_change': forcePasswordChange,
        'is_active': isActive,
        'address': address,
        'created_at': createdAt.toIso8601String(),
      };

  AppUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? middleName,
    String? phone,
    String? avatarUrl,
    UserRole? role,
    bool? forcePasswordChange,
    bool? isActive,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        middleName: middleName ?? this.middleName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
        isActive: isActive ?? this.isActive,
        address: address ?? this.address,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
