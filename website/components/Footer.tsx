import Image from "next/image";
import { EnvelopeSimpleIcon, HeadsetIcon } from "@phosphor-icons/react/dist/ssr";
import { COMPANY, COMPANY_AR, PLAY_STORE_URL, SUPPORT_EMAIL } from "@/lib/links";

export default function Footer() {
  return (
    <footer className="mx-auto max-w-[1400px] px-4 pb-10 md:px-10">
      {/* Support */}
      <section
        id="support"
        aria-labelledby="support-title"
        className="mb-16 grid grid-cols-1 items-center gap-6 rounded-[2rem] border border-hairline bg-mint-50 p-7 md:grid-cols-[auto_1fr_auto] md:p-10"
      >
        <span className="flex h-16 w-16 items-center justify-center rounded-2xl bg-white text-green-700 shadow-card">
          <HeadsetIcon size={34} weight="duotone" />
        </span>
        <div>
          <h2 id="support-title" className="display text-4xl text-emerald md:text-5xl">
            الدعم
          </h2>
          <p className="mt-1 text-slate">لديك سؤال أو واجهتك مشكلة؟ راسلنا وسنرد عليك.</p>
        </div>
        <a
          href={`mailto:${SUPPORT_EMAIL}`}
          className="inline-flex h-14 max-w-full items-center gap-3 justify-self-start rounded-full bg-emerald ps-6 pe-7 font-bold text-white shadow-[0_18px_40px_-14px_rgb(6_78_59/0.7)] transition-transform duration-300 active:scale-[0.98] md:justify-self-end"
        >
          <EnvelopeSimpleIcon size={22} weight="fill" className="shrink-0" />
          <span dir="ltr" className="truncate">
            {SUPPORT_EMAIL}
          </span>
        </a>
      </section>

      <div className="flex flex-col gap-8 border-t border-hairline pt-10 md:flex-row md:items-end md:justify-between">
        <div>
          <div className="flex items-center gap-3">
            <Image src="/carrot_logo.svg" alt="" width={40} height={40} />
            <span className="text-3xl font-black text-emerald">زاد</span>
          </div>
          <p className="mt-3 max-w-[36ch] text-slate">مساعد البيت الذكي: المصاريف والمطبخ والدواء والعائلة.</p>
        </div>

        <div className="flex flex-col gap-2 text-sm font-semibold text-muted md:items-end">
          <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer" className="hover:text-emerald">
            Google Play
          </a>
          <span>App Store قريباً</span>
          <a href={`mailto:${SUPPORT_EMAIL}`} dir="ltr" className="hover:text-emerald">
            {SUPPORT_EMAIL}
          </a>
        </div>
      </div>

      <p
        aria-hidden
        dir="ltr"
        className="mt-12 select-none text-center text-[17vw] font-black leading-[0.85] tracking-tighter text-mint-100"
      >
        {COMPANY}
      </p>

      <p className="mt-6 text-center text-sm text-muted">
        © 2026 <span className="font-bold text-emerald">{COMPANY}</span> {COMPANY_AR}
      </p>
    </footer>
  );
}
