(function () {
    const stage = document.getElementById('stage');
    const scrim = document.getElementById('scrim');

    function fit() {
        const scale = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
        document.documentElement.style.setProperty('--scale', String(scale));
    }

    function config(next) {
        if (!next) return;
        XS.config = Object.assign({}, XS.config, next);
        if (next.resource) XS.resource = next.resource;
    }

    function closeAll() {
        XS.views.showroom.close();
        XS.views.offer.close();
        XS.views.creator.close();
        XS.views.tablet.close();
        scrim.hidden = true;
        stage.classList.remove('hidden');
    }

    function only(view) {
        ['showroom', 'offer', 'creator', 'tablet'].forEach((id) => { if (id !== view) XS.views[id].close(); });
        scrim.hidden = false;
        stage.classList.remove('hidden');
    }

    window.addEventListener('message', (event) => {
        const { action, data } = event.data || {};

        switch (action) {
            case 'showroom':
                config(data.config);
                only('showroom');
                XS.views.showroom.open(data);
                break;
            case 'offer':
                config(data.config);
                only('offer');
                XS.views.offer.open(data);
                break;
            case 'tablet':
                config(data.config);
                only('tablet');
                XS.views.tablet.open(data);
                break;
            case 'creator':
                config(data.config);
                only('creator');
                XS.views.creator.open(data);
                break;
            case 'close':
                closeAll();
                break;
            case 'hide':
                stage.classList.add('hidden');
                scrim.hidden = true;
                break;
            case 'unhide':
                stage.classList.remove('hidden');
                scrim.hidden = false;
                break;
            case 'testdrive':
                XS.views.hud.start(data && data.seconds);
                break;
            case 'testdriveEnd':
                XS.views.hud.stop();
                break;
            default:
                break;
        }
    });

    document.addEventListener('keydown', (event) => {
        if (event.key !== 'Escape') return;
        if (scrim.hidden) return;
        XS.post('close');
    });

    window.addEventListener('resize', fit);
    fit();
})();
