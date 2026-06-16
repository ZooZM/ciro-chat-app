import 'package:equatable/equatable.dart';

class StatusAudienceContact extends Equatable {
  final String userId;
  final String name;
  final String phoneNumber;
  final String avatarUrl;

  const StatusAudienceContact({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.avatarUrl,
  });

  @override
  List<Object?> get props => [userId, name, phoneNumber, avatarUrl];
}
