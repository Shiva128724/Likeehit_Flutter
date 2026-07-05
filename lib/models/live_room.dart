import 'package:cloud_firestore/cloud_firestore.dart';

class LiveRoom {
  final String id;
  final String hostId;
  final String hostName;
  final String hostPhotoUrl;
  final String coverUrl;
  final int viewers;
  final bool isLive;
  final String type;
  final bool audioOnly;
  final Timestamp? createdAt;

  const LiveRoom({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.hostPhotoUrl,
    required this.coverUrl,
    required this.viewers,
    required this.isLive,
    required this.type,
    required this.audioOnly,
    required this.createdAt,
  });

  factory LiveRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LiveRoom(
      id: doc.id,
      hostId: data['hostId']?.toString() ?? '',
      hostName: data['hostName']?.toString() ?? 'Live creator',
      hostPhotoUrl: data['hostPhotoUrl']?.toString() ?? '',
      coverUrl: data['coverUrl']?.toString() ?? '',
      viewers: _asInt(data['viewers']),
      isLive: data['isLive'] != false,
      type: data['type']?.toString() ?? 'live',
      audioOnly: data['audioOnly'] == true,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }

  bool get isParty => audioOnly || type.toLowerCase() == 'party';

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
