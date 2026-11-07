# Setup guide

End-to-end deployment as I did it, from zero to a 24/7 Telegram assistant.

## 1. Oracle Cloud server (free)
1. Sign up at oracle.com/cloud/free and pick your **home region** (it can't be changed later).
2. Compute → Instances → Create:
   - Image: **Ubuntu 24.04**
   - Shape: **VM.Standard.A1.Flex**, 2 OCPU / 12 GB (Always Free limit since mid-2026)
   - Networking: **Create new VCN** + **Create new public subnet**
   - SSH keys: *Generate a key pair for me*, then download the private key
3. If you get "Out of capacity", try another availability domain or a smaller shape.
4. After creation: Networking tab → **Connect public subnet to internet** (quick action), then VNIC → IP administration → Edit → **Ephemeral public IP**.
5. Windows SSH: lock down the key file first.
   ```
   icacls key.key /inheritance:r
   icacls key.key /grant:r "%USERNAME%:R"
   icacls key.key /remove "NT AUTHORITY\Authenticated Users" "BUILTIN\Users" "Everyone"
   ssh -i key.key ubuntu@<PUBLIC_IP>
   ```

## 2. Docker + stack
```bash
# wait for first-boot updates, then install Docker
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 10; done
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu && exit   # log in again afterwards

git clone https://github.com/muttumanjunath/n8n-personal-ai-assistant.git
cd n8n-personal-ai-assistant/infra
cp .env.example .env && nano .env
printf 'use_default_settings: true\nserver:\n  secret_key: "%s"\n  limiter: false\n  image_proxy: false\nsearch:\n  safe_search: 0\n  formats:\n    - html\n    - json\n' $(openssl rand -hex 32) > searxng/settings.yml
docker compose up -d && docker compose ps
```

## 3. ngrok (public HTTPS for Telegram)
1. Create a free account at ngrok.com, claim a **free static domain**, and copy your **authtoken**.
2. Put both into `.env`. Telegram webhooks require HTTPS, and `WEBHOOK_URL` must match the domain.

## 4. Credentials in n8n
| Credential | Where to get it |
|---|---|
| Telegram API | @BotFather → `/newbot` |
| Google Gemini (PaLM) API | aistudio.google.com/apikey |
| Gmail OAuth2 (×2) | Google Cloud project → enable Gmail API → OAuth consent (External) → Web client with redirect `https://<NGROK_DOMAIN>/rest/oauth2-credential/callback`. Publish the app to avoid 7-day token expiry. |
| Postgres | Host `postgres`, DB `n8n_memory`, user `n8n`, password from `.env`, SSL off |
| Cloudflare AI (Header Auth) | Cloudflare dashboard → API Tokens → *Workers AI* template; header `Authorization: Bearer <token>` |

## 5. Import workflows
1. `image-generator.json`: set your Cloudflare account ID in the URL, publish, copy the workflow ID.
2. `personal-ai-assistant.json`: paste that ID into **Generate Image**, set your Telegram user ID in **Telegram Message → Restrict to User IDs**, adjust the email addresses in the system prompt and tool descriptions.
3. `morning-briefing.json`: set the chat ID and your city coordinates (Open-Meteo URL).
4. Publish all three.

## 6. Hardening
- n8n → Settings → Personal → **Enable 2FA**
- Cron backup: `0 3 * * * /path/to/infra/backup.sh`
- Oracle may reclaim idle Always Free VMs, so keep using it.
