const CACHE_NAME = "laobirds-offline-v2";

const CORE_ASSETS = [
    "./",
    "./index.html",
    "./observations.html",
    "./my-laobirds.html",
    "./birds.html",
    "./map.html",
    "./hotspots.html",
    "./iucn.html",
    "./laos-list.html",
    "./auth.html",
    "./style.css",
    "./data.js",
    "./supabase-config.js",
    "./logo.png"
];

self.addEventListener("install", event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(CORE_ASSETS))
            .then(() => self.skipWaiting())
    );
});

self.addEventListener("activate", event => {
    event.waitUntil(
        caches.keys()
            .then(keys =>
                Promise.all(
                    keys
                        .filter(key => key !== CACHE_NAME)
                        .map(key => caches.delete(key))
                )
            )
            .then(() => self.clients.claim())
    );
});

self.addEventListener("fetch", event => {
    const request = event.request;

    if (request.method !== "GET") {
        return;
    }

    const url = new URL(request.url);

    // Don't cache Supabase API/Auth/Storage requests.
    if (url.hostname.includes("supabase.co")) {
        return;
    }

    // LaoBirds local files.
    if (url.origin === self.location.origin) {
        event.respondWith(
            caches.match(request).then(cached => {
                if (cached) {
                    return cached;
                }

                return fetch(request)
                    .then(response => {
                        const copy = response.clone();

                        caches.open(CACHE_NAME)
                            .then(cache => {
                                cache.put(request, copy).catch(() => {});
                            });

                        return response;
                    })
                    .catch(() => caches.match("./index.html"));
            })
        );

        return;
    }

    // Third-party files such as Supabase JavaScript CDN.
    event.respondWith(
        fetch(request)
            .then(response => {

                if (
                    request.destination === "script" ||
                    request.destination === "style" ||
                    request.destination === "image"
                ) {
                    const copy = response.clone();

                    caches.open(CACHE_NAME)
                        .then(cache => {
                            cache.put(request, copy).catch(() => {});
                        });
                }

                return response;
            })
            .catch(() => caches.match(request))
    );
});