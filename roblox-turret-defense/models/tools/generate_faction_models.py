#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""터렛 디펜스 v3 — 5대 종족 본진 5종 · 대표 유닛 10종 · 몬스터/보스 2종 생성기

omega_destroyer_boss / human_command_nexus 는 generate_omega_nexus.py 가 만든다.
이 파일은 그 나머지를 만들고, 공용 재질/헬퍼를 공유한다.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshlib import TAU, Model, ellipsoid, extrude_poly, revolve, star_pts, torus, tube  # noqa: E402
from generate_omega_nexus import (bar, blade, box, cone, frame, limb_frame,  # noqa: E402
                                  write_obj)

# ---------------------------------------------------------------- 재질 (전 종족 공용)
MATS = {
    # 휴먼
    'HullBlue':    {'kd': (0.205, 0.262, 0.372), 'ns': 46, 'ks': 0.35},
    'HullNavy':    {'kd': (0.105, 0.140, 0.215), 'ns': 40, 'ks': 0.30},
    'HullLight':   {'kd': (0.620, 0.672, 0.740), 'ns': 54, 'ks': 0.40},
    'HullWhite':   {'kd': (0.860, 0.888, 0.910), 'ns': 44, 'ks': 0.30},
    # 메카
    'MechSteel':   {'kd': (0.330, 0.330, 0.352), 'ns': 58, 'ks': 0.50},
    'MechGun':     {'kd': (0.155, 0.155, 0.175), 'ns': 50, 'ks': 0.45},
    'MechRust':    {'kd': (0.430, 0.205, 0.110), 'ns': 30, 'ks': 0.25},
    'MechAmber':   {'kd': (1.000, 0.560, 0.090), 'ns': 90, 'ks': 0.70, 'ke': 0.70},
    # 아케인
    'ArcStone':    {'kd': (0.285, 0.245, 0.360), 'ns': 30, 'ks': 0.22},
    'ArcStoneLt':  {'kd': (0.430, 0.382, 0.520), 'ns': 40, 'ks': 0.30},
    'ArcCrystal':  {'kd': (0.560, 0.360, 0.960), 'ns': 95, 'ks': 0.85, 'ke': 0.55, 'd': 0.92},
    'ArcRune':     {'kd': (0.760, 0.560, 1.000), 'ns': 100, 'ks': 0.90, 'ke': 0.80},
    # 바이오
    'BioFlesh':    {'kd': (0.355, 0.235, 0.200), 'ns': 26, 'ks': 0.18},
    'BioFleshLt':  {'kd': (0.515, 0.372, 0.300), 'ns': 30, 'ks': 0.20},
    'BioCarapace': {'kd': (0.195, 0.155, 0.120), 'ns': 46, 'ks': 0.35},
    'BioAcid':     {'kd': (0.540, 1.000, 0.280), 'ns': 95, 'ks': 0.80, 'ke': 0.80},
    'BioFleshB':   {'kd': (0.300, 0.205, 0.175), 'ns': 22, 'ks': 0.14},
    # 드론
    'DroneHull':   {'kd': (0.215, 0.235, 0.270), 'ns': 60, 'ks': 0.55},
    'DroneDark':   {'kd': (0.090, 0.100, 0.120), 'ns': 45, 'ks': 0.40},
    'DroneCyan':   {'kd': (0.420, 0.920, 1.000), 'ns': 100, 'ks': 0.85, 'ke': 0.85},
    # 공용
    'Steel':       {'kd': (0.420, 0.445, 0.480), 'ns': 70, 'ks': 0.55},
    'DarkMetal':   {'kd': (0.085, 0.095, 0.120), 'ns': 40, 'ks': 0.30},
    'Concrete':    {'kd': (0.505, 0.520, 0.545), 'ns': 10, 'ks': 0.10},
    'Hazard':      {'kd': (0.930, 0.720, 0.090), 'ns': 30, 'ks': 0.25},
    'GlowCyan':    {'kd': (0.480, 0.940, 1.000), 'ns': 90, 'ks': 0.80, 'ke': 0.80},
    'GlowWhite':   {'kd': (0.900, 0.985, 1.000), 'ns': 90, 'ks': 0.85, 'ke': 0.85},
    'GlowRed':     {'kd': (1.000, 0.250, 0.200), 'ns': 90, 'ks': 0.60, 'ke': 0.80},
    # 몬스터
    'Hide':        {'kd': (0.280, 0.225, 0.235), 'ns': 28, 'ks': 0.22},
    'HideLight':   {'kd': (0.415, 0.345, 0.340), 'ns': 34, 'ks': 0.28},
    'BonePlate':   {'kd': (0.560, 0.520, 0.470), 'ns': 44, 'ks': 0.35},
    'Claw':        {'kd': (0.905, 0.880, 0.820), 'ns': 58, 'ks': 0.52},
    'MonGlow':     {'kd': (1.000, 0.380, 0.180), 'ns': 100, 'ks': 0.80, 'ke': 0.85},
    'MonGlowHero': {'kd': (1.000, 0.230, 0.520), 'ns': 100, 'ks': 0.85, 'ke': 0.90},
}

GLOW = ('MechAmber', 'ArcCrystal', 'ArcRune', 'BioAcid', 'DroneCyan', 'GlowCyan',
        'GlowWhite', 'GlowRed', 'MonGlow', 'MonGlowHero')


# ---------------------------------------------------------------- 헬퍼
def crystal(base, tip, r, sides=6, waist=0.34, r2=0.55):
    """양끝이 뾰족한 결정(크리스탈)."""
    b = np.asarray(base, float)
    t = np.asarray(tip, float)
    d = t - b
    L = float(np.linalg.norm(d))
    d = d / L
    x = np.cross(np.array([0.0, 0.0, 1.0]), d)
    if float(np.linalg.norm(x)) < 1e-6:
        x = np.array([1.0, 0.0, 0.0])
    x = x / np.linalg.norm(x)
    y = np.cross(d, x)
    V = [b]
    for rho, hh in ((1.0, waist), (r2, 0.74)):
        for i in range(sides):
            a = TAU * i / sides
            V.append(b + d * (L * hh) + rho * r * (math.cos(a) * x + math.sin(a) * y))
    V.append(t)
    apex = len(V) - 1
    F = []
    for i in range(sides):
        i2 = (i + 1) % sides
        F.append((0, 1 + i, 1 + i2))
    for i in range(sides):
        i2 = (i + 1) % sides
        F.append((1 + i, 1 + sides + i, 1 + sides + i2))
        F.append((1 + i, 1 + sides + i2, 1 + i2))
    for i in range(sides):
        i2 = (i + 1) % sides
        F.append((1 + sides + i, apex, 1 + sides + i2))
    return np.array(V), np.array(F)


def ring(m, tag, center, major, minor, mat, R=None, seg=18, tub=6):
    m.add(tag, mat, torus(major=major, minor=minor, seg=seg, tub=tub, center=center, R=R))


def biped(m, tag, o, s, mat_body, mat_armor, mat_glow, helmet=True, gun=False,
          claws=False, bulk=1.0, crest=False):
    """발밑이 o, 키가 s인 2족 유닛."""
    o = np.asarray(o, float)
    hip = o + np.array([0, 0, 0.52 * s])
    chest = o + np.array([0, 0, 0.72 * s])
    sh_z = 0.80 * s
    # 몸통
    m.add(tag + '_Torso', mat_body, revolve(
        [(0.155 * s * bulk, 0.88 * s), (0.205 * s * bulk, 0.80 * s),
         (0.175 * s * bulk, 0.66 * s), (0.135 * s * bulk, 0.54 * s)], 6, center=tuple(o)))
    m.add(tag + '_ChestPlate', mat_armor,
          extrude_poly([(-0.17 * s, 0.15 * s), (0.17 * s, 0.15 * s), (0.21 * s, -0.02 * s),
                        (0.10 * s, -0.16 * s), (-0.10 * s, -0.16 * s), (-0.21 * s, -0.02 * s)],
                       0.07 * s, R=frame((0.0, -1.0, 0.15)), center=tuple(chest + np.array([0, -0.18 * s, 0.0]))))
    m.add(tag + '_Core', mat_glow,
          ellipsoid(tuple(chest + np.array([0, -0.20 * s, 0.03 * s])),
                    (0.03 * s, 0.02 * s, 0.035 * s), 8, 5))
    # 머리
    head_c = o + np.array([0, -0.01 * s, 0.93 * s])
    m.add(tag + '_Head', mat_body, ellipsoid(tuple(head_c), (0.093 * s, 0.10 * s, 0.10 * s), 9, 6))
    m.add(tag + '_Visor', mat_glow,
          box(tuple(head_c + np.array([0, -0.075 * s, 0.005 * s])), (0.13 * s, 0.03 * s, 0.035 * s)))
    if helmet:
        m.add(tag + '_Helmet', mat_armor,
              ellipsoid(tuple(head_c + np.array([0, 0.012 * s, 0.035 * s])),
                        (0.105 * s, 0.108 * s, 0.085 * s), 9, 5))
    if crest:
        m.add(tag + '_Crest', mat_armor,
              extrude_poly([(-0.02 * s, 0.10 * s), (0.02 * s, 0.10 * s), (0.015 * s, -0.02 * s),
                            (-0.015 * s, -0.02 * s)], 0.03 * s,
                           R=frame((1.0, 0.0, 0.0)), center=tuple(head_c + np.array([0, 0.01 * s, 0.10 * s]))))
    # 어깨 + 팔
    for sx in (-1, 1):
        sh = o + np.array([sx * 0.19 * s * bulk, 0, sh_z])
        el = o + np.array([sx * 0.235 * s * bulk, -0.03 * s, 0.62 * s])
        wr = o + np.array([sx * 0.245 * s * bulk, -0.12 * s, 0.45 * s])
        m.add('%s_Shoulder_%d' % (tag, sx), mat_armor,
              ellipsoid(tuple(sh), (0.075 * s * bulk, 0.075 * s, 0.065 * s), 8, 5))
        m.add('%s_UpperArm_%d' % (tag, sx), mat_body, tube([sh, el], [0.045 * s * bulk, 0.038 * s], 7))
        m.add('%s_Elbow_%d' % (tag, sx), mat_armor, ellipsoid(tuple(el), (0.042 * s,) * 3, 7, 4))
        m.add('%s_Forearm_%d' % (tag, sx), mat_body, tube([el, wr], [0.038 * s, 0.032 * s], 7))
        m.add('%s_Hand_%d' % (tag, sx), mat_armor, box(tuple(wr + np.array([0, -0.01 * s, -0.03 * s])),
                                                       (0.055 * s, 0.05 * s, 0.07 * s)))
        if claws:
            for k in range(3):
                b0 = wr + np.array([(k - 1) * 0.028 * s, -0.02 * s, -0.06 * s])
                m.add('%s_Claw_%d_%d' % (tag, sx, k), 'Claw',
                      tube([b0, b0 + np.array([0, -0.04 * s, -0.07 * s]),
                            b0 + np.array([0, -0.05 * s, -0.15 * s])],
                           [0.016 * s, 0.011 * s, 0.002 * s], 5))
    # 다리
    for sx in (-1, 1):
        hp = o + np.array([sx * 0.085 * s, 0, 0.52 * s])
        kn = o + np.array([sx * 0.095 * s, -0.015 * s, 0.29 * s])
        an = o + np.array([sx * 0.095 * s, 0.005 * s, 0.06 * s])
        m.add('%s_Thigh_%d' % (tag, sx), mat_body, tube([hp, kn], [0.062 * s * bulk, 0.050 * s], 7))
        m.add('%s_Knee_%d' % (tag, sx), mat_armor, ellipsoid(tuple(kn), (0.055 * s,) * 3, 7, 4))
        m.add('%s_Shin_%d' % (tag, sx), mat_body, tube([kn, an], [0.048 * s, 0.038 * s], 7))
        m.add('%s_Boot_%d' % (tag, sx), mat_armor,
              box(tuple(o + np.array([sx * 0.095 * s, -0.03 * s, 0.035 * s])),
                  (0.085 * s, 0.17 * s, 0.07 * s)))
    if gun:
        g0 = o + np.array([0.27 * s, -0.16 * s, 0.48 * s])
        m.add(tag + '_Rifle', mat_armor, bar(tuple(g0), tuple(g0 + np.array([0, -0.46 * s, 0.03 * s])),
                                             0.075 * s, 0.11 * s))
        m.add(tag + '_RifleBarrel', 'DarkMetal',
              tube([tuple(g0 + np.array([0, -0.40 * s, 0.03 * s])),
                    tuple(g0 + np.array([0, -0.62 * s, 0.03 * s]))], [0.032 * s, 0.028 * s], 6))
        m.add(tag + '_Stock', mat_armor,
              box(tuple(g0 + np.array([0, 0.09 * s, -0.01 * s])), (0.06 * s, 0.16 * s, 0.10 * s)))
        m.add(tag + '_Mag', mat_armor,
              box(tuple(g0 + np.array([0, -0.17 * s, -0.10 * s])), (0.055 * s, 0.09 * s, 0.16 * s)))
        m.add(tag + '_Scope', 'DarkMetal',
              box(tuple(g0 + np.array([0, -0.20 * s, 0.085 * s])), (0.05 * s, 0.20 * s, 0.05 * s)))
        m.add(tag + '_MuzzleGlow', mat_glow,
              box(tuple(g0 + np.array([0, -0.63 * s, 0.03 * s])), (0.04 * s, 0.03 * s, 0.045 * s)))


def quadruped(m, tag, o, s, mat_body, mat_armor, mat_glow, tail=True, spikes=True):
    o = np.asarray(o, float)
    body_c = o + np.array([0, 0, 0.62 * s])
    m.add(tag + '_Body', mat_body, ellipsoid(tuple(body_c), (0.30 * s, 0.55 * s, 0.28 * s), 10, 6))
    m.add(tag + '_Back', mat_armor, ellipsoid(tuple(body_c + np.array([0, 0.02 * s, 0.10 * s])),
                                              (0.26 * s, 0.46 * s, 0.22 * s), 9, 5))
    # 머리
    head = o + np.array([0, -0.62 * s, 0.72 * s])
    m.add(tag + '_Neck', mat_body, tube([body_c + np.array([0, -0.40 * s, 0.14 * s]), head],
                                        [0.17 * s, 0.14 * s], 8))
    m.add(tag + '_Head', mat_body, ellipsoid(tuple(head), (0.15 * s, 0.20 * s, 0.15 * s), 9, 6))
    m.add(tag + '_Jaw', mat_armor, box(tuple(head + np.array([0, -0.13 * s, -0.08 * s])),
                                       (0.20 * s, 0.24 * s, 0.10 * s)))
    for sx in (-1, 1):
        m.add('%s_Eye_%d' % (tag, sx), mat_glow,
              ellipsoid(tuple(head + np.array([sx * 0.075 * s, -0.14 * s, 0.055 * s])),
                        (0.035 * s, 0.03 * s, 0.03 * s), 7, 4))
        # 이빨
        for k in range(3):
            b0 = head + np.array([sx * (0.05 + 0.035 * k) * s, -0.22 * s, -0.06 * s])
            m.add('%s_Tooth_%d_%d' % (tag, sx, k), 'Claw',
                  cone(tuple(b0), tuple(b0 + np.array([0, -0.01 * s, -0.07 * s])), 0.018 * s, 5))
        # 다리 2쌍
        for i, (hy, fy) in enumerate(((-0.26, -0.34), (0.28, 0.30))):
            hip = o + np.array([sx * 0.22 * s, hy * s, 0.52 * s])
            knee = o + np.array([sx * 0.30 * s, (hy - 0.10) * s, 0.30 * s])
            foot = o + np.array([sx * 0.30 * s, (hy - 0.14) * s, 0.04 * s])
            m.add('%s_Leg_%d_%d' % (tag, sx, i), mat_body,
                  tube([hip, knee, foot], [0.085 * s, 0.065 * s, 0.050 * s], 7))
            m.add('%s_Paw_%d_%d' % (tag, sx, i), mat_armor,
                  box(tuple(o + np.array([sx * 0.30 * s, (hy - 0.16) * s, 0.035 * s])),
                      (0.13 * s, 0.19 * s, 0.07 * s)))
    if spikes:
        for k in range(5):
            t = k / 4.0
            b0 = body_c + np.array([0, (0.30 - 0.62 * t) * s, 0.22 * s])
            m.add('%s_Spike_%d' % (tag, k), 'BonePlate',
                  cone(tuple(b0), tuple(b0 + np.array([0, 0.04 * s, (0.22 - 0.06 * k) * s])),
                       0.055 * s, 5))
    if tail:
        t0 = body_c + np.array([0, 0.48 * s, 0.06 * s])
        m.add(tag + '_Tail', mat_body,
              tube([t0, t0 + np.array([0, 0.26 * s, 0.10 * s]), t0 + np.array([0, 0.44 * s, 0.30 * s])],
                   [0.10 * s, 0.06 * s, 0.02 * s], 6))


# ================================================================ 본진 4종
def build_nexus_mecha():
    m = Model('NexusMecha')
    # 8각 기단
    m.add('Base', 'Concrete', revolve([(5.00, 0.50), (5.20, 0.24), (5.00, 0.0)], 8))
    m.add('BaseBand', 'Hazard', revolve([(5.06, 0.34), (5.06, 0.26)], 8))
    # 본체: 두꺼운 8각 블록 + 경사 상단
    m.add('Block', 'MechSteel',
          revolve([(3.10, 3.60), (3.70, 3.20), (4.05, 1.30), (4.20, 0.50), (3.95, 0.44)], 8))
    m.add('Deck', 'MechGun', revolve([(3.20, 3.66), (3.24, 3.52), (2.90, 3.50)], 8))
    # 면 장갑 + 리벳
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = np.array([math.cos(a), math.sin(a), 0.0])
        n = np.array([1.62 * d[0], 1.62 * d[1], 1.0])
        R = frame(n)
        m.add('Plate_%d' % k, 'MechGun',
              extrude_poly([(-1.30, -1.10), (1.30, -1.10), (1.10, 1.10), (-1.10, 1.10)], 0.14,
                           R=R, center=tuple(d * 3.90 + np.array([0, 0, 2.05]))))
        m.add('PlateTrim_%d' % k, 'MechSteel',
              extrude_poly([(-1.10, 1.02), (1.10, 1.02), (1.06, 1.16), (-1.06, 1.16)], 0.20,
                           R=R, center=tuple(d * 3.90 + np.array([0, 0, 2.05]))))
        m.add('Vent_%d' % k, 'DarkMetal',
              extrude_poly([(-0.55, -0.95), (0.55, -0.95), (0.55, -0.72), (-0.55, -0.72)], 0.18,
                           R=R, center=tuple(d * 3.90 + np.array([0, 0, 2.05]))))
        m.add('VentGlow_%d' % k, 'MechAmber',
              extrude_poly([(-0.45, -0.92), (0.45, -0.92), (0.45, -0.76), (-0.45, -0.76)], 0.22,
                           R=R, center=tuple(d * 3.90 + np.array([0, 0, 2.05]))))
    # 코너 버트레스
    for k in range(4):
        a = TAU * k / 8 + TAU / 16
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Buttress_%d' % k, 'MechSteel',
              wedge_geo((d * 4.05 + np.array([0, 0, 1.55])), (0.95, 0.95, 3.10), angle=a, taper=0.45))
    # 굴뚝 2개 + 링
    for i, (cx, cy) in enumerate(((-1.55, 1.30), (1.55, 1.30))):
        c = np.array([cx, cy, 0.0])
        m.add('Stack_%d' % i, 'MechGun',
              revolve([(0.44, 5.70), (0.46, 5.10), (0.40, 4.20), (0.52, 3.60)], 10, center=tuple(c)))
        for j, z in enumerate((3.95, 4.55, 5.15, 5.62)):
            m.add('StackRing_%d_%d' % (i, j), 'MechSteel',
                  torus(major=0.50, minor=0.065, seg=12, tub=5, center=(cx, cy, z)))
        m.add('StackGlow_%d' % i, 'MechAmber',
              ellipsoid((cx, cy, 5.72), (0.34, 0.34, 0.06), 10, 4))
        m.add('StackBase_%d' % i, 'MechSteel', box((cx, cy, 3.58), (1.00, 1.00, 0.30)))
    # 중앙 쌍열 포탑 (6각 포탑 + 맨틀 + 큐폴라)
    m.add('TurretBase', 'MechGun', revolve([(1.48, 3.72), (1.52, 3.46), (1.34, 3.34)], 8))
    m.add('TurretRing', 'MechSteel',
          torus(major=1.44, minor=0.11, seg=16, tub=5, center=(0.0, 0.0, 3.72)))
    m.add('TurretBody', 'MechSteel',
          revolve([(0.72, 5.10), (1.05, 4.92), (1.22, 4.40), (1.24, 3.78), (0.0, 3.70)], 6))
    m.add('TurretBand', 'MechAmber',
          revolve([(1.26, 4.02), (1.26, 3.92)], 6))
    m.add('TurretPlateL', 'MechGun',
          box((-0.92, 0.30, 4.55), (0.16, 0.90, 0.70), R=rot_z(0.30)))
    m.add('TurretPlateR', 'MechGun',
          box((0.92, 0.30, 4.55), (0.16, 0.90, 0.70), R=rot_z(-0.30)))
    m.add('TurretTop', 'MechGun', revolve([(0.70, 5.14), (0.62, 5.00)], 6))
    # 맨틀(포방패)
    m.add('Mantlet', 'MechGun',
          extrude_poly([(-0.95, 0.52), (0.95, 0.52), (1.05, -0.34), (0.30, -0.60), (-0.30, -0.60),
                        (-1.05, -0.34)], 0.26, R=frame((0.0, -1.0, 0.10)),
                       center=(0.0, -1.12, 4.42)))
    m.add('MantletTrim', 'MechSteel',
          extrude_poly([(-0.72, 0.30), (0.72, 0.30), (0.72, 0.16), (-0.72, 0.16)], 0.30,
                       R=frame((0.0, -1.0, 0.10)), center=(0.0, -1.12, 4.42)))
    # 큐폴라 + 안테나
    m.add('Cupola', 'MechGun', revolve([(0.34, 5.52), (0.36, 5.36), (0.26, 5.24)], 8))
    m.add('CupolaGlow', 'MechAmber', ellipsoid((0.0, -0.26, 5.40), (0.14, 0.06, 0.07), 7, 4))
    m.add('TurretAntenna', 'Steel', tube([(0.60, 0.35, 5.20), (0.70, 0.45, 6.45)], [0.035, 0.02], 5))
    m.add('TurretAntennaTip', 'MechAmber', ellipsoid((0.70, 0.45, 6.49), (0.055, 0.055, 0.055), 6, 4))
    for sx in (-1, 1):
        m.add('TurretBarrel_%d' % sx, 'MechGun',
              tube([(sx * 0.36, -1.10, 4.32), (sx * 0.36, -3.95, 4.30)], [0.20, 0.155], 8))
        m.add('TurretMuzzle_%d' % sx, 'DarkMetal',
              tube([(sx * 0.36, -3.85, 4.30), (sx * 0.36, -4.25, 4.30)], [0.24, 0.24], 8))
        m.add('TurretSleeve_%d' % sx, 'MechSteel',
              tube([(sx * 0.36, -1.35, 4.31), (sx * 0.36, -2.20, 4.31)], [0.28, 0.25], 8))
    # 지붕 설비
    m.add('RoofHazard', 'Hazard', box((-2.40, -1.10, 3.55), (1.40, 1.60, 0.06)))
    m.add('RoofBox', 'MechGun', box((2.35, -1.45, 3.76), (1.10, 0.90, 0.52)))
    m.add('RoofBoxGlow', 'MechAmber', box((2.35, -1.92, 3.76), (0.80, 0.06, 0.10)))
    for k in range(6):
        a = TAU * k / 6 + 0.4
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('GantryPost_%d' % k, 'MechSteel',
              box(tuple(d * 2.72 + np.array([0, 0, 3.92])), (0.10, 0.10, 0.62)))
    m.add('Pipe_0', 'MechRust', tube([(-3.10, 0.20, 3.62), (-1.20, 0.20, 3.62)], 0.11, 6))
    m.add('Pipe_1', 'MechRust', tube([(1.20, 0.20, 3.62), (3.10, 0.20, 3.62)], 0.11, 6))
    return m


def wedge_geo(center, size, angle=0.0, taper=0.5):
    """바닥이 넓고 윗면이 좁은 사각대(버트레스)."""
    sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    tx, ty = sx * taper, sy * taper
    V = np.array([[-sx, -sy, -sz], [sx, -sy, -sz], [sx, sy, -sz], [-sx, sy, -sz],
                  [-tx, -ty, sz], [tx, -ty, sz], [tx, ty, sz], [-tx, ty, sz]], float)
    F = np.array([(0, 1, 2), (0, 2, 3), (4, 6, 5), (4, 7, 6), (0, 4, 5), (0, 5, 1),
                  (1, 5, 6), (1, 6, 2), (2, 6, 7), (2, 7, 3), (3, 7, 4), (3, 4, 0)])
    R = np.array([[math.cos(angle), -math.sin(angle), 0], [math.sin(angle), math.cos(angle), 0],
                  [0, 0, 1]])
    return V @ R.T + np.asarray(center, float), F


def build_nexus_arcane():
    m = Model('NexusArcane')
    # 부유 섬 (아래로 뾰족한 바위)
    m.add('Island', 'ArcStone',
          revolve([(5.00, 0.90), (5.10, 0.62), (4.60, 0.20), (3.60, -0.90), (2.20, -2.10),
                   (0.90, -3.10), (0.10, -3.60)], 12,
                  mod=lambda a, r, z: (r * (1.0 + 0.06 * math.sin(3 * a) + 0.04 * math.cos(5 * a)), z)))
    m.add('IslandTop', 'ArcStoneLt', revolve([(4.50, 1.02), (4.70, 0.88), (4.50, 0.82)], 12))
    # 룬 바닥 링
    m.add('RuneFloor', 'ArcStoneLt', revolve([(3.30, 1.10), (3.30, 1.02)], 12))
    for k in range(12):
        a = TAU * k / 12
        d = np.array([math.cos(a), math.sin(a), 0.0])
        R = frame((d[0], d[1], 0.0))
        m.add('RuneMark_%d' % k, 'ArcRune',
              extrude_poly([(-0.16, 0.07), (0.16, 0.07), (0.10, -0.07), (-0.10, -0.07)], 0.04,
                           R=R, center=tuple(d * 3.05 + np.array([0, 0, 1.11]))))
    # 4개 제단 기둥
    for k in range(4):
        a = TAU * k / 4 + TAU / 8
        d = np.array([math.cos(a), math.sin(a), 0.0])
        p = d * 3.10
        m.add('Pillar_%d' % k, 'ArcStoneLt',
              revolve([(0.34, 2.90), (0.30, 2.60), (0.38, 1.60), (0.46, 1.10)], 6,
                      center=tuple(p)))
        m.add('PillarCap_%d' % k, 'ArcStone',
              rotate_box((p[0], p[1], 2.98), (0.80, 0.80, 0.22)))
        m.add('PillarCrystal_%d' % k, 'ArcCrystal',
              crystal((p[0], p[1], 3.06), (p[0], p[1], 3.95), 0.19, 5))
        m.add('PillarGlow_%d' % k, 'ArcRune',
              ellipsoid((p[0], p[1], 3.30), (0.10, 0.10, 0.10), 7, 4))
    # 중앙 크리스탈 첨탑 (3단)
    m.add('SpireBase', 'ArcStoneLt', revolve([(1.55, 1.30), (1.65, 1.05), (1.30, 0.92)], 8))
    m.add('Spire1', 'ArcCrystal', crystal((0.0, 0.0, 1.20), (0.0, 0.0, 4.20), 1.05, 8, 0.30, 0.62))
    m.add('Spire2', 'ArcCrystal', crystal((0.0, 0.0, 4.05), (0.0, 0.0, 6.10), 0.62, 8, 0.32, 0.55))
    m.add('SpireHot', 'ArcRune',
          crystal((0.0, 0.0, 1.60), (0.0, 0.0, 5.60), 0.30, 6, 0.30, 0.60))
    # 룬 링 2개 (기울어서 공중 부양)
    m.add('RuneRingA', 'ArcRune',
          torus(major=3.10, minor=0.075, seg=24, tub=5, center=(0, 0, 3.30),
                R=rot_x(0.26)))
    m.add('RuneRingB', 'ArcCrystal',
          torus(major=2.20, minor=0.060, seg=20, tub=5, center=(0, 0, 4.65),
                R=rot_x(-0.34)))
    # 부유 파편
    for k, (ang, rad, z, sc) in enumerate(((0.4, 3.9, 1.6, 1.0), (2.1, 4.0, 2.6, 0.8),
                                           (3.6, 3.7, 1.2, 0.9), (5.1, 4.1, 2.2, 0.7))):
        p = np.array([math.cos(ang) * rad, math.sin(ang) * rad, z])
        m.add('Shard_%d' % k, 'ArcCrystal',
              crystal(tuple(p - np.array([0, 0, 0.35 * sc])), tuple(p + np.array([0, 0, 0.55 * sc])),
                      0.24 * sc, 5))
    # 입구 아치
    m.add('Portal', 'ArcStoneLt',
          revolve([(1.20, 2.20), (1.30, 1.60), (1.10, 1.10)], 8, center=(0.0, -3.20, 0.0)))
    m.add('PortalGlow', 'ArcRune',
          ellipsoid((0.0, -3.30, 1.55), (0.55, 0.14, 0.75), 9, 6))
    return m


def rot_x(a):
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def rotate_box(center, size, ang=0.0):
    R = np.array([[math.cos(ang), -math.sin(ang), 0], [math.sin(ang), math.cos(ang), 0], [0, 0, 1]])
    return box(center, size, R=R)


def build_nexus_bio():
    m = Model('NexusBio')
    # 바닥 살점 판
    m.add('Ground', 'BioFleshB',
          revolve([(5.05, 0.30), (5.25, 0.14), (5.05, 0.0)], 12,
                  mod=lambda a, r, z: (r * (1 + 0.05 * math.sin(4 * a)), z)))
    # 하이브 둔덕
    m.add('Mound', 'BioFlesh',
          revolve([(1.55, 4.95), (2.60, 4.30), (3.60, 3.10), (4.55, 1.65), (4.90, 0.55),
                   (4.40, 0.28)], 14,
                  mod=lambda a, r, z: (r * (1.0 + 0.07 * math.sin(5 * a) + 0.04 * math.cos(9 * a)), z)))
    m.add('MoundTop', 'BioFleshLt', revolve([(1.50, 5.02), (1.20, 4.90), (1.10, 4.60)], 10))
    # 갈비뼈 아치 6개
    for k in range(6):
        a = TAU * k / 6 + 0.25
        d = np.array([math.cos(a), math.sin(a), 0.0])
        pts = [tuple(d * 4.60 + np.array([0, 0, 0.45])),
               tuple(d * 3.70 + np.array([0, 0, 2.15])),
               tuple(d * 2.45 + np.array([0, 0, 3.65])),
               tuple(d * 1.30 + np.array([0, 0, 4.70]))]
        m.add('Rib_%d' % k, 'BioCarapace', tube(pts, [0.19, 0.17, 0.14, 0.09], 6))
    # 껍질 판 10장
    for k in range(10):
        a = TAU * k / 10 + 0.15
        d = np.array([math.cos(a), math.sin(a), 0.0])
        R = frame((d[0] * 1.2, d[1] * 1.2, 1.0))
        m.add('Shell_%d' % k, 'BioCarapace',
              extrude_poly([(-0.58, 0.48), (0.58, 0.48), (0.44, -0.50), (0.0, -0.70), (-0.44, -0.50)],
                           0.10, R=R, center=tuple(d * 3.30 + np.array([0, 0, 2.35]))))
    # 포자낭 5개 (둔덕 위로 솟은 발광 주머니)
    sacs = [(2.30, -1.75, 4.05, 0.86), (-2.55, -0.95, 3.95, 0.78), (0.60, 2.55, 4.15, 0.92),
            (2.85, 1.55, 3.15, 0.60), (-1.95, 2.25, 3.10, 0.55)]
    for i, (x, y, z, r) in enumerate(sacs):
        m.add('Sac_%d' % i, 'BioFlesh', ellipsoid((x, y, z), (r, r, r * 1.18), 10, 7))
        m.add('SacGlow_%d' % i, 'BioAcid',
              ellipsoid((x, y, z + r * 0.82), (r * 0.52, r * 0.52, r * 0.50), 9, 5))
        m.add('SacStem_%d' % i, 'BioCarapace',
              tube([(x * 0.72, y * 0.72, z - r * 1.25), (x, y, z - r * 1.15)], [0.15, 0.11], 6))
    # 포자 굴뚝 2개
    for k, (x, y, h) in enumerate(((-0.85, 0.55, 5.55), (0.95, -0.35, 5.35))):
        m.add('SporeStack_%d' % k, 'BioFlesh',
              tube([(x, y, 4.55), (x * 1.1, y * 1.1, h)], [0.30, 0.20], 8))
        m.add('SporeMouth_%d' % k, 'BioAcid',
              ellipsoid((x * 1.1, y * 1.1, h + 0.03), (0.19, 0.19, 0.08), 8, 4))
        m.add('SporeRim_%d' % k, 'BioFleshLt',
              revolve([(0.24, 0.10), (0.30, 0.02), (0.24, -0.06)], 8,
                      center=(x * 1.1, y * 1.1, h)))
    # 정면 아가리 (입구) — -Y를 바라보는 고리 + 목구멍
    maw_c = np.array([0.0, -4.35, 1.90])
    m.add('MawRim', 'BioCarapace',
          torus(major=1.16, minor=0.34, seg=14, tub=7, center=tuple(maw_c), R=rot_x(math.pi / 2)))
    m.add('MawLip', 'BioFleshLt',
          torus(major=1.42, minor=0.16, seg=14, tub=5, center=tuple(maw_c + np.array([0, 0.12, 0])),
                R=rot_x(math.pi / 2)))
    m.add('MawThroat', 'DarkMetal',
          tube([tuple(maw_c + np.array([0, 0.16, 0])), tuple(maw_c + np.array([0, 1.05, 0]))],
               [0.94, 0.50], 12))
    m.add('MawGlow', 'BioAcid',
          ellipsoid(tuple(maw_c + np.array([0, 0.20, 0])), (0.60, 0.22, 0.60), 10, 6))
    for k in range(10):
        a = TAU * k / 10
        p0 = maw_c + np.array([math.cos(a) * 1.12, -0.12, math.sin(a) * 1.12])
        p1 = maw_c + np.array([math.cos(a) * 0.76, 0.14, math.sin(a) * 0.76])
        m.add('MawTooth_%d' % k, 'Claw', cone(tuple(p0), tuple(p1), 0.085, 5))
    # 촉수 6개
    for k in range(6):
        a = TAU * k / 6 + 0.5
        d = np.array([math.cos(a), math.sin(a), 0.0])
        p0 = d * 3.95 + np.array([0, 0, 0.85])
        p1 = d * 4.75 + np.array([0, 0, 0.45])
        p2 = d * 5.25 + np.array([0, 0, -0.25])
        p3 = d * 5.05 + np.array([0, 0, -1.05])
        m.add('Tentacle_%d' % k, 'BioFlesh',
              tube([tuple(p0), tuple(p1), tuple(p2), tuple(p3)], [0.36, 0.27, 0.17, 0.04], 6))
        m.add('TentacleTip_%d' % k, 'Claw',
              cone(tuple(p3), tuple(d * 4.95 + np.array([0, 0, -1.35])), 0.07, 5))
    return m


def build_nexus_drone():
    m = Model('NexusDrone')
    # 모함 링
    m.add('CarrierRing', 'DroneHull',
          torus(major=4.30, minor=0.72, seg=28, tub=8, center=(0, 0, 2.60)))
    m.add('RingBand', 'DroneDark',
          torus(major=4.30, minor=0.44, seg=28, tub=6, center=(0, 0, 2.60)))
    # 링 위 장갑 패널
    for k in range(10):
        a = TAU * k / 10
        d = np.array([math.cos(a), math.sin(a), 0.0])
        R = frame((d[0], d[1], 0.30))
        m.add('RingPlate_%d' % k, 'DroneDark',
              extrude_poly([(-0.78, 0.55), (0.78, 0.55), (0.68, -0.50), (-0.68, -0.50)], 0.22,
                           R=R, center=tuple(d * 4.30 + np.array([0, 0, 3.05]))))
        m.add('RingLight_%d' % k, 'DroneCyan',
              extrude_poly([(-0.30, 0.05), (0.30, 0.05), (0.30, -0.10), (-0.30, -0.10)], 0.26,
                           R=R, center=tuple(d * 4.30 + np.array([0, 0, 3.05]))))
    for k in range(8):
        a = TAU * k / 8 + TAU / 16
        d = np.array([math.cos(a), math.sin(a), 0.0])
        R = frame((d[0], d[1], 0.0))
        m.add('RingFin_%d' % k, 'DroneDark',
              extrude_poly([(-0.10, 0.55), (0.10, 0.55), (0.22, 0.18), (0.10, -0.40), (-0.10, -0.40)],
                           0.10, R=R, center=tuple(d * 4.30 + np.array([0, 0, 3.10]))))
    # 스포크 4개
    for k in range(4):
        a = TAU * k / 4 + TAU / 8
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Spoke_%d' % k, 'DroneHull', bar(tuple(d * 1.10 + np.array([0, 0, 2.60])),
                                               tuple(d * 3.80 + np.array([0, 0, 2.60])), 0.34, 0.30))
        m.add('SpokeGlow_%d' % k, 'DroneCyan',
              bar(tuple(d * 1.40 + np.array([0, 0, 2.80])), tuple(d * 3.60 + np.array([0, 0, 2.80])),
                  0.06, 0.04))
    # 중앙 코어
    m.add('CoreHousing', 'DroneDark',
          revolve([(1.25, 4.05), (1.30, 3.55), (1.15, 2.10), (1.25, 1.60), (0.90, 1.30)], 10))
    m.add('CoreSphere', 'DroneHull', ellipsoid((0, 0, 2.60), (1.55, 1.55, 1.55), 12, 8))
    m.add('CoreShoulder', 'DroneDark', revolve([(1.10, 4.05), (1.30, 3.70), (1.55, 3.05)], 10))
    m.add('UpperRing', 'DroneHull',
          torus(major=2.10, minor=0.10, seg=22, tub=5, center=(0, 0, 4.30)))
    m.add('CoreEye', 'DroneCyan', ellipsoid((0.0, -1.44, 2.62), (0.66, 0.26, 0.66), 10, 6))
    m.add('CoreEyeHot', 'GlowWhite', ellipsoid((0.0, -1.62, 2.62), (0.26, 0.10, 0.26), 8, 5))
    m.add('CoreTop', 'DroneHull', revolve([(1.05, 4.10), (0.70, 4.55), (0.28, 4.85), (0.10, 4.95)], 8))
    m.add('CoreTopLight', 'DroneCyan', ellipsoid((0, 0, 4.98), (0.14, 0.14, 0.12), 7, 4))
    m.add('CoreBottom', 'DroneDark', revolve([(0.95, 1.35), (0.55, 0.85), (0.10, 0.62)], 8))
    # 도킹 포트 4개 (링 안쪽)
    for k in range(4):
        a = TAU * k / 4
        d = np.array([math.cos(a), math.sin(a), 0.0])
        p = d * 3.55 + np.array([0, 0, 2.60])
        m.add('Dock_%d' % k, 'DroneDark', box(tuple(p), (0.90, 0.90, 0.60), R=rot_z(a)))
        m.add('DockGlow_%d' % k, 'DroneCyan',
              box(tuple(d * 3.55 + np.array([0, 0, 2.60 - 0.34])), (0.62, 0.62, 0.06), R=rot_z(a)))
    # 추진 포드 6개
    for k in range(6):
        a = TAU * k / 6 + 0.25
        d = np.array([math.cos(a), math.sin(a), 0.0])
        p = d * 4.30 + np.array([0, 0, 1.85])
        m.add('Thruster_%d' % k, 'DroneHull', revolve([(0.36, 2.05), (0.40, 1.70), (0.28, 1.45)], 7,
                                                     center=tuple(p)))
        m.add('ThrusterGlow_%d' % k, 'DroneCyan',
              ellipsoid(tuple(p + np.array([0, 0, 1.40])), (0.26, 0.26, 0.08), 8, 4))
    # 안테나
    m.add('Mast', 'DroneHull', tube([(0, 0, 4.70), (0, 0, 6.10)], [0.07, 0.03], 6))
    m.add('MastLight', 'GlowRed', ellipsoid((0, 0, 6.16), (0.09, 0.09, 0.09), 7, 4))
    for k in range(3):
        a = TAU * k / 3
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Antenna_%d' % k, 'DroneDark',
              bar(tuple(d * 0.10 + np.array([0, 0, 5.20])), tuple(d * 1.15 + np.array([0, 0, 5.55])),
                  0.06, 0.06))
    return m


def rot_z(a):
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


# ================================================================ 유닛 10종
def build_unit_human_soldier():
    m = Model('UnitHumanSoldier')
    biped(m, 'Soldier', (0, 0, 0), 1.95, 'HullNavy', 'HullBlue', 'GlowCyan',
          helmet=True, gun=True, crest=True, bulk=0.86)
    m.add('Soldier_Backpack', 'HullBlue', box((0, 0.19, 1.35), (0.34, 0.20, 0.42)))
    m.add('Soldier_PackLight', 'GlowCyan', box((0, 0.30, 1.42), (0.16, 0.05, 0.06)))
    for sx in (-1, 1):
        m.add('Soldier_Pad_%d' % sx, 'HullLight',
              box((sx * 0.21, 0.0, 1.48), (0.14, 0.22, 0.10), R=rot_z(sx * 0.25)))
    return m


def build_unit_human_bunker():
    m = Model('UnitHumanBunker')
    m.add('Base', 'Concrete', revolve([(1.55, 0.55), (1.70, 0.30), (1.55, 0.0)], 6))
    m.add('Body', 'HullBlue', revolve([(0.95, 1.10), (1.25, 0.95), (1.35, 0.50)], 6))
    m.add('Band', 'HullLight', revolve([(1.30, 0.98), (1.30, 0.86)], 6))
    m.add('SandbagRow', 'Hazard', revolve([(1.62, 0.62), (1.62, 0.44)], 8))
    # 사격 구멍 + 기관총
    m.add('Slit', 'DarkMetal', box((0.0, -1.20, 1.02), (0.92, 0.28, 0.26)))
    m.add('Gun', 'Steel', tube([(0.0, -1.05, 1.05), (0.0, -1.95, 1.08)], [0.085, 0.065], 7))
    m.add('GunMuzzle', 'GlowRed', ellipsoid((0.0, -1.98, 1.08), (0.06, 0.03, 0.06), 6, 4))
    m.add('GunShield', 'HullLight', box((0.0, -1.28, 1.05), (0.52, 0.10, 0.42)))
    m.add('GunMag', 'DarkMetal', box((0.0, -1.40, 0.86), (0.12, 0.22, 0.20)))
    # 모래주머니 3단
    for k in range(3):
        for j in range(3):
            x = (j - 1) * 0.42
            y = -1.55 - 0.10 * (k % 2)
            m.add('Bag_%d_%d' % (k, j), 'BioFleshLt',
                  box((x + 0.06 * (k % 2), y, 0.14 + k * 0.26), (0.40, 0.30, 0.24),
                      R=rot_z(0.1 * (j - 1))))
    m.add('Antenna', 'Steel', tube([(0.85, 0.60, 1.05), (0.95, 0.70, 2.35)], [0.035, 0.02], 5))
    m.add('AntennaLight', 'GlowCyan', ellipsoid((0.95, 0.70, 2.39), (0.06, 0.06, 0.06), 6, 4))
    m.add('RoofHatch', 'HullLight', revolve([(0.34, 1.16), (0.30, 1.10)], 7))
    return m


def build_unit_mecha_walker():
    m = Model('UnitMechaWalker')
    # 몸통
    m.add('Hull', 'MechSteel', revolve([(0.46, 3.05), (0.66, 2.85), (0.72, 2.35), (0.52, 1.95),
                                       (0.60, 1.75)], 6))
    m.add('Cockpit', 'MechGun', box((0.0, -0.42, 2.62), (0.62, 0.34, 0.44)))
    m.add('Canopy', 'MechAmber', box((0.0, -0.60, 2.62), (0.46, 0.06, 0.30)))
    m.add('RoofPlate', 'MechSteel', box((0.0, 0.0, 3.10), (0.86, 0.90, 0.14)))
    m.add('BackPack', 'MechGun', box((0.0, 0.62, 2.50), (0.80, 0.40, 0.72)))
    # 센서 헤드 + 안테나
    m.add('Head', 'MechSteel', box((0.0, -0.30, 3.24), (0.44, 0.40, 0.28)))
    m.add('HeadVisor', 'MechAmber', box((0.0, -0.50, 3.24), (0.34, 0.06, 0.09)))
    m.add('HeadAntenna', 'Steel', tube([(0.20, -0.24, 3.36), (0.28, -0.20, 3.94)], [0.025, 0.012], 5))
    m.add('HeadAntennaTip', 'MechAmber', ellipsoid((0.28, -0.20, 3.97), (0.045, 0.045, 0.045), 6, 4))
    # 어깨 미사일 셀
    for sx in (-1, 1):
        m.add('MissileBox_%d' % sx, 'MechGun', box((sx * 0.86, 0.10, 3.06), (0.36, 0.52, 0.26)))
        for k in range(3):
            m.add('MissileTip_%d_%d' % (sx, k), 'DarkMetal',
                  ellipsoid((sx * 0.86 + (k - 1) * 0.11, -0.18, 3.06), (0.045, 0.03, 0.045), 6, 4))
    m.add('BackVent', 'MechAmber', box((0.0, 0.84, 2.50), (0.56, 0.06, 0.16)))
    # 어깨 포드
    for sx in (-1, 1):
        m.add('ShoulderPod_%d' % sx, 'MechGun',
              box((sx * 0.78, 0.0, 2.86), (0.42, 0.66, 0.52)))
        m.add('ShoulderHatch_%d' % sx, 'MechSteel',
              box((sx * 0.98, 0.0, 2.90), (0.10, 0.48, 0.34)))
        # 팔 + 캐논
        m.add('Arm_%d' % sx, 'MechSteel',
              tube([(sx * 0.70, 0, 2.60), (sx * 0.86, -0.12, 2.10)], [0.14, 0.12], 7))
        m.add('ArmCannon_%d' % sx, 'MechGun',
              tube([(sx * 0.86, -0.18, 2.02), (sx * 0.86, -0.95, 1.94)], [0.15, 0.12], 8))
        m.add('ArmMuzzle_%d' % sx, 'DarkMetal',
              tube([(sx * 0.86, -0.90, 1.94), (sx * 0.86, -1.10, 1.94)], [0.17, 0.17], 8))
        # 역관절 다리
        m.add('Hip_%d' % sx, 'MechGun', ellipsoid((sx * 0.34, 0.0, 1.72), (0.20, 0.20, 0.20), 8, 5))
        m.add('Thigh_%d' % sx, 'MechSteel',
              tube([(sx * 0.34, 0, 1.70), (sx * 0.40, 0.18, 1.20)], [0.17, 0.15], 7))
        m.add('Knee_%d' % sx, 'MechGun', ellipsoid((sx * 0.40, 0.20, 1.14), (0.16, 0.16, 0.16), 8, 5))
        m.add('Shin_%d' % sx, 'MechSteel',
              tube([(sx * 0.40, 0.20, 1.12), (sx * 0.42, -0.10, 0.34)], [0.14, 0.12], 7))
        m.add('KneeGuard_%d' % sx, 'MechSteel',
              box((sx * 0.40, 0.04, 1.16), (0.34, 0.30, 0.30)))
        m.add('Foot_%d' % sx, 'MechGun',
              box((sx * 0.42, -0.16, 0.12), (0.38, 0.72, 0.20)))
        m.add('Toe_%d' % sx, 'MechSteel', box((sx * 0.42, -0.50, 0.10), (0.34, 0.20, 0.14)))
    return m


def build_unit_mecha_siege():
    m = Model('UnitMechaSiege')
    # 차체
    m.add('Hull', 'MechSteel',
          revolve([(0.0, 1.55), (0.95, 1.40), (1.10, 0.95), (1.00, 0.55), (0.0, 0.50)], 6))
    m.add('HullNose', 'MechGun',
          wedge_geo((0.0, -1.35, 0.95), (1.55, 1.30, 0.80), taper=0.55))
    m.add('HullRear', 'MechGun', box((0.0, 1.15, 1.05), (1.70, 0.60, 0.80)))
    # 궤도 2개
    for sx in (-1, 1):
        m.add('Track_%d' % sx, 'MechGun', box((sx * 1.02, 0.0, 0.42), (0.44, 2.60, 0.62)))
        for k in range(4):
            m.add('Wheel_%d_%d' % (sx, k), 'MechSteel',
                  revolve([(0.30, 0.30), (0.30, 0.24)], 8,
                          center=(sx * 1.02, -0.90 + k * 0.60, 0.0),
                          R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]])))
        m.add('TrackTrim_%d' % sx, 'MechRust',
              box((sx * 1.02, 0.0, 0.75), (0.48, 2.64, 0.08)))
    # 포탑 + 주포
    m.add('TurretBase', 'MechGun', revolve([(0.72, 2.05), (0.78, 1.80), (0.55, 1.55)], 8,
                                           center=(0.0, 0.10, 0.0)))
    m.add('TurretBody', 'MechSteel',
          revolve([(0.0, 2.45), (0.40, 2.35), (0.62, 2.05), (0.0, 1.90)], 8, center=(0.0, 0.10, 0.0)))
    m.add('TurretVisor', 'MechAmber', box((0.0, -0.50, 2.18), (0.50, 0.10, 0.10)))
    m.add('MainCannon', 'MechGun', tube([(0.0, -0.30, 2.05), (0.0, -2.55, 2.05)], [0.20, 0.16], 9))
    m.add('CannonSleeve', 'MechSteel', tube([(0.0, -0.45, 2.05), (0.0, -1.35, 2.05)], [0.28, 0.24], 9))
    m.add('MuzzleBrake', 'DarkMetal', tube([(0.0, -2.45, 2.05), (0.0, -2.85, 2.05)], [0.26, 0.26], 9))
    m.add('MuzzleGlow', 'MechAmber', ellipsoid((0.0, -2.86, 2.05), (0.18, 0.04, 0.18), 8, 4))
    # 보조 기관총 + 배기
    m.add('CoaxGun', 'DarkMetal', tube([(0.40, -0.40, 2.18), (0.40, -1.45, 2.18)], [0.07, 0.06], 6))
    for sx in (-1, 1):
        m.add('Exhaust_%d' % sx, 'MechRust',
              tube([(sx * 0.55, 1.35, 1.05), (sx * 0.55, 1.35, 1.92)], [0.14, 0.11], 6))
    m.add('HazardStripe', 'Hazard', box((0.0, -1.75, 1.32), (1.50, 0.10, 0.10)))
    return m


def build_unit_arcane_tower():
    m = Model('UnitArcaneTower')
    m.add('Rock', 'ArcStone',
          revolve([(1.30, 0.62), (1.38, 0.40), (1.05, -0.10), (0.45, -0.70), (0.08, -1.00)], 9,
                  mod=lambda a, r, z: (r * (1 + 0.10 * math.sin(3 * a)), z)))
    m.add('RockTop', 'ArcStoneLt', revolve([(1.22, 0.72), (1.30, 0.60), (1.10, 0.56)], 9))
    m.add('TowerBase', 'ArcStoneLt', revolve([(0.72, 1.05), (0.80, 0.82), (0.58, 0.66)], 6))
    m.add('TowerBody', 'ArcStone', revolve([(0.34, 3.10), (0.52, 2.60), (0.56, 1.40), (0.46, 0.90)], 6))
    m.add('TowerCrystal', 'ArcCrystal',
          crystal((0.0, 0.0, 3.00), (0.0, 0.0, 4.55), 0.36, 6, 0.30, 0.55))
    m.add('TowerHot', 'ArcRune', ellipsoid((0.0, 0.0, 2.35), (0.22, 0.22, 0.30), 8, 5))
    m.add('TowerRing', 'ArcRune',
          torus(major=0.95, minor=0.045, seg=18, tub=4, center=(0, 0, 2.95), R=rot_x(0.20)))
    for k in range(3):
        a = TAU * k / 3 + 0.4
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Shard_%d' % k, 'ArcCrystal',
              crystal(tuple(d * 1.15 + np.array([0, 0, 1.55])),
                      tuple(d * 1.15 + np.array([0, 0, 2.15])), 0.16, 5))
    return m


def build_unit_arcane_guardian():
    m = Model('UnitArcaneGuardian')
    # 로브
    m.add('Robe', 'ArcStone', revolve([(0.30, 2.10), (0.42, 1.60), (0.62, 0.70), (0.72, 0.05)], 8))
    m.add('RobeTrim', 'ArcRune', revolve([(0.73, 0.10), (0.73, 0.02)], 8))
    m.add('Chest', 'ArcStoneLt', revolve([(0.34, 2.55), (0.40, 2.30), (0.32, 2.05)], 6))
    m.add('ChestCore', 'ArcRune', ellipsoid((0, -0.30, 2.28), (0.13, 0.08, 0.16), 8, 5))
    head = np.array([0.0, -0.02, 2.78])
    m.add('Head', 'ArcStoneLt', ellipsoid(tuple(head), (0.22, 0.24, 0.24), 9, 6))
    m.add('Hood', 'ArcStone', ellipsoid(tuple(head + np.array([0, 0.05, 0.06])), (0.27, 0.27, 0.26), 9, 6))
    m.add('FaceGlow', 'ArcRune', box((0.0, -0.22, 2.78), (0.20, 0.05, 0.05)))
    # 어깨 크리스탈
    for sx in (-1, 1):
        m.add('Shoulder_%d' % sx, 'ArcStoneLt',
              ellipsoid((sx * 0.38, 0, 2.45), (0.20, 0.22, 0.18), 8, 5))
        m.add('ShoulderCrystal_%d' % sx, 'ArcCrystal',
              crystal((sx * 0.42, 0.02, 2.60), (sx * 0.55, 0.05, 3.20), 0.14, 5))
        m.add('Arm_%d' % sx, 'ArcStone',
              tube([(sx * 0.40, 0, 2.38), (sx * 0.52, -0.10, 1.85), (sx * 0.46, -0.24, 1.45)],
                   [0.11, 0.09, 0.08], 6))
        m.add('Hand_%d' % sx, 'ArcStoneLt', ellipsoid((sx * 0.46, -0.26, 1.40), (0.10, 0.10, 0.10), 7, 4))
    # 지팡이
    m.add('Staff', 'ArcStoneLt', tube([(0.62, -0.28, 0.10), (0.60, -0.30, 2.10), (0.58, -0.32, 3.05)],
                                      [0.05, 0.05, 0.045], 6))
    m.add('StaffCrystal', 'ArcCrystal',
          crystal((0.58, -0.32, 2.98), (0.58, -0.32, 3.55), 0.16, 6))
    m.add('StaffRing', 'ArcRune', torus(major=0.24, minor=0.03, seg=14, tub=4,
                                        center=(0.58, -0.32, 3.30), R=rot_x(0.5)))
    m.add('Aura', 'ArcRune', torus(major=0.85, minor=0.035, seg=20, tub=4,
                                   center=(0.0, 0.0, 0.10)))
    return m


def build_unit_bio_spire():
    m = Model('UnitBioSpire')
    m.add('Root', 'BioCarapace', revolve([(1.30, 0.28), (1.45, 0.10), (1.15, 0.02)], 9))
    m.add('Stem', 'BioFlesh',
          revolve([(0.30, 3.60), (0.44, 3.10), (0.52, 1.80), (0.66, 0.60), (0.90, 0.20)], 9,
                  mod=lambda a, r, z: (r * (1 + 0.08 * math.sin(5 * a)), z)))
    m.add('StemCore', 'BioAcid', ellipsoid((0, 0, 1.70), (0.20, 0.20, 0.75), 8, 6))
    # 포자낭 3개
    for k, (x, y, z, r) in enumerate(((0.70, -0.34, 2.62, 0.52), (-0.58, 0.46, 3.05, 0.44),
                                      (0.26, -0.66, 3.38, 0.36), (-0.30, -0.62, 2.05, 0.30))):
        m.add('Sac_%d' % k, 'BioFlesh', ellipsoid((x, y, z), (r, r, r * 1.12), 9, 6))
        m.add('SacGlow_%d' % k, 'BioAcid',
              ellipsoid((x, y, z + r * 0.78), (r * 0.50, r * 0.50, r * 0.50), 8, 5))
        m.add('SacStalk_%d' % k, 'BioCarapace',
              tube([(x * 0.4, y * 0.4, z - r), (x, y, z - r * 0.9)], [0.09, 0.07], 5))
    # 입 아가리
    m.add('Mouth', 'BioCarapace', revolve([(0.66, 3.66), (0.74, 3.34), (0.34, 3.02)], 9))
    m.add('MouthGlow', 'BioAcid', ellipsoid((0, 0, 3.50), (0.38, 0.38, 0.16), 9, 5))
    m.add('MouthRim', 'BioFleshLt', revolve([(0.72, 3.62), (0.80, 3.50), (0.72, 3.42)], 9))
    for k in range(6):
        a = TAU * k / 6
        p0 = np.array([math.cos(a) * 0.42, math.sin(a) * 0.42, 3.55])
        m.add('Tooth_%d' % k, 'Claw',
              cone(tuple(p0), tuple(p0 + np.array([math.cos(a) * -0.06, math.sin(a) * -0.06, 0.24])), 0.06, 5))
    # 촉수 5개
    for k in range(5):
        a = TAU * k / 5 + 0.2
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Tentacle_%d' % k, 'BioFlesh',
              tube([tuple(d * 0.85 + np.array([0, 0, 0.60])), tuple(d * 1.30 + np.array([0, 0, 0.30])),
                    tuple(d * 1.55 + np.array([0, 0, -0.10]))], [0.16, 0.11, 0.03], 6))
    return m


def build_unit_bio_beast():
    m = Model('UnitBioBeast')
    quadruped(m, 'Beast', (0, 0, 0), 1.35, 'BioFlesh', 'BioCarapace', 'BioAcid')
    m.add('Beast_SacSkin', 'BioFlesh', ellipsoid((0, -0.58, 1.00), (0.22, 0.26, 0.24), 8, 5))
    m.add('Beast_Sac', 'BioAcid', ellipsoid((0, -0.58, 1.14), (0.14, 0.16, 0.13), 8, 5))
    return m


def build_unit_drone_robot():
    m = Model('UnitDroneRobot')
    m.add('Core', 'DroneHull', ellipsoid((0, 0, 1.20), (0.52, 0.52, 0.46), 10, 7))
    m.add('Shell', 'DroneDark', ellipsoid((0, 0.02, 1.24), (0.56, 0.54, 0.30), 10, 6))
    m.add('Eye', 'DroneCyan', ellipsoid((0.0, -0.48, 1.22), (0.22, 0.12, 0.16), 9, 5))
    m.add('EyeHot', 'GlowWhite', ellipsoid((0.0, -0.55, 1.22), (0.09, 0.05, 0.07), 7, 4))
    m.add('EquatorRing', 'DroneDark',
          torus(major=0.62, minor=0.075, seg=18, tub=5, center=(0, 0, 1.20)))
    for k in range(3):
        a = TAU * k / 3 + 0.5
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Fin_%d' % k, 'DroneHull',
              extrude_poly([(0.0, 0.16), (0.62, 0.04), (0.62, -0.06), (0.0, -0.16)], 0.08,
                           R=frame((0.0, 0.0, 1.0)), center=tuple(d * 0.5 + np.array([0, 0, 1.20]))))
        m.add('FinLight_%d' % k, 'DroneCyan',
              ellipsoid(tuple(d * 1.06 + np.array([0, 0, 1.20])), (0.055, 0.055, 0.045), 6, 4))
    m.add('Top', 'DroneDark', revolve([(0.30, 1.66), (0.16, 1.78), (0.04, 1.84)], 8))
    m.add('TopLight', 'DroneCyan', ellipsoid((0, 0, 1.86), (0.07, 0.07, 0.05), 6, 4))
    for k in range(3):
        a = TAU * k / 3
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('Thruster_%d' % k, 'DroneDark',
              tube([tuple(d * 0.30 + np.array([0, 0, 0.80])), tuple(d * 0.34 + np.array([0, 0, 0.68]))],
                   [0.12, 0.10], 7))
        m.add('Thrust_%d' % k, 'DroneCyan',
              ellipsoid(tuple(d * 0.34 + np.array([0, 0, 0.64])), (0.10, 0.10, 0.04), 7, 4))
    return m


def build_unit_drone_swarm():
    m = Model('UnitDroneSwarm')
    # 중앙 캐리어 포드
    m.add('Pod', 'DroneHull', revolve([(0.55, 2.35), (0.66, 1.90), (0.52, 0.85), (0.30, 0.55)], 9))
    m.add('PodRing', 'DroneDark',
          torus(major=0.72, minor=0.09, seg=18, tub=5, center=(0, 0, 1.60)))
    m.add('PodEye', 'DroneCyan', ellipsoid((0, -0.60, 1.95), (0.20, 0.10, 0.20), 9, 5))
    m.add('PodHatch', 'DroneDark', revolve([(0.44, 0.62), (0.20, 0.42)], 8))
    m.add('PodGlow', 'DroneCyan', ellipsoid((0, 0, 0.46), (0.20, 0.20, 0.06), 8, 4))
    for k in range(4):
        a = TAU * k / 4 + 0.3
        d = np.array([math.cos(a), math.sin(a), 0.0])
        m.add('PodStrut_%d' % k, 'DroneDark',
              bar(tuple(d * 0.30 + np.array([0, 0, 1.30])), tuple(d * 0.95 + np.array([0, 0, 0.95])),
                  0.08, 0.08))
    # 소형 드론 6기
    pts = [(1.55, 0.0, 2.35), (-1.45, 0.35, 2.05), (0.45, 1.50, 2.45),
           (-0.55, -1.45, 2.20), (1.25, -1.15, 1.75), (-1.30, -0.95, 2.55)]
    for i, (x, y, z) in enumerate(pts):
        c = np.array([x, y, z])
        m.add('MiniBody_%d' % i, 'DroneHull', ellipsoid(tuple(c), (0.33, 0.33, 0.20), 9, 5))
        m.add('MiniRing_%d' % i, 'DroneDark',
              torus(major=0.40, minor=0.05, seg=14, tub=4, center=tuple(c)))
        m.add('MiniEye_%d' % i, 'DroneCyan', ellipsoid(tuple(c + np.array([0, -0.30, 0.03])),
                                                      (0.09, 0.06, 0.07), 7, 4))
    return m


# ================================================================ 몬스터
def build_monster_regular():
    m = Model('MonsterRegular')
    o = np.array([0.0, 0.0, 0.0])
    # 다리 (역관절)
    for sx in (-1, 1):
        hip = np.array([sx * 0.26, 0.0, 1.05])
        knee = np.array([sx * 0.34, 0.22, 0.62])
        ankle = np.array([sx * 0.30, -0.10, 0.18])
        m.add('Leg_%d' % sx, 'Hide', tube([hip, knee, ankle], [0.20, 0.16, 0.11], 8))
        m.add('Knee_%d' % sx, 'BonePlate', ellipsoid(tuple(knee), (0.15, 0.15, 0.14), 8, 5))
        m.add('Foot_%d' % sx, 'HideLight', box((sx * 0.30, -0.18, 0.09), (0.28, 0.46, 0.18)))
        for k in (-1, 1):
            b0 = np.array([sx * 0.30 + k * 0.08, -0.38, 0.09])
            m.add('Toe_%d_%d' % (sx, k), 'Claw',
                  tube([tuple(b0), tuple(b0 + np.array([0, -0.12, 0.0])), tuple(b0 + np.array([0, -0.18, -0.06]))],
                       [0.05, 0.035, 0.005], 5))
    # 몸통 (앞으로 숙인 자세)
    m.add('Torso', 'Hide', revolve([(0.40, 1.85), (0.52, 1.60), (0.46, 1.25), (0.36, 1.02)], 8,
                                   center=(0.0, 0.10, 0.0)))
    m.add('ChestPlate', 'BonePlate',
          extrude_poly([(-0.30, 0.22), (0.30, 0.22), (0.22, -0.18), (0.0, -0.28), (-0.22, -0.18)], 0.09,
                       R=frame((0.0, -1.0, 0.15)), center=(0.0, -0.42, 1.60)))
    m.add('ChestGlow', 'MonGlow', ellipsoid((0, -0.50, 1.58), (0.13, 0.06, 0.10), 8, 5))
    # 머리 + 턱
    head = np.array([0.0, -0.16, 2.02])
    m.add('Neck', 'Hide', tube([(0, 0.02, 1.80), tuple(head)], [0.18, 0.16], 7))
    m.add('Head', 'HideLight', ellipsoid(tuple(head), (0.26, 0.30, 0.26), 9, 6))
    m.add('Jaw', 'Hide', box((0.0, -0.34, 1.88), (0.34, 0.34, 0.14)))
    m.add('JawGlow', 'MonGlow', box((0.0, -0.42, 1.90), (0.24, 0.06, 0.03)))
    for sx in (-1, 1):
        m.add('Eye_%d' % sx, 'MonGlow', ellipsoid((sx * 0.11, -0.28, 2.08), (0.05, 0.04, 0.04), 7, 4))
        m.add('Horn_%d' % sx, 'BonePlate',
              cone((sx * 0.16, 0.02, 2.14), (sx * 0.34, 0.24, 2.44), 0.075, 5))
        # 팔 + 발톱
        sh = np.array([sx * 0.42, 0.02, 1.72])
        el = np.array([sx * 0.62, -0.18, 1.36])
        wr = np.array([sx * 0.66, -0.46, 1.10])
        m.add('Shoulder_%d' % sx, 'BonePlate', ellipsoid(tuple(sh), (0.15, 0.15, 0.14), 8, 5))
        m.add('Arm_%d' % sx, 'Hide', tube([sh, el, wr], [0.13, 0.10, 0.085], 7))
        m.add('Hand_%d' % sx, 'HideLight', ellipsoid(tuple(wr), (0.10, 0.10, 0.08), 7, 4))
        for k in range(3):
            b0 = wr + np.array([(k - 1) * 0.05, -0.06, -0.02])
            m.add('Claw_%d_%d' % (sx, k), 'Claw',
                  tube([tuple(b0), tuple(b0 + np.array([0, -0.10, -0.10])),
                        tuple(b0 + np.array([0, -0.14, -0.24]))], [0.032, 0.022, 0.004], 5))
    # 등 가시
    for k in range(4):
        t = k / 3.0
        b0 = np.array([0.0, 0.42 - 0.08 * k, 1.72 - 0.30 * k])
        m.add('BackSpike_%d' % k, 'BonePlate',
              cone(tuple(b0), tuple(b0 + np.array([0, 0.16, 0.26 - 0.04 * k])), 0.07, 5))
    return m


def build_monster_hero_boss():
    m = Model('MonsterHeroBoss')
    s = 2.0
    # 다리
    for sx in (-1, 1):
        hip = np.array([sx * 0.62, 0.0, 2.30])
        knee = np.array([sx * 0.78, -0.30, 1.45])
        ankle = np.array([sx * 0.70, 0.16, 0.50])
        m.add('Leg_%d' % sx, 'Hide', tube([hip, knee, ankle], [0.42, 0.33, 0.22], 9))
        m.add('ThighArmor_%d' % sx, 'BonePlate',
              ellipsoid(tuple(hip + np.array([sx * 0.10, -0.12, -0.10])), (0.34, 0.30, 0.30), 9, 5))
        m.add('Knee_%d' % sx, 'BonePlate', ellipsoid(tuple(knee), (0.30, 0.30, 0.28), 9, 5))
        m.add('ShinArmor_%d' % sx, 'BonePlate',
              box(tuple(knee + np.array([0, -0.14, -0.15])), (0.34, 0.20, 0.52)))
        m.add('Foot_%d' % sx, 'HideLight',
              box((sx * 0.70, -0.20, 0.20), (0.62, 0.98, 0.40)))
        for k in (-1, 0, 1):
            b0 = np.array([sx * 0.70 + k * 0.18, -0.66, 0.18])
            m.add('Toe_%d_%d' % (sx, k), 'Claw',
                  tube([tuple(b0), tuple(b0 + np.array([0, -0.24, -0.02])),
                        tuple(b0 + np.array([0, -0.36, -0.12]))], [0.11, 0.075, 0.01], 6))
    # 몸통
    m.add('Torso', 'Hide', revolve([(0.72, 3.95), (0.95, 3.55), (0.92, 2.90), (0.76, 2.35),
                                    (0.86, 2.10), (0.60, 1.98)], 10))
    m.add('ChestCore', 'MonGlowHero', ellipsoid((0, -0.86, 3.35), (0.40, 0.16, 0.42), 10, 6))
    m.add('ChestHot', 'GlowWhite', ellipsoid((0, -0.94, 3.35), (0.20, 0.08, 0.21), 8, 5))
    # 가슴/복부 갑주
    for sx in (-1, 1):
        m.add('ChestPlate_%d' % sx, 'BonePlate',
              extrude_poly([(-0.52, 0.36), (-0.04, 0.52), (0.10, 0.10), (0.02, -0.40),
                            (-0.46, -0.44), (-0.58, 0.0)], 0.16,
                           R=frame((0.34 * sx, -0.92, 0.20)),
                           center=(sx * 0.52, -0.76, 3.45)))
        m.add('RibPlate_%d' % sx, 'HideLight',
              extrude_poly([(-0.36, 0.08), (0.36, 0.08), (0.30, -0.10), (-0.30, -0.10)], 0.10,
                           R=frame((0.85 * sx, -0.5, 0.10)), center=(sx * 0.84, -0.36, 2.86)))
    for k in range(3):
        m.add('AbPlate_%d' % k, 'BonePlate',
              extrude_poly([(-0.38, 0.10), (0.38, 0.10), (0.28, -0.10), (-0.28, -0.10)], 0.12,
                           R=frame((0.0, -1.0, 0.22)), center=(0.0, -0.80, 2.86 - k * 0.30)))
    # 어깨 견갑 + 스파이크
    for sx in (-1, 1):
        c = np.array([sx * 1.05, 0.0, 3.72])
        m.add('Pauldron_%d' % sx, 'BonePlate', ellipsoid(tuple(c), (0.54, 0.50, 0.30), 10, 5))
        R_p = limb_frame((sx * 1.0, 0, 0.35), (0, 0, 1))
        m.add('PauldronPlate_%d' % sx, 'BonePlate',
              extrude_poly([(-0.46, 0.30), (0.46, 0.30), (0.56, 0.0), (0.30, -0.34), (-0.30, -0.34),
                            (-0.56, 0.0)], 0.14, R=R_p, center=tuple(c + np.array([sx * 0.06, 0, 0.26]))))
        m.add('PauldronRim_%d' % sx, 'Hide',
              torus(major=0.46, minor=0.07, seg=12, tub=5, center=tuple(c + np.array([0, 0, -0.22]))))
        for k in range(3):
            b0 = c + np.array([sx * (0.10 + 0.10 * k), 0.10 + 0.16 * k, 0.22])
            m.add('PauldronSpike_%d_%d' % (sx, k), 'BonePlate',
                  cone(tuple(b0), tuple(b0 + np.array([sx * 0.16, 0.12, 0.44 - 0.06 * k])), 0.09, 5))
    # 팔 (큰 클로)
    for sx in (-1, 1):
        sh = np.array([sx * 1.02, -0.10, 3.55])
        el = np.array([sx * 1.42, -0.52, 2.85])
        wr = np.array([sx * 1.48, -0.98, 2.15])
        m.add('UpperArm_%d' % sx, 'Hide', tube([sh, el], [0.30, 0.24], 9))
        m.add('Elbow_%d' % sx, 'BonePlate', ellipsoid(tuple(el), (0.26, 0.26, 0.24), 9, 5))
        m.add('ElbowSpike_%d' % sx, 'BonePlate',
              cone(tuple(el + np.array([sx * 0.12, 0.14, 0.10])),
                   tuple(el + np.array([sx * 0.34, 0.34, 0.34])), 0.10, 5))
        m.add('Forearm_%d' % sx, 'Hide', tube([el, wr], [0.24, 0.19], 9))
        m.add('ForearmArmor_%d' % sx, 'BonePlate',
              box(tuple(el + (wr - el) * 0.45 + np.array([sx * 0.20, -0.08, 0])),
                  (0.18, 0.30, 0.62)))
        m.add('Hand_%d' % sx, 'HideLight', ellipsoid(tuple(wr), (0.22, 0.24, 0.20), 9, 5))
        for k in range(3):
            b0 = wr + np.array([sx * (0.0 + 0.16 * (k - 1)), -0.18, -0.06])
            m.add('Claw_%d_%d' % (sx, k), 'Claw',
                  tube([tuple(b0), tuple(b0 + np.array([0, -0.20, -0.22])),
                        tuple(b0 + np.array([0, -0.30, -0.50]))], [0.075, 0.055, 0.008], 6))
        m.add('Thumb_%d' % sx, 'Claw',
              tube([tuple(wr + np.array([sx * 0.20, 0.0, 0.06])),
                    tuple(wr + np.array([sx * 0.30, -0.18, -0.06])),
                    tuple(wr + np.array([sx * 0.32, -0.26, -0.34]))], [0.07, 0.05, 0.008], 6))
    # 머리 + 왕관
    head = np.array([0.0, -0.28, 4.22])
    m.add('Neck', 'Hide', tube([(0, 0.02, 3.92), tuple(head)], [0.34, 0.30], 8))
    m.add('Head', 'HideLight', ellipsoid(tuple(head), (0.48, 0.52, 0.46), 10, 7))
    m.add('Jaw', 'BonePlate', box((0.0, -0.62, 3.98), (0.60, 0.52, 0.24)))
    for sx in (-1, 1):
        m.add('Eye_%d' % sx, 'MonGlowHero',
              ellipsoid(tuple(head + np.array([sx * 0.20, -0.46, 0.08])), (0.10, 0.06, 0.08), 8, 5))
        m.add('CheekSpike_%d' % sx, 'BonePlate',
              cone(tuple(head + np.array([sx * 0.36, -0.16, -0.02])),
                   tuple(head + np.array([sx * 0.66, -0.30, -0.20])), 0.09, 5))
    m.add('CrownBand', 'BonePlate',
          torus(major=0.46, minor=0.085, seg=14, tub=5, center=tuple(head + np.array([0, 0.02, 0.36]))))
    for k in range(5):
        a = -0.9 + k * 0.45
        b0 = head + np.array([math.sin(a) * 0.40, 0.02 + math.cos(a) * 0.12, 0.46])
        m.add('CrownSpike_%d' % k, 'BonePlate',
              cone(tuple(b0), tuple(b0 + np.array([math.sin(a) * 0.16, 0.06, 0.82 - 0.16 * abs(k - 2)])),
                   0.085, 5))
    # 등 스파이크 + 오라 링
    for k in range(5):
        b0 = np.array([0.0, 0.72 - 0.06 * k, 3.62 - 0.36 * k])
        m.add('BackSpike_%d' % k, 'BonePlate',
              cone(tuple(b0), tuple(b0 + np.array([0, 0.38, 0.44 - 0.06 * k])), 0.13, 5))
    m.add('AuraRing', 'MonGlowHero',
          torus(major=1.05, minor=0.032, seg=22, tub=4, center=(0, 0, 0.06)))
    return m


# ---------------------------------------------------------------- 출력
MODELS = [
    ('nexus_mecha', build_nexus_mecha, 'Nexus Mecha - heavy mecha fortress'),
    ('nexus_arcane', build_nexus_arcane, 'Nexus Arcane - floating crystal spire'),
    ('nexus_bio', build_nexus_bio, 'Nexus Bio - organic hive nest'),
    ('nexus_drone', build_nexus_drone, 'Nexus Drone - carrier mothership ring'),
    ('unit_human_soldier', build_unit_human_soldier, 'Human trooper'),
    ('unit_human_bunker', build_unit_human_bunker, 'Human bunker emplacement'),
    ('unit_mecha_walker', build_unit_mecha_walker, 'Mecha bipedal walker'),
    ('unit_mecha_siege', build_unit_mecha_siege, 'Mecha siege tank'),
    ('unit_arcane_tower', build_unit_arcane_tower, 'Arcane crystal tower'),
    ('unit_arcane_guardian', build_unit_arcane_guardian, 'Arcane guardian golem'),
    ('unit_bio_spire', build_unit_bio_spire, 'Bio spore spire'),
    ('unit_bio_beast', build_unit_bio_beast, 'Bio beast'),
    ('unit_drone_robot', build_unit_drone_robot, 'Drone hovering unit'),
    ('unit_drone_swarm', build_unit_drone_swarm, 'Drone swarm pod'),
    ('monster_regular', build_monster_regular, 'Regular monster grunt'),
    ('monster_hero_boss', build_monster_hero_boss, 'Hero boss - crowned armored brute'),
]


def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    total = 0
    for name, fn, title in MODELS:
        model = fn()
        obj = os.path.join(outdir, name + '.obj')
        mtl = os.path.join(outdir, name + '.mtl')
        tris = write_obj(model, obj, mtl, MATS, GLOW, title)
        v, t = model.stats()
        lo, hi = model.bbox()
        total += tris
        print('%-22s parts=%3d verts=%5d tris=%5d  w=%.1f h=%.1f d=%.1f'
              % (name, len(model.parts), v, t, hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]))
        assert tris < 10000, '%s: %d triangles over 10k' % (name, tris)
    print('total triangles:', total)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else
         os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
