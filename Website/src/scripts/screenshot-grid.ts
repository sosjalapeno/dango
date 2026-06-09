import gsap from 'gsap';
import { Flip } from 'gsap/Flip';

gsap.registerPlugin(Flip);

export function initScreenshotGrid() {
  const products = gsap.utils.toArray<HTMLElement>('.product');
  const gallery = document.querySelector<HTMLElement>('#screenshot-grid');
  if (!products.length || !gallery) return;

  let active = products[0];

  products.forEach((el) => {
    el.addEventListener('mousedown', (event) => event.preventDefault());
    el.addEventListener('click', () => changeGrid(el));
  });

  function changeGrid(el: HTMLElement) {
    if (el === active) return;

    const state = Flip.getState(products);
    active.dataset.grid = el.dataset.grid;
    el.dataset.grid = 'img-1';
    active = el;

    document.body.classList.add('gallery-flipping');

    Flip.from(state, {
      duration: 0.3,
      absolute: true,
      ease: 'power1.inOut',
      onComplete: () => {
        document.body.classList.remove('gallery-flipping');
      },
    });
  }
}
