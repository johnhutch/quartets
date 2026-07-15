// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Register the service worker (cached assets + offline fallback). Best-effort —
// a failure just means no offline support, never a broken page.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch(() => {})
  })
}
