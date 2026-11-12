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
    <section aria-label="اللي زاد بيشيله عنك" className="relative overflow-hidden bg-emerald py-6">
      <div className="marquee-track flex w-max gap-10 whitespace-nowrap">
        {row.map((t, i) => (
          <span key={i} className="display flex items-center gap-10 text-4xl text-white md:text-6xl">
            {t}
            <span aria-hidden className="h-3 w-3 rotate-45 rounded-[3px] bg-mint-glow" />
          </span>
        ))}
      </div>
    </section>
  );
}
