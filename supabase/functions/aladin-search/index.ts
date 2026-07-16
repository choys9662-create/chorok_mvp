import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const TTB_KEY = Deno.env.get("ALADIN_API_KEY") ?? "";
const BASE_URL = "https://www.aladin.co.kr/ttb/api";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "Authorization, Content-Type, apikey, x-client-info",
};

type Body = {
  query?: string;
  isbn?: string;
  queryType?: "Title" | "Author" | "Keyword";
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (!TTB_KEY) {
    return new Response(
      JSON.stringify({ error: "ALADIN_API_KEY not configured" }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const { query, isbn, queryType } = (await req.json()) as Body;

    let aladinUrl: URL;

    if (isbn) {
      aladinUrl = new URL(`${BASE_URL}/ItemLookUp.aspx`);
      aladinUrl.searchParams.set("TTBKey", TTB_KEY);
      aladinUrl.searchParams.set("itemIdType", "ISBN13");
      aladinUrl.searchParams.set("ItemId", isbn);
      aladinUrl.searchParams.set("output", "js");
      aladinUrl.searchParams.set("Version", "20131101");
      aladinUrl.searchParams.set("Cover", "MidBig");
      aladinUrl.searchParams.set("OptResult", "subInfo");
    } else if (query) {
      const qt = queryType ?? "Keyword";
      aladinUrl = new URL(`${BASE_URL}/ItemSearch.aspx`);
      aladinUrl.searchParams.set("TTBKey", TTB_KEY);
      aladinUrl.searchParams.set("Query", query);
      aladinUrl.searchParams.set("QueryType", qt);
      aladinUrl.searchParams.set("MaxResults", "20");
      aladinUrl.searchParams.set("start", "1");
      aladinUrl.searchParams.set("SearchTarget", "Book");
      aladinUrl.searchParams.set("output", "js");
      aladinUrl.searchParams.set("Version", "20131101");
      aladinUrl.searchParams.set("Cover", "MidBig");
      aladinUrl.searchParams.set("OptResult", "subInfo");
    } else {
      return new Response(JSON.stringify({ error: "query or isbn required" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const res = await fetch(aladinUrl.toString());
    const text = await res.text();
    const body = text.startsWith("﻿") ? text.slice(1) : text;

    return new Response(body, {
      headers: {
        ...CORS_HEADERS,
        "Content-Type": "application/json; charset=utf-8",
      },
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
