# Deploy — Quartets

Self-hosted on a **Synology DS918+** via DSM **Container Manager**.

We use **GitHub Actions** to automatically build the Docker image and push it to the GitHub Container Registry (GHCR) whenever code is pushed to `main`. On the Synology NAS, a **Watchtower** container automatically detects the new image, pulls it, and restarts the app with zero clicks.

A **Caddy** front proxy sits between the tunnel and the app (`tunnel → caddy → web`) so the ~10-15s while Watchtower recreates `web` doesn't return 502s — Caddy holds and retries requests until the new container is up. A Cloudflare Tunnel securely exposes the app to the internet without opening any ports on the router. See `DECISIONS.md` ADR-0007.

## Initial Setup on Synology

1. **Install Container Manager** from the Synology Package Center. *(Note: If your NAS is running DSM 7.1 or older, the app is called "Docker" and doesn't have the "Project" UI. You should either update your NAS to DSM 7.2 in Control Panel to get the new Container Manager, or you can run `sudo docker-compose up -d` via SSH instead of using the UI.)*
2. **Make the project dir**, e.g., `/volume1/docker/quartets`, and put the `.env` file in it (copy `.env.example`, fill in real values — `RAILS_MASTER_KEY` is the verbatim contents of `config/master.key`, and include your `TUNNEL_TOKEN`).
3. **Open Container Manager**:
   - Go to the **Project** tab.
   - Click **Create**.
   - Name it `quartets`, point the Path to your project directory.
   - For Source, choose **Create docker-compose.yml** and upload or paste the contents of `docker-compose.yml` from this repository.
   - Click **Next** and complete the wizard. The NAS will pull the Postgres, Web, Caddy, Cloudflared, and Watchtower images and start them up. (`Caddyfile` ships in the repo and is mounted into the Caddy container — keep it next to `docker-compose.yml` in the project dir.)

## Deploying Updates

Just `git push` to the `main` branch. 

GitHub Actions will build the new image and push it to GHCR. Within 5 minutes, Watchtower on your NAS will notice the new image, gracefully shut down the old `web` container, and start a new one. Watchtower is scoped (via the `com.centurylinklabs.watchtower.enable=true` label + `WATCHTOWER_LABEL_ENABLE`) to cycle **only** `web`, so Caddy, the tunnel, and Postgres stay up — and Caddy buffers requests through the restart so visitors see at most a one-time slow load, not an error.

*(Note: If your GitHub repository is private, you will need to generate a GitHub Personal Access Token (classic) with `read:packages` permission and add it to your `.env` file as `GITHUB_TOKEN` along with your username as `GITHUB_ACTOR`, so Watchtower has permission to pull the image.)*

## Expose it (HTTPS via Cloudflare)

The `docker-compose.yml` includes a `cloudflared` service. 

- Create a Zero Trust tunnel in the Cloudflare dashboard.
- Set its public hostname to point to `http://caddy:80` (the front proxy — **not** `web` directly; that's what makes deploys downtime-free).
- Drop the provided token into your `.env` file as `TUNNEL_TOKEN`.

Traffic will route securely to your NAS without needing Synology's reverse proxy or opening ports.

## Outbound mail (Resend)

Forgot-password email relays through **Resend** (free tier: 3,000/mo, 100/day —
forgot-password volume is a rounding error against that). The app is already
wired: `production.rb` reads `SMTP_*` from the `.env`, and mail silently no-ops
until `SMTP_ADDRESS` is set. One-time setup:

1. **Sign up** at [resend.com](https://resend.com) (free tier, no card).
2. **Verify the domain**: Resend dashboard → Domains → Add `playquartets.com`.
   It hands you DNS records (DKIM TXT/CNAMEs + an SPF record on a bounce
   subdomain). Add them in **Cloudflare DNS** — set each to **DNS only** (grey
   cloud), not proxied. Wait for Resend to show "Verified" (usually minutes).
3. **DMARC** (once, if not already present): add a TXT record in Cloudflare —
   name `_dmarc`, value `v=DMARC1; p=none;`. Loosest policy; it just makes
   receivers happier and gives you reports later if you tighten it.
4. **Mint an API key**: Resend dashboard → API Keys → Create (sending access
   only is fine). Copy it — it's shown once.
5. **Fill the NAS `.env`** (`/volume1/docker/quartets/.env`):

   ```
   SMTP_ADDRESS=smtp.resend.com
   SMTP_PORT=587
   SMTP_USERNAME=resend
   SMTP_PASSWORD=re_xxxxxxxxxxxx   # the API key
   SMTP_AUTHENTICATION=plain
   MAILER_SENDER=no-reply@playquartets.com
   ```

6. **Recreate `web`** so it picks up the env (a plain restart is not enough —
   env is baked at container create). Container Manager → Project → quartets →
   Action → Build/Recreate, or via SSH: `sudo docker-compose up -d web`.
7. **Smoke test**: hit `/users/password/new` on the live site, request a reset
   for a real account, and check the inbox (and spam folder — first send from a
   fresh domain sometimes lands there; subsequent ones settle). Every send also
   shows up in Resend's dashboard → Emails, which is the fastest way to tell
   "app didn't send" from "receiver binned it".

## Backups

- **Database:** `docker compose exec db pg_dump -U quartets quartets_production > backup.sql` (cron it via DSM Task Scheduler).
- The `pgdata` volume also gets swept up by Synology's Hyper Backup if you include the Docker volumes path.
