(function () {
    const { el } = XS;

    const T = { dealers: [], data: null, tab: 'floor', sell: null, ticker: null, clock: null };
    const $ = (id) => document.getElementById(id);

    const TABS = [
        ['floor', 'Floor'],
        ['stock', 'Stock'],
        ['orders', 'Orders'],
        ['money', 'Money', true],
        ['sales', 'Sales', true],
        ['team', 'Team'],
    ];

    function visibleTabs() {
        const boss = role().isBoss;
        return TABS.filter(([, , bossOnly]) => !bossOnly || boss)
            .map(([id, label], index) => ({ id, label, no: String(index + 1).padStart(2, '0') }));
    }

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

    function carLabel(car) {
        return `${car.brand ? `${car.brand} ` : ''}${car.name}`;
    }

    function stockText(stock) {
        if (stock < 0) return 'Always in stock';
        if (stock === 0) return 'Sold out';
        return `${stock} in stock`;
    }

    async function swap(spot, model) {
        const res = await XS.post('tabletSwap', { dealer: dealerId(), spot: spot.id, model });
        if (!res || !res.ok) {
            XS.toast((res && res.error) || 'The display did not change.', 'bad');
            render();
            return;
        }
        const car = XS.list(T.data.stock).find((c) => c.model === model);
        XS.toast(`Spot ${spot.number} now shows the ${car ? car.name : model}.`, 'good');
        update(res.office);
    }

    function openSell(model) {
        const sellable = XS.list(T.data.stock).filter((c) => c.stock !== 0);
        T.sell = { model: model || (sellable[0] && sellable[0].model) || null };
        render();
    }

    function floorCard(spot, cars, canSell) {
        const swapped = spot.model !== spot.own;
        const picker = el('select', { class: 'bk-in bk-sel left fl-pick', title: 'Show a different car here' },
            cars.map((car) => el('option', { value: car.model, text: carLabel(car), selected: car.model === spot.model ? true : null })));
        picker.addEventListener('change', () => swap(spot, picker.value));

        return el('article', { class: `fl-card ${swapped ? 'swapped' : ''}` }, [
            el('div', { class: 'fl-photo' }, XS.photo(spot.model, spot.name)),
            el('div', { class: 'fl-body' }, [
                el('span', { class: 'fl-spot', text: swapped ? `Spot ${spot.number} · swapped` : `Spot ${spot.number}` }),
                el('b', { class: 'fl-name', text: spot.name }),
                el('span', { class: 'fl-meta', text: `${XS.money(spot.price)} · ${stockText(spot.stock)}` }),
                el('label', { class: 'fl-change' }, [el('span', { text: 'Show' }), picker]),
                swapped ? el('button', { class: 'fl-reset', type: 'button', text: `Put the ${spot.ownName} back`, onclick: () => swap(spot, spot.own) }) : null,
                el('button', {
                    class: 'btn small primary fl-sell', type: 'button',
                    text: spot.stock === 0 ? 'Sold out' : 'Sell this car',
                    disabled: !canSell || spot.stock === 0 ? true : null,
                    onclick: () => openSell(spot.model),
                }),
            ]),
        ]);
    }

    function floorPanel() {
        const spots = XS.list(T.data.floor);
        const cars = XS.list(T.data.stock);
        const canSell = role().canSell;

        return [
            el('section', { class: 'panel' }, [
                el('h3', { text: `On display · ${spots.length}` }),
                el('p', {
                    class: 'fine',
                    text: canSell
                        ? 'Change what a spot shows, or sell its car to a customer standing with you. Everyone at the dealership sees the change.'
                        : 'Change what a spot shows. Your grade cannot sell.',
                }),
                spots.length
                    ? el('div', { class: 'fl-grid' }, spots.map((spot) => floorCard(spot, cars, canSell)))
                    : el('p', { class: 'fine', text: 'This dealership has no showcase spots yet. They are placed in /dealerships.' }),
            ]),
            canSell && cars.length
                ? el('button', { class: 'btn wide', type: 'button', text: 'Sell any car', onclick: () => openSell(null) })
                : null,
        ].filter(Boolean);
    }

    function sellPanel() {
        const cars = XS.list(T.data.stock);
        const sellable = cars.filter((c) => c.stock !== 0);
        const back = el('button', {
            class: 'btn ghost small sl-back', type: 'button', text: 'Back to the floor',
            onclick: () => { T.sell = null; render(); },
        });

        let car = cars.find((c) => c.model === T.sell.model && c.stock !== 0) || sellable[0] || null;
        if (!car) return [back, el('p', { class: 'fine', text: 'Nothing here is in stock to sell.' })];

        let target = null;
        const photo = el('div', { class: 'sl-photo' });
        const brand = el('span', { class: 'sl-brand' });
        const name = el('b', { class: 'sl-name' });
        const meta = el('span', { class: 'sl-meta' });

        const show = () => {
            XS.clear(photo).append(XS.photo(car.model, car.name));
            brand.textContent = car.brand || XS.title(car.category);
            name.textContent = car.name;
            meta.textContent = `${XS.money(car.price)} · ${stockText(car.stock)}`;
        };

        const picker = el('select', { class: 'bk-in bk-sel left sl-pick' },
            sellable.map((c) => el('option', { value: c.model, text: carLabel(c), selected: c.model === car.model ? true : null })));
        picker.addEventListener('change', () => {
            car = sellable.find((c) => c.model === picker.value) || car;
            T.sell.model = car.model;
            show();
        });

        const people = el('div', { class: 'people' });
        const send = el('button', { class: 'btn primary', type: 'button', text: 'Send the offer', disabled: true });

        const look = async () => {
            target = null;
            send.disabled = true;
            XS.clear(people).append(el('p', { class: 'fine', text: 'Looking for customers nearby…' }));

            const list = XS.list(await XS.post('nearby', { dealer: dealerId() }));
            XS.clear(people);

            if (!list.length) {
                people.append(el('p', { class: 'fine', text: 'Nobody is standing close enough. Bring them over and look again.' }));
                return;
            }

            list.forEach((p) => {
                const node = el('button', {
                    class: 'person', type: 'button',
                    onclick: () => {
                        target = p.id;
                        people.querySelectorAll('.person').forEach((n) => n.classList.toggle('on', n === node));
                        send.disabled = false;
                    },
                }, [el('b', { text: p.name }), el('span', { text: `ID ${p.id}` })]);
                people.append(node);
            });
        };

        send.addEventListener('click', async () => {
            if (!target) return;
            send.disabled = true;

            const res = await XS.post('offer', { dealer: dealerId(), model: car.model, target });
            if (!res || !res.ok) {
                XS.toast((res && res.error) || 'The offer could not be sent.', 'bad');
                send.disabled = false;
                return;
            }

            XS.toast(`Offer sent for the ${car.name}. It is up to them now.`, 'good');
            T.sell = null;
            render();
        });

        show();
        look();

        return [
            back,
            el('div', { class: 'sl-view' }, [
                el('section', { class: 'panel sl-car' }, [
                    el('h3', { text: 'The car' }),
                    photo, brand, name, meta,
                    el('label', { class: 'fl-change' }, [el('span', { text: 'Car' }), picker]),
                ]),
                el('section', { class: 'panel' }, [
                    el('h3', { text: 'Who is buying?' }),
                    people,
                    el('div', { class: 'actions tight sl-send' }, [
                        el('button', { class: 'btn', type: 'button', text: 'Look again', onclick: look }),
                        send,
                    ]),
                    el('p', { class: 'fine', text: 'They pick the paint and how they pay. Your commission is paid when they accept.' }),
                ]),
            ]),
        ];
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
                el('h3', { text: 'Every car here' }),
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
                el('h3', { text: 'Latest sales' }),
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

        visibleTabs().forEach((tab) => {
            nav.append(el('button', {
                class: `tb-tab ${T.tab === tab.id ? 'on' : ''}`, type: 'button',
                onclick: () => {
                    T.tab = tab.id;
                    T.sell = null;
                    render();
                },
            }, [el('em', { text: tab.no }), el('span', { text: tab.label })]));
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

        if (!role().isBoss && (T.tab === 'money' || T.tab === 'sales')) T.tab = 'floor';
        if (T.tab !== 'floor') T.sell = null;
        renderRail();

        const main = XS.clear($('tb-main'));
        const page = visibleTabs().find((t) => t.id === T.tab);
        main.append(el('div', { class: 'tb-head' }, [
            el('span', { class: 'bk-no', text: page.no }),
            el('small', { class: 'bk-kick', text: T.data.dealer.name }),
            el('h2', { text: page.label }),
        ]));

        const pages = { floor: floorPanel, stock: stockPanel, orders: ordersPanel, money: moneyPanel, sales: salesPanel, team: teamPanel };
        const panels = T.tab === 'floor' && T.sell ? sellPanel() : pages[T.tab]();
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
        T.tab = 'floor';
        T.sell = null;
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
            T.sell = null;
            update(res.data.data);
        });
    });

    XS.views.tablet = { open, close, stop };
})();
