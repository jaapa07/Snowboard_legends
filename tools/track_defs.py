"""Authored course layouts for Snowboard Legends 3D.
Segments: (length_m, turn_deg (+ = right), slope_deg, width_m, bank_deg)
Features use s (distance along the centreline in metres) and lat (lateral offset, + = right).
These hand-authored layouts drive the Blender course builder (visual + collision) and the runtime data
(checkpoints, AI racing line, pickups). They are not random: every number below is a design decision."""

TRACKS = {}

TRACKS["vale_pinheiros"] = dict(
    name="Vale dos Pinheiros", name_en="Pine Valley", theme="day", snow="snow_day", rock="rock_grey",
    sky=("#5aa8ff", "#d8ecff"), fog="#dceaff", sun=(-50, 35), trees=["tree_pine_a", "tree_pine_b", "tree_birch"], tree_density=1.0,
    segments=[(40, 0, 5, 22, 0), (110, 0, 9, 18, 0), (70, 40, 11, 16, 8), (70, -55, 11, 16, 8), (60, 15, 12, 20, 0),
              (90, 30, 12, 22, 6), (100, 75, 13, 16, 16), (60, 0, 11, 18, 0), (170, -25, 10, 18, 4), (80, 0, 4, 24, 0)],
    features=[
        dict(type="coins", s=60, lat=-4, n=5), dict(type="coins", s=95, lat=4, n=5), dict(type="coins", s=130, lat=0, n=6),
        dict(type="sign", s=165, lat=9, kind="sign_right"), dict(type="sign", s=235, lat=-9, kind="sign_left"),
        dict(type="ramp", s=150, lat=0, w=7, h=1.2, l=6),
        dict(type="split", s0=305, s1=372, div=5, kind="rocks"),
        dict(type="ramp", s=318, lat=6, w=5, h=1.5, l=6), dict(type="zone", s0=328, s1=338, lat0=2.5, lat1=11, kind="slush"),
        dict(type="landmark", s=333, lat=-6, kind="covered_bridge"),
        dict(type="split", s0=400, s1=480, div=6, kind="trees"),
        dict(type="coins", s=420, lat=-7, n=8), dict(type="rail", s=430, lat=7, len=14),
        dict(type="ramp", s=505, lat=0, w=8, h=1.6, l=7),
        dict(type="items", s=640), dict(type="coins", s=700, lat=0, n=6),
        dict(type="landmark", s=120, lat=-26, kind="village"), dict(type="landmark", s=560, lat=30, kind="watermill"),
        dict(type="landmark", s=760, lat=-24, kind="clocktower"),
        dict(type="hazard", s=690, lat=-6, kind="rock_grey"), dict(type="hazard", s=730, lat=5, kind="snowbank_1"),
    ])

TRACKS["lago_cristal"] = dict(
    name="Lago Cristal", name_en="Crystal Lake", theme="ice", snow="snow_soft", rock="rock_blue",
    sky=("#7ac8ff", "#eaf6ff"), fog="#e0f2ff", sun=(-40, 120), trees=["tree_pine_a", "tree_dead"], tree_density=0.7,
    segments=[(40, 0, 5, 20, 0), (90, -20, 10, 18, 4), (110, 60, 9, 16, 12), (80, 0, 6, 20, 0), (120, -70, 8, 15, 14),
              (90, 20, 11, 16, 4), (110, 50, 12, 14, 10), (100, -30, 10, 18, 6), (180, 10, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="zone", s0=240, s1=320, lat0=-10, lat1=10, kind="ice"), dict(type="zone", s0=560, s1=640, lat0=-9, lat1=9, kind="ice"),
        dict(type="tunnel", s0=330, s1=400, kind="cave"),
        dict(type="split", s0=420, s1=520, div=4, kind="ice_pillars"), dict(type="tunnel", s0=430, s1=510, lat=4.5, kind="narrow"),
        dict(type="coins", s=440, lat=4.5, n=8), dict(type="coins", s=460, lat=-5, n=4),
        dict(type="ramp", s=180, lat=0, w=8, h=1.4, l=6), dict(type="ramp", s=600, lat=-3, w=6, h=1.8, l=7), dict(type="ramp", s=615, lat=3, w=6, h=1.8, l=7),
        dict(type="items", s=280), dict(type="items", s=760),
        dict(type="coins", s=100, lat=0, n=6), dict(type="coins", s=700, lat=-4, n=6),
        dict(type="landmark", s=250, lat=-30, kind="frozen_lake"), dict(type="landmark", s=640, lat=28, kind="ice_castle"),
        dict(type="landmark", s=900, lat=-22, kind="ice_bridge"),
        dict(type="hazard", s=350, lat=4, kind="rock_ice"), dict(type="hazard", s=820, lat=-5, kind="rock_ice"),
    ])

TRACKS["pico_vulcanico"] = dict(
    name="Pico Vulcânico", name_en="Volcanic Peak", theme="volcano", snow="snow_ash", rock="rock_volcanic",
    sky=("#ff9a6a", "#ffe0c8"), fog="#d8b8a8", sun=(-25, 200), trees=["tree_dead"], tree_density=0.35,
    segments=[(40, 0, 6, 20, 0), (100, 25, 12, 16, 8), (90, -60, 13, 14, 16), (90, 60, 13, 14, 16), (110, 0, 14, 18, 0),
              (120, -45, 11, 16, 12), (100, 70, 13, 14, 18), (120, -20, 12, 18, 4), (110, 30, 10, 18, 6), (90, -10, 8, 18, 0), (100, 15, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="zone", s0=130, s1=200, lat0=-8, lat1=-2, kind="steam"), dict(type="zone", s0=640, s1=700, lat0=2, lat1=8, kind="steam"),
        dict(type="split", s0=420, s1=490, div=4, kind="lava_rocks"),
        dict(type="ramp", s=430, lat=5, w=5, h=1.8, l=6), dict(type="zone", s0=440, s1=452, lat0=2, lat1=9, kind="pit"),
        dict(type="ramp", s=250, lat=0, w=8, h=1.4, l=6), dict(type="ramp", s=820, lat=0, w=8, h=2.0, l=8),
        dict(type="items", s=360), dict(type="items", s=900),
        dict(type="coins", s=80, lat=0, n=6), dict(type="coins", s=470, lat=-5, n=7), dict(type="coins", s=760, lat=3, n=6),
        dict(type="rail", s=560, lat=-6, len=16),
        dict(type="landmark", s=300, lat=40, kind="volcano"), dict(type="landmark", s=600, lat=-26, kind="lava_falls"),
        dict(type="landmark", s=1000, lat=24, kind="obsidian_arch"),
        dict(type="hazard", s=300, lat=-4, kind="rock_dark"), dict(type="hazard", s=700, lat=-5, kind="rock_dark"), dict(type="hazard", s=950, lat=5, kind="rock_dark"),
    ])

TRACKS["festival_boreal"] = dict(
    name="Festival Boreal", name_en="Boreal Festival", theme="night", snow="snow_night", rock="rock_blue",
    sky=("#0a1030", "#2a3a7a"), fog="#1a2050", sun=(-35, 60), trees=["tree_pine_night"], tree_density=0.8,
    segments=[(40, 0, 5, 22, 0), (90, 0, 9, 18, 0), (80, -50, 10, 16, 10), (100, 0, 9, 24, 0), (90, 65, 11, 16, 14),
              (80, 0, 9, 18, 0), (110, -40, 11, 16, 10), (100, 20, 10, 20, 0), (180, -10, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="split", s0=225, s1=305, div=6, kind="houses"),
        dict(type="platform", s0=235, s1=295, lat=7, w=6, h=2.2, kind="roof"),
        dict(type="coins", s=245, lat=7, n=8),
        dict(type="rail", s=340, lat=-5, len=16), dict(type="rail", s=345, lat=5, len=16), dict(type="rail", s=520, lat=0, len=12),
        dict(type="ramp", s=140, lat=0, w=8, h=1.5, l=6), dict(type="ramp", s=600, lat=-4, w=6, h=1.6, l=6),
        dict(type="items", s=400), dict(type="items", s=730),
        dict(type="coins", s=70, lat=0, n=6), dict(type="coins", s=460, lat=-3, n=6), dict(type="coins", s=820, lat=3, n=6),
        dict(type="landmark", s=180, lat=-28, kind="pagoda"), dict(type="landmark", s=420, lat=26, kind="ferris_wheel"),
        dict(type="landmark", s=800, lat=-24, kind="plaza_tree"),
        dict(type="hazard", s=470, lat=5, kind="snowbank_0"),
    ])

TRACKS["floresta_gigante"] = dict(
    name="Floresta Gigante", name_en="Giant Forest", theme="forest", snow="snow_soft", rock="rock_grey",
    sky=("#6ab0e8", "#e0f0e0"), fog="#cfe0d8", sun=(-55, 300), trees=["tree_giant", "tree_pine_b", "tree_pine_a"], tree_density=1.3,
    segments=[(40, 0, 5, 20, 0), (110, 15, 10, 18, 0), (100, -45, 11, 16, 10), (120, 40, 12, 22, 8), (90, 0, 11, 18, 0),
              (130, -60, 12, 16, 14), (110, 30, 12, 22, 6), (110, 0, 11, 18, 0), (110, 35, 10, 16, 8), (100, -15, 9, 18, 0), (100, 20, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="split", s0=280, s1=370, div=7, kind="giant_roots"),
        dict(type="platform", s0=285, s1=365, lat=-7, w=5, h=3.0, kind="walkway"),
        dict(type="coins", s=300, lat=-7, n=8),
        dict(type="split", s0=600, s1=690, div=6, kind="trees"),
        dict(type="coins", s=620, lat=6, n=6), dict(type="ramp", s=650, lat=-6, w=5, h=1.6, l=6),
        dict(type="hazard", s=180, lat=-5, kind="log"), dict(type="hazard", s=200, lat=5, kind="log"), dict(type="hazard", s=500, lat=0, kind="log"),
        dict(type="ramp", s=440, lat=0, w=8, h=1.6, l=6), dict(type="ramp", s=900, lat=0, w=8, h=1.8, l=7),
        dict(type="items", s=420), dict(type="items", s=820),
        dict(type="coins", s=80, lat=0, n=6), dict(type="coins", s=980, lat=-3, n=6),
        dict(type="landmark", s=230, lat=30, kind="treehouse"), dict(type="landmark", s=560, lat=-28, kind="mushroom_ring"),
        dict(type="landmark", s=1000, lat=26, kind="hollow_trunk"),
    ])

TRACKS["estacao_abandonada"] = dict(
    name="Estação Abandonada", name_en="Abandoned Station", theme="station", snow="snow_storm", rock="rock_grey",
    sky=("#8aa0b8", "#e0e6ee"), fog="#c8d0dc", sun=(-35, 150), trees=["tree_dead", "tree_pine_a"], tree_density=0.5,
    segments=[(40, 0, 5, 22, 0), (100, 0, 10, 18, 0), (110, 50, 11, 16, 12), (100, 0, 12, 20, 0), (90, -55, 11, 16, 12),
              (120, 0, 10, 22, 0), (100, 40, 12, 16, 10), (120, -30, 11, 18, 6), (140, 10, 10, 18, 0), (100, -20, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="tunnel", s0=250, s1=330, kind="rail_tunnel"),
        dict(type="split", s0=470, s1=560, div=5, kind="train"),
        dict(type="platform", s0=478, s1=552, lat=-7, w=5, h=1.6, kind="metal"),
        dict(type="coins", s=490, lat=-7, n=7), dict(type="rail", s=520, lat=7, len=20),
        dict(type="ramp", s=200, lat=-3, w=6, h=1.6, l=6, kind="metal"), dict(type="ramp", s=380, lat=3, w=6, h=1.8, l=6, kind="metal"),
        dict(type="ramp", s=760, lat=0, w=8, h=2.0, l=8, kind="metal"),
        dict(type="items", s=420), dict(type="items", s=860),
        dict(type="hazard", s=600, lat=-5, kind="wagon"), dict(type="hazard", s=640, lat=5, kind="wagon"),
        dict(type="coins", s=60, lat=0, n=6), dict(type="coins", s=700, lat=0, n=6),
        dict(type="landmark", s=150, lat=-26, kind="water_tower"), dict(type="landmark", s=420, lat=30, kind="station_hall"),
        dict(type="landmark", s=900, lat=-24, kind="signal_bridge"),
    ])

TRACKS["tempestade_polar"] = dict(
    name="Tempestade Polar", name_en="Polar Storm", theme="storm", snow="snow_storm", rock="rock_blue",
    sky=("#9ab0c8", "#f0f4f8"), fog="#dde6ee", sun=(-30, 90), trees=["tree_pine_a", "tree_dead"], tree_density=0.6,
    segments=[(40, 0, 5, 22, 0), (120, 10, 10, 18, 0), (110, -40, 11, 18, 8), (130, 30, 12, 20, 6), (120, -60, 12, 16, 14),
              (120, 0, 11, 22, 0), (110, 50, 12, 16, 12), (130, -20, 11, 18, 4), (150, 15, 10, 18, 0), (110, -5, 8, 20, 0), (80, 10, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="zone", s0=150, s1=330, lat0=-11, lat1=11, kind="wind", force=3.5), dict(type="zone", s0=620, s1=860, lat0=-12, lat1=12, kind="wind", force=-4.0),
        dict(type="split", s0=640, s1=760, div=4, kind="ice_wall"), dict(type="zone", s0=640, s1=760, lat0=2, lat1=11, kind="shelter"),
        dict(type="zone", s0=400, s1=480, lat0=-10, lat1=10, kind="ice"), dict(type="zone", s0=900, s1=980, lat0=-9, lat1=9, kind="whiteout"),
        dict(type="ramp", s=230, lat=0, w=8, h=1.5, l=6), dict(type="ramp", s=560, lat=0, w=8, h=1.8, l=7), dict(type="ramp", s=1050, lat=0, w=8, h=2.0, l=8),
        dict(type="items", s=360), dict(type="items", s=800), dict(type="items", s=1100),
        dict(type="coins", s=90, lat=0, n=6), dict(type="coins", s=690, lat=6, n=8), dict(type="coins", s=1000, lat=-3, n=6),
        dict(type="rail", s=450, lat=-6, len=14),
        dict(type="landmark", s=300, lat=-30, kind="weather_station"), dict(type="landmark", s=700, lat=30, kind="ice_spires"),
        dict(type="landmark", s=1150, lat=-26, kind="wind_turbines"),
        dict(type="hazard", s=520, lat=-4, kind="rock_ice"), dict(type="hazard", s=940, lat=4, kind="snowbank_2"),
    ])

TRACKS["cume_celestial"] = dict(
    name="Cume Celestial", name_en="Celestial Summit", theme="sky", snow="snow_sky", rock="rock_blue",
    sky=("#4a3ab0", "#ffc8e8"), fog="#e8d8f8", sun=(-20, 240), trees=["tree_pine_a", "tree_birch"], tree_density=0.6,
    segments=[(40, 0, 6, 22, 0), (100, 0, 11, 18, 0), (90, 55, 12, 15, 14), (90, -55, 12, 15, 14), (120, 0, 13, 20, 0),
              (110, 70, 12, 14, 18), (120, -30, 13, 20, 6), (110, -50, 12, 15, 14), (130, 35, 13, 18, 8), (120, 0, 12, 20, 0),
              (130, -25, 11, 18, 6), (140, 10, 9, 18, 0), (120, -15, 9, 18, 0), (80, 0, 4, 24, 0)],
    features=[
        dict(type="split", s0=400, s1=480, div=5, kind="crystals"),
        dict(type="ramp", s=405, lat=-6, w=5, h=1.8, l=6), dict(type="ramp", s=440, lat=-6, w=5, h=1.8, l=6),
        dict(type="zone", s0=416, s1=430, lat0=-11, lat1=-3, kind="pit"),
        dict(type="split", s0=980, s1=1080, div=5, kind="crystals"),
        dict(type="platform", s0=990, s1=1070, lat=6, w=5, h=2.4, kind="cloud"),
        dict(type="rail", s=700, lat=-5, len=18), dict(type="rail", s=705, lat=5, len=18),
        dict(type="ramp", s=180, lat=0, w=8, h=1.6, l=6), dict(type="ramp", s=860, lat=0, w=8, h=2.0, l=8), dict(type="ramp", s=1200, lat=0, w=8, h=2.2, l=8),
        dict(type="items", s=320), dict(type="items", s=780), dict(type="items", s=1150),
        dict(type="zone", s0=560, s1=620, lat0=-8, lat1=8, kind="boost"),
        dict(type="coins", s=80, lat=0, n=6), dict(type="coins", s=600, lat=0, n=8), dict(type="coins", s=1010, lat=6, n=8), dict(type="coins", s=1300, lat=-3, n=6),
        dict(type="landmark", s=250, lat=-32, kind="sky_temple"), dict(type="landmark", s=720, lat=30, kind="floating_isles"),
        dict(type="landmark", s=1350, lat=-26, kind="star_gate"),
        dict(type="hazard", s=300, lat=4, kind="rock_ice"), dict(type="hazard", s=1260, lat=-5, kind="rock_ice"),
    ])

TRACKS["parque_manobras"] = dict(
    name="Parque de Manobras", name_en="Trick Park", theme="day", snow="snow_day", rock="rock_grey",
    sky=("#4a9aff", "#e0f0ff"), fog="#e0eeff", sun=(-55, 20), trees=["tree_pine_a", "tree_birch"], tree_density=0.6,
    segments=[(40, 0, 6, 28, 0), (120, 0, 12, 28, 0), (90, 30, 12, 26, 6), (120, -30, 12, 28, 6), (70, 0, 10, 28, 0), (80, 0, 4, 28, 0)],
    features=[
        dict(type="ramp", s=70, lat=-7, w=7, h=1.6, l=6), dict(type="ramp", s=80, lat=7, w=7, h=2.2, l=8),
        dict(type="rail", s=120, lat=0, len=20), dict(type="ramp", s=160, lat=-6, w=8, h=2.6, l=9), dict(type="ramp", s=170, lat=7, w=6, h=1.4, l=5),
        dict(type="rail", s=215, lat=-8, len=16), dict(type="rail", s=220, lat=8, len=16), dict(type="ramp", s=260, lat=0, w=10, h=2.8, l=10),
        dict(type="ramp", s=310, lat=-7, w=7, h=2.0, l=7), dict(type="rail", s=345, lat=6, len=18), dict(type="ramp", s=385, lat=0, w=10, h=3.0, l=10),
        dict(type="platform", s0=395, s1=440, lat=-8, w=6, h=1.8, kind="walkway"),
        dict(type="coins", s=100, lat=0, n=6), dict(type="coins", s=240, lat=-4, n=6), dict(type="coins", s=360, lat=4, n=6),
        dict(type="landmark", s=150, lat=-34, kind="village"), dict(type="landmark", s=330, lat=34, kind="clocktower"), dict(type="landmark", s=470, lat=-30, kind="watermill"),
    ])

ORDER = ["vale_pinheiros", "lago_cristal", "pico_vulcanico", "festival_boreal", "floresta_gigante", "estacao_abandonada", "tempestade_polar", "cume_celestial"]
TARGET_LEN = {"vale_pinheiros": 850, "lago_cristal": 1000, "pico_vulcanico": 1150, "festival_boreal": 950,
              "floresta_gigante": 1200, "estacao_abandonada": 1100, "tempestade_polar": 1300, "cume_celestial": 1500}
