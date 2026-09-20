<<<<<<< HEAD
# Party-Knight
=======
# Party Knight

A Godot 4.7.2 party-game prototype for 1–4 players: six medieval peasants, three lethal minigames, and an authoritative dedicated server. Play competitive matches with 2–4 friends, or start unscored solo practice. The host selects games and can shuffle their order. Levels are deliberately built from plain geometric shapes.

## Play locally

Open `project.godot` in Godot 4.7.2. Start a separate headless server using your Godot executable:

```powershell
& $Godot --headless --path . -- --server --port 7000
```

Run the project in one to four client processes. Enter `127.0.0.1`, port `7000`, choose your names and peasants, and join. Everyone must ready up; the first player is the host and can begin, including when playing alone. The dedicated server never occupies a player slot. Launching a client does not host a match.

Players receive a stable number (P1–P4) and matching colored nameplate when they join. Vacant numbers are reused without renumbering remaining players. Change your name in the lobby with Apply or Enter. The host selects at least one game from the list and can toggle random order; the server shuffles the selected games once when the match starts. Lance and Coins run for three rounds each. Ballista runs one shooter heat per player; each heat lasts up to 60 seconds. These options remain selected for a rematch.

For multiple client instances, use Godot's Debug → Customize Run Instances, or launch the executable repeatedly. Optional client arguments: `-- --connect 127.0.0.1 --port 7000 --name Turnip --character 0`.

## Games

- **Ballista Run:** runners use WASD and left-click to shove. Reach the gold finish line using cover. The shooter aims with the mouse and fires with left-click: four hitscan bolts, 0.5 seconds between shots, then a three-second reload. Every player shoots once. Each heat ends after 60 seconds or when all runners finish or are eliminated.
- **Lance:** WASD moves and left-click shoves in your facing direction. Claim an OPEN market stall before the sharks cross the street. Four-second warnings announce which stalls will close. Refuges decrease each wave. Last survivor wins; rounds last at most 45 seconds.
- **Coin Collection:** tap E for coins; stop tapping to retract over 0.25 seconds. The blade shakes for a random 1–4 seconds before dropping. Hand loss ends collection, but earned coins remain. Six blade cycles or 35 seconds end the round.

There is no jumping or sprinting in these three games. Bodies block other players in movement games; shoves have a one-second cooldown. ESC opens settings and releases the ballista mouse. TAB cycles living runner spectator targets.

Each completed game contributes 3/2/1/0 match points, regardless of its number of rounds or heats. Lance combines survival placements, Coins combines coin totals, and Ballista combines equally weighted shooting and running success rates. Tied placements share points and skip occupied ranks; tied final totals share the crown. Everyone returns with a complete character for the next round or heat.

Solo play is labeled PRACTICE and awards no match points. Ballista practice is an unopposed 60-second runner course; Lance and Coins retain their hazards. Solo play still requires a dedicated server.

One shared lobby is supported. Joins during matches are rejected. Disconnects forfeit participation. An incomplete Ballista rotation restarts with the remaining roster so everyone has equal shooter opportunities. Fewer than two players in a competitive match returns the survivor to the lobby without awarding the unfinished game. An empty server restores default lobby selections. Matches are not saved; settings store preferences and the last connection address.

## Verify

```powershell
& $Godot --headless --path . --script tests/test_rules.gd
& $Godot --headless --path . --script tests/inspect_assets.gd
& $Godot --headless --path . --script tests/test_session.gd
./tests/run_network.ps1 -Godot $Godot -Players 1 -Port 7100
./tests/run_network.ps1 -Godot $Godot -Players 2 -Port 7100
./tests/run_network.ps1 -Godot $Godot -Players 3 -Port 7101
./tests/run_network.ps1 -Godot $Godot -Players 4 -Port 7102
./tests/run_network.ps1 -Godot $Godot -Players 4 -Port 7102 -Games 'ballista,coins' -RandomOrder
./tests/run_network.ps1 -Godot $Godot -Players 2 -Port 7100 -LatencyMs 60 -LossPercent 2
./tests/run_network.ps1 -Godot $Godot -Players 2 -Port 7110 -Games 'ballista,lance' -LatencyMs 60 -LossPercent 2 -Presentation
./tests/run_network.ps1 -Godot $Godot -Players 2 -Port 7111 -Games 'coins' -Matches 2
./tests/run_rejections.ps1 -Godot $Godot
```

Network tests use separate OS processes and actual ENet connections. They shorten instructions/results only, rename players in the lobby, validate player numbers, and compare scores and game order across clients. A full playlist contains 7 practice attempts or 8/9/10 competitive rounds/heats with 2/3/4 players. Use stable IDs with `-Games ballista,lance,coins`; `-RandomOrder` tests shuffling. Gameplay timers remain unchanged during tests. Logs are written under `.godot/network-N/`. Test clients are development tooling, not an in-game bot mode.

`-Presentation` drives physical keyboard events through the normal client controller and samples the predicted pawn against received snapshots. It detects major divergence; human playtesting is still needed to assess movement feel, warning readability, and shove fairness. `-Matches 2` completes a rematch and verifies that scores reset while identities and selections persist.

## Export and Vultr deployment

Run `./deploy/build.ps1 -Godot $Godot`. The current workspace already has matching native export templates cached. For a fresh checkout, install standard Godot 4.7.2 export templates or pass `-TemplateArchive 'path/to/Godot_v4.7.2-stable_export_templates.tpz'` to the build script. Native templates work with this GDScript-only project even when the editor is the .NET edition. The script copies only the required templates into `.cache/templates/`, which the export presets reference. Distribute the complete `builds/windows/` directory to friends.

See [TEST_REPORT.md](TEST_REPORT.md) for completed checks and remaining live-hosting validation. No Vultr server has been provisioned by this project.

Provision an Ubuntu 24.04 x86-64 Vultr Cloud Compute VM near the players, initially 1 vCPU and 2 GB RAM. Obtain its public IP and configure SSH key access. Copy `builds/linux/` and `deploy/` to a staging directory on the VM using SCP, then run:

```bash
chmod +x deploy/install-server.sh
sudo ./deploy/install-server.sh "$PWD/linux"
sudo ufw allow OpenSSH
sudo ufw allow 7000/udp
# If enabling UFW for the first time, verify the SSH rule before enabling it.
sudo ufw enable
sudo journalctl -u party-knight -f
```

Attach a Vultr firewall allowing UDP 7000 and SSH from your administration IP. Both the host and Vultr firewalls must permit the game port. Friends connect to the VM's public IP. The systemd service runs as `party-knight`, restarts after crashes, and starts after a reboot. Change `/etc/party-knight.env` and both firewall rules together when changing ports.

For updates, stop the service and rerun the installer with the new build. This redesign uses protocol 3. Both clients and server must use the same release. Do not upgrade during an active match. Bump `Session.PROTOCOL` for incompatible changes to rules, RPCs, or scene state.

Live deployment requires your VM and SSH access. A successful local test does not establish Vultr reachability or internet performance. After deployment, complete a match from two separate internet connections, check four-player resource usage, and reboot the VM to verify automatic recovery.

## Structure and assets

`scripts/net` owns sessions and validates inputs. `scripts/games` owns rules and authoritative simulation. `scripts/view` owns blockouts, models, effects, and movement presentation. `scripts/ui` owns menus and HUD. Typed GameRules resources select the server scene, presentation scene, control profile, round/heat policy, and performance display. PartyGame supplies results and elimination; MovingGame and PartyPawn supply validated movement and shoves; HazardClock supplies hazard phases. Client modules own cameras, controls, and HUD hints. See [DESIGN.md](DESIGN.md) for system details and deferred games.

Characters use the supplied **Free Medieval 3D People Low Poly Pack**, `fbx/people_unity/peasant_1.fbx` through `peasant_6.fbx`, and its texture atlas. Original files remain intact. The pack's supplied `License.txt` points to Craftpix's license terms; retain that file with the project. Rig poses and all environment geometry are authored by this project.
>>>>>>> ab2e8cd (VTHacks submission)
