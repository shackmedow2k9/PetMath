// Worker thay thế Cloud Function askMathTutor (Firebase Blaze) bằng
// Cloudflare Workers (gói Free — không cần thẻ Visa).
//
// Nhiệm vụ DUY NHẤT của Worker này: (1) xác nhận người gọi là user Firebase
// đã đăng nhập thật (qua Identity Toolkit REST API — miễn phí, không cần
// Cloud Functions/Blaze), rồi (2) gọi Groq bằng API key giữ bí mật ở đây.
//
// Toàn bộ logic nghiệp vụ (đã nộp bài chưa, trừ Gem, đọc đáp án chuẩn từ
// Firestore) được chuyển hẳn về app Flutter — xem hàm askMathTutor mới
// trong lib/services/firestore_service.dart.

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }
    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }

    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json({ error: "invalid_json" }, 400);
    }

    const idToken = String(body?.idToken || "");
    const mode = String(body?.mode || "");
    const systemInstruction = String(body?.systemInstruction || "").slice(0, 2000);
    const prompt = String(body?.prompt || "").slice(0, 16000);

    if (!idToken || !systemInstruction || !prompt) {
      return json({ error: "missing_fields" }, 400);
    }

    // Chặn cứng độ dài trả lời — dù system prompt có yêu cầu ngắn gọn,
    // model đôi khi vẫn "lỡ tay" viết dài. "hint" (gợi ý từng bước) cần
    // ngắn hơn "answer" (giải đầy đủ + đáp án).
    const maxTokens = mode === "hint" ? 350 : 700;

    // 1) Xác thực idToken bằng Identity Toolkit (miễn phí, thuộc Firebase
    // Authentication — KHÔNG cần Blaze). Nếu token giả/hết hạn thì Google
    // trả lỗi và ta chặn ngay, tránh bị người lạ spam Groq free-tier.
    const lookupRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${env.FIREBASE_WEB_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken }),
      },
    );
    if (!lookupRes.ok) {
      return json({ error: "invalid_token" }, 401);
    }
    const lookupData = await lookupRes.json();
    const uid = lookupData?.users?.[0]?.localId;
    if (!uid) {
      return json({ error: "invalid_token" }, 401);
    }

    // 2) Gọi Groq (free, không cần thẻ) — model tương thích chuẩn OpenAI.
    let groqRes;
    try {
      groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${env.GROQ_API_KEY}`,
        },
        body: JSON.stringify({
          model: "openai/gpt-oss-120b",
          temperature: 0.4,
          max_tokens: maxTokens,
          messages: [
            { role: "system", content: systemInstruction },
            { role: "user", content: prompt },
          ],
        }),
      });
    } catch (e) {
      return json({ error: "groq_unreachable" }, 502);
    }

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      return json({ error: "groq_error", detail: errText }, 502);
    }

    const data = await groqRes.json();
    const text = data?.choices?.[0]?.message?.content?.trim();
    if (!text) {
      return json({ error: "empty_response" }, 502);
    }

    return json({ text });
  },
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}