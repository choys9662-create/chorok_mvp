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
  "이 이미지는 책의 한 페이지야. 본문 텍스트를 문장 단위로 정확히 끊어서 각 문장을 배열의 한 원소로 반환해. " +
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

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
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
              items: { type: "STRING" },
            },
          },
        }),
      },
    );

    if (!response.ok) {
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
    const sentences = parsed
      .filter((value): value is string => typeof value === "string")
      .map((value) => value.trim())
      .filter(Boolean);
    return json({ sentences });
  } catch {
    return json({ error: "internal_error" }, 500);
  }
});
