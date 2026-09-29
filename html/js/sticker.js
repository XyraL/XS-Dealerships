(function () {
    const { el } = XS;

    const CEILING = { acceleration: 0.55, braking: 1.8, traction: 3.2 };

    function bar(label, value, ceiling) {
        const pct = Math.max(4, Math.min(100, Math.round(((Number(value) || 0) / ceiling) * 100)));
        return el('div', { class: 'perf-row' }, [
            el('span', { class: 'perf-label', text: label }),
            el('span', { class: 'perf-track' }, el('span', { class: 'perf-fill', style: { width: `${pct}%` } })),
        ]);
    }

    function stockLine(car) {
        if (car.stock < 0) return 'Available now';
        if (car.stock === 0) return car.onOrder > 0 ? `Sold out · ${car.onOrder} on order` : 'Sold out';
        return `${car.stock} in stock${car.onOrder > 0 ? ` · ${car.onOrder} on order` : ''}`;
    }
    XS.stockLine = stockLine;

    XS.sticker = function (car, spec, dealer) {
        spec = spec || {};
        const unit = (XS.config.speedUnit || 'mph').toUpperCase();

        const perf = spec.missing
            ? el('p', { class: 'fine', text: 'This car is not streamed on the server, so there are no figures for it.' })
            : el('div', { class: 'perf' }, [
                el('div', { class: 'perf-top' }, [
                    el('div', { class: 'perf-big' }, [el('b', { text: spec.speed ?? '—' }), el('span', { text: unit })]),
                    el('div', { class: 'perf-meta' }, [
                        el('span', { text: 'TOP SPEED' }),
                        el('span', { text: `${spec.seats ?? '—'} SEATS · ${String(spec.class || '').toUpperCase()}` }),
                    ]),
                ]),
                bar('Acceleration', spec.acceleration, CEILING.acceleration),
                bar('Braking', spec.braking, CEILING.braking),
                bar('Handling', spec.traction, CEILING.traction),
            ]);

        const finance = car.terms
            ? el('section', { class: 'stk-sec' }, [
                el('h4', { text: 'FINANCE' }),
                el('p', { class: 'fin-line' }, [
                    el('b', { text: XS.money(car.terms.payment) }),
                    ` a payment, ${car.terms.payments} payments, every ${XS.duration(car.terms.intervalHours * 3600)}`,
                ]),
                el('p', { class: 'fine', text: `${car.terms.downPayment}% down (${XS.money(car.terms.down)}) · ${car.terms.interest}% on what is financed · ${XS.money(car.terms.down + car.terms.total)} in all` }),
            ])
            : null;

        return el('article', { class: 'sticker' }, [
            el('header', { class: 'stk-head' }, [
                el('span', { text: (dealer && dealer.name ? dealer.name : 'Dealership').toUpperCase() }),
                el('span', { text: 'DEALER WINDOW STICKER' }),
            ]),
            el('div', { class: 'stk-title' }, [
                el('span', { class: 'stk-brand', text: (car.brand || XS.title(car.category)).toUpperCase() }),
                el('h2', { class: 'stk-name', text: car.name }),
                el('span', { class: 'stk-code', text: `MODEL CODE ${String(car.model).toUpperCase()}` }),
            ]),
            el('section', { class: 'stk-sec' }, [el('h4', { text: 'PERFORMANCE' }), perf]),
            el('section', { class: 'stk-sec' }, [
                el('h4', { text: 'STANDARD EQUIPMENT' }),
                el('ul', { class: 'equip' }, [
                    el('li', { text: 'Factory specification, as delivered' }),
                    el('li', { text: 'Paint of your choice at no charge' }),
                    el('li', { text: 'Keys, plates and registration' }),
                    el('li', { text: 'Delivered with a full tank' }),
                ]),
            ]),
            finance,
            el('footer', { class: 'stk-total' }, [
                el('div', {}, [el('span', { class: 'stk-label', text: 'TOTAL PRICE' }), el('b', { class: 'stk-price', text: XS.money(car.price) })]),
                el('span', { class: `stk-stock ${car.stock === 0 ? 'out' : ''}`, text: stockLine(car) }),
            ]),
            el('div', { class: 'stk-barcode' }, [
                el('img', { src: XS.barcode(car.model), alt: '' }),
                el('span', { text: `${String(car.model).toUpperCase()}-${String(car.price).padStart(8, '0')}` }),
            ]),
        ]);
    };

    XS.buyForm = function (car, opts) {
        const cfg = XS.config.paint || {};
        const presets = XS.list(cfg.presets);
        const state = { primary: null, secondary: null, method: null };

        function swatches(slot) {
            const row = el('div', { class: 'swatches' });
            const label = el('span', { class: 'swatch-name', text: 'Factory' });

            function pick(hex, name, node) {
                state[slot] = hex || null;
                label.textContent = name;
                row.querySelectorAll('.swatch').forEach((n) => n.classList.toggle('on', n === node));
            }

            presets.forEach((preset, index) => {
                const node = el('button', {
                    class: `swatch ${preset.hex ? '' : 'factory'} ${index === 0 ? 'on' : ''}`,
                    type: 'button',
                    title: preset.label,
                    style: preset.hex ? { background: preset.hex } : null,
                    onclick: () => pick(preset.hex, preset.label, node),
                });
                row.append(node);
            });

            if (cfg.custom) {
                const input = el('input', { type: 'color', value: '#b3121b', title: 'Any colour' });
                const wrap = el('label', { class: 'swatch custom', title: 'Any colour' }, input);
                input.addEventListener('input', () => pick(input.value, input.value.toUpperCase(), wrap));
                row.append(wrap);
            }

            return el('div', { class: 'paint-slot' }, [
                el('div', { class: 'slot-head' }, [el('span', { text: slot === 'primary' ? 'Main colour' : 'Second colour' }), label]),
                row,
            ]);
        }

        const methods = opts.methods || {};
        const money = opts.money || {};
        const terms = car.terms;
        const choices = [];

        function choice(id, title, lines, disabled, why) {
            const node = el('button', {
                class: 'pay', type: 'button', disabled: disabled ? true : null,
                onclick: () => {
                    state.method = id;
                    choices.forEach((n) => n.classList.toggle('on', n === node));
                    opts.onChange && opts.onChange(state);
                },
            }, [el('b', { text: title }), ...lines.map((line) => el('span', { text: line })), why ? el('em', { text: why }) : null]);
            choices.push(node);
            return node;
        }

        const pays = el('div', { class: 'pays' });
        if (methods.cash) {
            pays.append(choice('cash', 'Cash', [XS.money(car.price)], opts.checkFunds && money.cash < car.price,
                opts.checkFunds && money.cash < car.price ? `You have ${XS.money(money.cash)}` : null));
        }
        if (methods.bank) {
            pays.append(choice('bank', 'Bank', [XS.money(car.price)], opts.checkFunds && money.bank < car.price,
                opts.checkFunds && money.bank < car.price ? `You have ${XS.money(money.bank)}` : null));
        }
        if (methods.finance && terms) {
            pays.append(choice('finance', 'Finance', [
                `${XS.money(terms.down)} down, from the bank`,
                `then ${terms.payments} × ${XS.money(terms.payment)}`,
            ], opts.checkFunds && money.bank < terms.down,
            opts.checkFunds && money.bank < terms.down ? `You have ${XS.money(money.bank)} in the bank` : null));
        }
        if (!pays.children.length) pays.append(el('p', { class: 'fine', text: 'This dealership is not taking payment right now.' }));

        const node = el('div', { class: 'buyform' }, [
            el('h4', { class: 'form-h', text: 'Paint' }),
            swatches('primary'),
            cfg.secondary ? swatches('secondary') : null,
            el('h4', { class: 'form-h', text: 'How are you paying?' }),
            pays,
        ]);

        return {
            node,
            state,
            paint() {
                return { primary: state.primary || false, secondary: state.secondary || false };
            },
            dueNow() {
                if (state.method === 'finance' && terms) return terms.down;
                return state.method ? car.price : null;
            },
        };
    };
})();
