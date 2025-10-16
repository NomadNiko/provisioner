import { Poppins } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/navbar";
import LenisScroll from "@/components/lenis-scroll";
import Footer from "@/components/footer";

const poppins = Poppins({
    subsets: ["latin"],
    variable: "--font-poppins",
    weight: ["400", "500", "600", "700"],
    display: "swap",
});

export const metadata = {
    title: "agentix - PrebuiltUI",
    description: "Agentix is a prebuilt UI template for AI-powered SaaS applications.",
    appleWebApp: {
        title: "agentix",
    },
};

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <body>
                <LenisScroll />
                <Navbar />
                {children}
                <Footer />
            </body>
        </html>
    );
}