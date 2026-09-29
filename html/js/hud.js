(function () {
    let timer = null;

    function stop() {
        if (timer) clearInterval(timer);
        timer = null;
        XS.show('testdrive', false);
    }

    function start(seconds) {
        stop();
        const total = Math.max(1, Number(seconds) || 60);
        const ends = Date.now() + total * 1000;
        const time = document.getElementById('td-time');
        const fill = document.getElementById('td-fill');

        const tick = () => {
            const left = Math.max(0, Math.ceil((ends - Date.now()) / 1000));
            time.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
            fill.style.width = `${(left / total) * 100}%`;
            document.getElementById('testdrive').classList.toggle('late', left <= 10);
            if (left <= 0) clearInterval(timer);
        };

        tick();
        timer = setInterval(tick, 250);
        XS.show('testdrive', true);
    }

    XS.views.hud = { start, stop };
})();
