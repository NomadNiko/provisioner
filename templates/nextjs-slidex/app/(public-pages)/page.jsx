import CallToActionSection from '@/sections/call-to-action-section';
import FaqSection from '@/sections/faq-section';
import HeroSection from '@/sections/hero-section';
import HowItWorksSection from '@/sections/how-it-works-section';
import MeetOurTeamSection from '@/sections/meet-our-team-section';
import OurPricingSection from '@/sections/our-pricing-section';
import OurTestimonialsSection from '@/sections/our-testimonials-section';

export default function Page() {
    return (
        <main className='px-4'>
            <HeroSection />
            <HowItWorksSection />
            <MeetOurTeamSection />
            <OurTestimonialsSection />
            <OurPricingSection />
            <FaqSection />
            <CallToActionSection />
        </main>
    );
}
