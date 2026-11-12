const items = [
  "رسايل البنك",
  "مسح الفواتير",
  "قائمة التسوق",
  "مواعيد الدوا",
  "شيف زاد",
  "مهام الأولاد",
  "أسعار السوق",
  "ميزانية الشهر",
  "شات العيلة",
];

// The page's single marquee: breadth of what Zad covers, none of it needs a click.
export default function Marquee() {
  const row = [...items, ...items];
  return (
    <section aria-label="اللي زاد بيشيله عنك" className="relative overflow-hidden border-y border-line py-8">
      <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-32 bg-gradient-to-r from-ink to-transparent" />
      <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-32 bg-gradient-to-l from-ink to-transparent" />
      <div className="marquee-track flex w-max gap-12 whitespace-nowrap">
        {row.map((t, i) => (
          <span key={i} className="flex items-center gap-12 text-3xl font-extrabold text-bone/80 md:text-5xl">
            {t}
            <span aria-hidden className="h-2 w-2 rotate-45 bg-carrot" />
          </span>
        ))}
      </div>
    </section>
  );
}
