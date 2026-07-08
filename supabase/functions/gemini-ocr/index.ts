import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { corsHeaders } from "npm:@supabase/supabase-js@2.95.0/cors";

const allowedMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);
const maxBase64Length = 19 * 1024 * 1024;
const model = Deno.env.get("GEMINI_OCR_MODEL")?.trim() || "gemini-2.5-flash";
const prompt =
  "이 이미지는 책의 한 페이지야. 본문 텍스트를 문단 단위로 구분하고, 각 문단 안의 문장을 정확히 끊어서 반환해. " +
  "결과는 문단의 배열이고, 각 문단은 그 문단에 속한 문장 문자열의 배열이야. " +
  "글자 그대로 전사하고 맞춤법·띄어쓰기·문장부호를 절대 교정하거나 바꾸지 마. " +
  "대화문과 인용부호(\"…\")를 고려해 자연스러운 문장 경계로 나눠. " +
  "페이지 번호·머리말·각주 등 본문 외 요소는 제외해. 본문이 없으면 빈 배열을 반환해.";

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

async function authenticatedUser(req: Request): Promise<boolean> {
  const authorization = req.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization || !supabaseUrl || !anonKey) return false;

  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.getUser();
  return !error && data.user != null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!(await authenticatedUser(req))) {
    return json({ error: "unauthorized" }, 401);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) return json({ error: "server_not_configured" }, 503);

  try {
    const body = await req.json();
    const imageBase64 = body?.imageBase64;
    const mimeType = body?.mimeType;
    if (typeof imageBase64 !== "string" || typeof mimeType !== "string") {
      return json({ error: "invalid_request" }, 400);
    }
    if (!allowedMimeTypes.has(mimeType)) {
      return json({ error: "unsupported_image_type" }, 400);
    }
    if (imageBase64.length === 0 || imageBase64.length > maxBase64Length) {
      return json({ error: "image_too_large" }, 413);
    }

    const requestInit: RequestInit = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inline_data: { mime_type: mimeType, data: imageBase64 } },
          ],
        }],
        generationConfig: {
          temperature: 0,
          responseMimeType: "application/json",
          responseSchema: {
            type: "ARRAY",
            items: {
              type: "ARRAY",
              items: { type: "STRING" },
            },
          },
        },
      }),
    };
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

    // Gemini는 부하 시 503/500을 간헐적으로 뱉는다. 단발 호출이면 그대로 502로
    // 노출되므로 일시 5xx만 짧은 백오프로 재시도해 흡수한다. 429(쿼터)는 재시도 안 함.
    let response = await fetch(url, requestInit);
    for (let attempt = 1; attempt <= 2 && !response.ok; attempt++) {
      if (![500, 502, 503, 504].includes(response.status)) break;
      console.error("gemini_retry", attempt, response.status);
      await new Promise((r) => setTimeout(r, 400 * attempt));
      response = await fetch(url, requestInit);
    }

    if (!response.ok) {
      console.error(
        "gemini_request_failed",
        response.status,
        (await response.text()).slice(0, 500),
      );
      const status = response.status === 429 ? 429 : 502;
      return json({ error: "gemini_request_failed" }, status);
    }

    const payload = await response.json();
    const text = payload?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("")
      .trim();
    if (!text) return json({ error: "empty_response" }, 502);

    const parsed = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return json({ error: "invalid_gemini_response" }, 502);
    }
    const paragraphs = parsed
      .filter(Array.isArray)
      .map((paragraph) =>
        paragraph
          .filter((value): value is string => typeof value === "string")
          .map((value) => value.trim())
          .filter(Boolean)
      )
      .filter((paragraph) => paragraph.length > 0);
    // sentences(평면)는 문단 정보가 없는 구버전 앱 호환용으로 함께 반환한다.
    return json({ sentences: paragraphs.flat(), paragraphs });
  } catch {
    return json({ error: "internal_error" }, 500);
  }
});
