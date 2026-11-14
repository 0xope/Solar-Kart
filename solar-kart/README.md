# Solar Kart

Mario-Kart-style mobile racer on Solana. Built in Godot, hosted on Vercel,
playable standalone or as a Telegram Mini App. Players earn SGA
(solanagames.app) through a competitive rewards system.

```
solar-kart-repo/
  game/     Godot 4.3 project (the racer itself)
  web/      Next.js app: landing page, hosts the game, wallet connect, reward API
```

## About the game (player-facing — for your audience)

Solar Kart is a fast, arcade-style kart racer you play right in your
browser or inside Telegram — no app download. Connect a Solana wallet,
race, and finish well to earn **SGA**, the in-game token.

**How the rewards work:**
- Racing is free — but only a **staked race** earns rewards. Pay a small
  SGA entry fee to enter a staked race; win or place well and you earn it
  back plus a bonus. Free races are practice, no stakes, no reward.
- **Every staked race**, the top 3 finishers earn an instant SGA reward.
- **Every week**, all your staked race finishes earn you points based on
  how you placed. At the end of the week, the top racers on the
  leaderboard split a bonus SGA pool — the better you consistently
  place, the bigger your share.
- **Claiming**: earned SGA accumulates in your account; hit "Claim SGA"
  whenever you want it sent to your connected wallet on-chain.
- **Shop**: spend SGA on kart skins, trails, and horns — pure style,
  never a competitive advantage.
- Play in **portrait** to browse the menu, connect your wallet, check the
  leaderboard, and shop. **Rotate to landscape** to race — that's game
  mode.

(This section is ready to drop into a marketing page or in-app "How it
works" screen as-is, or I can adjust the tone/length for wherever it's
going.)

## How the pieces connect

```
 [RaceEntry.tsx: Stake & Race] —— sendSgaPayment() —— on-chain SPL transfer to treasury
		|                                                              |
		v                                                              v
 [api/enter-race verifies payment] —— issues ticket for raceId —— [Vercel KV]
		|
		v
 [Godot Web export]  <—— postMessage(raceId, wallet display) ——  [Next.js page, wallet-adapter]
		|                                                              |
		| postMessage(race result)                                    |
		v                                                              |
 [GameShell.tsx] —— wallet.signMessage() —— POST /api/submit-run (signed) —→ verify signature + ticket
		|                                                              |
		v                                                              v
 [Vercel KV: weekly leaderboard + claimable balance]  <——  credited only if ticketed
		^
		| GET /api/leaderboard
		|
 [Cron: weekly-payout, Mondays 00:00 UTC] —— credits pool shares
		|
		v
 [Player clicks "Claim SGA"] —— wallet.signMessage() —— POST /api/claim-reward (signed)
		|
		v
 [lib/solana.ts sends SPL transfer from treasury, decimals read from the mint]

 [Shop.tsx] —— sendSgaPayment() —— api/shop/purchase verifies payment —— owned-items in KV
```

The key security property: **Godot never talks to the reward API
directly, and nothing is credited without a wallet signature.** Only the
browser holds the actual wallet extension (Phantom/Solflare), so Godot
just reports race results up to the web page via `postMessage`, the page
asks the wallet to sign a message proving the player authorized that
specific submission or claim, and the server verifies that signature
before touching any balance. See `web/lib/verifySignature.ts` and the
two API routes for the actual check.

Portrait and landscape are both first-class, not portrait-blocked:
**portrait = menu mode** (wallet connect, leaderboard, claim button, all
usable), **landscape = game mode** (shell hides, `game/index.html` goes
fullscreen). The rotate prompt only ever covers the game area, never the
whole page. This is enforced at the CSS layer
(`web/app/globals.css`, `@media (orientation: ...)`) and, redundantly,
inside the Godot build itself (`game/scripts/OrientationAlert.gd`) in
case the iframe finishes loading before the CSS state settles.

`web/app/page.tsx` switches between `LandingPage.tsx` (loading/menu
screen, animated background effect, Play + wallet-connect) and
`GameShell.tsx` (wallet/leaderboard/game). Landing page background art
has its own slot — see `web/public/backgrounds/README.md`.

## Competitive rewards system (SGA) — earning

Defined entirely in `web/lib/rewardTiers.ts` — the one file to edit to
retune numbers:

- **Per-race**: top 3 finishers get an instant SGA reward, credited to a
  claimable balance (not sent on-chain yet — see below).
- **Weekly leaderboard**: every reward-eligible race earns placement
  points; every Monday a fixed SGA pool splits across the top 50
  point-holders, proportional to points, then the board resets. Requires
  a minimum of 3 races that week to qualify, so one lucky run can't farm
  the pool.
- **Claiming**: players hit "Claim SGA" in the web UI, which triggers one
  on-chain SPL transfer for their entire accrued balance. Batching claims
  this way (instead of an on-chain transfer per race) keeps treasury RPC
  calls and fees down.

## How SGA flows back in — spending

Two sinks, both real on-chain payments to the treasury, both verified
server-side before anything is credited (`web/lib/solanaPayments.ts`):

- **Race entry stakes** (`RaceEntry.tsx`, `api/enter-race`) — racing is
  free to play, but only a **staked** race is reward-eligible. Paying
  `RACE_ENTRY_STAKE_SGA` before a race issues a "ticket" for that
  specific `raceId` (`web/lib/tickets.ts`); `api/submit-run` checks for
  that ticket before crediting anything. No ticket = the race still
  plays fine, it just doesn't earn points or a reward. This is the
  practical version of the 40/60/20 relationship discussed earlier: the
  gap between what's staked and what's paid out (per-race reward +
  weekly pool) is the platform's margin — tune both sides in
  `rewardTiers.ts` to whatever relationship you want, nothing computes
  the margin automatically.
- **Cosmetic shop** (`Shop.tsx`, `api/shop/*`, catalog in
  `web/lib/shopCatalog.ts`) — pure vanity purchases (skins, trails,
  horns), zero stat impact, so nothing here is pay-to-win. Ownership is
  permanent once purchased; applying the actual cosmetic in-game is a
  hook for later (see the comment at the top of `shopCatalog.ts`) since
  there's no art to apply yet.

Both reuse the exact same payment primitive: the client builds and sends
a real SPL transfer to the treasury (`web/lib/clientPayments.ts`), the
server independently confirms that transfer happened on-chain for the
right amount from the right wallet before crediting a ticket or an item
(`web/lib/solanaPayments.ts`) — nothing is ever trusted just because the
client says it paid.

## Setup

**Game:**
1. Open `game/project.godot` in Godot 4.3+.
2. Project → Export → add a "Web" preset → export into `web/public/game/`
   as `index.html`.

**Web:**
1. `cd web && npm install`
2. Copy `.env.example` to `.env.local`, fill in:
   - `SOLANA_RPC_URL` / `NEXT_PUBLIC_SOLANA_RPC_URL`
   - `SGA_MINT_ADDRESS` / `NEXT_PUBLIC_SGA_MINT_ADDRESS` (same mint, two vars — one server, one client)
   - `TREASURY_SECRET_KEY` / `NEXT_PUBLIC_TREASURY_WALLET_ADDRESS` (secret key server-only; its public address exposed for clients to build payments to)
   - `KV_REST_API_URL` / `KV_REST_API_TOKEN` (provision Vercel KV first)
   - `TELEGRAM_BOT_TOKEN`, `CRON_SECRET`
3. `npm run dev` locally, or push and let Vercel build.
4. In the Vercel dashboard: Storage → add a KV store; Settings → Cron
   Jobs will pick up `vercel.json` automatically on deploy.

**Telegram:** point your bot's Mini App URL at the deployed Vercel URL.
`web/telegram/init.ts` handles the rest.

## Path from here to full deployment

In rough order:

1. **Art** — you're handling character/environment/kart models and the
   landing background (`web/public/backgrounds/landing-bg.jpg`). Send
   assets + which piece each one is and I'll wire them into the existing
   scenes/CSS, one surgical swap at a time.
2. **Godot export** — export the Web build into `web/public/game/` (see
   Setup above). This is the first point where the whole thing can
   actually be clicked through end to end.
3. **Provision real infrastructure** — Vercel KV store, a funded Solana
   treasury wallet, the SGA mint address you have. Fill in `.env.local`
   / Vercel's environment variables.
4. **Test on Solana devnet first** — point `SOLANA_RPC_URL` at devnet and
   use a devnet-funded treasury before ever touching mainnet. This is
   the cheapest place to catch a payout bug; I can't run this testing
   myself (no network path to Solana RPC endpoints from this sandbox),
   so this step is on you, with me fixing whatever breaks.
5. **Deploy to Vercel** — connect the GitHub repo, set env vars in the
   Vercel dashboard, deploy. Confirm the cron job appears under Settings
   → Cron Jobs.
6. **Wire up Telegram** — create/point your bot's Mini App URL at the
   deployed Vercel URL, confirm `initTelegram()` picks up a real user
   inside Telegram's client.
7. **Switch to mainnet** — swap `SOLANA_RPC_URL` and the treasury/mint to
   mainnet values only once devnet testing looks right. **Do this only
   after real placement exists** (see the ⚠️ in Known Gaps) — with
   placement still hardcoded to 1st, going live on mainnet with staking
   on means every player wins every staked race, guaranteed.
8. **Multiplayer / real placement** — the actual blocker on step 7, not
   just a nice-to-have. This is the biggest real gameplay gap left.

## Security review notes (this pass)

Fixed in this pass, all in `web/lib/` and the two API routes:

- **Unauthenticated reward crediting** — previously `submit-run` trusted
  a client-supplied wallet address, gated only by a secret baked into the
  public Web/WASM build (readable by anyone). Now every submission and
  claim requires a message signed by the wallet's actual private key,
  verified server-side (`web/lib/verifySignature.ts`). This also moved
  run submission from Godot's `HTTPRequest` to the web page itself, since
  only the browser holds the wallet extension that can sign.
- **Claim race condition** — concurrent claim requests (double-click, two
  tabs) could both pass the "read balance" check before either cleared
  it. Now guarded by a short-lived per-wallet lock, and the balance is
  zeroed before the on-chain send (restored automatically if the send
  fails) rather than after.
- **Hardcoded token decimals** — `sendSgaReward` assumed 6 decimals; now
  reads the real value from the SGA mint before computing the raw amount.
  Wrong decimals would have meant every payout was off by a power of 10.
- **Weak wallet validation** — replaced length-only checks with real
  Solana address parsing (`isValidSolanaAddress`).
- **Replay protection** — a given `raceId` can only be submitted once
  (`submitted-race:{raceId}` in KV); a claim signature is only valid for
  5 minutes from when it was signed.

Still open, worth knowing about:

- Claimable balances are stored as floats in KV; fine at small scale, but
  floating-point rounding can drift over a very large number of
  transactions. Switching to integer smallest-units once the mint
  decimals are known is the fix if this becomes a concern.
- No on-chain program (Anchor) — rewards are plain SPL transfers from a
  treasury keypair. Fine to start; a program would let you decentralize
  treasury control later.
- `MIN_SECONDS_PER_LAP` in `validateRun.ts` is the only defense against
  physically-impossible race times. It's a floor, not real anti-cheat —
  there's no replay/physics verification of the actual race.

## Known gaps (explicitly out of scope for this pass — flag any of these and I'll build it next, surgically)

⚠️ **`placement` is hardcoded to `1` in `game/scripts/Track.gd`, and
staking is now live.** Combined, that means every staked race is
currently a guaranteed win — pay `RACE_ENTRY_STAKE_SGA`, always place
1st, always receive `PER_RACE_REWARD_SGA[1]`, which is a net profit every
single time at the numbers currently in `rewardTiers.ts` (3 in, 25 out).
This is fine for local testing but **do not enable staking for real
users until real placement (multiplayer or AI opponents) exists** — this
is the one gap in this list that's an active liability, not just
unfinished scope.

- Real multiplayer/AI opponents — the item above, restated as the actual
  feature gap.
- Environment/character/kart art — you're handling this. Shop items have
  no visual application yet since there's nothing to apply them to.
- No automated tests (unit or integration) anywhere in the repo yet.
