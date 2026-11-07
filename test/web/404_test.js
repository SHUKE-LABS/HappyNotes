'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(
  path.join(__dirname, '../../web/404.html'),
  'utf8',
);
const scriptMatch = html.match(/<script>\s*([\s\S]*?)\s*<\/script>/);

assert.ok(scriptMatch, '404.html should include a redirect script');
assert.match(html, /<h1>Page not found<\/h1>/);

function redirectFor(pathname) {
  let target;
  vm.runInNewContext(scriptMatch[1], {
    window: {
      location: {
        pathname,
        replace(value) {
          target = value;
        },
      },
    },
  });
  return target;
}

for (const id of ['35600', '0', '0012']) {
  assert.equal(redirectFor(`/note/${id}`), `/#/note/${id}`);
}

for (const pathname of [
  '/note',
  '/note/',
  '/note/not-a-number',
  '/note/42/extra',
  '/other',
]) {
  assert.equal(redirectFor(pathname), undefined, pathname);
}

console.log('404 redirect regression cases passed');
