(function () {
    const { el } = XS;

    let timer = null;
    let answered = false;

    function stop() {
        if (timer) clearInterval(timer);
        timer = null;
    }

    function open(offer) {
        stop();
        answered = false;
        XS.setAccent(offer.dealer && offer.dealer.accent);

        const host = XS.clear(document.getElementById('offer'));
        const car = {
            model: offer.model, name: offer.name, brand: offer.brand, category: offer.category,
            price: offer.price, stock: -1, onOrder: 0,
            terms: offer.methods && offer.methods.finance ? offer.terms : null,
        };

        const error = el('p', { class: 'side-error', hidden: true });
        const form = XS.buyForm(car, { methods: offer.methods, checkFunds: false, onChange: () => update() });
        const accept = el('button', { class: 'btn primary', type: 'button', text: 'Choose how to pay', disabled: true });
        const clock = el('span', { class: 'clock', text: '' });
        let left = Number(offer.seconds) || 60;

        function update() {
            const due = form.dueNow();
            accept.disabled = due === null || answered;
            accept.textContent = due === null ? 'Choose how to pay' : form.state.method === 'finance' ? `Accept · ${XS.money(due)} down` : `Accept · ${XS.money(due)}`;
        }

        async function answer(yes) {
            if (answered) return;
            answered = true;
            accept.disabled = true;

            const res = await XS.post('answer', { accept: yes, method: form.state.method, paint: form.paint(), model: offer.model });
            stop();

            if (!res || !res.ok) {
                error.textContent = (res && res.error) || 'The sale did not go through.';
                error.hidden = false;
                accept.textContent = 'Close';
                accept.disabled = false;
                accept.addEventListener('click', () => XS.post('close'));
            }
        }

        accept.addEventListener('click', () => answer(true));

        host.append(
            el('header', { class: 'offer-head' }, [
                el('div', { class: 'offer-title' }, [
                    el('small', { class: 'bk-kick', text: `${(offer.dealer && offer.dealer.name) || 'Dealership'} · An offer` }),
                    el('h1', { text: `${offer.seller} is selling you a car` }),
                ]),
                clock,
            ]),
            el('div', { class: 'offer-body' }, [
                el('div', { class: 'offer-left' }, [
                    el('div', { class: 'offer-photo' }, XS.photo(offer.model, offer.name)),
                    XS.sticker(car, offer.specs, offer.dealer),
                ]),
                el('div', { class: 'offer-right' }, [
                    form.node,
                    el('div', { class: 'checkout' }, [
                        el('div', { class: 'actions' }, [
                            el('button', { class: 'btn ghost', type: 'button', text: 'No thanks', onclick: () => answer(false) }),
                            accept,
                        ]),
                        error,
                    ]),
                ]),
            ]),
        );

        const tick = () => {
            clock.textContent = `${left}s to decide`;
            clock.classList.toggle('late', left <= 10);
            if (left <= 0) {
                stop();
                if (!answered) {
                    answered = true;
                    XS.toast('The offer ran out.', 'bad');
                    XS.post('close');
                }
            }
            left -= 1;
        };
        tick();
        timer = setInterval(tick, 1000);

        XS.show('offer', true);
    }

    function close() {
        stop();
        XS.show('offer', false);
    }

    XS.views.offer = { open, close };
})();
