// Failover chain tests. The whole point of this chain is that it only ever runs while
// something is already broken, so it is the code least likely to be exercised by hand and
// the most likely to rot silently — it gets tests, not a comment promising it works.
//
// Env has to be set before the module is imported: GEMINI_KEY_POOL / GROQ_KEY_POOL are
// module-level consts, so a dynamic import after Deno.env.set is the only way to observe
// a configured pool.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("ZAD_PROVIDER", "gemini");
Deno.env.set("ZAD_API_KEY_1", "k1");
Deno.env.set("ZAD_API_KEY_2", "k2");
Deno.env.set("GROQ_API_KEY_1", "groq1");
Deno.env.set("GROQ_API_KEY_2", "groq2");
Deno.env.set("ZAD_MODEL_FALLBACKS", "model-b,model-c");

const { callModel, fitForGroq, setModelCooldownMsForTests } = await import("./callModel.ts");
// الاختبارات بتشغّل موديلات فاشلة ورا بعض؛ الانتظار مقفول إلا في الاختبار بتاعه.
setModelCooldownMsForTests(0);

const BASE = {
  model: "model-a",
  system: "s",
  tools: [{ name: "t", description: "d", input_schema: { type: "object", properties: {} } }],
  history: [{ role: "user" as const, text: "hi" }],
};

/** Records every outbound call so a test can assert on the order models were tried in. */
function stubFetch(handler: (url: string, body: any) => Response) {
  const calls: Array<{ url: string; body: any }> = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    calls.push({ url, body });
    return Promise.resolve(handler(url, body));
  }) as typeof fetch;
  return { calls, restore: () => { globalThis.fetch = original; } };
}

const quota429 = () =>
  new Response(
    JSON.stringify({
      error: {
        code: 429,
        details: [{
          "@type": "type.googleapis.com/google.rpc.QuotaFailure",
          violations: [{ quotaId: "GenerateRequestsPerDayPerProjectPerModel-FreeTier", quotaValue: "20" }],
        }],
      },
    }),
    { status: 429 },
  );

const overloaded503 = () =>
  new Response(JSON.stringify({ error: { code: 503, status: "UNAVAILABLE" } }), { status: 503 });

const geminiOk = () =>
  new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: "تمام" }] } }],
      usageMetadata: { promptTokenCount: 5, candidatesTokenCount: 2 },
    }),
    { status: 200 },
  );

function modelOf(url: string): string {
  return url.match(/models\/([^:]+):/)?.[1] ?? "";
}

Deno.test("429 على كل المفاتيح بينتقل للموديل اللي بعده مش بيفشل", async () => {
  const s = stubFetch((url) => (modelOf(url) === "model-a" ? quota429() : geminiOk()));
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "تمام");
    // كل مفاتيح model-a اتجرّبت الأول، وبعدين model-b نجح من أول مفتاح
    const tried = s.calls.map((c) => modelOf(c.url));
    assertEquals(tried.filter((m) => m === "model-a").length, 2, "لازم يدوّر على المفتاحين");
    assertEquals(tried[tried.length - 1], "model-b");
  } finally {
    s.restore();
  }
});

Deno.test("503 بينتقل للموديل التالي من غير ما يحرق باقي المفاتيح", async () => {
  const s = stubFetch((url) => (modelOf(url) === "model-a" ? overloaded503() : geminiOk()));
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "تمام");
    const tried = s.calls.map((c) => modelOf(c.url));
    // مفتاح واحد بس على model-a: الـ 503 حِمل على الموديل، مش throttling على المفتاح
    assertEquals(tried.filter((m) => m === "model-a").length, 1);
    assertEquals(tried[tried.length - 1], "model-b");
  } finally {
    s.restore();
  }
});

Deno.test("موديل معلّق (timeout) بينتقل للي بعده فوراً — مش ٣ إعادات على نفسه", async () => {
  const original = globalThis.fetch;
  const tried: string[] = [];
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = String(input);
    tried.push(modelOf(url));
    if (modelOf(url) === "model-a") {
      return Promise.reject(new DOMException("Signal timed out.", "TimeoutError"));
    }
    return Promise.resolve(geminiOk());
  }) as typeof fetch;
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "تمام");
    assertEquals(tried, ["model-a", "model-b"]);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("موديل وقع بيتعدّى في الرسالة اللي بعدها — مابنبداش بيه تاني", async () => {
  setModelCooldownMsForTests(60_000);
  const s = stubFetch((url) => (modelOf(url) === "model-a" ? overloaded503() : geminiOk()));
  try {
    await callModel({ ...BASE });
    const afterFirst = s.calls.length;
    await callModel({ ...BASE });
    assertEquals(s.calls.slice(afterFirst).map((c) => modelOf(c.url)), ["model-b"]);
  } finally {
    s.restore();
    setModelCooldownMsForTests(0);
  }
});

Deno.test("404 (موديل اتسحب) و500 بينقلوا للموديل اللي بعده", async () => {
  for (const status of [404, 500]) {
    const s = stubFetch((url) => (modelOf(url) === "model-a" ? new Response("gone", { status }) : geminiOk()));
    try {
      const reply = await callModel({ ...BASE });
      assertEquals(reply.text, "تمام");
      assertEquals(s.calls.map((c) => modelOf(c.url)), ["model-a", "model-b"], `status ${status}`);
    } finally {
      s.restore();
    }
  }
});

Deno.test("سلسلة جيميناي كلها مقفولة → بيقع على Groq", async () => {
  const s = stubFetch((url) => {
    if (url.includes("api.groq.com")) {
      return new Response(
        JSON.stringify({
          choices: [{ message: { content: "من جروك", tool_calls: [] } }],
          usage: { prompt_tokens: 3, completion_tokens: 1 },
        }),
        { status: 200 },
      );
    }
    return quota429();
  });
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "من جروك");
    const groqCall = s.calls.find((c) => c.url.includes("api.groq.com"));
    assert(groqCall, "المفروض ينادي جروك");
    assertEquals(groqCall!.body.model, "openai/gpt-oss-120b");
    // الأدوات لازم توصل جروك كمان، وإلا الـ agent loop بيرجع نص بس ومبينفّذش حاجة
    assertEquals(groqCall!.body.tools.length, 1);
  } finally {
    s.restore();
  }
});

Deno.test("التفكير مقفول افتراضياً ومفتوح لما يتطلب صراحة", async () => {
  const s = stubFetch(() => geminiOk());
  try {
    await callModel({ ...BASE });
    assertEquals(s.calls[0].body.generationConfig.thinkingConfig, { thinkingBudget: 0 });
    await callModel({ ...BASE, thinking: true });
    assertEquals(s.calls[1].body.generationConfig.thinkingConfig, undefined);
  } finally {
    s.restore();
  }
});

Deno.test("400 إعدادات غلط بيفضل يفشل فوراً — مابيتخبّاش وراء السلسلة", async () => {
  const s = stubFetch(() => new Response("bad request", { status: 400 }));
  try {
    let threw = false;
    try {
      await callModel({ ...BASE });
    } catch (e) {
      threw = true;
      assert(String(e).includes("400"), `المفروض يفضح الـ 400، جه: ${e}`);
    }
    assert(threw, "400 المفروض يرمي مش يكمّل السلسلة");
    // محاولتين بالظبط على model-a: الأولى بـ thinkingConfig، والتانية من غيره بعد ما
    // الـ 400 خلّى الموديل يتعلّم إنه مش بيقبل الحقل. وبعدين بيرمي — مفيش انتقال
    // لموديل تاني، لأن خطأ إعدادات بيتصلح مش بيتلف حواليه.
    assertEquals(s.calls.map((c) => modelOf(c.url)), ["model-a", "model-a"]);
    assertEquals(s.calls[0].body.generationConfig.thinkingConfig, { thinkingBudget: 0 });
    assertEquals(s.calls[1].body.generationConfig.thinkingConfig, undefined);
  } finally {
    s.restore();
  }
});

Deno.test("موديل بيرفض thinkingConfig بيتعاد عليه من غيره وينجح", async () => {
  // بالظبط سلوك gemini-3.5-flash-lite: 400 لما thinkingConfig موجود، 200 من غيره.
  const s = stubFetch((_url, body) =>
    body?.generationConfig?.thinkingConfig ? new Response("invalid argument", { status: 400 }) : geminiOk()
  );
  try {
    const reply = await callModel({ ...BASE, model: "picky-model" });
    assertEquals(reply.text, "تمام");
    assertEquals(s.calls.length, 2, "محاولة بالحقل ومحاولة من غيره");

    // والمرة الجاية على نفس الموديل بيبعت من غير الحقل من أول مرة — الدرس اتحفظ.
    const before = s.calls.length;
    await callModel({ ...BASE, model: "picky-model" });
    assertEquals(s.calls.length - before, 1, "مفيش هدر محاولة تانية بعد ما اتعلّم");
    assertEquals(s.calls[before].body.generationConfig.thinkingConfig, undefined);
  } finally {
    s.restore();
  }
});

Deno.test("طلب جروك بيتقص لحد ما يدخل تحت حد الـ ٨٠٠٠ توكن — مابيبعتش ١٠٥٥٠", () => {
  const tool = (i: number) => ({
    name: `tool_${i}`,
    description: "أداة بتعمل حاجة مهمة للعميل ".repeat(8),
    input_schema: { type: "object", properties: { amount: { type: "number", description: "المبلغ بالعملة المحلية" } } },
  });
  const big = {
    model: "m",
    system: "قواعد أساسية في الأول. " + "سياق طويل عن العميل ومصاريفه ومواعيده. ".repeat(900) + " آخر سطر: بيانات العميل.",
    tools: Array.from({ length: 41 }, (_, i) => tool(i)),
    history: Array.from({ length: 10 }, (_, i) => ({ role: "user" as const, text: `رسالة ${i}` })),
    maxTokens: 1200,
  };
  const fit = fitForGroq(big);
  const estTokens = Math.ceil((fit.system.length + JSON.stringify(fit.tools).length + JSON.stringify(fit.history).length) / 2.5) +
    (fit.maxTokens ?? 0);
  assert(estTokens <= 7000, `المقدّر ${estTokens} لازم يبقى تحت الحد`);
  // الأدوات بترتيبها: أول أداة (الأهم) موجودة دايماً، والتقطيع من الآخر.
  assertEquals(fit.tools[0].name, "tool_0");
  assert(fit.tools.length < 41 && fit.tools.length > 0);
  // أول السيستم (القواعد) وآخره (سياق العميل) فاضلين.
  assert(fit.system.startsWith("قواعد أساسية"));
  assert(fit.system.endsWith("بيانات العميل."));
  // آخر رسالة من العميل ماتتشالش.
  assertEquals(fit.history.at(-1), { role: "user", text: "رسالة 9" });
  // طلب صغير مايتلمسش غير max_tokens.
  const small = fitForGroq({ ...big, system: "قصير", tools: [tool(1)], history: [{ role: "user", text: "هاي" }] });
  assertEquals(small.system, "قصير");
  assertEquals(small.tools.length, 1);
});

Deno.test("مفتاح Groq مرفوض (401) بيتعدّى للمفتاح التاني بدل ما رجل Groq كلها تفشل", async () => {
  const original = globalThis.fetch;
  const groqKeysUsed: string[] = [];
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.includes("api.groq.com")) {
      const auth = String((init?.headers as Record<string, string>)?.authorization ?? "");
      groqKeysUsed.push(auth);
      if (auth.endsWith("groq1")) return Promise.resolve(new Response("invalid api key", { status: 401 }));
      return Promise.resolve(new Response(JSON.stringify({ choices: [{ message: { content: "من المفتاح التاني", tool_calls: [] } }], usage: {} }), { status: 200 }));
    }
    return Promise.resolve(quota429());
  }) as typeof fetch;
  try {
    const first = await callModel({ ...BASE });
    const second = await callModel({ ...BASE });
    assertEquals(first.text, "من المفتاح التاني");
    assertEquals(second.text, "من المفتاح التاني");
    // المفتاح المرفوض اتجرب مرة واحدة بس، وبعدها بيتعدّى
    assertEquals(groqKeysUsed.filter((a) => a.endsWith("groq1")).length <= 1, true);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("جيميناي بطيء: بعد ميزانية السلسلة بيروح لجروك بدل ما يلف على كل الموديلات", async () => {
  const { setGeminiBudgetMsForTests } = await import("./callModel.ts");
  setGeminiBudgetMsForTests(3_000);
  const original = globalThis.fetch;
  const tried: string[] = [];
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (url.includes("api.groq.com")) {
      tried.push("groq");
      return Promise.resolve(
        new Response(
          JSON.stringify({ choices: [{ message: { content: "من جروك", tool_calls: [] } }], usage: {} }),
          { status: 200 },
        ),
      );
    }
    tried.push(modelOf(url));
    // موديل معلّق: مابيردش لحد ما المهلة تقطعه.
    return new Promise<Response>((_, reject) => {
      init?.signal?.addEventListener("abort", () => reject(init.signal!.reason));
    });
  }) as typeof fetch;
  const started = Date.now();
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "من جروك");
    // موديل واحد بس لحق يتجرّب (مهلته = الميزانية كلها)، وبعدين جروك — مش a ثم b ثم c.
    assertEquals(tried, ["model-a", "groq"]);
    assert(Date.now() - started < 6_000, `took ${Date.now() - started}ms`);
  } finally {
    globalThis.fetch = original;
    setGeminiBudgetMsForTests(null);
  }
});

Deno.test("كل موديلات جيميناي في الانتظار → جروك على طول من غير ما يلمس جيميناي", async () => {
  setModelCooldownMsForTests(60_000);
  const s = stubFetch((url) => {
    if (url.includes("api.groq.com")) {
      return new Response(
        JSON.stringify({ choices: [{ message: { content: "من جروك", tool_calls: [] } }], usage: {} }),
        { status: 200 },
      );
    }
    return overloaded503();
  });
  try {
    await callModel({ ...BASE }); // الأولى: a,b,c كلهم 503 → جروك، وكلهم يدخلوا الانتظار
    const afterFirst = s.calls.length;
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "من جروك");
    assertEquals(s.calls.slice(afterFirst).map((c) => c.url.includes("api.groq.com") ? "groq" : modelOf(c.url)), ["groq"]);
  } finally {
    s.restore();
    setModelCooldownMsForTests(0);
  }
});
