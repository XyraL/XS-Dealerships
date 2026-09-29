(function () {
    const { el } = XS;

    const S = {
        data: null,
        cars: [],
        specs: {},
        category: 'all',
        query: '',
        selected: null,
        step: 'view',
        tab: 'showroom',
        form: null,
        busy: false,
    };

    const $ = (id) => document.getElementById(id);

    function dealer() {
        return S.data ? S.data.dealer : null;
    }

    function can(action) {
        const allowed = S.data && S.data.can;
        return !!(allowed && allowed[action]);
    }

    function car(model) {
        return S.cars.find((c) => c.model === model) || null;
    }

    function categories() {
        const counts = new Map();
        S.cars.forEach((c) => counts.set(c.category, (counts.get(c.category) || 0) + 1));
        return [['all', S.cars.length], ...[...counts.entries()].sort((a, b) => a[0].localeCompare(b[0]))];
    }

    function visible() {
        const q = S.query.trim().toLowerCase();
        return S.cars.filter((c) => (S.category === 'all' || c.category === S.category)
            && (!q || `${c.brand} ${c.name} ${c.model}`.toLowerCase().includes(q)));
    }

    function renderMast() {
        const d = dealer();
        const typeLabel = { cars: 'Cars', luxury: 'Luxury', bikes: 'Motorcycles', trucks: 'Trucks & vans', boats: 'Boats', aircraft: 'Aircraft' }[d.type] || XS.title(d.type);
        $('sr-kicker').textContent = `${typeLabel} · ${d.mode === 'job' ? 'Staffed dealership' : 'Open to all'}`.toUpperCase();
        $('sr-name').textContent = d.name;

        const tabs = XS.clear($('sr-tabs'));
        const list = [['showroom', 'Showroom'], ['finance', 'My finance']];

        list.forEach(([id, label]) => {
            tabs.append(el('button', {
                class: `tab ${S.tab === id ? 'on' : ''}`, type: 'button', text: label,
                onclick: () => setTab(id),
            }));
        });
    }

    function setTab(tab) {
        S.tab = tab;
        renderMast();
        document.querySelectorAll('#showroom .pane').forEach((pane) => { pane.hidden = pane.dataset.pane !== tab; });

        if (tab === 'finance') XS.views.finance.render($('fin-list'), S.data.finance, { onUpdate: (list) => { S.data.finance = list; } });
    }

    function renderIndex() {
        const host = XS.clear($('sr-cats'));
        categories().forEach(([id, count]) => {
            host.append(el('button', {
                class: `cat ${S.category === id ? 'on' : ''}`, type: 'button',
                onclick: () => { S.category = id; renderIndex(); renderGrid(); },
            }, [el('span', { text: id === 'all' ? 'Everything' : XS.title(id) }), el('em', { text: count })]));
        });
    }

    function renderGrid() {
        const host = XS.clear($('sr-grid'));
        const cars = visible();

        if (!S.cars.length) {
            host.append(el('div', { class: 'empty' }, [el('b', { text: 'Nothing on the floor yet.' }), el('span', { text: 'This dealership has no cars in its catalogue.' })]));
            return;
        }
        if (!cars.length) {
            host.append(el('div', { class: 'empty' }, [el('b', { text: 'No cars match.' }), el('span', { text: 'Try another name or chapter.' })]));
            return;
        }

        cars.forEach((c, i) => {
            const card = el('button', {
                class: `card ${S.selected === c.model ? 'on' : ''} ${c.stock === 0 ? 'soldout' : ''}`,
                type: 'button', style: { animationDelay: `${Math.min(i, 12) * 22}ms` },
                onclick: () => select(c.model),
            }, [
                el('div', { class: 'card-photo' }, XS.photo(c.model, c.name)),
                el('div', { class: 'card-body' }, [
                    el('span', { class: 'card-brand', text: (c.brand || XS.title(c.category)).toUpperCase() }),
                    el('b', { class: 'card-name', text: c.name }),
                    el('div', { class: 'card-foot' }, [
                        el('span', { class: 'card-price', text: XS.money(c.price) }),
                        el('span', { class: `chip ${c.stock === 0 ? 'out' : c.stock > 0 ? 'count' : ''}`, text: c.stock < 0 ? 'Available' : c.stock === 0 ? 'Sold out' : `${c.stock} left` }),
                    ]),
                ]),
            ]);
            host.append(card);
        });
    }

    function renderBanner() {
        const banner = $('sr-banner');
        const ctx = S.data.context || {};

        if (ctx.swap) {
            banner.hidden = false;
            banner.textContent = 'Pick the car to put on this display spot.';
        } else if (!can('buy')) {
            banner.hidden = false;
            const staff = S.data.staffOnDuty || 0;
            banner.textContent = staff > 0
                ? `Cars here are sold by the staff. ${staff} salesperson${staff === 1 ? ' is' : 's are'} working now.`
                : 'Cars here are sold by the staff, and nobody is working right now.';
        } else {
            banner.hidden = true;
        }
    }

    function select(model, step) {
        S.selected = model;
        S.step = step || 'view';
        S.form = null;
        document.querySelectorAll('#sr-grid .card').forEach((n) => n.classList.remove('on'));
        renderGrid();
        renderSide();
    }

    function button(label, kind, action, disabled) {
        return el('button', { class: `btn ${kind || ''}`, type: 'button', disabled: disabled ? true : null, onclick: action, text: label });
    }

    function sideError(message) {
        const node = document.querySelector('#sr-side .side-error');
        if (node) {
            node.textContent = message || '';
            node.hidden = !message;
        }
    }

    function renderSide() {
        const host = XS.clear($('sr-side'));
        const c = car(S.selected);

        if (!c) {
            host.append(el('div', { class: 'side-empty' }, [el('b', { text: 'Pick a car' }), el('span', { text: 'Its window sticker shows up here.' })]));
            return;
        }

        if (S.step === 'buy') return renderBuy(host, c);
        if (S.step === 'sell') return renderSell(host, c);

        host.append(el('div', { class: 'side-scroll' }, XS.sticker(c, S.specs[c.model], dealer())));

        const ctx = S.data.context || {};
        const role = S.data.role || {};
        const actions = el('div', { class: 'actions' });

        if (ctx.swap && can('swap')) {
            actions.append(button('Show this one here', 'primary', () => swap(c)));
        }

        if (can('buy')) {
            actions.append(button(c.stock === 0 ? 'Sold out' : 'Buy', ctx.swap ? '' : 'primary', () => { S.step = 'buy'; renderSide(); }, c.stock === 0));
        }

        if (S.data.testDrives && can('test')) actions.append(button('Test drive', '', () => testDrive(c)));

        if (!can('buy') && !role.staff) {
            actions.append(el('p', { class: 'fine', text: 'Ask one of the salespeople to sell you this car.' }));
        }

        if (role.canSell) {
            actions.append(button('Sell to a customer', '', () => { S.step = 'sell'; renderSide(); }, c.stock === 0));
        }

        host.append(actions, el('p', { class: 'side-error', hidden: true }));
    }

    function renderBuy(host, c) {
        const form = XS.buyForm(c, {
            methods: S.data.methods, money: S.data.money, checkFunds: true,
            onChange: () => update(),
        });
        S.form = form;

        const due = el('b', { class: 'due', text: '—' });
        const confirm = button('Choose how to pay', 'primary', () => buy(c), true);

        function update() {
            const amount = form.dueNow();
            due.textContent = amount === null ? '—' : XS.money(amount);
            confirm.disabled = amount === null || S.busy;
            confirm.textContent = form.state.method === 'finance' ? `Pay ${XS.money(amount)} down` : amount === null ? 'Choose how to pay' : `Buy for ${XS.money(amount)}`;
        }

        host.append(
            el('div', { class: 'side-scroll' }, [
                el('div', { class: 'mini' }, [
                    el('div', { class: 'mini-photo' }, XS.photo(c.model, c.name)),
                    el('div', {}, [el('span', { class: 'card-brand', text: (c.brand || '').toUpperCase() }), el('b', { class: 'mini-name', text: c.name }), el('span', { class: 'fine', text: XS.stockLine(c) })]),
                ]),
                form.node,
            ]),
            el('div', { class: 'checkout' }, [
                el('div', { class: 'due-row' }, [el('span', { text: 'Due now' }), due]),
                el('div', { class: 'actions' }, [button('Back', 'ghost', () => { S.step = 'view'; renderSide(); }), confirm]),
                el('p', { class: 'side-error', hidden: true }),
            ]),
        );
    }

    async function renderSell(host, c) {
        let target = null;
        const list = el('div', { class: 'people' }, el('p', { class: 'fine', text: 'Looking for customers nearby…' }));
        const send = button('Send the offer', 'primary', () => offer(c, target), true);

        host.append(
            el('div', { class: 'side-scroll' }, [
                el('div', { class: 'mini' }, [
                    el('div', { class: 'mini-photo' }, XS.photo(c.model, c.name)),
                    el('div', {}, [el('span', { class: 'card-brand', text: (c.brand || '').toUpperCase() }), el('b', { class: 'mini-name', text: c.name }), el('span', { class: 'fine', text: XS.money(c.price) })]),
                ]),
                el('h4', { class: 'form-h', text: 'Who is buying?' }),
                list,
                el('p', { class: 'fine', text: 'They pick the paint and how they pay. Your commission is paid when they accept.' }),
            ]),
            el('div', { class: 'checkout' }, [
                el('div', { class: 'actions' }, [button('Back', 'ghost', () => { S.step = 'view'; renderSide(); }), send]),
                el('p', { class: 'side-error', hidden: true }),
            ]),
        );

        const people = XS.list(await XS.post('nearby', { dealer: dealer().id }));
        XS.clear(list);

        if (!people.length) {
            list.append(el('p', { class: 'fine', text: 'Nobody is standing close enough.' }));
            return;
        }

        people.forEach((p) => {
            const node = el('button', {
                class: 'person', type: 'button',
                onclick: () => {
                    target = p.id;
                    list.querySelectorAll('.person').forEach((n) => n.classList.toggle('on', n === node));
                    send.disabled = false;
                },
            }, [el('b', { text: p.name }), el('span', { text: `ID ${p.id}` })]);
            list.append(node);
        });
    }

    async function buy(c) {
        if (S.busy || !S.form) return;
        S.busy = true;
        sideError('');

        const res = await XS.post('buy', {
            dealer: dealer().id, model: c.model, method: S.form.state.method, paint: S.form.paint(),
        });

        S.busy = false;
        if (!res || !res.ok) sideError((res && res.error) || 'The purchase did not go through.');
    }

    async function offer(c, target) {
        if (!target) return;

        const res = await XS.post('offer', { dealer: dealer().id, model: c.model, target });
        if (!res || !res.ok) {
            sideError((res && res.error) || 'The offer could not be sent.');
            return;
        }

        XS.toast(`Offer sent for the ${c.name}. It is up to them now.`, 'good');
        S.step = 'view';
        renderSide();
    }

    async function testDrive(c) {
        const res = await XS.post('testDrive', { dealer: dealer().id, model: c.model });
        if (!res || !res.ok) sideError((res && res.error) || 'No test drive right now.');
    }

    async function swap(c) {
        const ctx = S.data.context || {};
        const res = await XS.post('swap', { dealer: dealer().id, spot: ctx.spot, model: c.model });
        if (!res || !res.ok) {
            sideError((res && res.error) || 'The car could not be swapped.');
            return;
        }
        XS.post('close');
    }

    function open(data) {
        S.data = data;
        S.cars = XS.list(data.cars);
        S.specs = data.specs && typeof data.specs === 'object' && !Array.isArray(data.specs) ? data.specs : {};
        S.category = 'all';
        S.query = '';
        S.busy = false;

        const ctx = data.context || {};
        S.tab = ctx.tab === 'finance' ? 'finance' : 'showroom';

        XS.setAccent(data.dealer.settings && data.dealer.settings.accent);

        const focus = ctx.focus && car(ctx.focus) ? ctx.focus : (S.cars[0] && S.cars[0].model);
        S.selected = focus || null;
        S.step = ctx.step === 'buy' && can('buy') ? 'buy' : ctx.step === 'sell' && data.role && data.role.canSell ? 'sell' : 'view';

        $('sr-search').value = '';
        renderMast();
        renderBanner();
        renderIndex();
        renderGrid();
        renderSide();
        setTab(S.tab);

        XS.show('showroom', true);

        const selected = document.querySelector('#sr-grid .card.on');
        if (selected) selected.scrollIntoView({ block: 'nearest' });
    }

    function close() {
        XS.show('showroom', false);
        S.data = null;
    }

    document.addEventListener('DOMContentLoaded', () => {
        $('sr-search').addEventListener('input', (e) => {
            S.query = e.target.value;
            renderGrid();
        });
        $('sr-close').addEventListener('click', () => XS.post('close'));
    });

    XS.views.showroom = { open, close };
})();
