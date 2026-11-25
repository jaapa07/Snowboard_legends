#!/usr/bin/env python3
"""Writes resources/{riders,boards,tracks,items}/*.tres from the design tables below."""
import os, json
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

RIDERS = [
    ("niko", "Niko", (3, 4, 3, 4, 3), "#19c3c0", "start", "Corajoso e equilibrado.", "Brave all-rounder."),
    ("mika", "Mika", (3, 5, 4, 2, 3), "#ff6f5e", "start", "Precisão cirúrgica nas curvas.", "Surgical precision in turns."),
    ("taro", "Taro", (5, 2, 3, 3, 4), "#ff7a1a", "start", "Velocidade bruta, curva aberta.", "Raw speed, wide turns."),
    ("luna", "Luna", (3, 3, 5, 4, 2), "#8a4ae0", "start", "Rainha dos saltos estrelados.", "Queen of starry jumps."),
    ("boro", "Boro", (4, 2, 2, 4, 5), "#3aa84a", "cup1:silver", "Tanque da montanha, difícil de derrubar.", "Mountain tank, hard to knock down."),
    ("yuki", "Yuki", (2, 5, 4, 4, 2), "#3a7aff", "cup1:gold", "Leve como neve fresca.", "Light as fresh powder."),
    ("zed", "Zed", (5, 3, 2, 4, 2), "#ffd800", "cup2:silver", "Vem do futuro, só pensa em velocidade.", "From the future, all about speed."),
    ("pippa", "Pippa", (2, 4, 5, 3, 3), "#ff7ab8", "cup2:gold", "Luvas enormes, manobras enormes.", "Huge gloves, huge tricks."),
    ("kaito", "Kaito", (4, 3, 4, 3, 3), "#c8283c", "cup4:gold", "Aventureiro andarilho das montanhas; piloto secreto.", "Wandering mountain adventurer; secret rider."),
]
# id, name, category, speed, control, jump, accel, spin, price, unlock
BOARDS = [
    ("starter", "Starter", "balanced", 0.0, 0.0, 0.0, 0.0, 0.0, 0, "start", "Prancha de iniciante: sem pontos fracos.", "No weak points."),
    ("carver", "Carver", "carving", -0.04, 0.10, -0.04, 0.02, -0.04, 0, "start", "Agarra a neve nas curvas fechadas.", "Bites hard into tight turns."),
    ("float", "Float", "freestyle", -0.04, 0.0, 0.10, 0.0, 0.06, 0, "start", "Flutua no ar, gira fácil.", "Floats and spins easily."),
    ("rocket", "Rocket", "speed", 0.10, -0.08, -0.04, 0.02, -0.06, 400, "cup1:bronze", "Velocidade final alta, exige pista limpa.", "High top speed, needs clean lines."),
    ("grip", "Grip", "carving", -0.02, 0.12, -0.06, 0.04, -0.06, 350, "cup1:bronze", "Controle máximo em gelo.", "Max control on ice."),
    ("twin", "Twin", "freestyle", -0.02, 0.02, 0.06, 0.0, 0.10, 450, "cup1:silver", "Simétrica, perfeita para giros.", "Symmetric, made for spins."),
    ("powder", "Powder", "balanced", 0.04, 0.04, 0.02, -0.06, -0.02, 500, "cup2:bronze", "Desliza em neve fofa sem perder ritmo.", "Keeps pace in soft snow."),
    ("rail", "Rail", "freestyle", -0.06, 0.04, 0.04, 0.04, 0.08, 550, "cup2:silver", "Feita para corrimãos e combos.", "Built for rails and combos."),
    ("alpine", "Alpine", "carving", 0.08, 0.08, -0.10, -0.02, -0.10, 650, "cup3:bronze", "Rígida e rápida, odeia pousos tortos.", "Stiff and fast, hates sloppy landings."),
    ("aurora", "Aurora", "balanced", 0.04, 0.02, 0.04, 0.02, 0.02, 800, "cup3:silver", "Equilíbrio refinado entre tudo.", "Refined balance of everything."),
    ("comet", "Comet", "speed", 0.12, -0.04, 0.0, 0.06, -0.08, 900, "cup4:bronze", "Arranca como um cometa.", "Launches like a comet."),
    ("legend", "Legend", "speed", 0.08, 0.04, 0.04, 0.04, 0.04, 1500, "cup4:gold", "A prancha das lendas: boa em tudo, perfeita em nada.", "Great at all, perfect at none."),
]
TRACKS = [
    ("vale_pinheiros", "Vale dos Pinheiros", "Pine Valley", 1, 850, "Descida aberta entre pinheiros, vila e riacho.", "Open run through pines, village and creek."),
    ("lago_cristal", "Lago Cristal", "Crystal Lake", 1, 1000, "Gelo escorregadio, cavernas e túnel estreito.", "Slippery ice, caves and a narrow tunnel."),
    ("pico_vulcanico", "Pico Vulcânico", "Volcanic Peak", 2, 1150, "Rocha escura, vapor e fenda sinalizada.", "Dark rock, steam and a marked fissure."),
    ("festival_boreal", "Festival Boreal", "Boreal Festival", 2, 950, "Noite de lanternas, rails e telhados.", "Lantern night, rails and rooftops."),
    ("floresta_gigante", "Floresta Gigante", "Giant Forest", 3, 1200, "Árvores colossais, raízes e trilha elevada.", "Colossal trees, roots and a raised trail."),
    ("estacao_abandonada", "Estação Abandonada", "Abandoned Station", 3, 1100, "Vagões, túnel ferroviário e rampas metálicas.", "Wagons, rail tunnel and metal ramps."),
    ("tempestade_polar", "Tempestade Polar", "Polar Storm", 4, 1300, "Vento lateral, gelo e nevasca.", "Crosswinds, ice and whiteout."),
    ("cume_celestial", "Cume Celestial", "Celestial Summit", 4, 1500, "A prova final: técnica, saltos e rotas.", "The final test: technique, jumps and routes."),
    ("parque_manobras", "Parque de Manobras", "Trick Park", 0, 520, "Circuito de rampas e rails para Trick Attack.", "Ramps and rails circuit for Trick Attack."),
]
# id, name, name_en, slot, model, duration, weights(1st..4th), desc, counter
ITEMS = [
    ("snowball", "Bola de neve", "Snowball", "offense", "item_snowball", 1.0, (1.0, 1.4, 1.4, 1.2), "Projétil frontal: desacelera por 1 s.", "Desvie ou use escudo."),
    ("icemine", "Mina de gelo", "Ice mine", "offense", "item_icemine", 1.2, (1.6, 1.2, 0.8, 0.5), "Armadilha traseira: derrapagem por 1,2 s.", "Salte por cima."),
    ("penguin", "Pinguim de vento", "Wind penguin", "offense", "item_penguin", 1.0, (0.2, 0.9, 1.3, 1.6), "Perseguidor de curto alcance.", "Obstáculo ou escudo."),
    ("fog", "Névoa", "Fog", "offense", "item_fog", 2.0, (0.6, 1.0, 1.0, 1.0), "Nuvem que reduz a visibilidade por 2 s.", "Saia da área."),
    ("wave", "Onda de neve", "Snow wave", "offense", "item_wave", 0.6, (0.8, 1.0, 1.0, 0.9), "Empurra rivais próximos.", "Mantenha distância."),
    ("gust", "Rajada", "Gust", "utility", "item_gust", 2.0, (0.4, 1.0, 1.4, 1.8), "Impulso de velocidade por 2 s.", "Curvas exigem controle."),
    ("shield", "Escudo aurora", "Aurora shield", "utility", "item_shield", 6.0, (1.8, 1.2, 0.8, 0.6), "Bloqueia um ataque, expira em 6 s.", "Espere expirar."),
    ("spring", "Mola", "Spring", "utility", "item_spring", 0.0, (1.0, 1.0, 1.0, 1.0), "Salto extra a partir do solo.", "Risco no pouso."),
    ("magnet", "Ímã", "Magnet", "utility", "item_magnet", 5.0, (1.0, 1.0, 1.0, 0.8), "Atrai moedas próximas por 5 s.", "Alcance limitado."),
    ("repair", "Reparador", "Repair kit", "utility", "item_repair", 0.0, (0.6, 0.8, 1.2, 1.6), "Recupera rapidamente de uma queda.", "Uso único."),
]


def tres(cls, script, fields):
    out = [f'[gd_resource type="Resource" script_class="{cls}" load_steps=2 format=3]', "",
           f'[ext_resource type="Script" path="{script}" id="1"]', "", "[resource]", 'script = ExtResource("1")']
    for k, v in fields.items():
        if isinstance(v, bool):
            out.append(f"{k} = {'true' if v else 'false'}")
        elif isinstance(v, (int, float)):
            out.append(f"{k} = {v}")
        elif isinstance(v, tuple) and v[0] == "sn":
            out.append(f'{k} = &"{v[1]}"')
        elif isinstance(v, tuple) and v[0] == "color":
            h = v[1].lstrip("#"); r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
            out.append(f"{k} = Color({r:.3f}, {g:.3f}, {b:.3f}, 1)")
        elif isinstance(v, tuple) and v[0] == "f32":
            out.append(f"{k} = PackedFloat32Array({', '.join(str(x) for x in v[1])})")
        else:
            out.append(f'{k} = "{v}"')
    return "\n".join(out) + "\n"


def main():
    for d in ("riders", "boards", "tracks", "items"):
        os.makedirs(os.path.join(ROOT, "resources", d), exist_ok=True)
    for rid, nm, st, col, unl, tp, te in RIDERS:
        f = dict(id=("sn", rid), display_name=nm, speed=st[0], control=st[1], jump=st[2], accel=st[3], resist=st[4],
                 model_path=f"res://assets/models/riders/{rid}.glb", portrait_path=f"res://assets/sprites/portraits/{rid}.png",
                 color=("color", col), tagline_pt=tp, tagline_en=te, unlock=unl)
        open(os.path.join(ROOT, "resources", "riders", rid + ".tres"), "w").write(tres("RiderDefinition", "res://scripts/core/rider_definition.gd", f))
    for bid, nm, cat, sp, co, ju, ac, spn, price, unl, dp, de in BOARDS:
        f = dict(id=("sn", bid), display_name=nm, category=cat, speed_mod=sp, control_mod=co, jump_mod=ju, accel_mod=ac, spin_mod=spn,
                 price=price, unlock=unl, node_name="board_" + bid, thumbnail_path=f"res://assets/sprites/boards/board_{bid}.png", description_pt=dp, description_en=de)
        open(os.path.join(ROOT, "resources", "boards", bid + ".tres"), "w").write(tres("BoardDefinition", "res://scripts/core/board_definition.gd", f))
    for k, (tid, nm, ne, cup, L, dp, de) in enumerate(TRACKS):
        f = dict(id=("sn", tid), display_name=nm, display_name_en=ne, scene_path=f"res://assets/models/tracks/{tid}.glb",
                 data_path=f"res://assets/data/tracks/{tid}.json", music_path=f"res://assets/audio/music/track_{tid}.ogg",
                 map_path=f"res://assets/sprites/maps/{tid}.png", cup=cup, length_m=float(L), description_pt=dp, description_en=de, campaign=cup > 0)
        open(os.path.join(ROOT, "resources", "tracks", tid + ".tres"), "w").write(tres("TrackDefinition", "res://scripts/core/track_definition.gd", f))
    for iid, nm, ne, slot, model, dur, w, dp, cp in ITEMS:
        f = dict(id=("sn", iid), display_name=nm, display_name_en=ne, slot=slot, icon_path=f"res://assets/sprites/items/{iid}.png", model_node=model,
                 duration=dur, weights=("f32", w), description_pt=dp, counterplay_pt=cp)
        open(os.path.join(ROOT, "resources", "items", iid + ".tres"), "w").write(tres("ItemDefinition", "res://scripts/core/item_definition.gd", f))
    for b in BOARDS:
        mods = [abs(x) for x in b[3:8]]
        assert max(mods) <= 0.12, b
    print("resources written")


if __name__ == "__main__":
    main()
