# FeatherHub Discord Bot

## Setup

### 1. Create Discord Bot
1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create New Application → "FeatherHub Bot"
3. Go to "Bot" → Reset Token → copy it
4. Enable: **Server Members Intent**, **Message Content Intent**
5. Go to "OAuth2 → URL Generator"
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `Manage Roles`, `Manage Channels`, `Ban Members`, `Send Messages`, `Read Message History`, `Use Slash Commands`
6. Open the generated URL and invite the bot to your server

### 2. Create Roles & Channels
- **Roles:** `Verified`, `Support`
- **Channels:**
  - `#verify` — where `/setup-verify` posts the button
  - `#no-writing` — ban channel (any message = instant ban)
  - `#bot-logs` — log channel for bans, tickets
  - Category `Tickets` — for ticket channels

### 3. Configure .env
```bash
cp .env.example .env
```
Fill in:
- `BOT_TOKEN` — from Developer Portal
- `GUILD_ID` — right-click server → Copy ID
- `VERIFIED_ROLE_ID` — right-click role → Copy ID
- `SUPPORT_ROLE_ID` — right-click Support role → Copy ID
- `VERIFY_CHANNEL_ID` — right-click #verify → Copy ID
- `BAN_CHANNEL_ID` — right-click #no-writing → Copy ID
- `TICKET_CATEGORY_ID` — right-click Tickets category → Copy ID
- `LOG_CHANNEL_ID` — right-click #bot-logs → Copy ID

### 4. Deploy
```bash
npm install
npm start
```

### 5. Post Verify Button
In #verify channel, type: `/setup-verify`

## Commands
| Command | Description |
|---------|-------------|
| `/verify` | Self-verify, get Verified role |
| `/status` | Check key system health |
| `/ticket` | Open a key support ticket |
| `/help` | Show all commands |
| `/setup-verify` | (Admin) Post verify button |

## Features
- **Verification** — button or `/verify` → gives Verified role
- **Ban Channel** — any message in the ban channel = instant ban
- **Key Status** — `/status` checks the Cloudflare Worker health
- **Tickets** — `/ticket` creates a private channel for key support
- **Bilingual** — auto-detects RU/EN from user roles
