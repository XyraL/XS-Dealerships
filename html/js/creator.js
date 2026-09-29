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

    const FALLBACK = {
        accent: '#b3121b',
        blip: { show: true, sprite: 326, colour: 3 },
        customers: { buy: true, swap: true, test: true },
        sale: { cash: true, bank: true, deliver: 'spawn', garage: 'pillboxgarage', warp: true },
        test: { enabled: true, seconds: 90, private: false, returnToStart: true },
        finance: { enabled: true, downPayment: 20, payments: 10, interest: 10, intervalHours: 24, missedLimit: 3, repossess: 'remove', holdDays: 7, returnToStock: true },
        staff: { commission: 10, gradeCommission: {}, sellGrade: 0, orderGrade: 1, bossGrade: 3, requireDuty: true },
        stock: { start: 3, wholesale: 70, deliveryMinutes: 5, maxPerOrder: 10, maxPending: 5 },
        showcase: { resetMinutes: 10, plate: 'FOR SALE' },
    };

    const $ = (id) => document.getElementById(id);
    const clone = (value) => JSON.parse(JSON.stringify(value ?? null));
    const plain = (value) => !!value && typeof value === 'object' && !Array.isArray(value);

    function merge(base, extra) {
        const out = clone(base) || {};
        if (!plain(extra)) return out;

        Object.entries(extra).forEach(([key, value]) => {
            if (value === null || value === undefined) return;
            out[key] = plain(value) && plain(out[key]) ? merge(out[key], value) : clone(value);
        });

        return out;
    }

    function settingsFrom(raw) {
        const settings = merge(merge(FALLBACK, C.data && C.data.defaults), raw);
        const rates = {};

        Object.entries(settings.staff.gradeCommission || {}).forEach(([grade, rate]) => {
            if (rate !== null && rate !== '' && Number.isFinite(Number(rate))) rates[grade] = Number(rate);
        });

        settings.staff.gradeCommission = rates;
        return settings;
    }

    function types() {
        return XS.list(C.data && C.data.types);
    }

    function typeInfo(id) {
        return types().find((t) => t.id === id) || types()[0] || { id: 'cars', label: 'Cars', blip: 326, categories: [] };
    }

    function blank() {
        const t = types()[0] || { id: 'cars', blip: 326 };
        const settings = settingsFrom({});
        settings.blip.sprite = t.blip || settings.blip.sprite;

        return {
            id: null, name: '', type: t.id, mode: 'npc', job: '',
            settings,
            points: { desk: null, buy: null, test: null, spots: [] },
            catalogue: [],
        };
    }

    function fromDealer(d) {
        const points = clone(d.points) || {};

        return {
            id: d.id,
            name: d.name,
            type: d.type,
            mode: d.mode,
            job: d.job || '',
            settings: settingsFrom(clone(d.settings)),
            points: { desk: points.desk || null, buy: points.buy || null, test: points.test || null, spots: XS.list(points.spots) },
            catalogue: XS.list(d.catalogue).map((c) => ({ model: c.model, price: c.price, stock: c.stock })),
        };
    }

    function chapters() {
        const list = [['details', 'Details'], ['selling', 'Selling'], ['finance', 'Finance']];
        if (C.draft && C.draft.mode === 'job') list.push(['staff', 'Staff']);
        list.push(['points', 'Points'], ['cars', 'Cars']);
        return list.map(([id, title], index) => ({ id, title, no: String(index + 1).padStart(2, '0') }));
    }

    function chapterNo(id) {
        const found = chapters().find((c) => c.id === id);
        return found ? found.no : '';
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

    function shortName(model) {
        const info = C.vmap[model];
        return info ? info.name : model;
    }

    function previewModel() {
        return (C.draft.catalogue[0] && C.draft.catalogue[0].model) || PREVIEW[C.draft.type] || 'sultan';
    }

    function heroModel(index) {
        const models = C.draft.catalogue.map((c) => c.model);
        if (!models.length) return PREVIEW[C.draft.type] || 'sultan';
        return models[index % models.length];
    }

    function yesNo(value, onFlip, words) {
        const [yes, no] = words || ['Yes', 'No'];
        return el('button', {
            class: `bk-yn ${value ? 'on' : ''}`, type: 'button', text: value ? yes : no,
            onclick: () => {
                onFlip(!value);
                markDirty();
                rerender();
            },
        });
    }

    function choice(options, value, onPick) {
        return el('span', { class: 'bk-choice' }, options.map(([id, title]) => el('button', {
            class: `bk-opt ${value === id ? 'on' : ''}`, type: 'button', text: title,
            onclick: () => {
                if (value === id) return;
                onPick(id);
                markDirty();
                rerender();
            },
        })));
    }

    function number(value, onSet, opts) {
        const o = opts || {};
        const input = el('input', {
            class: 'bk-in bk-num', type: 'number', value: value ?? '', min: o.min, max: o.max, step: o.step || 1,
            placeholder: o.placeholder || '',
            oninput: (e) => {
                onSet(e.target.value === '' ? null : Number(e.target.value));
                markDirty();
            },
            onchange: (e) => {
                if (e.target.value === '') return;
                let n = Number(e.target.value);
                if (o.min !== undefined) n = Math.max(o.min, n);
                if (o.max !== undefined) n = Math.min(o.max, n);
                if (String(n) !== e.target.value) {
                    e.target.value = n;
                    onSet(n);
                }
            },
        });

        return o.unit ? el('span', { class: 'bk-field' }, [input, el('em', { class: 'bk-unit', text: o.unit })]) : input;
    }

    function text(value, onSet, opts) {
        const o = opts || {};
        return el('input', {
            class: `bk-in bk-text ${o.wide ? 'wide' : ''} ${o.upper ? 'upper' : ''}`, type: 'text', value: value ?? '',
            maxlength: o.max || 64, placeholder: o.placeholder || '', spellcheck: 'false',
            oninput: (e) => {
                onSet(e.target.value);
                markDirty();
            },
        });
    }

    function pick(options, value, onPick, extra) {
        return el('select', {
            class: `bk-in bk-sel ${extra || ''}`,
            onchange: (e) => {
                onPick(e.target.value);
                markDirty();
                rerender();
            },
        }, options.map(([id, title]) => el('option', { value: id, text: title, selected: String(id) === String(value) ? true : null })));
    }

    function line(title, control, opts) {
        const o = opts || {};
        return el('div', { class: `bk-line ${o.off ? 'off' : ''}` }, [
            el('span', { class: 'bk-label', text: title }),
            el('span', { class: 'bk-dots' }),
            el('span', { class: 'bk-val' }, control),
        ]);
    }

    function block(title, rows, note, warn) {
        return el('section', { class: 'bk-sec' }, [
            el('h5', { text: title }),
            ...rows.filter(Boolean),
            note ? el('p', { class: `bk-note ${warn ? 'warn' : ''}`, text: note }) : null,
        ]);
    }

    function heading(title) {
        return title.split('\n').flatMap((part, i) => (i ? [el('br'), part] : [part]));
    }

    function spread(id, title, blurb, extra, spec) {
        const index = chapters().findIndex((c) => c.id === id);

        return el('div', { class: 'bk-spread' }, [
            el('div', { class: 'bk-hero' }, [
                el('span', { class: 'bk-no', text: chapterNo(id) }),
                el('small', { class: 'bk-kick', text: C.draft.name || 'New dealership' }),
                el('h2', {}, heading(title)),
                el('p', { class: 'bk-blurb', text: blurb }),
                ...(extra || []),
                el('div', { class: 'bk-photo' }, XS.photo(heroModel(Math.max(0, index)), '')),
            ]),
            el('div', { class: 'bk-spec', 'data-scroll': 'spec' }, spec.filter(Boolean)),
        ]);
    }

    function pageHead(id, title, blurb) {
        return el('div', { class: 'bk-pagehead' }, [
            el('span', { class: 'bk-no', text: chapterNo(id) }),
            el('div', { class: 'bk-pagehead-t' }, [
                el('small', { class: 'bk-kick', text: C.draft.name || 'New dealership' }),
                el('h2', { text: title }),
            ]),
            el('p', { class: 'bk-blurb', text: blurb }),
        ]);
    }

    function pageDetails() {
        const d = C.draft;
        const s = d.settings;
        const jobs = XS.list(C.data.jobs);

        let jobControl;
        if (jobs.length) {
            const options = [['', 'Pick a job…'], ...jobs.map((j) => [j.name, `${j.label} (${j.name})`])];
            if (d.job && !jobs.some((j) => j.name === d.job)) options.push([d.job, `${d.job} (missing)`]);
            jobControl = pick(options, d.job, (v) => { d.job = v; });
        } else {
            jobControl = text(d.job, (v) => { d.job = v.trim(); }, { placeholder: 'cardealer' });
        }

        return spread('details', 'The name\non the sign', 'What it is called, what it sells and who runs it. Everything else in the book hangs off this page.', [], [
            block('The dealership', [
                line('Name', text(d.name, (v) => {
                    d.name = v;
                    const kick = document.querySelector('#cr-body .bk-kick');
                    if (kick) kick.textContent = v || 'New dealership';
                }, { wide: true, max: 64, placeholder: 'Premium Deluxe Motorsport' })),
                line('Sells', pick(types().map((t) => [t.id, t.label]), d.type, (v) => {
                    const before = typeInfo(d.type);
                    d.type = v;
                    if (s.blip.sprite === before.blip) s.blip.sprite = typeInfo(v).blip;
                })),
                line('Run by', choice([['npc', 'Itself'], ['job', 'A job']], d.mode, (v) => { d.mode = v; })),
                d.mode === 'job' ? line('Job', jobControl) : null,
            ], d.mode === 'job'
                ? 'Anyone with this job works here. What each grade can do is on the Staff page.'
                : 'Nobody has to be on to sell. Stock is unlimited unless you set it per car.'),
            block('On the map', [
                line('Blip', yesNo(s.blip.show, (v) => { s.blip.show = v; })),
                line('Sprite', number(s.blip.sprite, (v) => { s.blip.sprite = v ?? 326; }, { min: 0, max: 1000 }), { off: !s.blip.show }),
                line('Colour', number(s.blip.colour, (v) => { s.blip.colour = v ?? 3; }, { min: 0, max: 85 }), { off: !s.blip.show }),
            ]),
            block('Catalogue', [
                line('Accent colour', el('input', {
                    class: 'bk-colour', type: 'color', value: s.accent,
                    oninput: (e) => {
                        s.accent = e.target.value;
                        XS.setAccent(s.accent);
                        markDirty();
                    },
                })),
            ], 'Buttons and highlights in this dealership’s catalogue, and on these pages.'),
        ]);
    }

    function pageSelling() {
        const d = C.draft;
        const s = d.settings;
        const t = s.test;
        const nothing = !s.sale.cash && !s.sale.bank && !s.finance.enabled;

        return spread('selling', 'How a car\nleaves the lot', 'Who can buy without a salesperson, how they pay, and what happens the moment the money clears.', [], [
            d.mode === 'job' ? block('Customers', [
                line('Buy a car themselves', yesNo(s.customers.buy, (v) => { s.customers.buy = v; })),
                line('Swap the showcase cars', yesNo(s.customers.swap, (v) => { s.customers.swap = v; })),
                line('Take a test drive', yesNo(s.customers.test, (v) => { s.customers.test = v; })),
            ], 'No means staff do it for them. A salesperson uses Sell to a customer, the car comes out with the keys once they pay, and nothing happens while nobody is on duty.') : null,
            block('Paying', [
                line('Cash', yesNo(s.sale.cash, (v) => { s.sale.cash = v; })),
                line('Bank', yesNo(s.sale.bank, (v) => { s.sale.bank = v; })),
                line('Finance', yesNo(s.finance.enabled, (v) => { s.finance.enabled = v; })),
            ], nothing ? 'With all three off, nothing can be bought here.' : 'Finance terms are on the Finance page.', nothing),
            block('Handover', [
                line('Where the car goes', choice([['spawn', 'Out front'], ['garage', 'Their garage']], s.sale.deliver, (v) => { s.sale.deliver = v; })),
                line('Put the buyer in the car', yesNo(s.sale.warp, (v) => { s.sale.warp = v; }), { off: s.sale.deliver !== 'spawn' }),
                line('Garage', text(s.sale.garage, (v) => { s.sale.garage = v.trim(); }, { max: 64, placeholder: 'pillboxgarage' })),
            ], 'Out front uses the bought-car point on the Points page. The garage takes the car when that point is blocked, and gets cars won back from finance.'),
            block('Test drives', [
                line('Test drives', yesNo(t.enabled, (v) => { t.enabled = v; })),
                line('Length', number(t.seconds, (v) => { t.seconds = v ?? 90; }, { min: 10, max: 1800, unit: 'sec' }), { off: !t.enabled }),
                line('Private world', yesNo(t.private, (v) => { t.private = v; }), { off: !t.enabled }),
                line('Back where they started', yesNo(t.returnToStart, (v) => { t.returnToStart = v; }), { off: !t.enabled }),
            ], t.enabled ? 'The driver is put straight in the car at the test drive point. In a private world nobody else sees or hits it.' : null),
            block('Showcase', [
                line('Swapped cars go back after', number(s.showcase.resetMinutes, (v) => { s.showcase.resetMinutes = v ?? 0; }, { min: 0, max: 1440, unit: 'min' })),
                line('Plate on display cars', text(s.showcase.plate, (v) => { s.showcase.plate = v.toUpperCase().slice(0, 8); }, { max: 8, upper: true, placeholder: 'FOR SALE' })),
            ], '0 minutes leaves whatever was put on a spot until someone changes it.'),
        ]);
    }

    function financeTerms(price, f) {
        const clamp = (value, low, high) => Math.min(high, Math.max(low, Number(value) || 0));
        const payments = Math.max(1, Math.floor(Number(f.payments) || 1));
        const down = Math.ceil(price * clamp(f.downPayment, 0, 100) / 100);
        const financed = Math.max(0, price - down);
        const total = financed + Math.ceil(financed * clamp(f.interest, 0, 1000) / 100);
        return { down, payments, total, payment: Math.ceil(total / payments) };
    }

    function every(hours) {
        const h = Number(hours) || 24;
        if (h < 1) return `every ${Math.round(h * 60)} minutes`;
        if (h === 1) return 'every hour';
        if (h === 24) return 'every day';
        if (h % 24 === 0) return `every ${h / 24} days`;
        return `every ${h} hours`;
    }

    function financeExample(f) {
        if (!f.enabled) return 'Finance is off here. Buyers pay the full price up front.';

        const first = C.draft.catalogue[0];
        const price = first ? Math.max(0, Number(first.price) || 0) : 100000;
        const t = financeTerms(price, f);
        const what = first ? `On the ${label(first.model)} at ${XS.money(price)}` : `On a ${XS.money(price)} car`;

        return `${what}: ${XS.money(t.down)} down, then ${t.payments} payment${t.payments === 1 ? '' : 's'} of ${XS.money(t.payment)}, one ${every(f.intervalHours)}. ${XS.money(t.down + t.total)} in all.`;
    }

    function pageFinance() {
        const f = C.draft.settings.finance;
        const example = el('p', { class: 'bk-example' });
        const refresh = () => { example.textContent = financeExample(f); };
        refresh();

        const n = (key, fallback, opts) => number(f[key], (v) => {
            f[key] = v ?? fallback;
            refresh();
        }, opts);
        const off = !f.enabled;

        return spread('finance', 'Paying it\noff', 'The terms this dealership offers. Payments come out of the buyer’s bank on their own.', [example], [
            block('Finance', [line('Offer finance here', yesNo(f.enabled, (v) => { f.enabled = v; }))]),
            block('Terms', [
                line('Down payment', n('downPayment', 20, { min: 0, max: 100, unit: '%' }), { off }),
                line('Payments after that', n('payments', 10, { min: 1, max: 120 }), { off }),
                line('Interest', n('interest', 10, { min: 0, max: 1000, unit: '%' }), { off }),
                line('One every', n('intervalHours', 24, { min: 0.1, max: 720, step: 0.5, unit: 'hours' }), { off }),
            ], 'Agreements already signed keep the terms they were signed on.'),
            block('When they stop paying', [
                line('Missed in a row before it is taken', n('missedLimit', 3, { min: 1, max: 50 }), { off }),
                line('Then the car is', choice([['remove', 'Gone for good'], ['hold', 'Held']], f.repossess, (v) => { f.repossess = v; }), { off }),
                f.repossess === 'hold' ? line('Held for', n('holdDays', 7, { min: 1, max: 90, unit: 'days' }), { off }) : null,
                line('Put back in stock', yesNo(f.returnToStock, (v) => { f.returnToStock = v; }), { off }),
            ], f.repossess === 'hold'
                ? 'While it is held, the buyer can pay what is left at the desk and the car goes back in their garage.'
                : 'The car is taken out of their garage for good.'),
        ]);
    }

    function jobGrades() {
        const job = XS.list(C.data.jobs).find((j) => j.name === C.draft.job);
        return job ? XS.list(job.grades).slice().sort((a, b) => a.level - b.level) : [];
    }

    function pageStaff() {
        const s = C.draft.settings;
        const st = s.staff;
        const stock = s.stock;
        const grades = jobGrades();

        const gradePick = (key) => {
            if (!grades.length) return number(st[key], (v) => { st[key] = v ?? 0; }, { min: 0, max: 100, unit: 'and up' });
            const options = grades.map((g) => [g.level, `${g.name} and up`]);
            if (!grades.some((g) => g.level === st[key])) options.push([st[key], `Grade ${st[key]} and up`]);
            return pick(options, st[key], (v) => { st[key] = Number(v); });
        };

        const rates = grades.map((g) => line(g.name, number(st.gradeCommission[g.level] ?? null, (v) => {
            if (v === null) delete st.gradeCommission[g.level];
            else st.gradeCommission[g.level] = v;
        }, { min: 0, max: 100, unit: '%', placeholder: String(st.commission) })));

        return spread('staff', 'Who runs\nthe floor', 'What each grade of the job can do, what they earn on a sale, and how the shop gets more cars in.', [], [
            block('Who can do what', [
                line('Sell to customers', gradePick('sellGrade')),
                line('Order stock', gradePick('orderGrade')),
                line('See the money', gradePick('bossGrade')),
                line('Have to be on duty', yesNo(st.requireDuty, (v) => { st.requireDuty = v; })),
            ], 'Grades the job marks as boss always see the money: the account, the sales log, and paying in or out.'),
            block('Commission', [
                line('On every sale', number(st.commission, (v) => { st.commission = v ?? 0; }, { min: 0, max: 100, unit: '%' })),
                ...rates,
            ], rates.length ? 'Paid to the salesperson who made the sale. A blank grade uses the rate above.' : 'Paid to the salesperson who made the sale.'),
            block('Ordering stock', [
                line('Orders arrive after', number(stock.deliveryMinutes, (v) => { stock.deliveryMinutes = v ?? 0; }, { min: 0, max: 10080, unit: 'min' })),
                line('The business pays', number(stock.wholesale, (v) => { stock.wholesale = v ?? 0; }, { min: 0, max: 1000, unit: '% of the price' })),
                line('Most cars in one order', number(stock.maxPerOrder, (v) => { stock.maxPerOrder = v ?? 1; }, { min: 1, max: 999 })),
                line('Orders on the way at once', number(stock.maxPending, (v) => { stock.maxPending = v ?? 1; }, { min: 1, max: 99 })),
                line('A new car starts with', number(stock.start < 0 ? null : stock.start, (v) => { stock.start = v === null ? -1 : v; }, { min: 0, max: 9999, unit: 'in stock', placeholder: '∞' })),
            ], 'Staff order from the dealer tablet. A new car is one you add on the Cars page. Blank is unlimited.'),
        ]);
    }

    function coords(p) {
        return p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)} · ${Math.round(p.h || 0)}°` : 'Not placed yet';
    }

    function others(skip) {
        const d = C.draft;
        const out = [];
        const add = (p, title, model) => {
            if (p && p !== skip) out.push({ x: p.x, y: p.y, z: p.z, h: p.h || 0, label: title, model: model || null });
        };

        add(d.points.desk, 'Sales desk', null);
        add(d.points.buy, 'Bought cars', previewModel());
        add(d.points.test, 'Test drives', previewModel());
        d.points.spots.forEach((spot, i) => add(spot, `Spot ${i + 1} · ${shortName(spot.model)}`, spot.model));

        return out;
    }

    async function place(title, preview, origin) {
        if (C.busy) return null;
        C.busy = true;
        const point = await XS.post('place', { label: title, preview, origin, others: others(origin), dealer: C.draft.id });
        C.busy = false;
        return point && typeof point === 'object' ? point : null;
    }

    function pointRow(key, title, desc, preview) {
        const p = C.draft.points[key];

        return el('div', { class: `bk-pt ${p ? '' : 'missing'}` }, [
            el('div', { class: 'bk-pt-t' }, [el('b', { text: title }), el('span', { text: desc }), el('code', { text: coords(p) })]),
            el('div', { class: 'bk-pt-a' }, [
                el('button', {
                    class: 'bk-btn', type: 'button', text: p ? 'Move' : 'Place',
                    onclick: async () => {
                        const next = await place(title, preview, p);
                        if (!next) return;
                        C.draft.points[key] = next;
                        markDirty();
                        rerender();
                    },
                }),
                p ? el('button', { class: 'bk-btn ghost', type: 'button', text: 'Go to', onclick: () => XS.post('teleport', { point: p }) }) : null,
            ]),
        ]);
    }

    function pagePoints() {
        const d = C.draft;
        const spots = d.points.spots;
        const models = d.catalogue.map((c) => c.model);

        const spotRows = spots.map((spot, index) => el('div', { class: 'bk-pt spot' }, [
            el('div', { class: 'bk-pt-photo' }, XS.photo(spot.model, '')),
            el('div', { class: 'bk-pt-t' }, [
                el('b', { text: `Spot ${index + 1}` }),
                el('select', {
                    class: 'bk-in bk-sel left',
                    onchange: (e) => {
                        spot.model = e.target.value;
                        markDirty();
                        rerender();
                    },
                }, models.map((m) => el('option', { value: m, text: label(m), selected: m === spot.model ? true : null }))),
                el('code', { text: coords(spot) }),
            ]),
            el('div', { class: 'bk-pt-a' }, [
                el('button', {
                    class: 'bk-btn', type: 'button', text: 'Move',
                    onclick: async () => {
                        const next = await place(`Showcase spot ${index + 1}`, spot.model, spot);
                        if (!next) return;
                        Object.assign(spot, next);
                        markDirty();
                        rerender();
                    },
                }),
                el('button', { class: 'bk-btn ghost', type: 'button', text: 'Go to', onclick: () => XS.post('teleport', { point: spot }) }),
                el('button', {
                    class: 'bk-btn danger', type: 'button', text: 'Remove',
                    onclick: () => {
                        spots.splice(index, 1);
                        markDirty();
                        rerender();
                    },
                }),
            ]),
        ]));

        return el('div', { class: 'bk-page', 'data-scroll': 'page' }, [
            pageHead('points', 'Where everything goes', 'Fly the camera over and drop each point where it belongs. While you place one, the others show as outlines and turn red when something would hit them.'),
            el('div', { class: 'bk-points' }, [
                el('div', { class: 'bk-pt-col' }, [
                    el('h5', { text: 'The desk and the handover' }),
                    pointRow('desk', 'Sales desk', 'Where people browse the catalogue, buy, and pay their finance.'),
                    pointRow('buy', 'Bought cars come out here', d.settings.sale.deliver === 'spawn'
                        ? 'The new owner gets the keys here. If something is parked on it, the car goes to the garage instead.'
                        : 'Not used while bought cars go straight to the garage.', previewModel()),
                    pointRow('test', 'Test drives start here', d.settings.test.enabled
                        ? 'Where the test car is brought round.'
                        : 'Test drives are off here, so this is not used.', previewModel()),
                ]),
                el('div', { class: 'bk-pt-col' }, [
                    el('h5', { text: `Showcase spots · ${spots.length}` }),
                    ...spotRows,
                    el('button', {
                        class: 'bk-add', type: 'button',
                        text: models.length ? '+ Add a spot' : 'Add cars on the Cars page first',
                        disabled: models.length ? null : true,
                        onclick: async () => {
                            const model = models[0];
                            const next = await place(`Showcase spot ${spots.length + 1}`, model);
                            if (!next) return;
                            spots.push(Object.assign({ id: Math.random().toString(36).slice(2, 8), model }, next));
                            markDirty();
                            rerender();
                        },
                    }),
                ]),
            ]),
        ]);
    }

    function pageCars() {
        const d = C.draft;
        const vehicles = XS.list(C.data.vehicles);
        const q = C.vq.trim().toLowerCase();
        const cats = [...new Set(vehicles.map((v) => v.category))].sort();
        const type = typeInfo(d.type);
        const typeCats = new Set(XS.list(type.categories));

        const matches = vehicles.filter((v) => (C.vcat === 'all' || v.category === C.vcat)
            && (!q || `${v.brand} ${v.name} ${v.model}`.toLowerCase().includes(q)));

        const add = (v) => {
            if (entry(v.model)) return;
            d.catalogue.push({ model: v.model, price: v.price, stock: d.mode === 'job' ? d.settings.stock.start : -1 });
        };

        const pool = el('div', { class: 'bk-pool' }, [
            el('div', { class: 'bk-tools' }, [
                el('input', {
                    class: 'bk-search', type: 'search', placeholder: 'Search every vehicle…', value: C.vq,
                    oninput: (e) => {
                        C.vq = e.target.value;
                        renderCarsKeepFocus();
                    },
                }),
                el('select', {
                    class: 'bk-in bk-sel left',
                    onchange: (e) => {
                        C.vcat = e.target.value;
                        rerender();
                    },
                }, [
                    el('option', { value: 'all', text: 'All categories' }),
                    ...cats.map((c) => el('option', { value: c, text: XS.title(c), selected: c === C.vcat ? true : null })),
                ]),
            ]),
            el('button', {
                class: 'bk-add', type: 'button', text: `+ Add every ${type.label.toLowerCase()} car`,
                onclick: () => {
                    vehicles.filter((v) => typeCats.has(v.category)).forEach(add);
                    markDirty();
                    rerender();
                },
            }),
            el('div', { class: 'bk-rows', id: 'cr-pool', 'data-scroll': 'pool' }, matches.slice(0, LIMIT).map((v) => {
                const has = !!entry(v.model);
                return el('div', { class: `bk-pr ${has ? 'has' : ''}` }, [
                    el('div', {}, [el('b', { text: v.name }), el('span', { text: `${v.brand || '—'} · ${XS.title(v.category)} · ${v.model}` })]),
                    el('span', { class: 'bk-pr-price', text: XS.money(v.price) }),
                    el('button', {
                        class: 'bk-btn', type: 'button', text: has ? 'Added' : 'Add', disabled: has ? true : null,
                        onclick: () => {
                            add(v);
                            markDirty();
                            rerender();
                        },
                    }),
                ]);
            })),
            matches.length > LIMIT ? el('p', { class: 'bk-note', text: `Showing ${LIMIT} of ${matches.length}. Search to narrow it down.` }) : null,
            !vehicles.length ? el('p', { class: 'bk-note', text: 'The framework has no vehicle list, so there is nothing to add from.' }) : null,
        ]);

        const inUse = new Set(d.points.spots.map((s) => s.model));

        const sold = el('div', { class: 'bk-sold' }, [
            el('div', { class: 'bk-sold-head' }, [el('b', { text: `Sold here · ${d.catalogue.length}` }), el('span', { text: 'Price · stock (blank is unlimited)' })]),
            d.catalogue.length
                ? el('div', { class: 'bk-rows', 'data-scroll': 'sold' }, d.catalogue.map((c, index) => el('div', { class: 'bk-sr' }, [
                    el('div', { class: 'bk-sr-photo' }, XS.photo(c.model, c.model)),
                    el('div', { class: 'bk-sr-name' }, [el('b', { text: label(c.model) }), el('span', { text: c.model })]),
                    el('input', {
                        class: 'bk-in', type: 'number', min: 0, value: c.price, title: 'Price',
                        oninput: (e) => {
                            c.price = Math.max(0, Number(e.target.value) || 0);
                            markDirty();
                        },
                    }),
                    el('input', {
                        class: 'bk-in', type: 'number', min: 0, value: c.stock < 0 ? '' : c.stock, placeholder: '∞', title: 'Stock',
                        oninput: (e) => {
                            c.stock = e.target.value === '' ? -1 : Math.max(0, Math.floor(Number(e.target.value) || 0));
                            markDirty();
                        },
                    }),
                    el('button', {
                        class: 'bk-rm', type: 'button', text: '×', title: inUse.has(c.model) ? 'On a showcase spot' : 'Stop selling it',
                        onclick: () => {
                            if (inUse.has(c.model)) {
                                XS.toast('A showcase spot is showing that car. Change the spot first.', 'bad');
                                return;
                            }
                            d.catalogue.splice(index, 1);
                            markDirty();
                            rerender();
                        },
                    }),
                ])))
                : el('p', { class: 'bk-note', text: 'Nothing yet. Add cars from the list on the left.' }),
        ]);

        return el('div', { class: 'bk-page' }, [
            pageHead('cars', 'What is on the floor', 'Every car this dealership sells, what it costs, and how many are in stock.'),
            el('div', { class: 'bk-cars' }, [pool, sold]),
        ]);
    }

    function renderCarsKeepFocus() {
        const input = document.querySelector('#cr-body .bk-search');
        const at = input ? input.selectionStart : null;
        rerender();
        const next = document.querySelector('#cr-body .bk-search');
        if (next) {
            next.focus();
            if (at !== null) next.setSelectionRange(at, at);
        }
    }

    function cover() {
        const count = XS.list(C.data && C.data.dealers).length;

        return el('div', { class: 'bk-cover' }, [
            el('span', { class: 'bk-no', text: String(count).padStart(2, '0') }),
            el('small', { class: 'bk-kick', text: count === 1 ? 'One dealership on the server' : `${count} dealerships on the server` }),
            el('h2', {}, heading('Pick one from\nthe book')),
            el('p', { class: 'bk-blurb', text: 'Or start a new one. Everything about a dealership is set in here and saved for the whole server: what it sells, who runs it, how it takes money, and where every car stands.' }),
        ]);
    }

    function renderList() {
        const host = XS.clear($('cr-list'));
        const dealers = XS.list(C.data && C.data.dealers);

        if (!dealers.length && !(C.draft && !C.draft.id)) {
            host.append(el('p', { class: 'bk-note', text: 'No dealerships yet. Start the first one below.' }));
        }

        dealers.forEach((d) => {
            const on = !!C.draft && C.draft.id === d.id;
            host.append(el('button', {
                class: `bk-dl ${on ? 'on' : ''}`, type: 'button',
                onclick: () => { if (!on) guard(() => select(d)); },
            }, [
                el('b', { text: on && C.draft.name ? C.draft.name : d.name }),
                el('span', { text: `${typeInfo(d.type).label} · ${d.mode === 'job' ? `run by ${d.job}` : 'runs itself'}` }),
                el('em', { text: `${XS.list(d.catalogue).length} cars · ${XS.list(d.points && d.points.spots).length} spots${on && C.dirty ? ' · editing' : ''}` }),
            ]));
        });

        if (C.draft && !C.draft.id) {
            host.append(el('div', { class: 'bk-dl on' }, [el('b', { text: C.draft.name || 'New dealership' }), el('span', { text: 'Not saved yet' })]));
        }
    }

    function renderTabs() {
        const host = XS.clear($('cr-tabs'));
        if (!C.draft) return;

        chapters().forEach((c) => {
            host.append(el('button', {
                class: `bk-chap ${C.tab === c.id ? 'on' : ''}`, type: 'button',
                onclick: () => {
                    C.tab = c.id;
                    renderEditor();
                },
            }, [el('em', { text: c.no }), c.id === 'cars' ? `Cars · ${C.draft.catalogue.length}` : c.title]));
        });
    }

    function renderEditor() {
        if (C.draft && !chapters().some((c) => c.id === C.tab)) C.tab = 'details';

        renderTabs();
        const body = XS.clear($('cr-body'));

        if (!C.draft) {
            body.append(cover());
            renderFooter();
            return;
        }

        const pages = { details: pageDetails, selling: pageSelling, finance: pageFinance, staff: pageStaff, points: pagePoints, cars: pageCars };
        body.append(pages[C.tab]());
        renderFooter();
    }

    function rerender() {
        const kept = [...document.querySelectorAll('#cr-body [data-scroll]')].map((node) => [node.dataset.scroll, node.scrollTop]);
        renderEditor();
        kept.forEach(([key, top]) => {
            const node = document.querySelector(`#cr-body [data-scroll="${key}"]`);
            if (node) node.scrollTop = top;
        });
    }

    function renderFooter() {
        const host = XS.clear($('cr-foot'));
        if (!C.draft) return;

        host.append(
            C.draft.id
                ? el('button', { class: 'bk-del', type: 'button', text: 'Delete', onclick: () => confirmBar(`Delete ${C.draft.name}? Its stock and open orders go with it.`, 'Delete it', remove) })
                : el('span'),
            el('span', { class: `bk-status ${C.dirty ? 'dirty' : ''}`, text: C.dirty ? 'Unsaved changes' : C.draft.id ? 'Saved' : 'Not saved yet' }),
            el('button', { class: 'bk-save', type: 'button', text: C.busy ? 'Saving' : 'Save', disabled: C.busy ? true : null, onclick: save }),
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
        XS.setAccent('#b3121b');
        XS.toast('Dealership deleted.', 'good');
        render();
    }

    function confirmBar(message, yes, onYes) {
        const bar = $('cr-confirm');
        XS.clear(bar).append(
            el('span', { text: message }),
            el('button', { class: 'bk-btn ghost', type: 'button', text: 'Cancel', onclick: () => { bar.hidden = true; } }),
            el('button', {
                class: 'bk-btn danger', type: 'button', text: yes,
                onclick: () => {
                    bar.hidden = true;
                    onYes();
                },
            }),
        );
        bar.hidden = false;
    }

    function guard(next) {
        if (!C.dirty) {
            next();
            return;
        }
        confirmBar('You have unsaved changes. Drop them?', 'Drop them', () => {
            C.dirty = false;
            next();
        });
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
        $('cr-new').addEventListener('click', () => guard(() => select(null)));
    });

    XS.views.creator = { open, close };
})();
