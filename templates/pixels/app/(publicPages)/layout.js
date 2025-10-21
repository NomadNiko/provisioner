import Footer from "@/components/Footer";
import Navbar from "@/components/Navbar";

export const metadata = {
    title: "pixels - PrebuiltUI",
    description: "pixels is a next.js template for building modern, fast, and secure saas applications.",
};

export default function Layout({ children }) {
    return (
        <>
            <Navbar />
            {children}
            <Footer />
        </>
    );
}