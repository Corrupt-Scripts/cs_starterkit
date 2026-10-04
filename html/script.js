const $ = (id) => document.getElementById(id);
const app = $('app');
const panel = $('panel');
const claimBtn = $('claimBtn');
const msg = $('message');

let currency = '$';
let state = 'idle'; // idle | claiming | done

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'cs_starterkit';

function post(name, body = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body),
    }).catch(() => {});
}

function esc(s) {
    const d = document.createElement('div');
    d.textContent = s == null ? '' : String(s);
    return d.innerHTML;
}

function money(n) {
    return currency + Number(n || 0).toLocaleString('en-GB');
}

function renderItems(items) {
    const wrap = $('items');
    wrap.innerHTML = '';
    items.forEach((it, i) => {
        const el = document.createElement('div');
        el.className = 'item';
        el.style.animationDelay = `${i * 40}ms`;

        const initial = esc((it.label || it.name || '?').charAt(0).toUpperCase());
        const img = it.image
            ? `<img src="${esc(it.image)}" alt="">`
            : `<div class="fallback">${initial}</div>`;

        el.innerHTML = `${img}<span class="count">x${esc(it.count)}</span><div class="label">${esc(it.label)}</div>`;

        const imgEl = el.querySelector('img');
        if (imgEl) {
            imgEl.onerror = () => {
                imgEl.outerHTML = `<div class="fallback">${initial}</div>`;
            };
        }
        wrap.appendChild(el);
    });
}

function open(data) {
    const kit = data.kit || {};
    currency = data.currency || '$';
    state = 'idle';

    panel.classList.remove('male', 'female');
    panel.classList.add(data.gender === 'female' ? 'female' : 'male');

    $('title').textContent = kit.title || 'Starter Kit';
    $('subtitle').textContent = kit.subtitle || '';
    $('genderSymbol').textContent = data.gender === 'female' ? '♀' : '♂';
    $('genderLabel').textContent = data.gender === 'female' ? 'Female Kit' : 'Male Kit';
    $('playerName').textContent = data.name ? `Welcome, ${data.name}` : '';

    renderItems(kit.items || []);
    $('cash').textContent = money(kit.cash);
    $('bank').textContent = money(kit.bank);

    if (kit.vehicle) {
        $('vehicleSection').style.display = '';
        $('vehicleLabel').textContent = kit.vehicle.label;
        const vImg = $('vehicleImg');
        vImg.style.display = '';
        vImg.onerror = () => { vImg.style.display = 'none'; };
        vImg.src = kit.vehicle.image || '';
        if (!kit.vehicle.image) vImg.style.display = 'none';
    } else {
        $('vehicleSection').style.display = 'none';
    }

    $('warning').textContent = data.claimMode === 'citizenid'
        ? 'This kit can only be claimed once per character.'
        : 'This kit can only be claimed once - ever.';

    msg.textContent = '';
    msg.className = 'message';
    claimBtn.disabled = false;
    claimBtn.className = 'claim';
    claimBtn.textContent = 'Claim Kit';

    app.classList.remove('hidden');
}

function hide() {
    app.classList.add('hidden');
}

function close() {
    if (state === 'claiming') return;
    hide();
    post('close');
}

function onResult(d) {
    msg.textContent = d.message || '';
    if (d.success) {
        state = 'done';
        msg.className = 'message ok';
        claimBtn.className = 'claim done';
        claimBtn.textContent = 'Claimed';
        claimBtn.disabled = true;
        setTimeout(close, 4000);
    } else {
        state = 'idle';
        msg.className = 'message err';
        claimBtn.disabled = false;
        claimBtn.textContent = 'Claim Kit';
    }
}

claimBtn.addEventListener('click', () => {
    if (state !== 'idle') return;
    state = 'claiming';
    claimBtn.disabled = true;
    claimBtn.textContent = 'Claiming...';
    msg.textContent = '';
    post('claim');
    // safety: re-enable if the server never answers
    setTimeout(() => {
        if (state === 'claiming') onResult({ success: false, message: 'No response from server, try again.' });
    }, 10000);
});

$('closeBtn').addEventListener('click', close);
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) close();
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') open(d.data || {});
    else if (d.action === 'close') hide();
    else if (d.action === 'result') onResult(d);
});
