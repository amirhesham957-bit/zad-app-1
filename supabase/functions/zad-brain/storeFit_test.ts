import { assertEquals } from "jsr:@std/assert@1";
import { itemSection, itemsForStore, storeSpecialty } from "./storeFit.ts";

// The owner's list on 2026-10-10 (zad_shopping_list, not purchased).
const LIST = [
  "شامبو", "سكر", "لحمة", "فراخ", "بيض", "Cream Cheese", "طماطم", "بصل", "خبز بلدي طازج", "لبن", "بلح",
  "زبيب ايراني", "طحينة سمسم سايب", "برانش توست القمح الكامل", "ليمون", "مرتديلا لحم مقطعة", "صابون سائل",
];

Deno.test("the shops the owner was told about read as what they are", () => {
  assertEquals(storeSpecialty("عطارة الرحمة"), "spices");
  assertEquals(storeSpecialty("مجمدات الأسمر"), "meat");
  assertEquals(storeSpecialty("جزارة الحاج محمد"), "meat");
  assertEquals(storeSpecialty("خضار وفاكهة أبو علي"), "produce");
  assertEquals(storeSpecialty("مخبز الشامي"), "bakery");
  assertEquals(storeSpecialty("كارفور"), "general");
  assertEquals(storeSpecialty("سوبر ماركت الفراعنة"), "general");
  assertEquals(storeSpecialty("هايبر وان"), "general");
});

Deno.test("the spice shop gets the spice-shop things, not the shampoo", () => {
  assertEquals(itemsForStore("عطارة الرحمة", LIST), ["زبيب ايراني", "طحينة سمسم سايب"]);
});

Deno.test("the frozen-meat shop gets meat and chicken", () => {
  assertEquals(itemsForStore("مجمدات الأسمر", LIST), ["لحمة", "فراخ", "مرتديلا لحم مقطعة"]);
});

Deno.test("the greengrocer and the bakery get theirs", () => {
  assertEquals(itemsForStore("خضار وفاكهة أبو علي", LIST), ["طماطم", "بصل", "بلح", "ليمون"]);
  assertEquals(itemsForStore("مخبز الشامي", LIST), ["خبز بلدي طازج", "برانش توست القمح الكامل"]);
});

Deno.test("a supermarket still gets the whole list", () => {
  assertEquals(itemsForStore("كارفور", LIST), LIST);
});

Deno.test("an item with no telling name follows its pantry category", () => {
  assertEquals(itemSection("أوراك متبلة"), "meat");
  assertEquals(itemSection("كيس ٢ كيلو", "اللحوم"), "meat");
  assertEquals(itemSection("كيس ٢ كيلو", "البقالة"), null);
  assertEquals(itemsForStore("مجمدات الأسمر", ["كيس ٢ كيلو"], () => "اللحوم"), ["كيس ٢ كيلو"]);
});

Deno.test("black pepper is a spice even though pepper is produce", () => {
  assertEquals(itemSection("فلفل أسود مطحون"), "spices");
  assertEquals(itemSection("فلفل رومي"), "produce");
});

Deno.test("nothing that fits = nothing listed, so no message for that shop", () => {
  assertEquals(itemsForStore("عطارة الرحمة", ["شامبو", "بيض", "Cream Cheese"]), []);
});
