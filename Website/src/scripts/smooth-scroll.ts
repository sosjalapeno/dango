import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ScrollSmoother } from 'gsap/ScrollSmoother';

gsap.registerPlugin(ScrollTrigger, ScrollSmoother);

let smoother: ScrollSmoother | undefined;

export function initSmoothScroll() {
  smoother?.kill();

  smoother = ScrollSmoother.create({
    wrapper: '#smooth-wrapper',
    content: '#smooth-content',
    smooth: 1.15,
    smoothTouch: 0.08,
    effects: false,
  });

  ScrollTrigger.refresh();

  return smoother;
}

export function getSmoothScroll() {
  return smoother;
}
