import Bento from "@/components/Bento";
import Download from "@/components/Download";
import Footer from "@/components/Footer";
import Hero from "@/components/Hero";
import Manifesto from "@/components/Manifesto";
import Marquee from "@/components/Marquee";
import Nav from "@/components/Nav";
import Story from "@/components/Story";

export default function Home() {
  return (
    <>
      <Nav />
      <main id="top">
        <Hero />
        <Marquee />
        <Story />
        <Manifesto />
        <Bento />
        <Download />
      </main>
      <Footer />
    </>
  );
}
