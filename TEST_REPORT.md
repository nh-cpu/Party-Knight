# Prototype verification

Verified locally using Godot 4.7.2 (engine build ed1daf0bf).

| Check | Result |
| --- | --- |
| Import and script compilation | Passed |
| Minigame rule tests | 16 checks passed |
| Session authority and lifecycle tests | 28 checks passed, including numbering, names, host-only selection, shuffle, solo start, and solo continuation |
| Solo nine-round match | Passed; all three games completed through match results |
| Two-player selected six-round match, random order, 120 ms simulated RTT and 2% packet loss | Passed; identical results and game order on both clients |
| Four-player selected six-round match, random order | Passed; only selected games played, identical results on all clients |
| Version mismatch, full lobby, late join, scene loading timeout | Passed using real ENet clients |
| Lobby layout, six peasant models, and three arena views | Rendered; colored numbered names replace floor markers; four-player lobby controls fit at 1280 × 720 |
| Windows release export | Passed; packaged client started headlessly without errors |
| Linux release export | Passed; dedicated server started in a non-root Fedora 44 container without graphics |
| Linux deployment script syntax | Passed with bash -n |

Logs and screenshots are in the local `.godot/` directory. Reproduction commands are in README.md and the `tests/` scripts. Test clients run in separate OS processes. The impairment test uses a UDP relay that delays each direction by 60 ms and randomly drops 2% of datagrams. Automated input exercises the authoritative rules and transport; this does not replace human assessment of predicted movement feel over the internet.

The latest lobby update uses protocol 2; update both clients and the dedicated server together. Every network test client changes its name before readying up and checks that its observed player numbers remain valid and stable. Session tests also check that numbers survive departures, vacant numbers can be reused, empty game selections cannot start, and a single selected game ends after three rounds. The loading-timeout test now verifies that the remaining player continues into play.

Earlier baseline testing completed nine-round matches with two, three, and four clients, including an impaired two-client connection, and passed all 16 minigame rule checks. This update reran session, selection, solo, connection-rejection, rendering, export, and executable startup checks; it did not rerun the unchanged minigame rule suite or the baseline three-player scenario.

The simultaneous-disconnect test exposed an unnecessary peer-relay error. Server relaying was disabled because this game routes every action through the authority; three- and four-client tests then completed without server errors.

## Still dependent on live infrastructure

No Vultr VM or SSH connection has been supplied. Public firewall reachability, a match from separate internet connections, four-client VM resource usage, and automatic recovery after a Vultr reboot remain to be verified. The Linux container test validates the executable, not a deployed Ubuntu service.

The project deliberately uses basic geometry, procedural rig poses, synthesized sound cues, and simple blood effects. Art and audio polish remain prototype quality.
