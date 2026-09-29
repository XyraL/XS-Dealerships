(function () {
    const { el } = XS;

    const C = {
        data: null,
        vmap: {},
        draft: null,
        dirty: false,
        tab: 'details',
        vq: '',
        vcat: 'all',
        busy: false,
    };

    const PREVIEW = { cars: 'sultan', luxury: 'adder', bikes: 'bati', trucks: 'mule', boats: 'dinghy', aircraft: 'frogger' };
    const LIMIT = 150;

    const $ = (id) => document.getElementById(id);
    const clone = (value) => JSON.parse(JSON.stringify(value ?? null));

    function types() {
        return XS.list(C.data && C.data.types);
    }

    function typeInfo(id) {
        return types().find((t) => t.id === id) || types()[0] || { id: 'cars', label: 'Cars', blip: 326, categories: [] };
    }

    function blank() {
        const t = types()[0] || { id: 'cars', blip: 326 };
        return {
            id: null, name: '', type: t.id, mode: 'npc', job: '',
            settings: { access: 'anyone', testDrives: true, finance: true, commission: null, accent: '#b3121b', blip: { show: true, sprite: t.blip || 326, colour: 3 } },
            points: { desk: null, buy: null, test: null, spots: [] },
            catalogue: [],
        };
    }

    function fromDealer(d) {
        const draft = blank();
        draft.id = d.id;
        draft.name = d.name;
        draft.type = d.type;
        draft.mode = d.mode;
        draft.job = d.job || '';
        draft.settings = Object.assign(draft.settings, clone(d.settings) || {});
        draft.settings.blip = Object.assign({ show: true, sprite: 326, colour: 3 }, draft.settings.blip || {});
        const points = clone(d.points) || {};
        draft.points = { desk: points.desk || null, buy: points.buy || null, test: points.test || null, spots: XS.list(points.spots) };
        draft.catalogue = XS.list(d.catalogue).map((c) => ({ model: c.model, price: c.price, stock: c.stock }));
        return draft;
    }

    function markDirty() {
        C.dirty = true;
        renderFooter();
        renderList();
    }

    function entry(model) {
        return C.draft.catalogue.find((c) => c.model === model) || null;
    }

    function label(model) {
        const info = C.vmap[model];
        return info ? `${info.brand ? `${info.brand} ` : ''}${info.name}` : model;
    }

    function previewModel() {
        return (C.draft.catalogue[0] && C.draft.catalogue[0].model) || PREVIEW[C.draft.type] || 'sultan';
    }

    function field(title, control, hint) {
        return el('label', { class: 'field' }, [el('span', { class: 'field-t', text: title }), control, hint ? el('em', { class: 'field-h', text: hint }) : null]);
    }

    function text(value, onInput, attrs) {
        return el('input', Object.assign({ type: 'text', value: value ?? '', oninput: (e) => onInput(e.target.value) }, attrs || {}));
    }

    function number(value, onInput, attrs) {
        return el('input', Object.assign({ type: 'number', value: value ?? '', oninput: (e) => onInput(e.target.value === '' ? null : Number(e.target.value)) }, attrs || {}));
    }

    function segmented(options, value, onPick) {
        const host = el('div', { class: 'seg' });
        options.forEach(([id, title]) => {
            host.append(el('button', {
                class: `seg-b ${value === id ? 'on' : ''}`, type: 'button', text: title,
                onclick: () => { onPick(id); },
            }));
        });
        return host;
    }

    function toggle(value, onFlip, title) {
        const box = el('input', { type: 'checkbox', checked: value ? true : null, onchange: (e) => onFlip(e.target.checked) });
        return el('label', { class: 'toggle' }, [box, el('span', { class: 'toggle-ui' }), el('span', { text: title })]);
    }

    function renderList() {
        const host = XS.clear($('cr-list'));
        const dealers = XS.list(C.data && C.data.dealers);

        host.append(el('button', { class: 'btn primary wide', type: 'button', text: '+ New dealership', onclick: () => guard(() => select(null)) }));

        if (!dealers.length) {
            host.append(el('p', { class: 'fine pad', text: 'No dealerships yet. Make the first one.' }));
        }

        dealers.forEach((d) => {
            const on = C.draft && C.draft.id === d.id;
            host.append(el('button', {
                class: `dl ${on ? 'on' : ''}`, type: 'button',
                onclick: () => { if (!on) guard(() => select(d)); },
            }, [
                el('b', { text: d.name }),
                el('span', { text: `${typeInfo(d.type).label} · ${d.mode === 'job' ? `job: ${d.job}` : 'NPC'}` }),
                el('em', { text: `${XS.list(d.catalogue).length} cars · ${XS.list(d.points && d.points.spots).length} spots${on && C.dirty ? ' · editing' : ''}` }),
            ]));
        });

        if (C.draft && !C.draft.id) {
            host.append(el('div', { class: 'dl on' }, [el('b', { text: C.draft.name || 'New dealership' }), el('span', { text: 'Not saved yet' })]));
        }
    }

    function renderEditor() {
        const tabs = XS.clear($('cr-tabs'));
        const body = XS.clear($('cr-body'));

        if (!C.draft) {
            body.append(el('div', { class: 'empty' }, [el('b', { text: 'Pick a dealership or make a new one.' }), el('span', { text: 'Everything about it is set here and saved to the database.' })]));
            renderFooter();
            return;
        }

        [['details', 'Details'], ['points', 'Points'], ['cars', `Cars (${C.draft.catalogue.length})`]].forEach(([id, title]) => {
            tabs.append(el('button', { class: `tab ${C.tab === id ? 'on' : ''}`, type: 'button', text: title, onclick: () => { C.tab = id; renderEditor(); } }));
        });

        if (C.tab === 'details') renderDetails(body);
        if (C.tab === 'points') renderPoints(body);
        if (C.tab === 'cars') renderCars(body);

        renderFooter();
    }

    function renderDetails(host) {
        const d = C.draft;
        const s = d.settings;
        const jobs = XS.list(C.data.jobs);

        const jobControl = jobs.length
            ? el('select', { onchange: (e) => { d.job = e.target.value; markDirty(); } }, [
                el('option', { value: '', text: 'Pick a job…' }),
                ...jobs.map((j) => el('option', { value: j.name, text: `${j.label} (${j.name})`, selected: j.name === d.job ? true : null })),
            ])
            : text(d.job, (v) => { d.job = v.trim(); markDirty(); }, { placeholder: 'job name, e.g. cardealer' });

        host.append(el('div', { class: 'form' }, [
            el('div', { class: 'form-col' }, [
                field('Name', text(d.name, (v) => { d.name = v; markDirty(); }, { maxlength: 64, placeholder: 'e.g. Premium Deluxe Motorsport' })),
                field('Type', el('select', {
                    onchange: (e) => {
                        const before = typeInfo(d.type);
                        d.type = e.target.value;
                        if (s.blip.sprite === before.blip) s.blip.sprite = typeInfo(d.type).blip;
                        markDirty();
                        renderEditor();
                    },
                }, types().map((t) => el('option', { value: t.id, text: t.label, selected: t.id === d.type ? true : null }))),
                'Decides which cars “Add every car of this type” picks and the default blip.'),
                field('Run by', segmented([['npc', 'Nobody — it runs itself'], ['job', 'A job']], d.mode, (v) => { d.mode = v; markDirty(); renderEditor(); })),
                d.mode === 'job' ? field('Job', jobControl, 'Anyone with this job, on duty, is staff here.') : null,
                d.mode === 'job'
                    ? field('Who can buy, swap and test drive', segmented([['anyone', 'Anyone'], ['job', 'Staff only']], s.access, (v) => { s.access = v; markDirty(); renderEditor(); }),
                        s.access === 'job' ? 'Customers can only look. A salesperson has to sell to them, and nothing is sold while nobody is on duty.' : 'Customers can buy on their own too. Commission is only paid when a salesperson makes the sale.')
                    : null,
                d.mode === 'job'
                    ? field('Commission %', number(s.commission, (v) => { s.commission = v; markDirty(); }, { min: 0, max: 100, placeholder: `${C.data.commission} (the default)` }), 'Paid to the salesperson on each sale they make.')
                    : null,
            ]),
            el('div', { class: 'form-col' }, [
                el('div', { class: 'field' }, [el('span', { class: 'field-t', text: 'On offer' }),
                    toggle(s.testDrives, (v) => { s.testDrives = v; markDirty(); }, 'Test drives'),
                    toggle(s.finance, (v) => { s.finance = v; markDirty(); }, 'Finance'),
                ]),
                el('div', { class: 'field' }, [el('span', { class: 'field-t', text: 'Map blip' }),
                    toggle(s.blip.show, (v) => { s.blip.show = v; markDirty(); }, 'Show on the map'),
                    el('div', { class: 'pair' }, [
                        field('Sprite', number(s.blip.sprite, (v) => { s.blip.sprite = v ?? 326; markDirty(); }, { min: 0, max: 900 })),
                        field('Colour', number(s.blip.colour, (v) => { s.blip.colour = v ?? 3; markDirty(); }, { min: 0, max: 85 })),
                    ]),
                ]),
                field('Catalogue colour', el('div', { class: 'accent-pick' }, [
                    el('input', { type: 'color', value: s.accent || '#b3121b', oninput: (e) => { s.accent = e.target.value; XS.setAccent(s.accent); markDirty(); } }),
                    el('span', { class: 'fine', text: 'Buttons and highlights in this dealership’s catalogue.' }),
                ])),
            ]),
        ]));
    }

    async function place(title, preview, origin) {
        if (C.busy) return null;
        C.busy = true;
        const point = await XS.post('place', { label: title, preview, origin });
        C.busy = false;
        return point && typeof point === 'object' ? point : null;
    }

    function coords(p) {
        return p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)} · ${Math.round(p.h || 0)}°` : 'Not placed';
    }

    function pointRow(key, title, desc, preview) {
        const p = C.draft.points[key];
        return el('div', { class: `pt ${p ? '' : 'missing'}` }, [
            el('div', { class: 'pt-t' }, [el('b', { text: title }), el('span', { text: desc }), el('code', { text: coords(p) })]),
            el('div', { class: 'pt-a' }, [
                el('button', {
                    class: 'btn small', type: 'button', text: p ? 'Move' : 'Place',
                    onclick: async () => {
                        const next = await place(title, preview, p);
                        if (!next) return;
                        C.draft.points[key] = next;
                        markDirty();
                        renderEditor();
                    },
                }),
                p ? el('button', { class: 'btn small ghost', type: 'button', text: 'Go to', onclick: () => XS.post('teleport', { point: p }) }) : null,
            ]),
        ]);
    }

    function renderPoints(host) {
        const d = C.draft;
        const spots = d.points.spots;
        const models = d.catalogue.map((c) => c.model);

        const spotRows = spots.map((spot, index) => el('div', { class: 'pt spot' }, [
            el('div', { class: 'pt-t' }, [
                el('b', { text: `Spot ${index + 1}` }),
                el('select', {
                    onchange: (e) => { spot.model = e.target.value; markDirty(); },
                }, models.map((m) => el('option', { value: m, text: label(m), selected: m === spot.model ? true : null }))),
                el('code', { text: coords(spot) }),
            ]),
            el('div', { class: 'pt-a' }, [
                el('button', {
                    class: 'btn small', type: 'button', text: 'Move',
                    onclick: async () => {
                        const next = await place(`Showcase spot ${index + 1}`, spot.model, spot);
                        if (!next) return;
                        Object.assign(spot, next);
                        markDirty();
                        renderEditor();
                    },
                }),
                el('button', { class: 'btn small ghost', type: 'button', text: 'Go to', onclick: () => XS.post('teleport', { point: spot }) }),
                el('button', { class: 'btn small danger', type: 'button', text: 'Remove', onclick: () => { spots.splice(index, 1); markDirty(); renderEditor(); } }),
            ]),
        ]));

        host.append(el('div', { class: 'points' }, [
            pointRow('desk', 'Sales desk', 'Where people browse every car, buy, and pay their finance. Staff open the office here.'),
            el('div', { class: 'pt-group' }, [
                el('div', { class: 'pt-group-h' }, [
                    el('b', { text: 'Showcase spots' }),
                    el('span', { text: 'A car on display. People can look at it, buy it, or swap it for another car to look at.' }),
                ]),
                ...spotRows,
                el('button', {
                    class: 'btn wide ghost', type: 'button',
                    text: models.length ? '+ Add a spot' : 'Add cars on the Cars tab first',
                    disabled: models.length ? null : true,
                    onclick: async () => {
                        const model = models[0];
                        const next = await place(`Showcase spot ${spots.length + 1}`, model);
                        if (!next) return;
                        spots.push(Object.assign({ id: Math.random().toString(36).slice(2, 8), model }, next));
                        markDirty();
                        renderEditor();
                    },
                }),
            ]),
            pointRow('buy', 'Bought cars come out here', 'Where a car is handed over once it is paid for. If something is parked on it, the car goes to the garage instead.', previewModel()),
            pointRow('test', 'Test drives start here', d.settings.testDrives ? 'Where the test car is brought round.' : 'Test drives are off for this dealership, so this is not used.', previewModel()),
        ]));
    }

    function renderCars(host) {
        const d = C.draft;
        const vehicles = XS.list(C.data.vehicles);
        const q = C.vq.trim().toLowerCase();
        const cats = [...new Set(vehicles.map((v) => v.category))].sort();
        const type = typeInfo(d.type);
        const typeCats = new Set(XS.list(type.categories));

        const matches = vehicles.filter((v) => (C.vcat === 'all' || v.category === C.vcat)
            && (!q || `${v.brand} ${v.name} ${v.model}`.toLowerCase().includes(q)));

        const defaultStock = () => (d.mode === 'job' ? C.data.jobStock : -1);

        const add = (v) => {
            if (entry(v.model)) return;
            d.catalogue.push({ model: v.model, price: v.price, stock: defaultStock() });
        };

        const pool = el('div', { class: 'pool' }, [
            el('div', { class: 'pool-tools' }, [
                el('input', { type: 'search', placeholder: 'Search every vehicle…', value: C.vq, oninput: (e) => { C.vq = e.target.value; renderCarsKeepFocus(); } }),
                el('select', { onchange: (e) => { C.vcat = e.target.value; renderEditor(); } }, [
                    el('option', { value: 'all', text: 'All categories' }),
                    ...cats.map((c) => el('option', { value: c, text: XS.title(c), selected: c === C.vcat ? true : null })),
                ]),
            ]),
            el('button', {
                class: 'btn wide ghost', type: 'button', text: `+ Add every ${type.label.toLowerCase()} car`,
                onclick: () => {
                    vehicles.filter((v) => typeCats.has(v.category)).forEach(add);
                    markDirty();
                    renderEditor();
                },
            }),
            el('div', { class: 'pool-list', id: 'cr-pool' }, matches.slice(0, LIMIT).map((v) => {
                const has = !!entry(v.model);
                return el('div', { class: `pr ${has ? 'has' : ''}` }, [
                    el('div', {}, [el('b', { text: v.name }), el('span', { text: `${v.brand || '—'} · ${XS.title(v.category)} · ${v.model}` })]),
                    el('span', { class: 'pr-price', text: XS.money(v.price) }),
                    el('button', { class: 'btn small', type: 'button', text: has ? 'Added' : 'Add', disabled: has ? true : null, onclick: () => { add(v); markDirty(); renderEditor(); } }),
                ]);
            })),
            matches.length > LIMIT ? el('p', { class: 'fine', text: `Showing ${LIMIT} of ${matches.length}. Search to narrow it down.` }) : null,
            !vehicles.length ? el('p', { class: 'fine', text: 'The framework has no vehicle list, so there is nothing to add from.' }) : null,
        ]);

        const inUse = new Set(d.points.spots.map((s) => s.model));

        const sold = el('div', { class: 'sold' }, [
            el('div', { class: 'sold-head' }, [el('b', { text: `Sold here (${d.catalogue.length})` }), el('span', { text: 'Price · stock (blank for unlimited)' })]),
            d.catalogue.length
                ? el('div', { class: 'sold-list' }, d.catalogue.map((c, index) => el('div', { class: 'sr' }, [
                    el('div', { class: 'sr-photo' }, XS.photo(c.model, c.model)),
                    el('div', { class: 'sr-name' }, [el('b', { text: label(c.model) }), el('span', { text: c.model })]),
                    el('input', { type: 'number', min: 0, value: c.price, title: 'Price', oninput: (e) => { c.price = Math.max(0, Number(e.target.value) || 0); markDirty(); } }),
                    el('input', {
                        type: 'number', min: 0, value: c.stock < 0 ? '' : c.stock, placeholder: '∞', title: 'Stock',
                        oninput: (e) => { c.stock = e.target.value === '' ? -1 : Math.max(0, Math.floor(Number(e.target.value) || 0)); markDirty(); },
                    }),
                    el('button', {
                        class: 'x small', type: 'button', text: '×', title: inUse.has(c.model) ? 'On a showcase spot' : 'Stop selling it',
                        onclick: () => {
                            if (inUse.has(c.model)) {
                                XS.toast('A showcase spot is showing that car. Change the spot first.', 'bad');
                                return;
                            }
                            d.catalogue.splice(index, 1);
                            markDirty();
                            renderEditor();
                        },
                    }),
                ])))
                : el('p', { class: 'fine pad', text: 'Nothing yet. Add cars from the list on the left.' }),
        ]);

        host.append(el('div', { class: 'cars' }, [pool, sold]));
    }

    function renderCarsKeepFocus() {
        const input = document.querySelector('#cr-body .pool-tools input[type="search"]');
        const at = input ? input.selectionStart : null;
        renderEditor();
        const next = document.querySelector('#cr-body .pool-tools input[type="search"]');
        if (next) {
            next.focus();
            if (at !== null) next.setSelectionRange(at, at);
        }
    }

    function renderFooter() {
        const host = XS.clear($('cr-foot'));
        if (!C.draft) return;

        const status = el('span', { class: `cr-status ${C.dirty ? 'dirty' : ''}`, text: C.dirty ? 'Unsaved changes' : C.draft.id ? 'Saved' : 'Not saved yet' });

        host.append(
            C.draft.id ? el('button', { class: 'btn danger', type: 'button', text: 'Delete', onclick: () => confirmBar(`Delete ${C.draft.name}? Its stock and open orders go with it.`, 'Delete it', remove) }) : el('span'),
            status,
            el('button', { class: 'btn primary', type: 'button', text: 'Save dealership', disabled: C.busy ? true : null, onclick: save }),
        );
    }

    async function save() {
        if (C.busy || !C.draft) return;

        if (!C.draft.name.trim()) {
            XS.toast('Give the dealership a name.', 'bad');
            C.tab = 'details';
            renderEditor();
            return;
        }
        if (C.draft.mode === 'job' && !C.draft.job) {
            XS.toast('Pick the job that runs this dealership.', 'bad');
            C.tab = 'details';
            renderEditor();
            return;
        }

        C.busy = true;
        renderFooter();
        const res = await XS.post('saveDealer', { draft: C.draft });
        C.busy = false;

        if (!res || !res.ok) {
            XS.toast((res && res.error) || 'It did not save.', 'bad');
            renderFooter();
            return;
        }

        C.data = res.data;
        indexVehicles();
        const saved = XS.list(C.data.dealers).find((d) => d.id === res.id);
        C.draft = saved ? fromDealer(saved) : C.draft;
        C.dirty = false;
        XS.toast('Saved. Everyone on the server sees the change now.', 'good');
        render();
    }

    async function remove() {
        if (!C.draft || !C.draft.id) return;
        const res = await XS.post('deleteDealer', { id: C.draft.id });
        if (!res || !res.ok) {
            XS.toast((res && res.error) || 'It was not deleted.', 'bad');
            return;
        }
        C.data = res.data;
        indexVehicles();
        C.draft = null;
        C.dirty = false;
        XS.toast('Dealership deleted.', 'good');
        render();
    }

    function confirmBar(message, yes, onYes) {
        const bar = $('cr-confirm');
        XS.clear(bar).append(
            el('span', { text: message }),
            el('button', { class: 'btn ghost small', type: 'button', text: 'Cancel', onclick: () => { bar.hidden = true; } }),
            el('button', { class: 'btn danger small', type: 'button', text: yes, onclick: () => { bar.hidden = true; onYes(); } }),
        );
        bar.hidden = false;
    }

    function guard(next) {
        if (!C.dirty) {
            next();
            return;
        }
        confirmBar('You have unsaved changes. Drop them?', 'Drop them', () => { C.dirty = false; next(); });
    }

    function select(dealer) {
        C.draft = dealer ? fromDealer(dealer) : blank();
        C.dirty = !dealer;
        C.tab = 'details';
        XS.setAccent(C.draft.settings.accent);
        render();
    }

    function render() {
        renderList();
        renderEditor();
    }

    function indexVehicles() {
        C.vmap = {};
        XS.list(C.data && C.data.vehicles).forEach((v) => { C.vmap[v.model] = v; });
    }

    function open(data) {
        C.data = data;
        indexVehicles();

        if (C.draft && C.dirty) {
            XS.toast('Your unsaved changes are still here.', 'good');
        } else if (C.draft && C.draft.id) {
            const fresh = XS.list(data.dealers).find((d) => d.id === C.draft.id);
            C.draft = fresh ? fromDealer(fresh) : null;
        } else {
            C.draft = null;
        }

        XS.setAccent(C.draft ? C.draft.settings.accent : '#b3121b');
        $('cr-confirm').hidden = true;
        render();
        XS.show('creator', true);
    }

    function close() {
        XS.show('creator', false);
    }

    document.addEventListener('DOMContentLoaded', () => {
        $('cr-close').addEventListener('click', () => XS.post('close'));
    });

    XS.views.creator = { open, close };
})();
