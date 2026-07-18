# Organization scope

The watcher monitors **every repository** under [github.com/heavy-duty](https://github.com/heavy-duty).

Discovery is **search-based** (`gh search … --owner heavy-duty`), so new org repos are included automatically — no allowlist edit required.

As of 2026-07-18 the org includes (non-exhaustive snapshot):

- platform, box, rig, cast, infra, handbook, incubator
- bulldozer, bulldozer-examples, wallet-adapter, nx-anchor, anchor
- znap (+ example, shuttle, tokio, hats)
- solana-utils, spl-utils, calculate-leaderboard
- drill-* actions, bounty-program helpers
- metaplex-series, nft-as-a-wallet, solfate-images, solana-colombia-hacker-house-bounty-program
- .github

Refresh anytime:

```bash
gh api orgs/heavy-duty/repos --paginate --jq '.[].full_name' | sort
```
