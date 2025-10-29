class UserProfile {
  final String uid;
  final String fullname;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String? primaryAddress;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    required this.fullname,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.primaryAddress,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullname': fullname,
      'email': email,
      'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (primaryAddress != null) 'primaryAddress': primaryAddress,
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      fullname: (map['fullname'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      avatarUrl: map['avatarUrl'] as String?,
      primaryAddress: map['primaryAddress'] as String?,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }
}
