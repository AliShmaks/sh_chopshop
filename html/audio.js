const sounds = new Map();
const VOLUME = 0.55;
const MAX_DISTANCE = 40.0;
const REF_DISTANCE = 3.0;
let listener = { x: 0, y: 0, z: 0, fx: 1, fy: 0, fz: 0 };

// Sound files per type
const SOUND_URLS = {
    wheel:   'sounds/air-impact-wrench.mp3',
    grinder: 'sounds/angle-grinder.mp3',
};

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (!data.action) return;

    switch (data.action) {
        case 'start':    startSound(data, 'wheel');   break;   // legacy default
        case 'startWheel':   startSound(data, 'wheel');   break;
        case 'startGrinder': startSound(data, 'grinder'); break;
        case 'stop':     stopSound(data.id);     break;
        case 'stopAll':  stopAllSounds();        break;
        case 'listener': updateListener(data);   break;
    }
});

function startSound(data, kind) {
    kind = kind || 'wheel';
    const id = String(data.id) + '_' + kind;   // unique per type
    if (sounds.has(id)) return;

    const url = SOUND_URLS[kind] || SOUND_URLS.wheel;
    const audio = new Audio(url);
    audio.loop = true;
    audio.volume = VOLUME;
    audio.preload = 'auto';

    const pos = {
        x: Number(data.x) || 0,
        y: Number(data.y) || 0,
        z: Number(data.z) || 0,
    };

    sounds.set(id, { audio, pos, kind });

  audio.play().catch((err) => {
    console.error('[ChopShopAudio] play failed:', kind, err.name, '|', err.message, '| src:', audio.src);
    audio.addEventListener('error', () => {
        console.error('[ChopShopAudio] audio error code:', audio.error && audio.error.code);
    });
});
}

function stopSound(rawId) {
    if (rawId == null) return;
    const base = String(rawId);
    // stop any kind with this id
    for (const [key, entry] of Array.from(sounds.entries())) {
        if (key === base || key.startsWith(base + '_')) {
            entry.audio.pause();
            entry.audio.currentTime = 0;
            sounds.delete(key);
        }
    }
}

function stopAllSounds() {
    for (const id of Array.from(sounds.keys())) {
        const entry = sounds.get(id);
        if (entry) {
            entry.audio.pause();
            entry.audio.currentTime = 0;
        }
        sounds.delete(id);
    }
}

function updateListener(data) {
    listener.x = Number(data.x) || 0;
    listener.y = Number(data.y) || 0;
    listener.z = Number(data.z) || 0;
    if (data.fx !== undefined) {
        listener.fx = Number(data.fx) || 0;
        listener.fy = Number(data.fy) || 0;
        listener.fz = Number(data.fz) || 0;
    }
    recalcVolumes();
}

function recalcVolumes() {
    for (const entry of sounds.values()) {
        const dx = entry.pos.x - listener.x;
        const dy = entry.pos.y - listener.y;
        const dz = entry.pos.z - listener.z;
        const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
        const vol = distanceToVolume(dist);
        entry.audio.volume = vol;
        if (vol <= 0 && !entry.audio.paused) entry.audio.pause();
        else if (vol > 0 && entry.audio.paused) entry.audio.play().catch(() => {});
    }
}

function distanceToVolume(dist) {
    if (dist <= REF_DISTANCE) return VOLUME;
    if (dist >= MAX_DISTANCE) return 0;
    const t = (dist - REF_DISTANCE) / (MAX_DISTANCE - REF_DISTANCE);
    return VOLUME * (1 - t);
}

setInterval(recalcVolumes, 500);