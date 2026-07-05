import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/live_room.dart';
import 'level_service.dart';

class LiveService {
  LiveService._();

  static final LiveService instance = LiveService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _fallbackBackendBaseUrl =
      'https://asia-south1-likeehit-flutter-435116.cloudfunctions.net';

  Stream<int> watchCurrentUserStars() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream<int>.empty();
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return _asIntStatic(data['stars']);
    });
  }

  Stream<bool> watchIsFollowing(String targetUid) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || targetUid.isEmpty || uid == targetUid) {
      return Stream<bool>.value(false);
    }
    return _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> setFollowing(String targetUid, {required bool follow}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in.');
    if (targetUid.isEmpty || uid == targetUid) return;

    final targetFollowerRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(uid);
    final currentFollowingRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid);
    final targetUserRef = _firestore.collection('users').doc(targetUid);
    final currentUserRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final followerDoc = await transaction.get(targetFollowerRef);
      if (follow && !followerDoc.exists) {
        transaction.set(targetFollowerRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.set(currentFollowingRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.set(targetUserRef, {
          'followers': FieldValue.increment(1),
        }, SetOptions(merge: true));
        transaction.set(currentUserRef, {
          'following': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } else if (!follow && followerDoc.exists) {
        transaction.delete(targetFollowerRef);
        transaction.delete(currentFollowingRef);
        transaction.set(targetUserRef, {
          'followers': FieldValue.increment(-1),
        }, SetOptions(merge: true));
        transaction.set(currentUserRef, {
          'following': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStarRechargeOrders({
    int limit = 25,
  }) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('starRechargeOrders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<void> topUpCurrentUserStars(int amount) async {
    if (amount <= 0) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in.');
    }
    await _firestore.collection('users').doc(uid).set({
      'stars': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> createStarRechargePaymentLink({
    required int stars,
    required int amountPaise,
    required String packTitle,
  }) async {
    final response = await _postLiveEvent('createStarRechargePaymentLink', {
      'stars': stars,
      'amountPaise': amountPaise,
      'packTitle': packTitle,
    });
    if (response['ok'] != true) {
      throw StateError(
        response['error']?.toString() ?? 'Unable to create payment link.',
      );
    }
    return response;
  }

  Future<void> syncStarRechargePayment(String paymentLinkId) async {
    final response = await _postLiveEvent('syncStarRechargePayment', {
      'paymentLinkId': paymentLinkId,
    });
    if (response['ok'] != true) {
      throw StateError(
        response['error']?.toString() ?? 'Unable to sync payment.',
      );
    }
  }

  Future<Map<String, dynamic>> purchaseSvipPlan(String planId) async {
    final response = await _postLiveEvent('purchaseSvipPlan', {
      'planId': planId,
    });
    if (response['ok'] != true) {
      throw StateError(
        response['error']?.toString() ?? 'Unable to purchase SVIP plan.',
      );
    }
    return response;
  }

  Stream<List<LiveRoom>> liveRooms() {
    return _firestore
        .collection('liveRooms')
        .where('isLive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(LiveRoom.fromDoc).toList());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _firestore.collection('liveRooms').doc(roomId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPartyRoom(String roomId) {
    return _firestore.collection('party_rooms').doc(roomId).snapshots();
  }

  Stream<List<PartySeatState>> watchPartySeats(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('seats')
        .snapshots()
        .map((snapshot) {
          final seats =
              snapshot.docs.map((doc) => PartySeatState.fromDoc(doc)).toList()
                ..sort((a, b) => a.index.compareTo(b.index));
          return seats;
        });
  }

  Stream<List<PartySeatState>> watchPartySeatRequests(String roomId) {
    return watchPartySeats(roomId).map(
      (seats) => seats
          .where((seat) => seat.status == PartySeatStatus.requesting)
          .toList(),
    );
  }

  Future<PartySeatState?> currentPartySeatForUser(
    String roomId, {
    String? userId,
  }) async {
    final uid = userId ?? _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return null;
    final snapshot = await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('seats')
        .where('userId', isEqualTo: uid)
        .get();
    final seats =
        snapshot.docs
            .map((doc) => PartySeatState.fromDoc(doc))
            .where((seat) => seat.status != PartySeatStatus.empty)
            .toList()
          ..sort((a, b) {
            if (a.isOccupied != b.isOccupied) return a.isOccupied ? -1 : 1;
            return a.index.compareTo(b.index);
          });
    return seats.isEmpty ? null : seats.first;
  }

  Stream<List<PartyChatMessage>> watchPartyChats(
    String roomId, {
    int limit = 80,
  }) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PartyChatMessage.fromDoc(doc))
              .toList(),
        );
  }

  Future<void> ensurePartySeats(String roomId, {int totalSeats = 12}) async {
    final user = _auth.currentUser;
    final roomRef = _firestore.collection('liveRooms').doc(roomId);
    final seatsRef = _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('seats');
    final room = await roomRef.get();
    final roomData = room.data() ?? <String, dynamic>{};
    final hostId = roomData['hostId']?.toString() ?? '';
    final hostName = roomData['hostName']?.toString() ?? 'Host';
    final hostPhoto = roomData['hostPhotoUrl']?.toString() ?? '';

    final batch = _firestore.batch();
    for (var i = 0; i < totalSeats; i++) {
      final doc = seatsRef.doc('seat_$i');
      final snapshot = await doc.get();
      if (snapshot.exists) continue;
      final hostSeat = i == 0 && hostId.isNotEmpty;
      batch.set(doc, {
        'index': i,
        'userId': hostSeat ? hostId : '',
        'userName': hostSeat ? hostName : '',
        'userPhotoUrl': hostSeat ? hostPhoto : '',
        'isLocked': false,
        'isMuted': false,
        'status': hostSeat ? 'occupied' : 'empty',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_firestore.collection('party_rooms').doc(roomId), {
      'roomId': roomId,
      'hostId': hostId,
      'createdBy': user?.uid ?? hostId,
      'backgroundTheme': roomData['backgroundTheme']?.toString() ?? 'royal',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updatePartyBackgroundTheme(
    String roomId, {
    required String theme,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final room = await _firestore.collection('liveRooms').doc(roomId).get();
    final hostId = room.data()?['hostId']?.toString() ?? '';
    if (hostId.isNotEmpty && hostId != user.uid) {
      throw StateError('Only host can change background effects.');
    }
    await _firestore.collection('party_rooms').doc(roomId).set({
      'backgroundTheme': theme,
      'backgroundUpdatedBy': user.uid,
      'backgroundUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<PartyModerationUser>> watchPartyBlockedUsers(String roomId) {
    return _watchPartyModerationUsers(roomId, 'blockedUsers');
  }

  Stream<List<PartyModerationUser>> watchPartyChatDisabledUsers(String roomId) {
    return _watchPartyModerationUsers(roomId, 'chatDisabledUsers');
  }

  Stream<List<PartyModerationUser>> watchLiveBlockedUsers(String roomId) {
    return _watchLiveModerationUsers(roomId, 'blockedUsers');
  }

  Stream<List<PartyModerationUser>> watchLiveChatDisabledUsers(String roomId) {
    return _watchLiveModerationUsers(roomId, 'chatDisabledUsers');
  }

  Future<void> blockPartyUser(String roomId, String targetUid) {
    return _setPartyModerationUser(roomId, targetUid, 'blockedUsers');
  }

  Future<void> blockLiveUser(String roomId, String targetUid) {
    return _setLiveModerationUser(roomId, targetUid, 'blockedUsers');
  }

  Future<void> unblockPartyUser(String roomId, String targetUid) async {
    await _requirePartyHost(roomId);
    await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('blockedUsers')
        .doc(targetUid)
        .delete();
  }

  Future<void> unblockLiveUser(String roomId, String targetUid) async {
    await _requirePartyHost(roomId);
    await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('blockedUsers')
        .doc(targetUid)
        .delete();
  }

  Future<void> disablePartyUserChat(String roomId, String targetUid) {
    return _setPartyModerationUser(roomId, targetUid, 'chatDisabledUsers');
  }

  Future<void> disableLiveUserChat(String roomId, String targetUid) {
    return _setLiveModerationUser(roomId, targetUid, 'chatDisabledUsers');
  }

  Future<void> enablePartyUserChat(String roomId, String targetUid) async {
    await _requirePartyHost(roomId);
    await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('chatDisabledUsers')
        .doc(targetUid)
        .delete();
  }

  Future<void> enableLiveUserChat(String roomId, String targetUid) async {
    await _requirePartyHost(roomId);
    await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('chatDisabledUsers')
        .doc(targetUid)
        .delete();
  }

  Future<void> requestPartySeat(String roomId, int index) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final profile = await _currentProfile(user);
    final existingSeat = await currentPartySeatForUser(roomId);
    if (existingSeat != null && existingSeat.index != index) {
      throw StateError('You are already seated on another seat.');
    }
    final seatRef = _partySeatRef(roomId, index);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(seatRef);
      final seat = snapshot.exists ? PartySeatState.fromDoc(snapshot) : null;
      if (seat != null && seat.isLocked) {
        throw StateError('This seat is locked.');
      }
      if (seat != null &&
          seat.status != PartySeatStatus.empty &&
          seat.userId != user.uid) {
        throw StateError('This seat is not available.');
      }
      transaction.set(seatRef, {
        'index': index,
        'userId': user.uid,
        'userName': profile.name,
        'userPhotoUrl': profile.photoUrl,
        'isLocked': false,
        'isMuted': true,
        'status': 'requesting',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> acceptPartySeat(String roomId, int index) async {
    final host = _auth.currentUser;
    if (host == null) throw StateError('You must be signed in.');
    final roomRef = _firestore.collection('liveRooms').doc(roomId);
    final seatRef = _partySeatRef(roomId, index);
    final pendingSeat = await seatRef.get();
    final pendingUserId = pendingSeat.data()?['userId']?.toString() ?? '';
    if (pendingUserId.isNotEmpty) {
      final existingSeat = await currentPartySeatForUser(
        roomId,
        userId: pendingUserId,
      );
      if (existingSeat != null &&
          existingSeat.index != index &&
          existingSeat.isOccupied) {
        throw StateError('User is already seated on another seat.');
      }
    }

    await _firestore.runTransaction((transaction) async {
      final room = await transaction.get(roomRef);
      final roomData = room.data() ?? <String, dynamic>{};
      if (roomData['hostId']?.toString() != host.uid) {
        throw StateError('Only host can accept seat requests.');
      }
      final snapshot = await transaction.get(seatRef);
      if (!snapshot.exists) throw StateError('Seat request not found.');
      final seat = PartySeatState.fromDoc(snapshot);
      if (seat.status != PartySeatStatus.requesting || seat.userId.isEmpty) {
        throw StateError('Seat request is no longer pending.');
      }
      transaction.set(seatRef, {
        'status': 'occupied',
        'isMuted': false,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> rejectPartySeat(String roomId, int index) async {
    final host = _auth.currentUser;
    if (host == null) throw StateError('You must be signed in.');
    final roomRef = _firestore.collection('liveRooms').doc(roomId);
    final seatRef = _partySeatRef(roomId, index);

    await _firestore.runTransaction((transaction) async {
      final room = await transaction.get(roomRef);
      final roomData = room.data() ?? <String, dynamic>{};
      if (roomData['hostId']?.toString() != host.uid) {
        throw StateError('Only host can reject seat requests.');
      }
      transaction.set(seatRef, _emptySeatData(index), SetOptions(merge: true));
    });
  }

  Future<void> leavePartySeat(String roomId, int index) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final room = await _firestore.collection('liveRooms').doc(roomId).get();
    final hostId = room.data()?['hostId']?.toString() ?? '';
    final seatRef = _partySeatRef(roomId, index);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(seatRef);
      if (!snapshot.exists) return;
      final seat = PartySeatState.fromDoc(snapshot);
      if (seat.userId != user.uid && hostId != user.uid) {
        throw StateError('You cannot remove this speaker.');
      }
      transaction.set(seatRef, _emptySeatData(index), SetOptions(merge: true));
    });
  }

  Future<void> updatePartySeatMute(
    String roomId,
    int index, {
    required bool isMuted,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final room = await _firestore.collection('liveRooms').doc(roomId).get();
    final hostId = room.data()?['hostId']?.toString() ?? '';
    final seatRef = _partySeatRef(roomId, index);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(seatRef);
      if (!snapshot.exists) throw StateError('Seat not found.');
      final seat = PartySeatState.fromDoc(snapshot);
      if (seat.userId != user.uid && hostId != user.uid) {
        throw StateError('You cannot mute this speaker.');
      }
      transaction.set(seatRef, {
        'isMuted': isMuted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<AppUser> _currentProfile(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.exists ? AppUser.fromDoc(userDoc) : AppUser.fromAuth(user);
  }

  Future<void> _requirePartyHost(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final room = await _firestore.collection('liveRooms').doc(roomId).get();
    final hostId = room.data()?['hostId']?.toString() ?? '';
    if (hostId != user.uid) {
      throw StateError('Only host can manage room users.');
    }
  }

  Stream<List<PartyModerationUser>> _watchPartyModerationUsers(
    String roomId,
    String collection,
  ) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection(collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PartyModerationUser.fromDoc(doc))
              .toList(),
        );
  }

  Stream<List<PartyModerationUser>> _watchLiveModerationUsers(
    String roomId,
    String collection,
  ) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection(collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PartyModerationUser.fromDoc(doc))
              .toList(),
        );
  }

  Future<void> _setPartyModerationUser(
    String roomId,
    String targetUid,
    String collection,
  ) async {
    await _requirePartyHost(roomId);
    if (targetUid.isEmpty) return;
    final room = await _firestore.collection('liveRooms').doc(roomId).get();
    final hostId = room.data()?['hostId']?.toString() ?? '';
    if (targetUid == hostId) {
      throw StateError('Host cannot be moderated.');
    }
    final targetDoc = await _firestore.collection('users').doc(targetUid).get();
    final data = targetDoc.data() ?? <String, dynamic>{};
    await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection(collection)
        .doc(targetUid)
        .set({
          'uid': targetUid,
          'name': data['name']?.toString() ?? 'User',
          'photoUrl':
              data['photoURL']?.toString() ??
              data['photoUrl']?.toString() ??
              '',
          'userLevel': _rankingSenderLevel(data),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _setLiveModerationUser(
    String roomId,
    String targetUid,
    String collection,
  ) async {
    await _requirePartyHost(roomId);
    if (targetUid.isEmpty) return;
    final roomRef = _firestore.collection('liveRooms').doc(roomId);
    final room = await roomRef.get();
    final hostId = room.data()?['hostId']?.toString() ?? '';
    if (targetUid == hostId) {
      throw StateError('Host cannot be moderated.');
    }
    final targetDoc = await _firestore.collection('users').doc(targetUid).get();
    final data = targetDoc.data() ?? <String, dynamic>{};
    final moderationRef = roomRef.collection(collection).doc(targetUid);
    final payload = <String, dynamic>{
      'uid': targetUid,
      'name': data['name']?.toString() ?? 'User',
      'photoUrl':
          data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '',
      'userLevel': _rankingSenderLevel(data),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomRef);
      final roomData = roomSnap.data() ?? <String, dynamic>{};
      final activeUsers = roomData['activeUserIds'] is List
          ? List<String>.from(
              (roomData['activeUserIds'] as List).map(
                (item) => item.toString(),
              ),
            )
          : <String>[];
      final viewers = _asIntStatic(roomData['viewers']);
      transaction.set(moderationRef, payload, SetOptions(merge: true));
      if (collection == 'blockedUsers' && activeUsers.contains(targetUid)) {
        transaction.set(roomRef, {
          'activeUserIds': FieldValue.arrayRemove([targetUid]),
          'viewers': viewers > 0 ? viewers - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  DocumentReference<Map<String, dynamic>> _partySeatRef(
    String roomId,
    int index,
  ) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('seats')
        .doc('seat_$index');
  }

  Map<String, dynamic> _emptySeatData(int index) {
    return {
      'index': index,
      'userId': '',
      'userName': '',
      'userPhotoUrl': '',
      'isMuted': false,
      'status': 'empty',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Stream<List<LiveChatMessage>> watchMessages(String roomId, {int limit = 25}) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => LiveChatMessage.fromDoc(doc)).toList(),
        );
  }

  Stream<List<LiveGiftEvent>> watchGiftEvents(String roomId, {int limit = 12}) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('giftEvents')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => LiveGiftEvent.fromDoc(doc)).toList(),
        );
  }

  Stream<List<LiveVipEntryEvent>> watchVipEntries(
    String roomId, {
    int limit = 8,
  }) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('vipEntries')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LiveVipEntryEvent.fromDoc(doc))
              .toList(),
        );
  }

  Stream<PkBattleState?> watchPkState(String roomId) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('system')
        .doc('pkState')
        .snapshots()
        .map((doc) => doc.exists ? PkBattleState.fromDoc(doc) : null);
  }

  Stream<List<PkResultEvent>> watchPkResults(String roomId, {int limit = 5}) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('pkResults')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PkResultEvent.fromDoc(doc))
              .toList();
        });
  }

  Stream<List<PkRequestItem>> watchSentPkRequests(
    String roomId, {
    int limit = 5,
  }) {
    return _firestore
        .collection('pkRequests')
        .where('senderRoomId', isEqualTo: roomId)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs.map((doc) => PkRequestItem.fromDoc(doc)).toList()
                ..sort((a, b) {
                  final aCreated = a.createdAt?.millisecondsSinceEpoch ?? 0;
                  final bCreated = b.createdAt?.millisecondsSinceEpoch ?? 0;
                  return bCreated.compareTo(aCreated);
                });
          return items.take(limit).toList();
        });
  }

  Stream<List<PkRequestItem>> watchIncomingPkRequests(
    String roomId, {
    int limit = 5,
  }) {
    return _firestore
        .collection('pkRequests')
        .where('targetRoomId', isEqualTo: roomId)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs.map((doc) => PkRequestItem.fromDoc(doc)).toList()
                ..sort((a, b) {
                  final aCreated = a.createdAt?.millisecondsSinceEpoch ?? 0;
                  final bCreated = b.createdAt?.millisecondsSinceEpoch ?? 0;
                  return bCreated.compareTo(aCreated);
                });
          return items.take(limit).toList();
        });
  }

  Stream<List<RoomGiftLeaderEntry>> watchRoomGiftLeaders(
    String roomId, {
    int limit = 12,
  }) {
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('roomGiftLeaders')
        .orderBy('totalStars', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RoomGiftLeaderEntry.fromDoc(doc))
              .toList(),
        );
  }

  Stream<int> watchRoomUserGiftStars(String roomId, String uid) {
    if (uid.isEmpty) return Stream<int>.value(0);
    return _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('roomGiftLeaders')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() ?? <String, dynamic>{};
          return _asIntStatic(data['totalStars']);
        });
  }

  Stream<List<RoomAudienceEntry>> watchRoomAudience(String roomId) {
    return _firestore.collection('liveRooms').doc(roomId).snapshots().asyncMap((
      room,
    ) async {
      final data = room.data() ?? <String, dynamic>{};
      final activeUserIds = data['activeUserIds'] is List
          ? List<String>.from(
              (data['activeUserIds'] as List).map((item) => item.toString()),
            )
          : <String>[];

      final giftDocs = await _firestore
          .collection('liveRooms')
          .doc(roomId)
          .collection('roomGiftLeaders')
          .get();
      final currentGifts = <String, int>{
        for (final doc in giftDocs.docs)
          (doc.data()['uid']?.toString() ?? doc.id): _asIntStatic(
            doc.data()['totalStars'],
          ),
      };
      final audienceIds = <String>{
        ...activeUserIds,
        ...currentGifts.keys,
      }.toList();
      if (audienceIds.isEmpty) return <RoomAudienceEntry>[];

      final users = await Future.wait(
        audienceIds.take(80).map((uid) async {
          final doc = await _firestore.collection('users').doc(uid).get();
          final userData = doc.data() ?? <String, dynamic>{};
          return RoomAudienceEntry(
            uid: uid,
            name: userData['name']?.toString() ?? 'User',
            photoUrl:
                userData['photoURL']?.toString() ??
                userData['photoUrl']?.toString() ??
                '',
            userLevel: _rankingSenderLevel(userData),
            currentGiftStars: currentGifts[uid] ?? 0,
            totalGiftStars: _asIntStatic(userData['totalGiftedStars']),
          );
        }),
      );
      users.sort((a, b) {
        final current = b.currentGiftStars.compareTo(a.currentGiftStars);
        if (current != 0) return current;
        return b.totalGiftStars.compareTo(a.totalGiftStars);
      });
      return users;
    });
  }

  Stream<RoomExpState> watchRoomExp(String roomId) {
    return _firestore.collection('liveRooms').doc(roomId).snapshots().map((
      snapshot,
    ) {
      return roomExpFromRoomData(snapshot.data() ?? <String, dynamic>{});
    });
  }

  static RoomExpState roomExpFromRoomData(Map<String, dynamic> data) {
    final totalGiftStars = _asIntStatic(data['totalGiftStars']);
    final totalExp = _asIntStatic(data['roomExpTotal']);
    final effectiveTotalExp = totalExp > 0 ? totalExp : totalGiftStars;
    final todayExp = _asIntStatic(data['roomExpToday']);
    final level = roomLevelForExp(effectiveTotalExp);
    final currentLevelExp = roomExpForLevel(level);
    final nextLevelExp = roomExpForLevel(level + 1);
    final isMaxLevel = level >= roomExpMaxLevel;
    final expInLevel = isMaxLevel ? 0 : effectiveTotalExp - currentLevelExp;
    final expNeededForNextLevel = isMaxLevel
        ? 0
        : nextLevelExp - currentLevelExp;
    return RoomExpState(
      totalExp: effectiveTotalExp,
      todayExp: todayExp,
      level: level,
      currentLevelExp: currentLevelExp,
      nextLevelExp: nextLevelExp,
      expInLevel: expInLevel.clamp(0, expNeededForNextLevel),
      expNeededForNextLevel: expNeededForNextLevel,
      isMaxLevel: isMaxLevel,
    );
  }

  static const int roomExpMaxLevel = 50;

  static int roomExpForLevel(int level) {
    final safeLevel = level.clamp(1, roomExpMaxLevel);
    return (safeLevel - 1) * 30000;
  }

  static int roomLevelForExp(int exp) {
    if (exp <= 0) return 1;
    for (var level = roomExpMaxLevel; level >= 1; level--) {
      if (exp >= roomExpForLevel(level)) return level;
    }
    return 1;
  }

  Stream<List<TotalGiftLeaderboardEntry>> watchTotalGiftLeaderboard({
    int limit = 100,
  }) {
    return _firestore
        .collection('users')
        .orderBy('totalGiftedStars', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TotalGiftLeaderboardEntry.fromDoc(doc))
              .where((e) => e.totalGiftedStars > 0)
              .toList();
        });
  }

  Stream<List<WorldRankingEntry>> watchWorldGiftRankings(
    WorldRankingPeriod period, {
    int limit = 100,
    bool regionMode = false,
  }) {
    final activeKey = _rankingPeriodKey(period);
    final keyField = switch (period) {
      WorldRankingPeriod.hourly => 'hostRankingHourKey',
      WorldRankingPeriod.daily => 'hostRankingDayKey',
      WorldRankingPeriod.weekly => 'hostRankingWeekKey',
    };

    final controller = StreamController<List<WorldRankingEntry>>();
    final entriesByUid = <String, WorldRankingEntry>{};

    void publish() {
      final entries =
          entriesByUid.values.where((entry) => entry.stars > 0).toList()
            ..sort((a, b) => b.stars.compareTo(a.stars));
      controller.add(entries.take(limit).toList());
    }

    void upsert(WorldRankingEntry entry) {
      if (entry.stars <= 0) {
        entriesByUid.remove(entry.uid);
        return;
      }
      final existing = entriesByUid[entry.uid];
      if (existing == null || entry.stars >= existing.stars) {
        entriesByUid[entry.uid] = entry;
      }
    }

    final userSub = _firestore
        .collection('users')
        .where(keyField, isEqualTo: activeKey)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            final entry = WorldRankingEntry.fromDoc(
              change.doc,
              period,
              activeKey,
            );
            if (change.type == DocumentChangeType.removed) {
              entriesByUid.remove(entry.uid);
            } else {
              upsert(entry);
            }
          }
          publish();
        }, onError: controller.addError);

    final roomSub = _firestore
        .collection('liveRooms')
        .where(keyField, isEqualTo: activeKey)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            final entry = WorldRankingEntry.fromRoomDoc(
              change.doc,
              period,
              activeKey,
            );
            if (change.type == DocumentChangeType.removed) {
              entriesByUid.remove(entry.uid);
            } else {
              upsert(entry);
            }
          }
          publish();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await userSub.cancel();
      await roomSub.cancel();
    };

    return controller.stream;
  }

  Future<void> sendMessage(String roomId, String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to chat.');
    }
    final liveBlocked = await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('blockedUsers')
        .doc(user.uid)
        .get();
    if (liveBlocked.exists) {
      throw StateError('You are blocked from this room.');
    }
    final liveChatDisabled = await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('chatDisabledUsers')
        .doc(user.uid)
        .get();
    if (liveChatDisabled.exists) {
      throw StateError('Your chat is disabled in this room.');
    }
    final blocked = await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('blockedUsers')
        .doc(user.uid)
        .get();
    if (blocked.exists) {
      throw StateError('You are blocked from this room.');
    }
    final chatDisabled = await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('chatDisabledUsers')
        .doc(user.uid)
        .get();
    if (chatDisabled.exists) {
      throw StateError('Your chat is disabled in this room.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = userDoc.exists
        ? AppUser.fromDoc(userDoc)
        : AppUser.fromAuth(user);
    final userData = userDoc.data() ?? <String, dynamic>{};
    final vipLevel = _asIntStatic(userData['vipLevel']).clamp(0, 7);
    final userLevel = LevelService.userLevelFromUserData(userData).level;
    final svipTier = _activeSvipTierFromData(userData);
    final roomDoc = await _firestore.collection('liveRooms').doc(roomId).get();
    final roomData = roomDoc.data() ?? <String, dynamic>{};
    final isHost = roomData['hostId']?.toString() == user.uid;

    await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'uid': user.uid,
          'name': profile.name,
          'profileId': profile.username,
          'userLevel': userLevel,
          'vipLevel': vipLevel,
          'svipTier': svipTier,
          'isHost': isHost,
          'text': message,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> sendPartyMessage(String roomId, String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to chat.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = userDoc.exists
        ? AppUser.fromDoc(userDoc)
        : AppUser.fromAuth(user);
    final userData = userDoc.data() ?? <String, dynamic>{};
    final userLevel = LevelService.userLevelFromUserData(userData).level;
    final svipTier = _activeSvipTierFromData(userData);
    await _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('chats')
        .add({
          'senderId': user.uid,
          'username': profile.name,
          'profileId': profile.username,
          'userLevel': userLevel,
          'svipTier': svipTier,
          'userPhotoUrl': profile.photoUrl,
          'messageText': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<void> sendGiftEvent(
    String roomId, {
    required String giftName,
    required int stars,
    int quantity = 1,
    String pkSide = 'left',
  }) async {
    final response = await _postLiveEvent('sendGiftEvent', {
      'roomId': roomId,
      'giftName': giftName,
      'stars': stars,
      'quantity': quantity,
      'pkSide': pkSide,
    });
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'Gift send failed');
    }
  }

  Future<void> sendVipEntry(String roomId, {required String tier}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = userDoc.exists
        ? AppUser.fromDoc(userDoc)
        : AppUser.fromAuth(user);

    await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('vipEntries')
        .add({
          'uid': user.uid,
          'name': profile.name,
          'tier': tier,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<PkRequestItem> createPkRequest({
    required String roomId,
    required String mode,
    String? targetIdentifier,
  }) async {
    final payload = <String, dynamic>{'roomId': roomId, 'mode': mode};
    if (targetIdentifier != null && targetIdentifier.isNotEmpty) {
      payload['targetIdentifier'] = targetIdentifier;
    }
    final response = await _postLiveEvent('createPkRequest', payload);
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'PK request failed');
    }
    final request = response['request'];
    if (request is Map<String, dynamic>) {
      return PkRequestItem.fromMap(request);
    }
    if (request is Map) {
      return PkRequestItem.fromMap(Map<String, dynamic>.from(request));
    }
    throw StateError('PK request failed');
  }

  Future<void> respondPkRequest({
    required String requestId,
    required bool accept,
    String? roomId,
  }) async {
    final payload = <String, dynamic>{'requestId': requestId, 'accept': accept};
    if (roomId != null && roomId.isNotEmpty) {
      payload['roomId'] = roomId;
    }
    final response = await _postLiveEvent('respondPkRequest', payload);
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'PK response failed');
    }
  }

  Future<void> cancelPkRequest(String requestId) async {
    final response = await _postLiveEvent('cancelPkRequest', {
      'requestId': requestId,
    });
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'PK cancel failed');
    }
  }

  Future<void> updatePkState(
    String roomId, {
    required bool active,
    required int leftScore,
    required int rightScore,
    required int secondsLeft,
    String? leftHostName,
    String? rightHostName,
    String? mode,
  }) async {
    final payload = <String, dynamic>{
      'roomId': roomId,
      'active': active,
      'leftScore': leftScore,
      'rightScore': rightScore,
      'secondsLeft': secondsLeft,
    };
    if (leftHostName != null) payload['leftHostName'] = leftHostName;
    if (rightHostName != null) payload['rightHostName'] = rightHostName;
    if (mode != null) payload['mode'] = mode;

    final response = await _postLiveEvent('syncPkState', payload);
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'PK sync failed');
    }
  }

  Future<void> settlePkResult(
    String roomId, {
    required int leftScore,
    required int rightScore,
  }) async {
    final response = await _postLiveEvent('finalizePkBattle', {
      'roomId': roomId,
      'leftScore': leftScore,
      'rightScore': rightScore,
    });
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'PK finalize failed');
    }
  }

  Future<String> createRoom({
    String? liveTitle,
    String? hashtag,
    String? coverUrl,
    String roomType = 'live',
    bool audioOnly = false,
    Map<String, dynamic>? setupConfig,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to go live.');
    }
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final profile = userDoc.exists
        ? AppUser.fromDoc(userDoc)
        : AppUser.fromAuth(user);
    final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final hostSvipTier = _activeSvipTierFromData(userData);

    await _firestore.collection('liveRooms').doc(roomId).set({
      'roomId': roomId,
      'hostId': user.uid,
      'hostName': profile.name,
      'hostUsername': profile.username,
      'hostPhotoUrl': profile.photoUrl,
      'hostVipLevel': _asIntStatic(userData['vipLevel']).clamp(0, 7),
      'hostSvipTier': hostSvipTier,
      'hostSvipLabel': hostSvipTier > 0 ? 'SVIP$hostSvipTier' : '',
      'hostSvipPlan': userData['svipPlan']?.toString() ?? '',
      'hostSvipUntil': userData['svipUntil'],
      'roomExpTotal': _asIntStatic(userData['roomExpTotal']),
      'roomExpToday': 0,
      'roomExpDate': '',
      'roomLevel': 1,
      'coverUrl': (coverUrl?.trim().isNotEmpty ?? false)
          ? coverUrl!.trim()
          : profile.photoUrl,
      'liveTitle': liveTitle?.trim().isNotEmpty == true
          ? liveTitle!.trim()
          : 'welcome',
      'hashtag': hashtag?.trim().isNotEmpty == true
          ? hashtag!.trim()
          : '#Hosting',
      'setupConfig': setupConfig ?? <String, dynamic>{},
      'type': roomType,
      'audioOnly': audioOnly,
      'viewers': 0,
      'totalGiftStars': 0,
      'isLive': true,
      'agoraChannelName': 'Likeehit',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return roomId;
  }

  Future<bool> roomIsAvailable(String roomId) async {
    if (roomId.trim().isEmpty) return false;
    final snapshot = await _firestore.collection('liveRooms').doc(roomId).get();
    final data = snapshot.data();
    return snapshot.exists && data?['isLive'] != false;
  }

  Future<void> ensureLiveRoomAccess(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to join live streams.');
    }
    final blocked = await _firestore
        .collection('liveRooms')
        .doc(roomId)
        .collection('blockedUsers')
        .doc(uid)
        .get();
    if (blocked.exists) {
      throw StateError('You are blocked from this room.');
    }
  }

  Future<void> joinRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to join live streams.');
    }
    await ensureLiveRoomAccess(roomId);

    final roomRef = _firestore.collection('liveRooms').doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final activeUsers = data['activeUserIds'] is List
          ? List<String>.from(
              (data['activeUserIds'] as List).map((item) => item.toString()),
            )
          : <String>[];

      final alreadyJoined = activeUsers.contains(uid);
      transaction.set(roomRef, {
        if (!alreadyJoined) 'viewers': FieldValue.increment(1),
        'activeUserIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> leaveRoom(String roomId, {required bool isHost}) async {
    final uid = _auth.currentUser?.uid;
    final roomRef = _firestore.collection('liveRooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final viewers = _asInt(data['viewers']);
      final activeUsers = data['activeUserIds'] is List
          ? List<String>.from(
              (data['activeUserIds'] as List).map((item) => item.toString()),
            )
          : <String>[];
      final hadJoined = uid != null && activeUsers.contains(uid);

      transaction.set(roomRef, {
        if (isHost) 'isLive': false,
        if (isHost) 'endedAt': FieldValue.serverTimestamp(),
        if (!isHost && hadJoined) 'viewers': viewers > 0 ? viewers - 1 : 0,
        if (uid != null) 'activeUserIds': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> markRoomConnected(String roomId) async {
    await _firestore.collection('liveRooms').doc(roomId).set({
      'agoraConnected': true,
      'streamingStatus': 'connected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markRoomFailed(String roomId, String reason) async {
    await _firestore.collection('liveRooms').doc(roomId).set({
      'isLive': false,
      'agoraConnected': false,
      'streamingStatus': 'failed',
      'lastError': reason,
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  List<String> get _liveBackendBaseUrls {
    final configured = (dotenv.env['LIKEEHIT_LIVE_API_BASE_URL'] ?? '').trim();
    final urls = <String>[];

    void addUrl(String url) {
      final normalized = url.replaceAll(RegExp(r'/+$'), '');
      if (normalized.isNotEmpty && !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }

    addUrl(configured);
    addUrl(_fallbackBackendBaseUrl);
    return urls;
  }

  Future<Map<String, dynamic>> _postLiveEvent(
    String path,
    Map<String, dynamic> body,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to read Firebase ID token.');
    }
    Map<String, dynamic>? lastResponse;

    for (final baseUrl in _liveBackendBaseUrls) {
      final response = await _postLiveEventToBaseUrl(
        baseUrl: baseUrl,
        path: path,
        body: body,
        token: token,
      );
      final shouldRetry = response['_retryWithFallback'] == true;
      response.remove('_retryWithFallback');
      lastResponse = response;
      if (!shouldRetry) {
        return response;
      }
    }

    return lastResponse ??
        <String, dynamic>{
          'ok': false,
          'error': 'Unable to reach backend endpoint "$path".',
        };
  }

  Future<Map<String, dynamic>> _postLiveEventToBaseUrl({
    required String baseUrl,
    required String path,
    required Map<String, dynamic> body,
    required String token,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (response.body.isEmpty) {
      return <String, dynamic>{'ok': false, 'error': 'Empty backend response'};
    }
    final responseBody = response.body.trimLeft();
    if (!responseBody.startsWith('{') && !responseBody.startsWith('[')) {
      final preview = responseBody.length > 80
          ? responseBody.substring(0, 80)
          : responseBody;
      return <String, dynamic>{
        'ok': false,
        '_retryWithFallback': true,
        'error':
            'Backend endpoint "$path" did not return JSON. Deploy/update Firebase Functions and check LIKEEHIT_LIVE_API_BASE_URL. Response: $preview',
      };
    }
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{
      'ok': false,
      'error': 'Unexpected backend response',
    };
  }
}

enum PartySeatStatus { empty, requesting, occupied }

enum WorldRankingPeriod { hourly, daily, weekly }

class PartySeatState {
  const PartySeatState({
    required this.index,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.isLocked,
    required this.isMuted,
    required this.status,
    required this.updatedAt,
  });

  final int index;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final bool isLocked;
  final bool isMuted;
  final PartySeatStatus status;
  final Timestamp? updatedAt;

  bool get isEmpty => status == PartySeatStatus.empty;
  bool get isRequesting => status == PartySeatStatus.requesting;
  bool get isOccupied => status == PartySeatStatus.occupied;

  factory PartySeatState.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawStatus = data['status']?.toString().toLowerCase() ?? 'empty';
    final status = switch (rawStatus) {
      'occupied' => PartySeatStatus.occupied,
      'requesting' => PartySeatStatus.requesting,
      _ => PartySeatStatus.empty,
    };
    return PartySeatState(
      index: _asIntStatic(data['index']),
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      userPhotoUrl: data['userPhotoUrl']?.toString() ?? '',
      isLocked: data['isLocked'] == true,
      isMuted: data['isMuted'] == true,
      status: status,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
    );
  }
}

class LiveChatMessage {
  const LiveChatMessage({
    required this.uid,
    required this.name,
    required this.profileId,
    required this.userLevel,
    required this.vipLevel,
    required this.svipTier,
    required this.isHost,
    required this.text,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String profileId;
  final int userLevel;
  final int vipLevel;
  final int svipTier;
  final bool isHost;
  final String text;
  final Timestamp? createdAt;

  factory LiveChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LiveChatMessage(
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Viewer',
      profileId: data['profileId']?.toString() ?? '',
      userLevel: _asIntStatic(data['userLevel']).clamp(0, 100),
      vipLevel: _asIntStatic(data['vipLevel']).clamp(0, 7),
      svipTier: _asIntStatic(data['svipTier']).clamp(0, 3),
      isHost: data['isHost'] == true,
      text: data['text']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }
}

class PartyChatMessage {
  const PartyChatMessage({
    required this.senderId,
    required this.username,
    required this.profileId,
    required this.userLevel,
    required this.svipTier,
    required this.userPhotoUrl,
    required this.messageText,
    required this.timestamp,
  });

  final String senderId;
  final String username;
  final String profileId;
  final int userLevel;
  final int svipTier;
  final String userPhotoUrl;
  final String messageText;
  final Timestamp? timestamp;

  factory PartyChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PartyChatMessage(
      senderId: data['senderId']?.toString() ?? '',
      username: data['username']?.toString() ?? 'Guest',
      profileId: data['profileId']?.toString() ?? '',
      userLevel: _asIntStatic(data['userLevel']).clamp(0, 100),
      svipTier: _asIntStatic(data['svipTier']).clamp(0, 3),
      userPhotoUrl: data['userPhotoUrl']?.toString() ?? '',
      messageText: data['messageText']?.toString() ?? '',
      timestamp: data['timestamp'] is Timestamp ? data['timestamp'] : null,
    );
  }
}

class LiveGiftEvent {
  const LiveGiftEvent({
    required this.id,
    required this.uid,
    required this.name,
    required this.giftName,
    required this.stars,
    required this.quantity,
    required this.totalStars,
    required this.roomId,
    required this.hostName,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String name;
  final String giftName;
  final int stars;
  final int quantity;
  final int totalStars;
  final String roomId;
  final String hostName;
  final Timestamp? createdAt;

  factory LiveGiftEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LiveGiftEvent(
      id: doc.id,
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Viewer',
      giftName: data['giftName']?.toString() ?? 'Gift',
      stars: _asIntStatic(data['stars']),
      quantity: _asIntStatic(data['quantity']),
      totalStars: _asIntStatic(data['totalStars']),
      roomId: data['roomId']?.toString() ?? '',
      hostName: data['hostName']?.toString() ?? 'Host',
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }
}

class LiveVipEntryEvent {
  const LiveVipEntryEvent({
    required this.uid,
    required this.name,
    required this.tier,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String tier;
  final Timestamp? createdAt;

  factory LiveVipEntryEvent.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return LiveVipEntryEvent(
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? 'VIP',
      tier: data['tier']?.toString() ?? 'VIP',
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }
}

class PkBattleState {
  const PkBattleState({
    required this.active,
    required this.status,
    required this.leftScore,
    required this.rightScore,
    required this.secondsLeft,
    required this.leftHostName,
    required this.rightHostName,
    this.battleId = '',
    this.leftHostId = '',
    this.rightHostId = '',
    this.leftRoomId = '',
    this.rightRoomId = '',
    this.mode = 'forAll',
    this.connectedAt,
    this.battleEndsAt,
  });

  final bool active;
  final String status;
  final int leftScore;
  final int rightScore;
  final int secondsLeft;
  final String leftHostName;
  final String rightHostName;
  final String battleId;
  final String leftHostId;
  final String rightHostId;
  final String leftRoomId;
  final String rightRoomId;
  final String mode;
  final Timestamp? connectedAt;
  final Timestamp? battleEndsAt;

  factory PkBattleState.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PkBattleState(
      active: data['active'] == true,
      status: data['status']?.toString() ?? 'IDLE',
      leftScore: _asIntStatic(data['leftScore']),
      rightScore: _asIntStatic(data['rightScore']),
      secondsLeft: _asIntStatic(data['secondsLeft']),
      leftHostName: data['leftHostName']?.toString() ?? 'You',
      rightHostName: data['rightHostName']?.toString() ?? 'Rival',
      battleId: data['battleId']?.toString() ?? '',
      leftHostId: data['leftHostId']?.toString() ?? '',
      rightHostId: data['rightHostId']?.toString() ?? '',
      leftRoomId: data['leftRoomId']?.toString() ?? '',
      rightRoomId: data['rightRoomId']?.toString() ?? '',
      mode: data['mode']?.toString() ?? 'forAll',
      connectedAt:
          _timestampFromAny(data['connectedAt']) ??
          _timestampFromMillis(data['connectedAtMs']),
      battleEndsAt:
          _timestampFromAny(data['battleEndsAt']) ??
          _timestampFromMillis(data['battleEndsAtMs']),
    );
  }
}

class PkResultEvent {
  const PkResultEvent({
    required this.winner,
    required this.leftScore,
    required this.rightScore,
    required this.rewardStars,
    required this.createdAt,
  });

  final String winner;
  final int leftScore;
  final int rightScore;
  final int rewardStars;
  final Timestamp? createdAt;

  factory PkResultEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PkResultEvent(
      winner: data['winner']?.toString() ?? 'draw',
      leftScore: _asIntStatic(data['leftScore']),
      rightScore: _asIntStatic(data['rightScore']),
      rewardStars: _asIntStatic(data['rewardStars']),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }
}

class TotalGiftLeaderboardEntry {
  const TotalGiftLeaderboardEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.userLevel,
    required this.totalGiftedStars,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final int userLevel;
  final int totalGiftedStars;

  factory TotalGiftLeaderboardEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return TotalGiftLeaderboardEntry(
      uid: data['uid']?.toString() ?? doc.id,
      name: data['name']?.toString() ?? 'User',
      photoUrl:
          data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '',
      userLevel: _rankingSenderLevel(data),
      totalGiftedStars: _asIntStatic(data['totalGiftedStars']),
    );
  }
}

class WorldRankingEntry {
  const WorldRankingEntry({
    required this.uid,
    required this.profileId,
    required this.name,
    required this.photoUrl,
    required this.svipTier,
    required this.userLevel,
    required this.stars,
  });

  final String uid;
  final String profileId;
  final String name;
  final String photoUrl;
  final int svipTier;
  final int userLevel;
  final int stars;

  factory WorldRankingEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    WorldRankingPeriod period,
    String activeKey,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final periodField = switch (period) {
      WorldRankingPeriod.hourly => 'hostHourlyEarnedStars',
      WorldRankingPeriod.daily => 'hostDailyEarnedStars',
      WorldRankingPeriod.weekly => 'hostWeeklyEarnedStars',
    };
    final keyField = switch (period) {
      WorldRankingPeriod.hourly => 'hostRankingHourKey',
      WorldRankingPeriod.daily => 'hostRankingDayKey',
      WorldRankingPeriod.weekly => 'hostRankingWeekKey',
    };
    final keyMatches = data[keyField]?.toString() == activeKey;
    final periodStars = keyMatches ? _asIntStatic(data[periodField]) : 0;
    final profileId =
        data['profileId']?.toString().trim() ??
        data['username']?.toString().trim() ??
        data['hostUsername']?.toString().trim() ??
        '';
    return WorldRankingEntry(
      uid: data['uid']?.toString() ?? doc.id,
      profileId: profileId.isEmpty ? doc.id : profileId,
      name: data['name']?.toString() ?? 'User',
      photoUrl:
          data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '',
      svipTier: _activeSvipTierFromData(data),
      userLevel: _rankingHostLevel(data),
      stars: periodStars,
    );
  }

  factory WorldRankingEntry.fromRoomDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    WorldRankingPeriod period,
    String activeKey,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final periodField = switch (period) {
      WorldRankingPeriod.hourly => 'hostHourlyEarnedStars',
      WorldRankingPeriod.daily => 'hostDailyEarnedStars',
      WorldRankingPeriod.weekly => 'hostWeeklyEarnedStars',
    };
    final keyField = switch (period) {
      WorldRankingPeriod.hourly => 'hostRankingHourKey',
      WorldRankingPeriod.daily => 'hostRankingDayKey',
      WorldRankingPeriod.weekly => 'hostRankingWeekKey',
    };
    final keyMatches = data[keyField]?.toString() == activeKey;
    final periodStars = keyMatches ? _asIntStatic(data[periodField]) : 0;
    final uid = data['hostId']?.toString() ?? data['uid']?.toString() ?? doc.id;
    final profileId =
        data['hostUsername']?.toString().trim() ??
        data['profileId']?.toString().trim() ??
        data['username']?.toString().trim() ??
        '';
    return WorldRankingEntry(
      uid: uid,
      profileId: profileId.isEmpty ? uid : profileId,
      name: data['hostName']?.toString() ?? data['name']?.toString() ?? 'Host',
      photoUrl:
          data['hostPhotoUrl']?.toString() ??
          data['photoURL']?.toString() ??
          data['photoUrl']?.toString() ??
          '',
      svipTier: _activeSvipTierFromData(data),
      userLevel: _rankingHostLevel(data),
      stars: periodStars,
    );
  }
}

class RoomGiftLeaderEntry {
  const RoomGiftLeaderEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.totalStars,
    required this.pkSide,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final int totalStars;
  final String pkSide;

  factory RoomGiftLeaderEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return RoomGiftLeaderEntry(
      uid: data['uid']?.toString() ?? doc.id,
      name: data['name']?.toString() ?? 'User',
      photoUrl:
          data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '',
      totalStars: _asIntStatic(data['totalStars']),
      pkSide: data['pkSide']?.toString() ?? 'left',
    );
  }
}

class RoomAudienceEntry {
  const RoomAudienceEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.userLevel,
    required this.currentGiftStars,
    required this.totalGiftStars,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final int userLevel;
  final int currentGiftStars;
  final int totalGiftStars;
}

class PartyModerationUser {
  const PartyModerationUser({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.userLevel,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final int userLevel;

  factory PartyModerationUser.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return PartyModerationUser(
      uid: data['uid']?.toString() ?? doc.id,
      name: data['name']?.toString() ?? 'User',
      photoUrl:
          data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '',
      userLevel: _rankingSenderLevel(data),
    );
  }
}

class RoomExpState {
  const RoomExpState({
    required this.totalExp,
    required this.todayExp,
    required this.level,
    required this.currentLevelExp,
    required this.nextLevelExp,
    required this.expInLevel,
    required this.expNeededForNextLevel,
    required this.isMaxLevel,
  });

  final int totalExp;
  final int todayExp;
  final int level;
  final int currentLevelExp;
  final int nextLevelExp;
  final int expInLevel;
  final int expNeededForNextLevel;
  final bool isMaxLevel;

  double get levelProgress {
    if (isMaxLevel || expNeededForNextLevel <= 0) return 1;
    return (expInLevel / expNeededForNextLevel).clamp(0, 1).toDouble();
  }

  String get chipText {
    if (isMaxLevel) return 'MAX';
    return '$expInLevel/$expNeededForNextLevel';
  }
}

class PkRequestItem {
  const PkRequestItem({
    required this.requestId,
    required this.mode,
    required this.status,
    required this.senderRoomId,
    required this.senderHostId,
    required this.senderHostName,
    required this.targetRoomId,
    required this.targetHostId,
    required this.targetHostName,
    required this.createdAt,
    required this.updatedAt,
    this.battleId = '',
    this.expiresAt,
    this.message = '',
    this.pkSide = 'left',
  });

  final String requestId;
  final String mode;
  final String status;
  final String senderRoomId;
  final String senderHostId;
  final String senderHostName;
  final String targetRoomId;
  final String targetHostId;
  final String targetHostName;
  final String battleId;
  final Timestamp? expiresAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String message;
  final String pkSide;

  bool get isExpired {
    final expiresAtValue = expiresAt;
    if (expiresAtValue == null) return false;
    return expiresAtValue.millisecondsSinceEpoch <=
        DateTime.now().millisecondsSinceEpoch;
  }

  bool get isConnected => status.toUpperCase() == 'CONNECTED';
  bool get isSearching =>
      status.toUpperCase() == 'SEARCHING' || status.toUpperCase() == 'INVITED';

  factory PkRequestItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PkRequestItem(
      requestId: data['requestId']?.toString() ?? doc.id,
      mode: data['mode']?.toString() ?? 'forAll',
      status: data['status']?.toString() ?? 'SEARCHING',
      senderRoomId: data['senderRoomId']?.toString() ?? '',
      senderHostId: data['senderHostId']?.toString() ?? '',
      senderHostName: data['senderHostName']?.toString() ?? 'Host',
      targetRoomId: data['targetRoomId']?.toString() ?? '',
      targetHostId: data['targetHostId']?.toString() ?? '',
      targetHostName: data['targetHostName']?.toString() ?? '',
      battleId: data['battleId']?.toString() ?? '',
      expiresAt:
          _timestampFromAny(data['expiresAt']) ??
          _timestampFromMillis(data['expiresAtMs']),
      createdAt:
          _timestampFromAny(data['createdAt']) ??
          _timestampFromMillis(data['createdAtMs']),
      updatedAt:
          _timestampFromAny(data['updatedAt']) ??
          _timestampFromMillis(data['updatedAtMs']),
      message: data['message']?.toString() ?? '',
      pkSide: data['pkSide']?.toString() ?? 'left',
    );
  }

  factory PkRequestItem.fromMap(Map<String, dynamic> data) {
    return PkRequestItem(
      requestId: data['requestId']?.toString() ?? '',
      mode: data['mode']?.toString() ?? 'forAll',
      status: data['status']?.toString() ?? 'SEARCHING',
      senderRoomId: data['senderRoomId']?.toString() ?? '',
      senderHostId: data['senderHostId']?.toString() ?? '',
      senderHostName: data['senderHostName']?.toString() ?? 'Host',
      targetRoomId: data['targetRoomId']?.toString() ?? '',
      targetHostId: data['targetHostId']?.toString() ?? '',
      targetHostName: data['targetHostName']?.toString() ?? '',
      battleId: data['battleId']?.toString() ?? '',
      expiresAt:
          _timestampFromAny(data['expiresAt']) ??
          _timestampFromMillis(data['expiresAtMs']),
      createdAt:
          _timestampFromAny(data['createdAt']) ??
          _timestampFromMillis(data['createdAtMs']),
      updatedAt:
          _timestampFromAny(data['updatedAt']) ??
          _timestampFromMillis(data['updatedAtMs']),
      message: data['message']?.toString() ?? '',
      pkSide: data['pkSide']?.toString() ?? 'left',
    );
  }
}

int _asIntStatic(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int _rankingHostLevel(Map<String, dynamic> data) {
  final explicitHostLevel = _asIntStatic(data['hostLevel']);
  if (explicitHostLevel > 0) return explicitHostLevel;

  final roomLevel = _asIntStatic(data['roomLevel']);
  if (roomLevel > 0) return roomLevel;

  return max(
    1,
    LiveService.roomLevelForExp(_asIntStatic(data['roomExpTotal'])),
  );
}

int _rankingSenderLevel(Map<String, dynamic> data) {
  final explicitLevel = _asIntStatic(data['userLevel']);
  if (explicitLevel > 0) return explicitLevel;
  return max(1, LevelService.userLevelFromUserData(data).level);
}

String _rankingPeriodKey(WorldRankingPeriod period) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return switch (period) {
    WorldRankingPeriod.hourly => _rankingHourKey(now),
    WorldRankingPeriod.daily => _rankingDayKey(now),
    WorldRankingPeriod.weekly => _isoWeekKey(now),
  };
}

String _rankingHourKey(DateTime date) {
  return '${_rankingDayKey(date)}T${date.hour.toString().padLeft(2, '0')}';
}

String _rankingDayKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _isoWeekKey(DateTime date) {
  final utcDate = DateTime.utc(date.year, date.month, date.day);
  final thursday = utcDate.add(Duration(days: 4 - utcDate.weekday));
  final yearStart = DateTime.utc(thursday.year);
  final week = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

Timestamp? _timestampFromAny(dynamic value) {
  if (value is Timestamp) return value;
  return null;
}

Timestamp? _timestampFromMillis(dynamic value) {
  if (value is int) {
    return Timestamp.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return Timestamp.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

int _activeSvipTierFromData(Map<String, dynamic> data) {
  final until = _timestampFromAny(data['svipUntil']);
  if (until != null && !until.toDate().isAfter(DateTime.now())) return 0;

  final tier = _asIntStatic(data['svipTier']);
  if (tier > 0) return tier.clamp(1, 3);

  final plan = data['svipPlan']?.toString().toLowerCase() ?? '';
  if (plan == 'royal') return 3;
  if (plan == 'pro') return 2;
  if (plan == 'lite') return 1;

  final legacyLevel = _asIntStatic(data['svipLevel']);
  if (legacyLevel >= 7) return 3;
  if (legacyLevel >= 3) return 2;
  if (legacyLevel >= 1) return 1;
  return 0;
}
