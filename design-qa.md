# FocusOrbit Design QA

## Verified Captures

- `output/qa/destination-photos-v3.png`
- `output/qa/flight-cockpit-v4.png`
- `output/qa/launch-cockpit-v3.png`
- `output/qa/arrival-cockpit-v3.png`
- `output/qa/flight-earth-moon-v6.png`
- `output/qa/orbit-continuity-v6.png`
- `output/qa/lunar-touchdown-v5.png`
- `output/qa/docking-contact-v5.png`
- `output/qa/home-motion-v7.png`
- `output/qa/docking-tminus-v8.png`
- `output/qa/docking-contact-v9.png`
- `output/qa/destination-sizing-v12.png`
- `output/qa/home-control-v13.png`
- `output/qa/settings-japanese-v13.png`
- `output/qa/home-first-guide-v14.png`
- `output/qa/introduction-v15.png`
- `output/qa/ascent-ground-v15.png`
- `output/qa/ascent-earth-limb-v15.png`
- `output/qa/orbit-continuity-v15.png`
- `output/qa/docking-connected-v16.png`
- `output/qa/setup-180-v17.png`
- `output/qa/lunar-generated-approach-v17.png`
- `output/qa/lunar-generated-touchdown-v17.png`
- `output/qa/saturn-orbit-flyby-v18.png`

## Result

- Normal flight uses 21 low-luminance point stars with no speed lines or frequent flybys.
- A project-local photoreal cockpit overlay establishes a seated pilot viewpoint with ceiling, window seals, side consoles, and a dashboard.
- Launch progresses through pad hold, engine ignition, tower clearance, cloud ascent, sky darkening, and orbital insertion.
- Lunar and Mars arrivals transition to real surface imagery; station arrival uses docking guidance; Jupiter and Saturn use orbital capture.
- Destination selection uses photographic NASA imagery for every destination. Saturn and station images have transparent space backgrounds, and Saturn's full ring span remains visible.
- The home product title is `FOCUS ORBIT`; `宇宙集中タイマー` is the descriptor.
- Japanese voice selection explicitly prioritizes premium/enhanced natural female voices and excludes character-like voices where possible.
- Mission-pass authentication illuminates five scanner segments in sequence and emits one rigid haptic for each newly crossed segment.
- Flight rendering uses a 60 fps timeline and interpolates telemetry-driven body movement to avoid half-second position jumps.
- Earth is centered below the cockpit window with its upper hemisphere visible; station missions suppress the departure Earth layer.
- Launch imagery remains continuous through tower clearance, atmospheric darkening, and orbital insertion without a black scene cut.
- Lunar and Mars approaches include surface closure, dust, touchdown settling, and confirmed contact. Station arrival aligns the forward port, converges capture guides, and confirms docking capture.
- The cockpit window remains the common camera reference through launch, cruise, approach, and contact. Earth recedes below the craft while the destination stays on the forward optical axis.
- Shared visual geometry prevents celestial-body position and scale resets between launch, cruise, and arrival.
- Final approach begins during the mission's last 9.2 seconds. The countdown uses ceiling semantics and reaches zero only at touchdown, docking capture, or orbital insertion.
- Station docking accelerates its final closure toward the forward port, so the capture target fills the window at contact rather than completing at a visible distance.
- Home, setup, and destination selection use restrained ambient drift, press feedback, selection springs, and cross-screen fades. Reduced Motion disables the repeating home motion.
- Destination cards use one fixed right-side celestial slot. Moon, Mars, and Jupiter share an 88 pt body diameter; Saturn receives a 112 pt ring-safe frame; the station uses a 104 pt full-craft frame. Selection no longer changes the card's outer size.
- The home screen now exposes daily focus time, a seven-day activity chart, streak status, and a reusable previous-mission action without adding gamification.
- First-time users receive a non-blocking three-step guide on the home screen instead of a forced onboarding flow.
- Mission history details can repopulate focus title, duration, and destination into a new mission setup.
- Settings use Japanese primary headings with restrained English secondary labels and clearly explain on-device records and completion-only notifications.
- First launch now uses a skippable three-page Japanese introduction derived from the useful preflight structure in the supplied reference video, without adopting its map, flight, or payment features.
- Visible duration presets now include 120, 150, and 180 minutes while preserving 1-to-180-minute custom input.
- Launch continuity now makes the pad and tower shrink away, passes through clouds and atmospheric darkening, reveals a large Earth limb, and resolves to the exact same orbital framing used by cruise.
- Final approach lasts 14 seconds and inherits matching cruise geometry. Its range starts at 18 km for surface landings, 120 m for station docking, and 12,000 km for giant-planet orbit insertion.
- Moon and Mars use project-local photorealistic portrait descent plates with a fixed forward landing corridor; their terrain rises into view only during the final 20 percent of approach.
- Station success requires range zero and exact center alignment; the completed frame visibly closes four green latch indicators around the port.
- Jupiter and Saturn perform lateral flyby and orbital-insertion visuals instead of landing or contact states.

No blocking P0, P1, or P2 visual issues remain in the iPhone 15 Pro simulator review. Final voice timbre, haptics, and sustained frame pacing require physical-device verification.

Final result: passed
