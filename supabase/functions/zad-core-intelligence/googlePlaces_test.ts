import { assertEquals } from "jsr:@std/assert@1";
import { googleNearby, googleNearbyAny, googlePlacesKeys, parseNearby } from "./googlePlaces.ts";

Deno.test("googlePlacesKeys: every set key, PLACES first, no duplicates", () => {
  const env: Record<string, string> = { GOOGLE_MAPS_API_KEY: "maps", GOOGLE_PLACES_API_KEY: " places ", GOOGLE_API_KEY: "maps" };
  assertEquals(googlePlacesKeys((n) => env[n]), [
    { name: "GOOGLE_PLACES_API_KEY", key: "places" },
    { name: "GOOGLE_MAPS_API_KEY", key: "maps" },
  ]);
  assertEquals(googlePlacesKeys(() => undefined), []);
  assertEquals(googlePlacesKeys((n) => (n === "GOOGLE_MAPS_API_KEY" ? "  " : undefined)), []);
});

Deno.test("googleNearbyAny: a refused key steps to the next — the 2026-09-29 case", async () => {
  const seen: string[] = [];
  const fake = ((_url: string, init: RequestInit) => {
    const key = new Headers(init.headers).get("X-Goog-Api-Key")!;
    seen.push(key);
    return Promise.resolve(key === "blocked"
      ? new Response("Requests to this API ... are blocked.", { status: 403 })
      : new Response(JSON.stringify({ places: [{ displayName: { text: "كارفور" }, location: { latitude: 30, longitude: 31 } }] }), { status: 200 }));
  }) as unknown as typeof fetch;
  const out = await googleNearbyAny(fake, [{ name: "A", key: "blocked" }, { name: "B", key: "good" }], { lat: 30, lon: 31, tag: "supermarket", radius: 3000 });
  assertEquals(seen, ["blocked", "good"]);
  assertEquals(out?.name, "B");
  assertEquals(out?.places[0].name, "كارفور");
  assertEquals(await googleNearbyAny(fake, [{ name: "A", key: "blocked" }], { lat: 30, lon: 31, tag: "supermarket", radius: 3000 }), null);
});

Deno.test("parseNearby keeps named places with a location, nearest first", () => {
  const places = parseNearby({
    places: [
      { displayName: { text: "كارفور" }, location: { latitude: 30.05, longitude: 31.2357 } },
      { displayName: { text: "  " }, location: { latitude: 30.045, longitude: 31.2357 } },
      { displayName: { text: "خير زمان" }, location: { latitude: 30.045, longitude: 31.2357 } },
      { displayName: { text: "بلا مكان" } },
    ],
  }, 30.0444, 31.2357);
  assertEquals(places.map((p) => p.name), ["خير زمان", "كارفور"]);
  assertEquals(places[0].distance_meters < 100, true);
  assertEquals(parseNearby({}, 0, 0), []);
  assertEquals(parseNearby(null, 0, 0), []);
});

Deno.test("googleNearby asks for two fields only and the tag's types", async () => {
  let sent: { headers: Headers; body: Record<string, unknown> } | undefined;
  const fake = ((_url: string, init: RequestInit) => {
    sent = { headers: new Headers(init.headers), body: JSON.parse(String(init.body)) };
    return Promise.resolve(new Response(JSON.stringify({ places: [] }), { status: 200 }));
  }) as unknown as typeof fetch;
  const out = await googleNearby(fake, "k", { lat: 30, lon: 31, tag: "pharmacy", radius: 3000 });
  assertEquals(out, []);
  assertEquals(sent?.headers.get("X-Goog-FieldMask"), "places.displayName,places.location");
  assertEquals(sent?.body.includedTypes, ["pharmacy", "drugstore"]);
});

Deno.test("googleNearby says null on refusal or an unknown tag, so the next source runs", async () => {
  const refuse = (() => Promise.resolve(new Response("PERMISSION_DENIED", { status: 403 }))) as unknown as typeof fetch;
  assertEquals(await googleNearby(refuse, "k", { lat: 30, lon: 31, tag: "supermarket", radius: 3000 }), null);
  assertEquals(await googleNearby(refuse, "k", { lat: 30, lon: 31, tag: "cinema", radius: 3000 }), null);
});
