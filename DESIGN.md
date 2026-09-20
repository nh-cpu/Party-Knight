# Party Knight redesign

The playable roster is Ballista Run, Lance, and Coin Collection. The previous Chalice, Axe, and Drawbridge games are retired. This release retains the dedicated ENet authority and lobby, with protocol 3.

## Boundaries

- Session owns identity, selection, readiness, loading barriers, unique attempt tokens, heat indices, accumulated performance, and once-per-game match scoring.
- GameRules resources provide stable IDs and independent authoritative/presentation scenes. Shared input and UI contain no numeric minigame branches. The stationary Coins role and mounted ballista do not require a moving pawn.
- PartyGame owns elimination causes and simulation ticks. Same-tick deaths tie. Coins retains scores after elimination; forfeits are excluded by the session roster.
- MovingGame accepts sequenced normalized inputs and batches shove impulses. PartyPawn has acceleration, braking, body blocking, and complete prediction state. Jump capability is disabled in every current game.
- GameView supplies model spawning, remote collision proxies, prediction/reconciliation, spectator support, and cosmetic effects. Each game view owns its camera, input actions, and HUD hints.
- HazardClock models reset, warning, active, and recovery. Coins never exposes its randomized impact deadline. Other hazards expose announced deadlines for readable countdowns.

## Ballista authority

Each shooter receives four shots with a 0.5-second minimum interval and three-second automatic reload. A heat lasts 60 seconds, or ends when every runner resolves. Role order follows the round roster. One complete rotation gives every player one shooter heat. An incomplete rotation restarts after a disconnect to preserve equal opportunity.

Clients send only a bounded finite aim direction and action sequence. The server supplies the mount origin and selects historical runner capsules using half the measured ENet RTT plus 50 ms presentation delay, capped at 200 ms. Static cover is ray-tested on the authority. Hits are resolved before finish crossings in the same simulation tick; an already-finished runner cannot be hit. Visual cover fading on runner clients never changes authoritative cover collision.

The combined performance is half the fraction stopped as shooter plus half the fraction of runner heats completed. Coin totals and Lance survival placement totals are accumulated separately. Each game's combined ranking awards 3/2/1/0 once, with shared placements skipping occupied ranks. Solo practice is always unscored.

## Deferred designs (not shipped)

- **Blacksmith:** equal component inventories; head, shaft, and grip trade assembly time against reach, damage, attack interval, knockback, and handling. Eight protected seconds, up to twenty assembly seconds, then thirty-five combat seconds. Finished builders can attack after protection ends. A 14 x 14 metre forge, fixed elevated camera, WASD/E/mouse attacks, body blocking, no jumping. Reuse movement, interactions, damage, and results; server derives all weapon stats from component IDs.
- **Stable Footing:** an 8 x 8 grid of two-metre tiles (6 x 6 active for two players), connected inward collapse patterns, one-second warnings, and a 45-second cap. WASD, shove, and Space jump. This alone enables the shared optional jump. Server controls tile collision, warnings, shoves, and falls. Last survivor wins; simultaneous deaths/timeouts tie.
- **Raging Shark:** a 14 x 14 metre courtyard; sharks target a living player, warn for 0.9 seconds, charge straight at 12 m/s to the wall, then recover for one second. Add a shark every ten seconds, capped at three for two players or four otherwise; warnings shorten to 0.6 seconds. No jump, 45-second cap, authoritative targeting and swept hits. Reuse Lance movement, shoving, warnings, and survival scoring.

## Reference boundary

Machine Party's Duck Hunt, Tunnel Hazard, assembly, and collapsing-floor formats informed the role cameras and readable objectives. Dimensions, controller constants, shark theming, coin rules, and scoring are Party Knight decisions. References: https://machineparty.wiki/minigames/all-minigames/ and https://steamcommunity.com/app/4108000/allnews/ . No reference game code or assets are included.

## Hosting

One Linux authoritative server remains the deployment target. Existing systemd/Vultr packaging is retained. A provisioned VM and SSH environment are still required before internet matches, firewall reachability, VM capacity, and reboot recovery can be accepted.
