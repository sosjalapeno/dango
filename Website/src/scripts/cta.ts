import gsap from 'gsap';

export function initHeroCta() {
  const shine = document.querySelector<HTMLElement>('.hero-cta__shine');
  if (!shine) return;

  gsap.to(shine, {
    x: '240%',
    duration: 1.8,
    ease: 'power2.inOut',
    repeat: -1,
    repeatDelay: 2.2,
  });
}
