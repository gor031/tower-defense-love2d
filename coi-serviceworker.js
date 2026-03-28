/*! coi-serviceworker v0.1.7 - Guido Zuidhof, licensed under MIT */
/*
 * This service worker intercepts all fetch requests and adds
 * Cross-Origin-Embedder-Policy and Cross-Origin-Opener-Policy headers
 * to enable SharedArrayBuffer on GitHub Pages.
 */
if (typeof window === 'undefined') {
    // Service Worker context
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));

    self.addEventListener("fetch", function (e) {
        if (e.request.cache === "only-if-cached" && e.request.mode !== "same-origin") {
            return;
        }

        e.respondWith(
            fetch(e.request)
                .then(function (response) {
                    if (response.status === 0) {
                        return response;
                    }

                    const newHeaders = new Headers(response.headers);
                    newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
                    newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");

                    return new Response(response.body, {
                        status: response.status,
                        statusText: response.statusText,
                        headers: newHeaders,
                    });
                })
                .catch((err) => console.error(err))
        );
    });
} else {
    // Window context - register the service worker
    (async function () {
        if ("serviceWorker" in navigator) {
            const registration = await navigator.serviceWorker.register(
                window.document.currentScript.src
            );

            if (registration.active && !navigator.serviceWorker.controller) {
                window.location.reload();
            }
        }
    })();
}
