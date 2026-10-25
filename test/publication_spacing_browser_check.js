// Run as a read-only browser evaluation on a rendered Publications page.
() => {
  const items = [...document.querySelectorAll('.publication-item')];
  if (!items.length) throw new Error('No publication items found');
  for (const node of document.querySelectorAll('.publication-body h3, .publication-authors, .publication-venue')) {
    const style = getComputedStyle(node);
    const ratio = +style.lineHeight.replace('px', '') / +style.fontSize.replace('px', '');
    if (ratio > 1.405 || ratio < 1.395) {
      throw new Error(`${node.className || node.tagName}: expected 1.4 line-height, got ${ratio}`);
    }
  }
  for (const node of document.querySelectorAll('.publication-authors sup')) {
    if (getComputedStyle(node).lineHeight !== '0px') {
      throw new Error('Equal-contribution markers must not expand the author line');
    }
  }
  for (const item of items) {
    const next = item.nextElementSibling;
    if (!next) continue;
    const gap = next.getBoundingClientRect().top - item.getBoundingClientRect().bottom;
    if (gap > 10.5 || gap < 9.5) throw new Error(`Inconsistent item spacing: ${gap}px`);
  }
  if (document.documentElement.scrollWidth > innerWidth) {
    throw new Error('Page overflows horizontally');
  }
  return { passed: true, items: items.length, viewport: innerWidth, lineHeight: 1.4, itemGap: 10 };
}
