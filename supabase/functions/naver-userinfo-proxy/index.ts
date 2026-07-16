import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Supabase Auth(GoTrue)가 네이버 access token을 Authorization 헤더에 담아 호출.
// 네이버 응답은 { response: { id, email, name, ... } } 형태로 중첩돼 있어
// Supabase가 기대하는 평평한 클레임(email, sub, name)으로 재포장한다.
Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing_authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const naverRes = await fetch("https://openapi.naver.com/v1/nid/me", {
    headers: { Authorization: authHeader },
  });

  if (!naverRes.ok) {
    return new Response(
      JSON.stringify({
        error: "naver_userinfo_failed",
        status: naverRes.status,
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  const data = await naverRes.json();
  const profile = data.response ?? {};

  return new Response(
    JSON.stringify({
      sub: profile.id,
      email: profile.email,
      email_verified: true,
      name: profile.name ?? profile.nickname,
      picture: profile.profile_image,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
