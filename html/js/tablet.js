(function () {
    const { el } = XS;

    const T = { dealers: [], data: null, tab: 'stock', ticker: null, clock: null };
    const $ = (id) => document.getElementById(id);

    const TABS = [
        ['stock', 'Stock', '▦'],
        ['orders', 'Orders', '⇣'],
        ['money', 'Money', '$', true],
        ['sales', 'Sales', '✓', true],
        ['team', 'Team', '☺'],
    ];

    function dealerId() {
        return T.data && T.data.dealer ? T.data.dealer.id : null;
    }

    function role() {
        return (T.data && T.data.role) || {};
    }

    function stop() {
        if (T.ticker) clearInterval(T.ticker);
        T.ticker = null;
    }

    function update(data) {
        if (!data) return;
        T.data = data;
        render();
    }

    function stockPanel() {
        const data = T.data;
        const canOrder = role().canOrder;
        const table = el('div', { class: 'ledger' });

        table.append(el('div', { class: 'lg-row lg-head' }, [
            el('span', { text: 'Car' }), el('span', { text: 'In stock' }), el('span', { text: 'On order' }),
            el('span', { text: 'Cost each' }), el('span', { text: canOrder ? 'Order' : '' }),
        ]));

        XS.list(data.stock).forEach((car) => {
            let quantity = 1;
            const count = el('b', { class: 'qty-n', text: '1' });
            const orderBtn = el('button', { class: 'btn small', type: 'button' });

            const step = (by) => {
                quantity = Math.max(1, Math.min(data.order.maxPerOrder, quantity + by));
                count.textContent = String(quantity);
                orderBtn.textContent = `Order · ${XS.money(car.unitCost * quantity)}`;
            };

            orderBtn.addEventListener('click', async () => {
                orderBtn.disabled = true;
                const res = await XS.post('order', { dealer: dealerId(), model: car.model, quantity });
                orderBtn.disabled = false;
                if (!res || !res.ok) {
                    XS.toast((res && res.error) || 'The order did not go through.', 'bad');
                    return;
                }
                XS.toast(`${quantity} × ${car.name} ordered. Arriving in ${XS.duration(data.order.deliveryMinutes * 60)}.`, 'good');
                update(res.office);
            });

            const unlimited = car.stock < 0;
            step(0);

            table.append(el('div', { class: `lg-row ${car.stock === 0 ? 'out' : ''}` }, [
                el('span', { class: 'lg-car' }, [el('b', { text: car.name }), el('em', { text: car.brand || XS.title(car.category) })]),
                el('span', { class: 'lg-num', text: unlimited ? 'Always' : car.stock }),
                el('span', { class: 'lg-num', text: car.onOrder || '—' }),
                el('span', { class: 'lg-num', text: unlimited ? '—' : XS.money(car.unitCost) }),
                canOrder && !unlimited
                    ? el('span', { class: 'lg-order' }, [
                        el('button', { class: 'qty', type: 'button', text: '−', onclick: () => step(-1) }),
                        count,
                        el('button', { class: 'qty', type: 'button', text: '+', onclick: () => step(1) }),
                        orderBtn,
                    ])
                    : el('span', {}),
            ]));
        });

        const cars = XS.list(data.stock);
        const out = cars.filter((c) => c.stock === 0).length;
        const low = cars.filter((c) => c.stock > 0 && c.stock <= 1).length;

        return [
            el('div', { class: 'tb-kpis' }, [
                kpi('Cars sold here', cars.length),
                kpi('Sold out', out, out > 0 ? 'bad' : ''),
                kpi('One left', low, low > 0 ? 'warn' : ''),
                kpi('On the way', XS.list(data.orders).reduce((n, o) => n + o.quantity, 0)),
            ]),
            el('section', { class: 'panel' }, [
                el('h3', { text: 'Stock' }),
                canOrder ? el('p', { class: 'fine', text: `Orders are paid from the business account at ${data.order.wholesale}% of the price and arrive in ${XS.duration(data.order.deliveryMinutes * 60)}.` })
                    : el('p', { class: 'fine', text: 'Your grade cannot order stock.' }),
                table,
            ]),
        ];
    }

    function kpi(label, value, kind) {
        return el('div', { class: `kpi ${kind || ''}` }, [el('span', { text: label }), el('b', { text: value })]);
    }

    function ordersPanel() {
        const orders = XS.list(T.data.orders);
        const list = orders.length
            ? el('div', { class: 'orders' }, orders.map((o) => el('div', { class: 'order' }, [
                el('b', { text: `${o.quantity} × ${o.name}` }),
                el('span', { text: `Ordered by ${o.by || 'staff'} · ${XS.money(o.cost)}` }),
                el('em', { class: 'eta', 'data-left': o.arrivesIn, text: o.arrivesIn > 0 ? `Arrives in ${XS.duration(o.arrivesIn)}` : 'Arriving now' }),
            ])))
            : el('p', { class: 'fine', text: 'Nothing on the way. Order from the Stock page.' });

        return [el('section', { class: 'panel' }, [
            el('h3', { text: 'On the way' }),
            el('p', { class: 'fine', text: `Up to ${T.data.order.maxPending} orders at once. Staff on duty get a message when one arrives.` }),
            list,
        ])];
    }

    function moneyPanel() {
        const data = T.data;
        const amount = el('input', { type: 'number', min: 1, placeholder: 'Amount', class: 'tb-amount' });

        const move = async (direction) => {
            const value = Math.floor(Number(amount.value) || 0);
            if (value <= 0) {
                XS.toast('Enter an amount first.', 'bad');
                return;
            }
            const res = await XS.post('moveMoney', { dealer: dealerId(), direction, amount: value });
            if (!res || !res.ok) {
                XS.toast((res && res.error) || 'That did not go through.', 'bad');
                return;
            }
            XS.toast(direction === 'withdraw' ? `${XS.money(value)} moved to your bank.` : `${XS.money(value)} paid into the business.`, 'good');
            update(res.office);
        };

        const rows = XS.list(data.ledger);

        return [
            el('div', { class: 'tb-split' }, [
                el('section', { class: 'panel account' }, [
                    el('h3', { text: 'Business account' }),
                    el('b', { class: 'balance', text: XS.money(data.balance) }),
                    el('span', { class: 'fine', text: data.bank === 'ledger' ? 'Kept in the dealership’s own books.' : `Held with ${data.bank}.` }),
                ]),
                el('section', { class: 'panel' }, [
                    el('h3', { text: 'Move money' }),
                    amount,
                    el('div', { class: 'actions tight' }, [
                        el('button', { class: 'btn', type: 'button', text: 'Pay in', onclick: () => move('deposit') }),
                        el('button', { class: 'btn primary', type: 'button', text: 'Take out', onclick: () => move('withdraw') }),
                    ]),
                    el('p', { class: 'fine', text: 'Moves money between the business and your own bank.' }),
                ]),
            ]),
            el('section', { class: 'panel' }, [
                el('h3', { text: 'Transactions' }),
                rows.length
                    ? el('div', { class: 'tx-list' }, rows.map((r) => el('div', { class: 'tx' }, [
                        el('div', {}, [el('b', { text: r.note || XS.title(r.kind) }), el('span', { text: `${r.by || '—'} · ${XS.ago(r.at)}` })]),
                        el('b', { class: `tx-amt ${r.amount < 0 ? 'out' : 'in'}`, text: `${r.amount < 0 ? '−' : '+'}${XS.money(Math.abs(r.amount))}` }),
                    ])))
                    : el('p', { class: 'fine', text: 'No money has moved yet.' }),
            ]),
        ];
    }

    function salesPanel() {
        const sales = XS.list(T.data.sales);
        const total = sales.reduce((n, s) => n + s.price, 0);

        return [
            el('div', { class: 'tb-kpis' }, [
                kpi('Sales shown', sales.length),
                kpi('Worth', XS.money(total)),
                kpi('Commission paid', XS.money(sales.reduce((n, s) => n + (s.commission || 0), 0))),
            ]),
            el('section', { class: 'panel' }, [
                el('h3', { text: 'Sales' }),
                sales.length
                    ? el('div', { class: 'sales' }, sales.map((s) => el('div', { class: 'sale' }, [
                        el('div', {}, [el('b', { text: s.name }), el('span', { text: `${s.buyer}${s.seller ? ` · sold by ${s.seller}` : ' · bought direct'} · ${s.plate}` })]),
                        el('div', { class: 'sale-r' }, [
                            el('b', { text: XS.money(s.price) }),
                            el('span', { text: `${XS.title(s.method)}${s.commission ? ` · ${XS.money(s.commission)} commission` : ''} · ${XS.ago(s.at)}` }),
                        ]),
                    ])))
                    : el('p', { class: 'fine', text: 'No sales yet.' }),
            ]),
        ];
    }

    function teamPanel() {
        const members = XS.list(T.data.team);

        return [el('section', { class: 'panel' }, [
            el('h3', { text: 'Team this week' }),
            members.length
                ? el('div', { class: 'team' }, members.map((m) => el('div', { class: 'member' }, [
                    el('span', { class: `dot ${m.onDuty ? 'on' : m.online ? 'idle' : ''}`, title: m.onDuty ? 'On duty' : m.online ? 'Off duty' : 'Offline' }),
                    el('div', { class: 'member-name' }, [el('b', { text: m.name }), el('span', { text: m.onDuty ? 'On duty' : m.online ? 'Off duty' : 'Offline' })]),
                    el('span', { class: 'member-n', text: `${m.sales} sale${m.sales === 1 ? '' : 's'}` }),
                    el('b', { class: 'member-c', text: XS.money(m.commission) }),
                ])))
                : el('p', { class: 'fine', text: 'Nobody from the team is around.' }),
            el('p', { class: 'fine', text: 'Sales and commission from the last seven days.' }),
        ])];
    }

    function renderRail() {
        const nav = XS.clear($('tb-nav'));
        const boss = role().isBoss;

        TABS.forEach(([id, label, glyph, bossOnly]) => {
            if (bossOnly && !boss) return;
            nav.append(el('button', {
                class: `tb-tab ${T.tab === id ? 'on' : ''}`, type: 'button',
                onclick: () => { T.tab = id; render(); },
            }, [el('span', { class: 'tb-glyph', text: glyph }), el('span', { text: label })]));
        });

        $('tb-name').textContent = T.data.dealer.name;

        const switcher = $('tb-switch');
        XS.clear(switcher);
        switcher.hidden = T.dealers.length < 2;
        T.dealers.forEach((d) => switcher.append(el('option', { value: d.id, text: d.name, selected: d.id === dealerId() ? true : null })));

        const r = role();
        $('tb-duty').textContent = `${T.data.onDuty} on duty · you: grade ${r.grade}${r.isBoss ? ', boss' : ''}${r.canSell ? ` · ${r.commission}% commission` : ''}`;
    }

    function render() {
        stop();
        XS.setAccent(T.data.dealer.accent);

        if (!role().isBoss && (T.tab === 'money' || T.tab === 'sales')) T.tab = 'stock';
        renderRail();

        const main = XS.clear($('tb-main'));
        const title = TABS.find((t) => t[0] === T.tab)[1];
        main.append(el('div', { class: 'tb-head' }, [el('span', { class: 'kicker', text: 'DEALER MANAGEMENT' }), el('h2', { text: title })]));

        const panels = { stock: stockPanel, orders: ordersPanel, money: moneyPanel, sales: salesPanel, team: teamPanel }[T.tab]();
        panels.forEach((p) => main.append(p));

        T.ticker = setInterval(() => {
            main.querySelectorAll('.eta').forEach((node) => {
                const left = Math.max(0, Number(node.dataset.left) - 1);
                node.dataset.left = left;
                node.textContent = left > 0 ? `Arrives in ${XS.duration(left)}` : 'Arriving now';
            });
        }, 1000);
    }

    function tick() {
        const now = new Date();
        $('tb-time').textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    }

    function open(payload) {
        T.dealers = XS.list(payload.dealers);
        T.data = payload.data;
        T.tab = 'stock';
        render();
        tick();
        if (T.clock) clearInterval(T.clock);
        T.clock = setInterval(tick, 15000);
        XS.show('tablet', true);
    }

    function close() {
        stop();
        if (T.clock) clearInterval(T.clock);
        T.clock = null;
        XS.show('tablet', false);
    }

    document.addEventListener('DOMContentLoaded', () => {
        $('tb-close').addEventListener('click', () => XS.post('close'));
        $('tb-switch').addEventListener('change', async (e) => {
            const res = await XS.post('tablet', { dealer: Number(e.target.value) });
            if (!res || !res.ok) {
                XS.toast((res && res.error) || 'That dealership would not open.', 'bad');
                return;
            }
            T.dealers = XS.list(res.data.dealers);
            update(res.data.data);
        });
    });

    XS.views.tablet = { open, close, stop };
})();
