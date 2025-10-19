import Banner from '@/components/banner';
import Footer from '@/components/footer';
import Navbar from '@/components/navbar';

export const metadata = {
    title: 'SlideX - PrebuiltUI',
    description: 'SlideX is a powerful AI-powered platform that allows you to create and edit slides effortlessly with AI.',
    appleWebApp: {
        title: 'SlideX - PrebuiltUI',
    },
};

export default function Layout({ children }) {
    return (
        <>
            <Banner />
            <Navbar />
            {children}
            <Footer />
        </>
    );
}
