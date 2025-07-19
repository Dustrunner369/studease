
export default {
  bootstrap: () => import('./main.server.mjs').then(m => m.default),
  inlineCriticalCss: false,
  baseHref: '/',
  locale: undefined,
  routes: undefined,
  entryPointToBrowserMapping: {},
  assets: {
    'index.csr.html': {size: 511, hash: '36fbbc2b921f34f13e0f9d7fd99283e21687eee6a2f8fb82d0f5c212d2ef14d9', text: () => import('./assets-chunks/index_csr_html.mjs').then(m => m.default)},
    'index.server.html': {size: 1051, hash: 'f90499264c8f483c201ae384771844cbb2999ae3f918bb31e706be4fbf2d56c6', text: () => import('./assets-chunks/index_server_html.mjs').then(m => m.default)}
  },
};
