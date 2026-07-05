const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { RtcTokenBuilder, RtcRole } = require('agora-token');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();
const { FieldValue } = admin.firestore;

const AGORA_APP_ID = defineSecret('AGORA_APP_ID');
const AGORA_APP_CERTIFICATE = defineSecret('AGORA_APP_CERTIFICATE');
const RAZORPAY_KEY_ID = defineSecret('RAZORPAY_KEY_ID');
const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
const ROOM_EXP_MAX_LEVEL = 50;
const USER_LEVEL_MAX_LEVEL = 100;
const SVIP_PLANS = {
  lite: {
    title: 'SVIP Lite',
    tier: 1,
    label: 'SVIP1',
    level: 1,
    days: 7,
    priceStars: 99,
  },
  pro: {
    title: 'SVIP Pro',
    tier: 2,
    label: 'SVIP2',
    level: 3,
    days: 30,
    priceStars: 299,
  },
  royal: {
    title: 'SVIP Royal',
    tier: 3,
    label: 'SVIP3',
    level: 7,
    days: 90,
    priceStars: 999,
  },
};

function getInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function getRole(value) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === 'host' || normalized === 'publisher') {
    return RtcRole.PUBLISHER;
  }
  return RtcRole.SUBSCRIBER;
}

function getSide(value) {
  const normalized = String(value ?? '').trim().toLowerCase();
  return normalized === 'right' ? 'right' : 'left';
}

function getString(value, fallback = '') {
  const text = String(value ?? '').trim();
  return text.length > 0 ? text : fallback;
}

function razorpayAuthHeader() {
  const keyId = RAZORPAY_KEY_ID.value();
  const keySecret = RAZORPAY_KEY_SECRET.value();
  if (!keyId || !keySecret) {
    throw new Error('Razorpay secrets are not configured.');
  }
  const credentials = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  return `Basic ${credentials}`;
}

async function razorpayRequest(method, path, body = null) {
  const response = await fetch(`https://api.razorpay.com/v1/${path}`, {
    method,
    headers: {
      Authorization: razorpayAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const description =
      data?.error?.description || data?.error?.reason || response.statusText;
    throw new Error(`Razorpay error: ${description}`);
  }
  return data;
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function hourKey() {
  return new Date().toISOString().slice(0, 13);
}

function weekKey() {
  const date = new Date();
  const utcDate = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const day = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utcDate.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((utcDate - yearStart) / 86400000 + 1) / 7);
  return `${utcDate.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

function rankingDateInIst() {
  return new Date(Date.now() + IST_OFFSET_MS);
}

function rankingDayKey() {
  return rankingDateInIst().toISOString().slice(0, 10);
}

function rankingHourKey() {
  return rankingDateInIst().toISOString().slice(0, 13);
}

function rankingWeekKey() {
  const date = rankingDateInIst();
  const utcDate = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const day = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utcDate.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((utcDate - yearStart) / 86400000 + 1) / 7);
  return `${utcDate.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

function roomExpForLevel(level) {
  const parsed = Number.parseInt(String(level ?? 1), 10);
  const safeLevel = Math.min(
    Math.max(Number.isFinite(parsed) ? parsed : 1, 1),
    ROOM_EXP_MAX_LEVEL,
  );
  return (safeLevel - 1) * 30000;
}

function roomLevelForExp(exp) {
  const safeExp = getInt(exp, 0);
  for (let level = ROOM_EXP_MAX_LEVEL; level >= 1; level -= 1) {
    if (safeExp >= roomExpForLevel(level)) return level;
  }
  return 1;
}

function userExpNeededForNextLevel(level) {
  const parsed = Number.parseInt(String(level ?? 0), 10);
  const safeLevel = Math.min(
    Math.max(Number.isFinite(parsed) ? parsed : 0, 0),
    USER_LEVEL_MAX_LEVEL,
  );
  return 50 + safeLevel * 60;
}

function userExpForLevel(level) {
  const parsed = Number.parseInt(String(level ?? 0), 10);
  const safeLevel = Math.min(
    Math.max(Number.isFinite(parsed) ? parsed : 0, 0),
    USER_LEVEL_MAX_LEVEL,
  );
  let total = 0;
  for (let currentLevel = 0; currentLevel < safeLevel; currentLevel += 1) {
    total += userExpNeededForNextLevel(currentLevel);
  }
  return total;
}

function userLevelForExp(exp) {
  const safeExp = getInt(exp, 0);
  for (let level = USER_LEVEL_MAX_LEVEL; level >= 0; level -= 1) {
    if (safeExp >= userExpForLevel(level)) return level;
  }
  return 0;
}

async function requireAuth(req) {
  const header = String(req.headers.authorization ?? '').trim();
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new Error('Missing Firebase ID token.');
  }
  return admin.auth().verifyIdToken(match[1]);
}

function normalizePkMode(value) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === 'withfriends' || normalized === 'with_friends') {
    return 'withFriends';
  }
  if (normalized === 'random') {
    return 'random';
  }
  return 'forAll';
}

function timestampFromMillis(ms) {
  return admin.firestore.Timestamp.fromMillis(ms);
}

function timestampToMillis(value) {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  return null;
}

function svipTierFromData(data) {
  const tier = getInt(data?.svipTier, 0);
  if (tier > 0) return tier;

  const planId = getString(data?.svipPlan).toLowerCase();
  if (SVIP_PLANS[planId]) return SVIP_PLANS[planId].tier;

  const legacyLevel = getInt(data?.svipLevel, 0);
  if (legacyLevel >= 7) return 3;
  if (legacyLevel >= 3) return 2;
  if (legacyLevel >= 1) return 1;
  return 0;
}

async function syncActiveRoomSvip(uid, svipData) {
  const [liveRooms, partyRooms] = await Promise.all([
    db.collection('liveRooms').where('hostId', '==', uid).get(),
    db.collection('party_rooms').where('hostId', '==', uid).get(),
  ]);

  const batch = db.batch();
  let count = 0;
  for (const doc of liveRooms.docs) {
    if (doc.data()?.isLive !== true) continue;
    batch.set(doc.ref, svipData, { merge: true });
    count += 1;
  }
  for (const doc of partyRooms.docs) {
    batch.set(doc.ref, svipData, { merge: true });
    count += 1;
  }
  if (count > 0) {
    await batch.commit();
  }
}

function toPublicRoomData(roomSnap) {
  const data = roomSnap.data() ?? {};
  return {
    roomId: roomSnap.id,
    hostId: getString(data.hostId),
    hostName: getString(data.hostName, 'Host'),
    hostPhotoUrl: getString(data.hostPhotoUrl || data.hostPhotoURL, ''),
  };
}

async function getUserProfile(uid) {
  const [userSnap, authUser] = await Promise.all([
    db.collection('users').doc(uid).get(),
    auth.getUser(uid).catch(() => null),
  ]);

  const userData = userSnap.data() ?? {};
  const name = getString(
    userData.name || userData.displayName || userData.fullName,
    authUser?.displayName || authUser?.email || 'User',
  );
  const photoUrl = getString(
    userData.photoUrl ||
      userData.photoURL ||
      userData.avatarUrl ||
      userData.avatarURL,
    authUser?.photoURL || '',
  );

  return {
    uid,
    name,
    photoUrl,
  };
}

async function resolveLiveRoom(identifier) {
  const target = getString(identifier);
  if (!target) return null;

  const byRoomId = await db.collection('liveRooms').doc(target).get();
  if (byRoomId.exists) {
    return toPublicRoomData(byRoomId);
  }

  const byHostId = await db
    .collection('liveRooms')
    .where('hostId', '==', target)
    .where('isLive', '==', true)
    .limit(1)
    .get();
  if (!byHostId.empty) {
    return toPublicRoomData(byHostId.docs[0]);
  }

  const byHostName = await db
    .collection('liveRooms')
    .where('hostName', '==', target)
    .where('isLive', '==', true)
    .limit(1)
    .get();
  if (!byHostName.empty) {
    return toPublicRoomData(byHostName.docs[0]);
  }

  return null;
}

function buildPkStatePayload({
  status,
  battleId,
  mode,
  leftRoom,
  rightRoom,
  leftScore,
  rightScore,
  secondsLeft,
  startedAt,
  battleEndsAt,
  requestId,
}) {
  return {
    active: status === 'CONNECTED' || status === 'ACTIVE',
    status,
    battleId,
    mode,
    leftRoomId: leftRoom.roomId,
    rightRoomId: rightRoom.roomId,
    leftHostId: leftRoom.hostId,
    rightHostId: rightRoom.hostId,
    leftHostName: leftRoom.hostName,
    rightHostName: rightRoom.hostName,
    leftHostPhotoUrl: leftRoom.hostPhotoUrl,
    rightHostPhotoUrl: rightRoom.hostPhotoUrl,
    leftScore,
    rightScore,
    secondsLeft,
    requestId,
    startedAt,
    connectedAt: startedAt,
    battleEndsAt,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function writeRoomPkState(transaction, roomId, payload) {
  const roomPkRef = db
    .collection('liveRooms')
    .doc(roomId)
    .collection('system')
    .doc('pkState');
  transaction.set(roomPkRef, payload, { merge: true });
  transaction.set(
    db.collection('liveRooms').doc(roomId),
    {
      pkStatus: payload.status,
      pkBattleId: payload.battleId,
      pkRequestId: payload.requestId,
      pkMode: payload.mode,
      pkUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

exports.getAgoraRtcToken = onRequest(
  {
    region: 'asia-south1',
    cors: true,
    secrets: [AGORA_APP_ID, AGORA_APP_CERTIFICATE],
  },
  async (req, res) => {
    try {
      const appId = AGORA_APP_ID.value().trim();
      const appCertificate = AGORA_APP_CERTIFICATE.value().trim();
      if (!appId || !appCertificate) {
        res.status(500).json({
          error: 'AGORA_APP_ID or AGORA_APP_CERTIFICATE is not configured.',
        });
        return;
      }

      const channelName = String(
        req.method === 'POST' ? req.body?.channelName : req.query.channelName,
      )
        .trim()
        .slice(0, 64) || 'Likeehit';
      const uid = getInt(
        req.method === 'POST' ? req.body?.uid : req.query.uid,
        0,
      );
      const role = getRole(
        req.method === 'POST' ? req.body?.role : req.query.role,
      );
      const ttlSeconds = getInt(
        req.method === 'POST' ? req.body?.ttlSeconds : req.query.ttlSeconds,
        7200,
      );

      const currentTimestamp = Math.floor(Date.now() / 1000);
      const privilegeExpiredTs = currentTimestamp + ttlSeconds;
      const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        role,
        privilegeExpiredTs,
      );
      if (!token) {
        throw new Error('Agora token generation returned an empty token.');
      }

      res.status(200).json({
        appId,
        channelName,
        uid,
        role: role === RtcRole.PUBLISHER ? 'publisher' : 'subscriber',
        ttlSeconds,
        privilegeExpiredTs,
        token,
      });
    } catch (error) {
      res.status(500).json({
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.sendGiftEvent = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const roomId = getString(payload.roomId);
      const giftName = getString(payload.giftName, 'Gift');
      const stars = getInt(payload.stars, 0);
      const quantity = getInt(payload.quantity, 1);
      const pkSide = getSide(payload.pkSide);

      if (!roomId) {
        throw new Error('roomId is required.');
      }
      if (stars <= 0 || quantity <= 0) {
        throw new Error('stars and quantity must be positive.');
      }

      const totalStars = stars * quantity;
      const roomRef = db.collection('liveRooms').doc(roomId);
      const userRef = db.collection('users').doc(uid);
      const eventRef = roomRef.collection('giftEvents').doc();
      const leaderRef = roomRef.collection('roomGiftLeaders').doc(uid);
      const pkRef = roomRef.collection('system').doc('pkState');

      const result = await db.runTransaction(async (transaction) => {
        const [roomSnap, userSnap, pkSnap] = await Promise.all([
          transaction.get(roomRef),
          transaction.get(userRef),
          transaction.get(pkRef),
        ]);

        if (!roomSnap.exists) {
          throw new Error('Live room not found.');
        }
        const roomData = roomSnap.data() ?? {};
        if (roomData.isLive === false) {
          throw new Error('Live room is no longer active.');
        }
        const hostId = getString(roomData.hostId);
        const hostRef = hostId ? db.collection('users').doc(hostId) : null;
        const hostSnap = hostRef ? await transaction.get(hostRef) : null;

        const userData = userSnap.data() ?? {};
        const hostData = hostSnap?.data() ?? {};
        const currentStars = getInt(userData.stars, 0);
        if (currentStars < totalStars) {
          throw new Error('Not enough stars');
        }

        const profile = await getUserProfile(uid);
        const currentPk = pkSnap.data() ?? {};
        const targetSide = getSide(
          payload.pkSide || currentPk.defaultSide || 'left',
        );
        const nextLeftScore =
          targetSide === 'left'
            ? getInt(currentPk.leftScore, 0) + totalStars
            : getInt(currentPk.leftScore, 0);
        const nextRightScore =
          targetSide === 'right'
            ? getInt(currentPk.rightScore, 0) + totalStars
            : getInt(currentPk.rightScore, 0);
        const now = FieldValue.serverTimestamp();
        const expDate = todayKey();
        const currentRoomExp = getInt(
          roomData.roomExpTotal,
          getInt(roomData.totalGiftStars, 0),
        );
        const nextRoomExp = currentRoomExp + totalStars;
        const currentTodayExp =
          getString(roomData.roomExpDate) === expDate
            ? getInt(roomData.roomExpToday, 0)
            : 0;
        const nextTodayExp = currentTodayExp + totalStars;
        const rankingHour = rankingHourKey();
        const rankingDay = rankingDayKey();
        const rankingWeek = rankingWeekKey();
        const nextHourlyGiftedStars =
          getString(userData.giftRankingHourKey) === rankingHour
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextDailyGiftedStars =
          getString(userData.giftRankingDayKey) === rankingDay
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextWeeklyGiftedStars =
          getString(userData.giftRankingWeekKey) === rankingWeek
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextHostHourlyEarnedStars =
          getString(hostData.hostRankingHourKey) === rankingHour
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextHostDailyEarnedStars =
          getString(hostData.hostRankingDayKey) === rankingDay
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextHostWeeklyEarnedStars =
          getString(hostData.hostRankingWeekKey) === rankingWeek
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextRoomHostHourlyEarnedStars =
          getString(roomData.hostRankingHourKey) === rankingHour
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextRoomHostDailyEarnedStars =
          getString(roomData.hostRankingDayKey) === rankingDay
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextRoomHostWeeklyEarnedStars =
          getString(roomData.hostRankingWeekKey) === rankingWeek
            ? FieldValue.increment(totalStars)
            : totalStars;
        const nextRoomLevel = roomLevelForExp(nextRoomExp);
        const currentUserExp = getInt(
          userData.userExpTotal,
          getInt(userData.totalGiftedStars, 0),
        );
        const nextUserExp = currentUserExp + totalStars;
        const nextUserLevel = userLevelForExp(nextUserExp);
        const hostLevel = nextRoomLevel;

        transaction.set(
          userRef,
          {
            stars: currentStars - totalStars,
            totalGiftedStars: FieldValue.increment(totalStars),
            hourlyGiftedStars: nextHourlyGiftedStars,
            dailyGiftedStars: nextDailyGiftedStars,
            weeklyGiftedStars: nextWeeklyGiftedStars,
            giftRankingHourKey: rankingHour,
            giftRankingDayKey: rankingDay,
            giftRankingWeekKey: rankingWeek,
            userExpTotal: nextUserExp,
            userLevel: nextUserLevel,
            updatedAt: now,
          },
          { merge: true },
        );

        if (hostRef) {
          transaction.set(
            hostRef,
            {
              uid: hostId,
              name: getString(hostData.name, getString(roomData.hostName, 'Host')),
              profileId: getString(
                hostData.profileId || hostData.username || hostData.hostUsername,
                getString(roomData.hostUsername, hostId),
              ),
              photoUrl: getString(
                hostData.photoUrl || hostData.photoURL,
                getString(roomData.hostPhotoUrl || roomData.hostPhotoURL, ''),
              ),
              hostLevel,
              hostHourlyEarnedStars: nextHostHourlyEarnedStars,
              hostDailyEarnedStars: nextHostDailyEarnedStars,
              hostWeeklyEarnedStars: nextHostWeeklyEarnedStars,
              hostRankingHourKey: rankingHour,
              hostRankingDayKey: rankingDay,
              hostRankingWeekKey: rankingWeek,
              hostTotalGiftEarnedStars: FieldValue.increment(totalStars),
              updatedAt: now,
            },
            { merge: true },
          );
        }

        transaction.set(
          roomRef,
          {
            hostId,
            hostName: getString(roomData.hostName, getString(hostData.name, 'Host')),
            hostUsername: getString(
              roomData.hostUsername || hostData.profileId || hostData.username,
              hostId,
            ),
            hostPhotoUrl: getString(
              roomData.hostPhotoUrl || roomData.hostPhotoURL,
              getString(hostData.photoUrl || hostData.photoURL, ''),
            ),
            hostSvipTier: getInt(roomData.hostSvipTier, getInt(hostData.svipTier, 0)),
            hostLevel,
            hostHourlyEarnedStars: nextRoomHostHourlyEarnedStars,
            hostDailyEarnedStars: nextRoomHostDailyEarnedStars,
            hostWeeklyEarnedStars: nextRoomHostWeeklyEarnedStars,
            hostRankingHourKey: rankingHour,
            hostRankingDayKey: rankingDay,
            hostRankingWeekKey: rankingWeek,
            hostTotalGiftEarnedStars: FieldValue.increment(totalStars),
            totalGiftStars: FieldValue.increment(totalStars),
            pkPotStars: FieldValue.increment(totalStars),
            roomExpTotal: nextRoomExp,
            roomExpToday: nextTodayExp,
            roomExpDate: expDate,
            roomLevel: nextRoomLevel,
            updatedAt: now,
          },
          { merge: true },
        );

        transaction.set(
          pkRef,
          {
            leftScore: nextLeftScore,
            rightScore: nextRightScore,
            updatedAt: now,
          },
          { merge: true },
        );

        transaction.set(
          leaderRef,
          {
            uid,
            name: profile.name,
            photoUrl: profile.photoUrl,
            hostId,
            totalStars: FieldValue.increment(totalStars),
            pkSide: targetSide,
            updatedAt: now,
          },
          { merge: true },
        );

        transaction.set(eventRef, {
          uid,
          name: profile.name,
          photoUrl: profile.photoUrl,
          giftName,
          stars,
          quantity,
          totalStars,
          roomId,
          hostId,
          hostName: getString(roomData.hostName, getString(hostData.name, 'Host')),
          hostUsername: getString(
            roomData.hostUsername || hostData.profileId || hostData.username,
            hostId,
          ),
          hostPhotoUrl: getString(
            roomData.hostPhotoUrl || roomData.hostPhotoURL,
            getString(hostData.photoUrl || hostData.photoURL, ''),
          ),
          hostSvipTier: getInt(roomData.hostSvipTier, getInt(hostData.svipTier, 0)),
          hostLevel,
          pkSide: targetSide,
          createdAt: now,
        });

        return {
          balance: currentStars - totalStars,
          leftScore: nextLeftScore,
          rightScore: nextRightScore,
          roomExpTotal: nextRoomExp,
          roomExpToday: nextTodayExp,
          roomLevel: nextRoomLevel,
          userExpTotal: nextUserExp,
          userLevel: nextUserLevel,
          pkSide: targetSide,
        };
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.createPkRequest = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const roomId = getString(payload.roomId);
      const mode = normalizePkMode(payload.mode);
      const targetIdentifier = getString(payload.targetIdentifier);

      if (!roomId) {
        throw new Error('roomId is required.');
      }

      const roomRef = db.collection('liveRooms').doc(roomId);
      const requestRef = db.collection('pkRequests').doc();
      const requestId = requestRef.id;
      const nowMs = Date.now();
      const expiresAtMs = nowMs + 30_000;
      const expiresAt = timestampFromMillis(expiresAtMs);
      const createdAt = timestampFromMillis(nowMs);
      const hostProfile = await getUserProfile(uid);

      const result = await db.runTransaction(async (transaction) => {
        const roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists) {
          throw new Error('Live room not found.');
        }
        const roomData = roomSnap.data() ?? {};
        const hostId = getString(roomData.hostId);
        if (hostId && hostId !== uid) {
          throw new Error('Only the room host can start PK requests.');
        }

        const currentPkRef = roomRef.collection('system').doc('pkState');
        const currentPkSnap = await transaction.get(currentPkRef);
        const currentPk = currentPkSnap.data() ?? {};
        const existingStatus = String(currentPk.status ?? '').toUpperCase();
        if (currentPk.active === true || existingStatus === 'SEARCHING') {
          throw new Error('A PK battle is already active or searching.');
        }

        const senderRoom = {
          roomId,
          hostId: uid,
          hostName: getString(roomData.hostName, hostProfile.name),
          hostPhotoUrl: getString(
            roomData.hostPhotoUrl || roomData.hostPhotoURL,
            hostProfile.photoUrl,
          ),
        };

        let targetRoom = null;
        let requestStatus = 'SEARCHING';
        let message = '';
        let battleId = '';

        if (mode === 'withFriends') {
          targetRoom = await resolveLiveRoom(targetIdentifier);
          if (!targetRoom) {
            throw new Error('Target host not found.');
          }
          if (targetRoom.hostId === uid || targetRoom.roomId === roomId) {
            throw new Error('You cannot invite yourself.');
          }
          requestStatus = 'INVITED';
          message = 'Invitation sent';
        }

        if (mode === 'random') {
          const candidateQuery = db
            .collection('pkRequests')
            .where('status', '==', 'SEARCHING')
            .limit(50);
          const candidateSnap = await transaction.get(candidateQuery);
          const candidateDoc = candidateSnap.docs
            .filter((doc) => {
              const data = doc.data() ?? {};
              const candidateMode = normalizePkMode(data.mode);
              return (
                candidateMode !== 'withFriends' &&
                getString(data.senderRoomId) !== roomId &&
                timestampToMillis(data.expiresAt) > nowMs
              );
            })
            .sort((a, b) => {
              const aCreated = timestampToMillis(a.data()?.createdAt) ?? nowMs;
              const bCreated = timestampToMillis(b.data()?.createdAt) ?? nowMs;
              return aCreated - bCreated;
            });

          for (const doc of candidateDoc) {
            const data = doc.data() ?? {};
            const candidateMode = normalizePkMode(data.mode);
            if (
              candidateMode === 'withFriends' ||
              getString(data.senderRoomId) === roomId ||
              timestampToMillis(data.expiresAt) <= nowMs
            ) {
              continue;
            }
            const candidateRoom = await resolveLiveRoom(
              getString(data.senderRoomId),
            );
            if (!candidateRoom) {
              continue;
            }
            const leftRequestCreatedAt = timestampToMillis(data.createdAt) ?? nowMs;
            const rightRequestCreatedAt = nowMs;
            const candidateIsLeft =
              leftRequestCreatedAt <= rightRequestCreatedAt;
            const leftRoom = candidateIsLeft ? candidateRoom : senderRoom;
            const rightRoom = candidateIsLeft ? senderRoom : candidateRoom;
            battleId = db.collection('pkBattles').doc().id;
            const startedAt = createdAt;
            const battleEndsAt = timestampFromMillis(nowMs + 120_000);
            const pkPayload = buildPkStatePayload({
              status: 'CONNECTED',
              battleId,
              mode,
              leftRoom,
              rightRoom,
              leftScore: 0,
              rightScore: 0,
              secondsLeft: 120,
              startedAt,
              battleEndsAt,
              requestId,
            });

            transaction.set(
              db.collection('pkBattles').doc(battleId),
              {
                ...pkPayload,
                status: 'ACTIVE',
                createdAt,
              },
              { merge: true },
            );

            transaction.set(
              doc.ref,
              {
                status: 'CONNECTED',
                battleId,
                targetRoomId: roomId,
                targetHostId: uid,
                targetHostName: hostProfile.name,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true },
            );

            transaction.set(
              requestRef,
              {
                requestId,
                mode,
                status: 'CONNECTED',
                senderRoomId: senderRoom.roomId,
                senderHostId: senderRoom.hostId,
                senderHostName: senderRoom.hostName,
                senderHostPhotoUrl: senderRoom.hostPhotoUrl,
                targetRoomId: rightRoom.roomId,
                targetHostId: rightRoom.hostId,
                targetHostName: rightRoom.hostName,
                battleId,
                createdAt,
                createdAtMs: nowMs,
                updatedAt: FieldValue.serverTimestamp(),
                updatedAtMs: nowMs,
                expiresAt,
                expiresAtMs,
                message: 'Random PK matched',
                pkSide: candidateIsLeft ? 'right' : 'left',
              },
              { merge: true },
            );

            writeRoomPkState(transaction, leftRoom.roomId, pkPayload);
            writeRoomPkState(transaction, rightRoom.roomId, pkPayload);

            return {
              requestId,
              mode,
              status: 'CONNECTED',
              senderRoomId: senderRoom.roomId,
              senderHostId: senderRoom.hostId,
              senderHostName: senderRoom.hostName,
              senderHostPhotoUrl: senderRoom.hostPhotoUrl,
              targetRoomId: rightRoom.roomId,
              targetHostId: rightRoom.hostId,
              targetHostName: rightRoom.hostName,
              battleId,
              createdAt,
              createdAtMs: nowMs,
              updatedAtMs: nowMs,
              expiresAt,
              expiresAtMs,
              message: 'Random PK matched',
              pkSide: candidateIsLeft ? 'right' : 'left',
            };
          }
        }

        if (mode === 'forAll' || mode === 'random') {
          transaction.set(
            requestRef,
            {
              requestId,
              mode,
              status: requestStatus,
              senderRoomId: senderRoom.roomId,
              senderHostId: senderRoom.hostId,
              senderHostName: senderRoom.hostName,
              senderHostPhotoUrl: senderRoom.hostPhotoUrl,
              targetRoomId: targetRoom?.roomId ?? '',
              targetHostId: targetRoom?.hostId ?? '',
              targetHostName: targetRoom?.hostName ?? '',
              battleId,
              createdAt,
              createdAtMs: nowMs,
              updatedAt: FieldValue.serverTimestamp(),
              updatedAtMs: nowMs,
              expiresAt,
              expiresAtMs,
              message,
              pkSide: 'left',
            },
            { merge: true },
          );
        } else {
          transaction.set(
            requestRef,
            {
              requestId,
              mode,
              status: requestStatus,
              senderRoomId: senderRoom.roomId,
              senderHostId: senderRoom.hostId,
              senderHostName: senderRoom.hostName,
              senderHostPhotoUrl: senderRoom.hostPhotoUrl,
              targetRoomId: targetRoom?.roomId ?? '',
              targetHostId: targetRoom?.hostId ?? '',
              targetHostName: targetRoom?.hostName ?? '',
              battleId,
              createdAt,
              createdAtMs: nowMs,
              updatedAt: FieldValue.serverTimestamp(),
              updatedAtMs: nowMs,
              expiresAt,
              expiresAtMs,
              message,
              pkSide: 'left',
            },
            { merge: true },
          );
        }

        return {
          requestId,
          mode,
          status: requestStatus,
          senderRoomId: senderRoom.roomId,
          senderHostId: senderRoom.hostId,
          senderHostName: senderRoom.hostName,
          senderHostPhotoUrl: senderRoom.hostPhotoUrl,
          targetRoomId: targetRoom?.roomId ?? '',
          targetHostId: targetRoom?.hostId ?? '',
          targetHostName: targetRoom?.hostName ?? '',
          battleId,
          createdAt,
          createdAtMs: nowMs,
          updatedAtMs: nowMs,
          expiresAt,
          expiresAtMs,
          message,
          pkSide: 'left',
        };
      });

      res.status(200).json({ ok: true, request: result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.respondPkRequest = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const requestId = getString(payload.requestId);
      const accept = payload.accept === true || String(payload.accept) === 'true';
      const roomId = getString(payload.roomId);
      if (!requestId) {
        throw new Error('requestId is required.');
      }

      const requestRef = db.collection('pkRequests').doc(requestId);

      const result = await db.runTransaction(async (transaction) => {
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists) {
          throw new Error('PK request not found.');
        }

        const request = requestSnap.data() ?? {};
        const status = String(request.status ?? '').toUpperCase();
        if (status === 'CONNECTED' || status === 'REJECTED' || status === 'DECLINED' || status === 'CANCELLED' || status === 'EXPIRED') {
          throw new Error('PK request is no longer available.');
        }

        const mode = normalizePkMode(request.mode);
        const senderRoom = await resolveLiveRoom(getString(request.senderRoomId));
        if (!senderRoom) {
          throw new Error('Sender room not found.');
        }

        const targetRoom = await resolveLiveRoom(
          getString(request.targetRoomId) || roomId,
        );

        if (accept) {
          if (mode === 'withFriends' && targetRoom && targetRoom.hostId !== uid) {
            throw new Error('Only the invited host can accept this request.');
          }
          if (
            mode !== 'withFriends' &&
            targetRoom &&
            targetRoom.hostId &&
            targetRoom.hostId !== uid &&
            !roomId
          ) {
            throw new Error('roomId is required to accept this request.');
          }

          const acceptorRoom = targetRoom ?? (roomId ? await resolveLiveRoom(roomId) : null);
          if (!acceptorRoom) {
            throw new Error('Target room not found.');
          }
          if (acceptorRoom.hostId === senderRoom.hostId) {
            throw new Error('You cannot battle yourself.');
          }

          const battleId = db.collection('pkBattles').doc().id;
          const createdAt = timestampFromMillis(Date.now());
          const battleEndsAt = timestampFromMillis(Date.now() + 120_000);
          const pkPayload = buildPkStatePayload({
            status: 'CONNECTED',
            battleId,
            mode,
            leftRoom: senderRoom,
            rightRoom: acceptorRoom,
            leftScore: 0,
            rightScore: 0,
            secondsLeft: 120,
            startedAt: createdAt,
            battleEndsAt,
            requestId,
          });

          transaction.set(
            db.collection('pkBattles').doc(battleId),
            {
              ...pkPayload,
              status: 'ACTIVE',
              createdAt,
            },
            { merge: true },
          );

          transaction.set(
            requestRef,
            {
              requestId,
              mode,
              status: 'CONNECTED',
              battleId,
              targetRoomId: acceptorRoom.roomId,
              targetHostId: acceptorRoom.hostId,
              targetHostName: acceptorRoom.hostName,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          writeRoomPkState(transaction, senderRoom.roomId, pkPayload);
          writeRoomPkState(transaction, acceptorRoom.roomId, pkPayload);

          return {
            requestId,
            mode,
            status: 'CONNECTED',
            senderRoomId: senderRoom.roomId,
            senderHostId: senderRoom.hostId,
            senderHostName: senderRoom.hostName,
            targetRoomId: acceptorRoom.roomId,
            targetHostId: acceptorRoom.hostId,
            targetHostName: acceptorRoom.hostName,
            battleId,
            createdAt,
            createdAtMs: Date.now(),
            updatedAtMs: Date.now(),
            expiresAt: request.expiresAt ?? null,
            expiresAtMs: timestampToMillis(request.expiresAt),
            message: 'PK connected',
            pkSide: 'right',
          };
        }

        const nextStatus = mode === 'withFriends' ? 'DECLINED' : 'REJECTED';
        transaction.set(
          requestRef,
          {
            status: nextStatus,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return {
          requestId,
          mode,
          status: nextStatus,
          senderRoomId: senderRoom.roomId,
          targetRoomId: getString(request.targetRoomId) || roomId,
          message: nextStatus === 'DECLINED' ? 'Request declined' : 'Request rejected',
        };
      });

      res.status(200).json({ ok: true, request: result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.cancelPkRequest = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const requestId = getString(payload.requestId);
      if (!requestId) {
        throw new Error('requestId is required.');
      }

      const requestRef = db.collection('pkRequests').doc(requestId);

      const result = await db.runTransaction(async (transaction) => {
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists) {
          throw new Error('PK request not found.');
        }
        const request = requestSnap.data() ?? {};
        const status = String(request.status ?? '').toUpperCase();
        if (status === 'CONNECTED' || status === 'ENDED') {
          throw new Error('Connected PK requests cannot be cancelled.');
        }

        const senderRoom = await resolveLiveRoom(getString(request.senderRoomId));
        if (!senderRoom || senderRoom.hostId !== uid) {
          throw new Error('Only the sender can cancel this request.');
        }

        transaction.set(
          requestRef,
          {
            status: 'CANCELLED',
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        return {
          requestId,
          status: 'CANCELLED',
          senderRoomId: senderRoom.roomId,
        };
      });

      res.status(200).json({ ok: true, request: result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.syncPkState = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const roomId = getString(payload.roomId);
      if (!roomId) {
        throw new Error('roomId is required.');
      }

      const roomRef = db.collection('liveRooms').doc(roomId);
      const pkRef = roomRef.collection('system').doc('pkState');

      const active = payload.active === true || String(payload.active) === 'true';
      const leftScore = getInt(payload.leftScore, 0);
      const rightScore = getInt(payload.rightScore, 0);
      const secondsLeft = getInt(payload.secondsLeft, 0);
      const leftHostName = getString(payload.leftHostName, 'You');
      const rightHostName = getString(payload.rightHostName, 'Rival');
      const mode = getString(payload.mode, 'forAll');
      const leftHostId = getString(payload.leftHostId, uid);
      const rightHostId = getString(payload.rightHostId, '');
      const leftScoreDelta = getInt(payload.leftScoreDelta, 0);
      const rightScoreDelta = getInt(payload.rightScoreDelta, 0);

      const result = await db.runTransaction(async (transaction) => {
        const [roomSnap, pkSnap] = await Promise.all([
          transaction.get(roomRef),
          transaction.get(pkRef),
        ]);
        if (!roomSnap.exists) {
          throw new Error('Live room not found.');
        }
        const roomData = roomSnap.data() ?? {};
        const hostId = getString(roomData.hostId);
        if (hostId && hostId !== uid) {
          const currentPk = pkSnap.data() ?? {};
          const leftOwner = getString(currentPk.leftHostId);
          const rightOwner = getString(currentPk.rightHostId);
          if (leftOwner !== uid && rightOwner !== uid) {
            throw new Error('Only the room host can update PK state.');
          }
        }

        const currentPk = pkSnap.data() ?? {};
        const nextLeftScore = leftScoreDelta !== 0
          ? getInt(currentPk.leftScore, 0) + leftScoreDelta
          : leftScore;
        const nextRightScore = rightScoreDelta !== 0
          ? getInt(currentPk.rightScore, 0) + rightScoreDelta
          : rightScore;

        transaction.set(
          pkRef,
          {
            active,
            leftScore: nextLeftScore,
            rightScore: nextRightScore,
            secondsLeft,
            leftHostName,
            rightHostName,
            leftHostId,
            rightHostId,
            mode,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        transaction.set(
          roomRef,
          {
            pkPotStars: Math.max(
              getInt(roomData.pkPotStars, 0),
              nextLeftScore + nextRightScore,
            ),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        return {
          active,
          leftScore: nextLeftScore,
          rightScore: nextRightScore,
          secondsLeft,
          leftHostName,
          rightHostName,
          mode,
        };
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.finalizePkBattle = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const roomId = getString(payload.roomId);
      if (!roomId) {
        throw new Error('roomId is required.');
      }

      const roomRef = db.collection('liveRooms').doc(roomId);
      const pkRef = roomRef.collection('system').doc('pkState');
      const resultRef = roomRef.collection('system').doc('pkResult');
      const historyRef = roomRef.collection('pkResults').doc();

      const result = await db.runTransaction(async (transaction) => {
        const [roomSnap, pkSnap] = await Promise.all([
          transaction.get(roomRef),
          transaction.get(pkRef),
        ]);
        if (!roomSnap.exists) {
          throw new Error('Live room not found.');
        }

        const roomData = roomSnap.data() ?? {};
        const hostId = getString(roomData.hostId);
        if (hostId && hostId !== uid) {
          const currentPk = pkSnap.data() ?? {};
          const leftOwner = getString(currentPk.leftHostId);
          const rightOwner = getString(currentPk.rightHostId);
          if (leftOwner !== uid && rightOwner !== uid) {
            throw new Error('Only the room host can finalize PK.');
          }
        }

        const currentPk = pkSnap.data() ?? {};
        const leftScore = getInt(currentPk.leftScore, 0);
        const rightScore = getInt(currentPk.rightScore, 0);
        const winner = leftScore === rightScore
          ? 'draw'
          : (leftScore > rightScore ? 'left' : 'right');
        const pot = getInt(roomData.pkPotStars, 0);
        const reward = winner === 'left' ? Math.round(pot * 0.3) : 0;
        const winnerUid = winner === 'left'
          ? getString(currentPk.leftHostId, uid)
          : getString(currentPk.rightHostId, '');

        if (reward > 0 && winnerUid) {
          transaction.set(
            db.collection('users').doc(winnerUid),
            {
              stars: FieldValue.increment(reward),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        transaction.set(
          roomRef,
          {
            pkPotStars: 0,
            pkStatus: 'ENDED',
            pkEndedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        transaction.set(
          pkRef,
          {
            active: false,
            status: 'ENDED',
            secondsLeft: 0,
            rewardStars: reward,
            winner,
            endedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        const payloadData = {
          winner,
          leftScore,
          rightScore,
          rewardStars: reward,
          winnerUid,
          createdAt: FieldValue.serverTimestamp(),
        };

        transaction.set(resultRef, payloadData);
        transaction.set(historyRef, payloadData);

        return payloadData;
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.createStarRechargePaymentLink = onRequest(
  {
    region: 'asia-south1',
    cors: true,
    secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET],
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const stars = getInt(payload.stars, 0);
      const amountPaise = getInt(payload.amountPaise, 0);
      const packTitle = getString(payload.packTitle, `${stars} Stars`);

      if (stars <= 0 || amountPaise <= 0) {
        throw new Error('stars and amountPaise must be positive.');
      }

      const profile = await getUserProfile(uid);
      const paymentLink = await razorpayRequest('POST', 'payment_links', {
        amount: amountPaise,
        currency: 'INR',
        accept_partial: false,
        description: `LikeeHit ${packTitle} recharge`,
        reference_id: `LH_${Date.now()}_${uid.slice(0, 8)}`,
        customer: {
          name: profile.name,
          email: decoded.email || undefined,
          contact: decoded.phone_number || undefined,
        },
        notify: {
          sms: false,
          email: false,
        },
        reminder_enable: false,
        notes: {
          uid,
          stars: String(stars),
          packTitle,
          type: 'star_recharge',
        },
      });

      const orderRef = db
        .collection('users')
        .doc(uid)
        .collection('starRechargeOrders')
        .doc(paymentLink.id);

      await orderRef.set(
        {
          uid,
          stars,
          amountPaise,
          packTitle,
          provider: 'razorpay',
          razorpayPaymentLinkId: paymentLink.id,
          shortUrl: paymentLink.short_url || '',
          status: paymentLink.status || 'created',
          credited: false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      res.status(200).json({
        ok: true,
        paymentLinkId: paymentLink.id,
        shortUrl: paymentLink.short_url || '',
        status: paymentLink.status || 'created',
      });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.syncStarRechargePayment = onRequest(
  {
    region: 'asia-south1',
    cors: true,
    secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET],
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const paymentLinkId = getString(payload.paymentLinkId);
      if (!paymentLinkId) {
        throw new Error('paymentLinkId is required.');
      }

      const paymentLink = await razorpayRequest(
        'GET',
        `payment_links/${paymentLinkId}`,
      );
      const paid = paymentLink.status === 'paid';
      const userRef = db.collection('users').doc(uid);
      const orderRef = userRef
        .collection('starRechargeOrders')
        .doc(paymentLinkId);

      const result = await db.runTransaction(async (transaction) => {
        const orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) {
          throw new Error('Recharge order not found.');
        }
        const orderData = orderSnap.data() ?? {};
        if (getString(orderData.uid) !== uid) {
          throw new Error('Recharge order owner mismatch.');
        }

        if (!paid) {
          transaction.set(
            orderRef,
            {
              status: paymentLink.status || 'created',
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          return {
            credited: false,
            status: paymentLink.status || 'created',
            stars: getInt(orderData.stars, 0),
          };
        }

        const alreadyCredited = orderData.credited === true;
        const stars = getInt(orderData.stars, 0);
        if (!alreadyCredited && stars > 0) {
          transaction.set(
            userRef,
            {
              stars: FieldValue.increment(stars),
              totalRechargedStars: FieldValue.increment(stars),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        transaction.set(
          orderRef,
          {
            status: 'paid',
            credited: true,
            paidAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        transaction.set(userRef.collection('walletTransactions').doc(), {
          type: 'star_recharge',
          provider: 'razorpay',
          paymentLinkId,
          stars,
          amountPaise: getInt(orderData.amountPaise, 0),
          createdAt: FieldValue.serverTimestamp(),
        });

        return { credited: !alreadyCredited, status: 'paid', stars };
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);

exports.purchaseSvipPlan = onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const decoded = await requireAuth(req);
      const uid = decoded.uid;
      const payload = req.method === 'POST' ? req.body ?? {} : req.query ?? {};
      const planId = getString(payload.planId, 'lite').toLowerCase();
      const plan = SVIP_PLANS[planId];
      if (!plan) {
        throw new Error('Invalid SVIP plan.');
      }

      const userRef = db.collection('users').doc(uid);
      const result = await db.runTransaction(async (transaction) => {
        const userSnap = await transaction.get(userRef);
        const userData = userSnap.data() ?? {};
        const currentStars = getInt(userData.stars, 0);
        const existingUntil = timestampToMillis(userData.svipUntil);
        const nowMs = Date.now();
        const isActive = Boolean(existingUntil && existingUntil > nowMs);
        const activeTier = isActive ? svipTierFromData(userData) : 0;

        if (isActive && activeTier >= plan.tier) {
          const currentPlanId = getString(userData.svipPlan, planId).toLowerCase();
          const currentPlan = SVIP_PLANS[currentPlanId] ?? plan;
          const normalizedTier = activeTier > 0 ? activeTier : currentPlan.tier;
          const normalizedLabel = `SVIP${normalizedTier}`;
          transaction.set(
            userRef,
            {
              svipActive: true,
              svipTier: normalizedTier,
              svipLabel: normalizedLabel,
              svipPlan: currentPlanId,
              svipLevel: Math.max(getInt(userData.svipLevel, 0), currentPlan.level),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          return {
            charged: false,
            alreadyActive: true,
            svipLevel: Math.max(getInt(userData.svipLevel, 0), currentPlan.level),
            svipTier: normalizedTier,
            svipLabel: normalizedLabel,
            svipPlan: currentPlanId,
            svipUntil: existingUntil,
            remainingStars: currentStars,
          };
        }

        if (currentStars < plan.priceStars) {
          throw new Error('Not enough stars for this SVIP plan.');
        }

        const baseMs = existingUntil && existingUntil > nowMs
          ? existingUntil
          : nowMs;
        const untilMs = baseMs + plan.days * 24 * 60 * 60 * 1000;
        const nextLevel = Math.max(getInt(userData.svipLevel, 0), plan.level);
        const purchaseRef = userRef.collection('svipPurchases').doc();

        transaction.set(
          userRef,
          {
            stars: currentStars - plan.priceStars,
            svipLevel: nextLevel,
            svipTier: plan.tier,
            svipLabel: plan.label,
            svipPlan: planId,
            svipActive: true,
            svipUntil: timestampFromMillis(untilMs),
            svipPurchasedStars: FieldValue.increment(plan.priceStars),
            svipPurchaseCount: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        transaction.set(purchaseRef, {
          planId,
          title: plan.title,
          tier: plan.tier,
          label: plan.label,
          level: plan.level,
          days: plan.days,
          priceStars: plan.priceStars,
          svipUntil: timestampFromMillis(untilMs),
          createdAt: FieldValue.serverTimestamp(),
        });

        transaction.set(userRef.collection('walletTransactions').doc(), {
          type: 'svip_purchase',
          planId,
          stars: -plan.priceStars,
          createdAt: FieldValue.serverTimestamp(),
        });

        return {
          charged: true,
          alreadyActive: false,
          svipLevel: nextLevel,
          svipTier: plan.tier,
          svipLabel: plan.label,
          svipPlan: planId,
          svipUntil: untilMs,
          remainingStars: currentStars - plan.priceStars,
        };
      });

      await syncActiveRoomSvip(uid, {
        hostSvipTier: result.svipTier ?? 0,
        hostSvipLabel: result.svipLabel ?? '',
        hostSvipPlan: result.svipPlan ?? '',
        hostSvipUntil: timestampFromMillis(result.svipUntil),
        updatedAt: FieldValue.serverTimestamp(),
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error) {
      res.status(400).json({
        ok: false,
        error: error?.message ?? String(error),
      });
    }
  },
);
