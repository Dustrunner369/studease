
export default {
  bootstrap: () => import('./main.server.mjs').then(m => m.default),
  inlineCriticalCss: true,
  baseHref: '/',
  locale: undefined,
  routes: undefined,
  entryPointToBrowserMapping: {},
  assets: {
    'index.csr.html': {size: 1816, hash: '362651ee8da4da5e59a025634e82d51888c096e2d6d71502591d43f4fbae238e', text: () => import('./assets-chunks/index_csr_html.mjs').then(m => m.default)},
    'index.server.html': {size: 1365, hash: '8932a3be72504f2f31c1240398d83493f48cc8bf28e5ceebc49b9976cb50856a', text: () => import('./assets-chunks/index_server_html.mjs').then(m => m.default)},
    'styles-NWKEDMF5.css': {size: 19292, hash: 'K99KDEpHFjc', text: () => import('./assets-chunks/styles-NWKEDMF5_css.mjs').then(m => m.default)}
  },
};
