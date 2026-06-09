import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Flip } from 'gsap/Flip';
import { ExpoScaleEase } from 'gsap/EasePack';

gsap.registerPlugin(ScrollTrigger, Flip, ExpoScaleEase);

let flipCtx: gsap.Context | undefined;

function createTween() {
  const galleryElement = document.querySelector<HTMLElement>('#gallery-8');
  if (!galleryElement) return;

  const galleryItems = galleryElement.querySelectorAll('.gallery__item');
  const galleryWrap = galleryElement.parentElement;
  if (!galleryWrap) return;

  flipCtx?.revert();
  galleryElement.classList.remove('gallery--final');

  flipCtx = gsap.context(() => {
    galleryElement.classList.add('gallery--final');
    const flipState = Flip.getState(galleryItems);
    galleryElement.classList.remove('gallery--final');

    const flip = Flip.to(flipState, {
      simple: true,
      ease: 'expoScale(1,5)',
    });

    const tl = gsap.timeline({
      scrollTrigger: {
        trigger: galleryElement,
        start: 'center center',
        end: '+=100%',
        scrub: true,
        pin: galleryWrap,
        invalidateOnRefresh: true,
      },
    });

    tl.add(flip);

    return () => {
      gsap.set(galleryItems, { clearProps: 'all' });
    };
  });
}

export function initBento() {
  createTween();
  window.addEventListener('resize', () => {
    createTween();
    ScrollTrigger.refresh();
  });
}
