import { Poppins } from "next/font/google";
import "./globals.css";
import { ThemeContextProvider } from "@/context/ThemeContext";

const poppins = Poppins({
    variable: "--font-poppins",
    subsets: ["latin"],
    weight: ["400", "500", "600", "700"],
});

export const metadata = {
    title: "Landing - PrebuiltUI",
    description: "Landing is a SaaS template for developers to build SaaS applications.",
};

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <body>
                <ThemeContextProvider>
                    {children}
                </ThemeContextProvider>
            </body>
        </html>
    );
}