# Design decisions & lessons learned

### Telegram over WhatsApp
The official WhatsApp Cloud API only sees messages sent *to the bot*, so it can't summarise personal chats. Unofficial QR-code bridges can, but they break WhatsApp's terms and risk a number ban. Telegram gives a free, official bot API with webhooks.

### Oracle Cloud + ngrok instead of laptop
The first version ran in Docker on a laptop, which meant the bot was offline whenever the laptop was. Moved to an Always Free ARM VM. ngrok's free static domain gives a stable HTTPS URL without buying a domain or managing certificates. n8n's data folder was copied over 1:1, so all credentials and workflows survived the move.

### Gemini flash-lite + strict tool budget
Free-tier rate limits are the main constraint: about 5 RPM on `flash` versus more on `flash-lite`. An early version burned 8 LLM calls on one question by calling Wikipedia per item. Fixes: a "max N tool calls" rule in the system prompt, `maxIterations` capped, and retry on the model node.

### Web search: SearXNG, not Gemini grounding
Gemini's built-in Google Search grounding returned `429 RESOURCE_EXHAUSTED` on the free tier. A self-hosted SearXNG container (JSON format enabled) gives unlimited, key-less search; the HTTP Request tool's *optimize response* keeps only `title, url, content, publishedDate` to save tokens.

### Postgres memory
Simple (in-RAM) memory is wiped on every container restart. Postgres Chat Memory in the same Compose network fixed that with one credential.

### Memory trimming (Gemini 400 fix)
A sliding memory window can cut the history in the middle of a tool exchange, so the oldest loaded message becomes an AI *function call* with no user turn before it. Gemini rejects that with `400: function call turn must come immediately after a user turn`, and once it happens every following message fails. Fix: a **Trim Memory** Postgres step runs before the agent and deletes everything older than the last 6 *human* messages for that session, so the stored history always starts with a user turn. The memory window (20 interactions) is larger than what remains, so the loaded history is never cut mid-exchange.

### Telegram formatting
LLMs output `**bold**`, which Telegram's legacy Markdown rejects ("can't parse entities"). Replies are HTML-escaped and converted (headings/bold → `<b>`, italics → `<i>`, bullets → `•`) and sent with `parse_mode=HTML`.

### Image generation with fallback
Cloudflare Workers AI FLUX-1-schnell returns base64 → *Convert to File* → Telegram `sendPhoto` (binary). Any error or exhausted quota routes to Pollinations.ai (URL-based, no key). It's packaged as a **sub-workflow tool**, because an agent tool can't easily return binary data.

### Two Gmail accounts
Separate search/read/draft tools per account with explicit names (`… 2001`, `… 9321`) plus system-prompt rules: check both when unspecified, read only with the matching account's tool, and draft from the receiving account. **Draft-only** by design.

### Error UX
The agent's error output feeds a *Build Error Message* node that maps raw errors (429, invalid_grant, 404, timeout) to human hints and replies on the same channel, so the bot never fails silently.
