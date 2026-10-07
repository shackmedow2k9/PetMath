/**
 * Cloud Functions cho EduPet — nơi DUY NHẤT thật sự "gửi" thông báo đẩy
 * (push notification) tới học sinh, kể cả khi app đã tắt hẳn. Phía Flutter
 * (lib/services/notification_service.dart) chỉ xin quyền + lưu FCM token +
 * hiển thị thông báo khi app đang mở — KHÔNG tự gửi được gì, vì gửi FCM
 * bắt buộc phải qua 1 server có quyền Admin (đây chính là server đó).
 *
 * 4 loại thông báo, khớp với `StudentModel.notificationPrefs`:
 *   1. streak      — nhắc giữ streak nếu SAU 6 TIẾNG mỗi ngày vẫn CHƯA học
 *                     (không gửi nếu hôm đó đã học rồi). Chạy định kỳ.
 *   2. levelUp      — khi pet lên cấp độ mới. Trigger theo document `pets`.
 *   3. achievement  — khi mở khoá huy hiệu mới (students.badgeIds có phần
 *                     tử mới). Trigger theo document `students`.
 *   4. update       — tin tức/cập nhật chung của app, gửi qua TOPIC
 *                     'app_updates' (không theo từng token) khi có
 *                     document mới trong collection `announcements`
 *                     (Giáo viên/Admin tạo — xem firestore.rules).
 *
 * TRIỂN KHAI: cần Firebase CLI + gói Blaze (pay-as-you-go), rồi chạy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated, onDocumentCreated } =
  require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Việt Nam dùng múi giờ cố định UTC+7, không có giờ mùa hè (DST) — nên chỉ
// cần cộng thẳng số phút lệch, không cần thư viện timezone ngoài.
const VN_OFFSET_MINUTES = 7 * 60;

/** Dịch 1 mốc thời gian UTC sang "giờ địa phương VN" (vẫn là Date, nhưng
 * đọc bằng các hàm getUTC* sẽ ra đúng giờ/ngày ở VN). */
function toVnShifted(date) {
  return new Date(date.getTime() + VN_OFFSET_MINUTES * 60000);
}

/** Khoá dạng "YYYY-M-D" theo giờ VN — dùng so sánh "có phải cùng 1 ngày
 * (theo giờ VN) hay không" mà không cần thư viện ngày tháng ngoài. */
function vnDateKey(date) {
  const vn = toVnShifted(date);
  return `${vn.getUTCFullYear()}-${vn.getUTCMonth()}-${vn.getUTCDate()}`;
}

/** Số giờ đã trôi qua kể từ 00:00 (giờ VN) của ngày chứa [date]. */
function vnHoursSinceMidnight(date) {
  const vn = toVnShifted(date);
  return vn.getUTCHours() + vn.getUTCMinutes() / 60;
}

/** true nếu [prefs] KHÔNG tắt loại thông báo [key] — mặc định bật nếu
 * học sinh chưa từng chỉnh (thiếu field hoặc thiếu key con). */
function prefEnabled(prefs, key) {
  return !prefs || prefs[key] !== false;
}

/** Gửi 1 thông báo tới đúng 1 thiết bị qua FCM token, bỏ qua êm nếu
 * token đã hết hạn/không hợp lệ (KHÔNG throw — 1 lỗi gửi không được làm
 * hỏng cả batch học sinh khác). */
async function sendToToken(token, title, body, data) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: data || {},
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
    return true;
  } catch (err) {
    logger.warn(`Gửi FCM thất bại cho token ${token.slice(0, 12)}…`, err);
    return false;
  }
}

// ---------- 1. NHẮC GIỮ STREAK (sau 6 tiếng mỗi ngày vẫn chưa học) ----------
//
// Chạy mỗi 30 phút, quét toàn bộ học sinh có fcmToken. Với mỗi học sinh:
//  - Bỏ qua nếu đã tắt loại "streak" trong notificationPrefs.
//  - Bỏ qua nếu HÔM NAY (giờ VN) đã học rồi (lastStudyDate == hôm nay).
//  - Bỏ qua nếu CHƯA đủ 6 tiếng kể từ 00:00 giờ VN hôm nay.
//  - Bỏ qua nếu ĐÃ gửi nhắc streak rồi trong chính hôm nay (tránh spam
//    mỗi 30 phút lại nhắc lại — chỉ nhắc 1 lần/ngày).
exports.streakReminderCheck = onSchedule(
  { schedule: "every 30 minutes", timeZone: "Asia/Ho_Chi_Minh" },
  async () => {
    const now = new Date();
    const todayKey = vnDateKey(now);
    const hoursSinceMidnight = vnHoursSinceMidnight(now);
    if (hoursSinceMidnight < 6) {
      logger.info("Chưa tới mốc 6 tiếng trong ngày (giờ VN) — bỏ qua lượt này.");
      return;
    }

    const snap = await db
      .collection("students")
      .where("fcmToken", "!=", null)
      .get();

    let sentCount = 0;
    const writes = [];

    for (const doc of snap.docs) {
      const student = doc.data();
      const token = student.fcmToken;
      if (!token) continue;
      if (!prefEnabled(student.notificationPrefs, "streak")) continue;

      const lastStudyDate = student.lastStudyDate?.toDate?.();
      const studiedToday =
        lastStudyDate != null && vnDateKey(lastStudyDate) === todayKey;
      if (studiedToday) continue;

      const lastReminderDate = student.lastStreakReminderSentDate?.toDate?.();
      const alreadyRemindedToday =
        lastReminderDate != null && vnDateKey(lastReminderDate) === todayKey;
      if (alreadyRemindedToday) continue;

      const streakDays = student.streakDays || 0;
      const body =
        streakDays > 0
          ? `Bạn đang giữ streak ${streakDays} ngày — học ngay hôm nay để không mất streak nhé! 🔥`
          : "Hôm nay chưa học bài nào — làm 1 bài thôi để bắt đầu streak mới nào! 🔥";

      const ok = await sendToToken(
        token,
        "Đừng quên giữ streak! 🔥",
        body,
        { type: "streak" },
      );
      if (ok) {
        sentCount++;
        writes.push(
          doc.ref.update({
            lastStreakReminderSentDate: admin.firestore.Timestamp.fromDate(now),
          }),
        );
      }
    }

    await Promise.all(writes);
    logger.info(`streakReminderCheck: đã gửi ${sentCount} thông báo.`);
  },
);

// ---------- 2. PET LÊN CẤP ----------
exports.onPetLevelUp = onDocumentUpdated("pets/{petId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (!(after.level > before.level)) return; // chỉ gửi khi thật sự LÊN cấp

  const ownerId = after.ownerId;
  if (!ownerId) return;

  const studentDoc = await db.collection("students").doc(ownerId).get();
  if (!studentDoc.exists) return;
  const student = studentDoc.data();
  const token = student.fcmToken;
  if (!token) return;
  if (!prefEnabled(student.notificationPrefs, "levelUp")) return;

  await sendToToken(
    token,
    "Pet lên cấp rồi! 🎉",
    `${after.name || "Pet của bạn"} đã lên cấp ${after.level}! Vào xem ngay nào.`,
    { type: "levelUp", petId: event.params.petId, level: String(after.level) },
  );
});

// ---------- 3. MỞ KHOÁ THÀNH TÍCH (badgeIds có phần tử mới) ----------
//
// Danh sách tên hiển thị PHẢI khớp id với AchievementCatalog phía Flutter
// (lib/models/achievement_catalog.dart) — chỉ dùng để hiển thị tiêu đề
// đẹp trong thông báo đẩy, KHÔNG dùng để xét điều kiện mở khoá (việc đó
// vẫn do client tính trong FirestoreService.checkAndAwardAchievements).
// Thêm thành tựu mới ở catalog Dart thì nhớ thêm cả dòng tương ứng ở đây.
const ACHIEVEMENT_TITLES = {
  streak_3: "Bền bỉ",
  streak_7: "Chăm chỉ",
  streak_14: "Kiên trì",
  streak_30: "Huyền thoại streak",
  answers_10: "Khởi động",
  answers_50: "Chăm học",
  answers_200: "Học giỏi",
  answers_500: "Bậc thầy tri thức",
  petlevel_5: "Pet đang lớn",
  petlevel_10: "Pet trưởng thành",
  petlevel_20: "Pet siêu cấp",
  fish_5: "Ngư dân tập sự",
  fish_15: "Nhà sưu tầm cá",
};

function achievementTitle(id) {
  return ACHIEVEMENT_TITLES[id] || id;
}

exports.onAchievementUnlocked = onDocumentUpdated(
  "students/{studentId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    const beforeBadges = new Set(before.badgeIds || []);
    const newBadges = (after.badgeIds || []).filter(
      (id) => !beforeBadges.has(id),
    );
    if (newBadges.length === 0) return;

    const token = after.fcmToken;
    if (!token) return;
    if (!prefEnabled(after.notificationPrefs, "achievement")) return;

    const titles = newBadges.map(achievementTitle);
    const body =
      titles.length === 1
        ? `Bạn vừa mở khoá huy hiệu "${titles[0]}"! 🏆`
        : `Bạn vừa mở khoá ${titles.length} huy hiệu mới: ${titles.join(", ")}! 🏆`;

    await sendToToken(token, "Thành tích mới! 🏆", body, {
      type: "achievement",
      badgeIds: newBadges.join(","),
    });
  },
);

// ---------- 4. THÔNG BÁO CẬP NHẬT APP (broadcast qua topic) ----------
//
// Giáo viên/Admin tạo 1 document mới trong collection `announcements`
// (xem firestore.rules) với 2 field { title, body } — function này tự
// gửi tới TOÀN BỘ thiết bị đã đăng ký topic 'app_updates' (xem
// NotificationService.registerForStudent / setUpdateTopicEnabled).
exports.onAnnouncementCreated = onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {
    const data = event.data.data();
    if (!data || !data.title || !data.body) {
      logger.warn("Announcement thiếu title/body — bỏ qua.");
      return;
    }
    try {
      await messaging.send({
        topic: "app_updates",
        notification: { title: data.title, body: data.body },
        data: { type: "update" },
        android: { priority: "high" },
      });
    } catch (err) {
      logger.error("Gửi thông báo cập nhật app thất bại", err);
    }
  },
);