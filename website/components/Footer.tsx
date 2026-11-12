import Image from "next/image";
import { COMPANY, COMPANY_AR, PLAY_STORE_URL } from "@/lib/links";

export default function Footer() {
  return (
    <footer className="mx-auto max-w-[1400px] px-4 pb-10 md:px-10">
      <div className="flex flex-col gap-8 border-t border-hairline pt-10 md:flex-row md:items-end md:justify-between">
        <div>
          <div className="flex items-center gap-3">
            <Image src="/carrot_logo.svg" alt="" width={40} height={40} />
            <span className="text-3xl font-black text-emerald">زاد</span>
          </div>
          <p className="mt-3 max-w-[36ch] text-slate">مساعد البيت الذكي: مصاريف، مطبخ، دوا، وعيلة.</p>
        </div>

        <div className="flex flex-col gap-2 text-sm font-semibold text-muted md:items-end">
          <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer" className="hover:text-emerald">
            Google Play
          </a>
          <span>App Store قريباً</span>
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
        © 2026 <span className="font-bold text-emerald">{COMPANY}</span> {COMPANY_AR}. صُنع في مصر.
      </p>
    </footer>
  );
}
