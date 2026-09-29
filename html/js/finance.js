(function () {
    const { el } = XS;

    function statement(row, redraw) {
        const held = row.status === 'held';
        const due = row.dueIn <= 0 ? 'due now' : `in ${XS.duration(row.dueIn)}`;

        async function act(request, done) {
            const res = await request;
            if (!res || !res.ok) {
                XS.toast((res && res.error) || 'That did not go through.', 'bad');
                return;
            }
            XS.toast(done, 'good');
            redraw(XS.list(res.finance));
        }

        const figures = el('div', { class: 'st-figures' }, [
            el('div', {}, [el('span', { text: held ? 'To get it back' : 'Left to pay' }), el('b', { text: XS.money(row.balance) })]),
            held
                ? el('div', {}, [el('span', { text: 'Held for' }), el('b', { text: row.heldFor > 0 ? XS.duration(row.heldFor) : 'expired' })])
                : el('div', {}, [el('span', { text: 'Next payment' }), el('b', { text: XS.money(row.payment) }), el('em', { text: due })]),
            held ? null : el('div', {}, [el('span', { text: 'Payments left' }), el('b', { text: row.paymentsLeft })]),
        ]);

        const warn = !held && row.missed > 0
            ? el('p', { class: 'st-warn', text: `${row.missed} of ${row.missedLimit} payments missed. One more short and the dealership takes it back.` })
            : null;

        const actions = el('div', { class: 'actions' });
        if (held) {
            actions.append(
                el('p', { class: 'fine', text: 'The dealership took this car back. Pay what is left and it goes back in your garage.' }),
                el('button', { class: 'btn primary', type: 'button', text: `Pay ${XS.money(row.balance)} and get it back`, onclick: () => act(XS.post('recover', { id: row.id }), `The ${row.name} is back in your garage.`) }),
            );
        } else {
            actions.append(
                el('button', { class: 'btn', type: 'button', text: `Pay ${XS.money(row.payment)} now`, onclick: () => act(XS.post('pay', { id: row.id }), 'Payment made.') }),
                el('button', { class: 'btn primary', type: 'button', text: `Pay it all off: ${XS.money(row.balance)}`, onclick: () => act(XS.post('pay', { id: row.id, everything: true }), `The ${row.name} is paid off.`) }),
            );
        }

        return el('article', { class: `statement ${held ? 'held' : ''}` }, [
            el('header', { class: 'st-head' }, [
                el('div', { class: 'st-photo' }, XS.photo(row.model, row.name)),
                el('div', {}, [
                    el('span', { class: 'card-brand', text: `${(row.brand || '').toUpperCase()}${row.brand ? ' · ' : ''}${row.dealer.toUpperCase()}` }),
                    el('b', { class: 'st-name', text: row.name }),
                    el('span', { class: 'plate', text: row.plate }),
                ]),
                el('span', { class: `badge ${held ? 'bad' : 'ok'}`, text: held ? 'Held' : 'Active' }),
            ]),
            figures,
            warn,
            actions,
        ]);
    }

    function render(host, list, opts) {
        XS.clear(host);
        list = XS.list(list);

        const redraw = (next) => {
            if (opts && opts.onUpdate) opts.onUpdate(next);
            render(host, next, opts);
        };

        if (!list.length) {
            host.append(el('div', { class: 'empty' }, [
                el('b', { text: 'No finance agreements.' }),
                el('span', { text: 'Cars you buy on finance show up here, with what is left to pay and when.' }),
            ]));
            return;
        }

        host.append(el('div', { class: 'statements' }, list.map((row) => statement(row, redraw))));
    }

    XS.views.finance = { render };
})();
