const XS = {
    resource: typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'XS-Dealerships',
    config: { currency: '$', speedUnit: 'mph', images: false, paint: { presets: [], secondary: true, custom: true } },
    views: {},
};
window.XS = XS;

XS.post = async function (endpoint, payload) {
    try {
        const res = await fetch(`https://${XS.resource}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
        });
        return await res.json();
    } catch (err) {
        return null;
    }
};

XS.el = function (tag, attrs, children) {
    const node = document.createElement(tag);

    for (const [key, value] of Object.entries(attrs || {})) {
        if (value === null || value === undefined || value === false) continue;

        if (key === 'class') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key === 'style' && typeof value === 'object') Object.assign(node.style, value);
        else if (key.startsWith('on')) node.addEventListener(key.slice(2).toLowerCase(), value);
        else if (value === true) node.setAttribute(key, '');
        else node.setAttribute(key, value);
    }

    for (const child of [].concat(children ?? [])) {
        if (child === null || child === undefined || child === false) continue;
        node.append(child.nodeType ? child : document.createTextNode(String(child)));
    }

    return node;
};

XS.list = function (value) {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') return Object.values(value);
    return [];
};

XS.money = function (value) {
    const n = Math.round(Number(value) || 0);
    return (n < 0 ? '-' : '') + (XS.config.currency || '$') + Math.abs(n).toLocaleString('en-US');
};

XS.title = function (text) {
    return String(text ?? '').replace(/(^|[\s_-])(\w)/g, (m, sep, ch) => (sep === '_' || sep === '-' ? ' ' : sep) + ch.toUpperCase());
};

XS.duration = function (seconds) {
    const s = Math.max(0, Math.round(Number(seconds) || 0));
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    if (m < 60) return `${m}m`;
    const h = Math.floor(m / 60);
    if (h < 48) return `${h}h ${m % 60 ? `${m % 60}m` : ''}`.trim();
    return `${Math.floor(h / 24)}d ${h % 24 ? `${h % 24}h` : ''}`.trim();
};

XS.ago = function (stamp) {
    const then = Number(stamp) * 1000;
    if (!then) return '';
    const secs = Math.max(0, Math.floor((Date.now() - then) / 1000));
    if (secs < 60) return 'just now';
    if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
    if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
    return `${Math.floor(secs / 86400)}d ago`;
};

const SILHOUETTE = 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 140"><path fill="#c9c4b8" d="M40 104c-12 0-20-6-20-16 0-9 5-15 16-18l46-12 28-22c7-5 15-8 24-8h70c10 0 19 3 26 9l30 24 26 5c14 3 22 12 22 25 0 8-6 13-14 13h-8a26 26 0 0 0-50 0H106a26 26 0 0 0-50 0z"/><circle cx="81" cy="108" r="19" fill="#9d978a"/><circle cx="233" cy="108" r="19" fill="#9d978a"/></svg>');

XS.photo = function (model, alt) {
    const img = XS.el('img', { alt: alt || '', loading: 'lazy', draggable: 'false' });
    const tries = [`images/vehicles/${model}.png`];
    if (XS.config.images) tries.push(String(XS.config.images).replace('%s', encodeURIComponent(model)));
    tries.push(SILHOUETTE);

    let at = 0;
    img.addEventListener('error', () => {
        at += 1;
        if (at < tries.length) img.src = tries[at];
    });
    img.src = tries[0];
    return img;
};

XS.toast = function (message, kind) {
    const host = document.getElementById('toasts');
    if (!host || !message) return;
    const node = XS.el('div', { class: `toast ${kind || ''}`, text: message });
    host.append(node);
    requestAnimationFrame(() => node.classList.add('in'));
    setTimeout(() => {
        node.classList.remove('in');
        setTimeout(() => node.remove(), 300);
    }, 3200);
};

XS.barcode = function (seed) {
    let h = 2166136261;
    const text = String(seed || 'xs');
    const bars = [];
    for (let i = 0; i < 46; i += 1) {
        h ^= text.charCodeAt(i % text.length) + i;
        h = Math.imul(h, 16777619) >>> 0;
        bars.push(1 + (h % 3));
    }
    let x = 0;
    const rects = bars.map((w, i) => {
        const r = i % 2 === 0 ? `<rect x="${x}" y="0" width="${w}" height="40"/>` : '';
        x += w;
        return r;
    }).join('');
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${x} 40" preserveAspectRatio="none"><g fill="#16181c">${rects}</g></svg>`;
    return 'data:image/svg+xml;utf8,' + encodeURIComponent(svg);
};

XS.setAccent = function (hex) {
    const value = /^#[0-9a-f]{6}$/i.test(hex || '') ? hex : '#b3121b';
    document.documentElement.style.setProperty('--accent', value);
    const r = parseInt(value.slice(1, 3), 16);
    const g = parseInt(value.slice(3, 5), 16);
    const b = parseInt(value.slice(5, 7), 16);
    const luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    document.documentElement.style.setProperty('--on-accent', luma > 0.6 ? '#16181c' : '#ffffff');
};

XS.clear = function (node) {
    while (node && node.firstChild) node.removeChild(node.firstChild);
    return node;
};

XS.show = function (id, on) {
    const node = typeof id === 'string' ? document.getElementById(id) : id;
    if (node) node.hidden = !on;
};
