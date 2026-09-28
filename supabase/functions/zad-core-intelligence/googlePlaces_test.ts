import { assertEquals } from "jsr:@std/assert@1";
import { googleNearby, googlePlacesKey, parseNearby } from "./googlePlaces.ts";

Deno.test("googlePlacesKey takes the first name that is set", () => {
  const env: Record<string, string> = { GOOGLE_API_KEY: "b", GOOGLE_PLACES_API_KEY: " a " };
  assertEquals(googlePlacesKey((n) => env[n]), "a");
  assertEquals(googlePlacesKey(() => undefined), undefined);
  assertEquals(googlePlacesKey((n) => (n === "GOOGLE_MAPS_API_KEY" ? "  " : undefined)), undefined);
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
