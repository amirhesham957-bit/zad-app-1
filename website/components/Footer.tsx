import Image from "next/image";
import { PLAY_STORE_URL } from "@/lib/links";

export default function Footer() {
  return (
    <footer className="mx-auto max-w-[1400px] px-4 pb-12 md:px-10">
      <div className="flex flex-col gap-10 border-t border-line pt-12 md:flex-row md:items-end md:justify-between">
        <div>
          <div className="flex items-center gap-3">
            <Image src="/carrot_logo.svg" alt="" width={40} height={40} />
            <span className="text-3xl font-black">زاد</span>
          </div>
          <p className="mt-4 max-w-[36ch] text-mist">مساعد البيت الذكي: مصاريف، مطبخ، دوا، وعيلة.</p>
        </div>

        <div className="flex flex-col gap-2 text-sm text-dim md:items-end">
          <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer" className="hover:text-bone">
            Google Play
          </a>
          <span>App Store قريباً</span>
        </div>
      </div>

      <div className="mt-16 overflow-hidden">
        <p
          aria-hidden
          className="select-none text-center text-[22vw] font-black leading-[0.85] tracking-tighter text-transparent [-webkit-text-stroke:1px_rgb(238_242_236/0.12)]"
        >
          Astra Lab
        </p>
      </div>

      <p className="mt-8 text-center text-sm text-dim">
        © 2026 <span className="font-bold text-mist">Astra Lab</span> أسترا لاب. صُنع في مصر.
      </p>
    </footer>
  );
}
