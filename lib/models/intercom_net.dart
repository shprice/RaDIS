import 'package:uuid/uuid.dart';

class IntercomNet {
  final String id;
  String name;
  int communicationsDeviceId;

  IntercomNet({
    String? id,
    required this.name,
    this.communicationsDeviceId = 1,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'communicationsDeviceId': communicationsDeviceId,
      };

  factory IntercomNet.fromJson(Map<String, dynamic> json) => IntercomNet(
        id: json['id'] as String?,
        name: json['name'] as String,
        communicationsDeviceId:
            (json['communicationsDeviceId'] as num?)?.toInt() ?? 1,
      );

  IntercomNet copyWith({String? name, int? communicationsDeviceId}) =>
      IntercomNet(
        id: id,
        name: name ?? this.name,
        communicationsDeviceId:
            communicationsDeviceId ?? this.communicationsDeviceId,
      );
}
