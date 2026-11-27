#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""터렛 디펜스 v3 — 블렌더 5.3.0 / Roblox Studio용 3D 모델 2종 생성기 (.obj + .mtl)

1) omega_destroyer_boss.obj   : 최종 보스 「오메가 파괴신」
2) human_command_nexus.obj    : 휴먼 종족 전술 지휘소 본진

- 저작 좌표는 Z축 위, 정면은 -Y (블렌더 정면 뷰 = 숫자패드 1)
- 출력 OBJ는 표준 Y-up, 정면 +Z
- 1 unit = 1 m, 각 모델은 단일 메시(단일 o) + 파츠별 g/usemtl 재질 분리
- 모델당 10,000 트라이앵글 이하 (Roblox MeshPart 한계)
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshlib import TAU, Model, ellipsoid, extrude_poly, revolve, star_pts, torus, tube  # noqa: E402


# ---------------------------------------------------------------- helpers
def frame(normal, hint=(0.0, 0.0, 1.0)):
    """두께축이 normal인 판재용 회전행렬. 열: 로컬 x=면내 가로, y=법선, z=면내 세로."""
    n = np.asarray(normal, float)
    n = n / np.linalg.norm(n)
    h = np.asarray(hint, float)
    if abs(float(np.dot(h, n))) > 0.95:
        h = np.array([0.0, 1.0, 0.0])
    u = np.cross(h, n)
    u = u / np.linalg.norm(u)
    v = np.cross(n, u)
    return np.array([u, n, v]).T  # 열: 로컬 x, y(법선), z


def limb_frame(d, n_out):
    """뼈대 방향 d, 바깥쪽 n_out인 판재용 회전행렬 (로컬 x=길이방향)."""
    d = np.asarray(d, float)
    d = d / np.linalg.norm(d)
    n = np.asarray(n_out, float)
    n = n - float(np.dot(n, d)) * d
    n = n / np.linalg.norm(n)
    v = np.cross(n, d)
    return np.array([d, n, v]).T  # 열: 길이방향, 바깥, 둘레


def box(center, size, R=None):
    sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    V = np.array([[x, y, z] for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)], float)
    F = np.array([(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1),
                  (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)])
    if R is not None:
        V = V @ np.asarray(R, float).T
    return V + np.asarray(center, float), F


def bar(p0, p1, w, h):
    """두 점을 잇는 사각 막대"""
    p0 = np.asarray(p0, float)
    p1 = np.asarray(p1, float)
    d = p1 - p0
    L = float(np.linalg.norm(d))
    d = d / L
    up = np.array([0.0, 0.0, 1.0])
    if abs(float(np.dot(d, up))) > 0.95:
        up = np.array([0.0, 1.0, 0.0])
    x = np.cross(up, d)
    x = x / np.linalg.norm(x)
    z = np.cross(d, x)
    R = np.array([x, d, z]).T
    return box((p0 + p1) / 2.0, (w, L, h), R=R)


def cone(base, tip, r, segs=6):
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
    V = [b + r * (math.cos(TAU * i / segs) * x + math.sin(TAU * i / segs) * y)
         for i in range(segs)]
    V.append(t)
    apex = segs
    V.append(b)
    c = segs + 1
    F = [(i, (i + 1) % segs, apex) for i in range(segs)]
    F += [(i, c, (i + 1) % segs) for i in range(segs)]
    return np.array(V), np.array(F)


def blade(base, tip, w0, w1, thick):
    """뾰족한 깃/판재. 로컬 x=길이, y=두께, z=폭."""
    b = np.asarray(base, float)
    t = np.asarray(tip, float)
    d = t - b
    L = float(np.linalg.norm(d))
    u = d / L
    n = np.array([0.0, 1.0, 0.0])
    v = np.cross(u, n)
    if float(np.linalg.norm(v)) < 1e-6:
        n = np.array([1.0, 0.0, 0.0])
        v = np.cross(u, n)
    v = v / np.linalg.norm(v)
    R = np.array([u, n, v]).T
    pts = [(0.0, -w0 * 0.5), (L * 0.42, -w1 * 0.56), (L * 0.78, -w1 * 0.40),
           (L * 0.97, -w1 * 0.10), (L, 0.0), (L * 0.97, w1 * 0.10),
           (L * 0.78, w1 * 0.40), (L * 0.42, w1 * 0.56), (0.0, w0 * 0.5)]
    return extrude_poly(pts, thick, R=R, center=tuple(b))


def spike_row(m, tag, pts, radii, mat, radial=6):
    for i, (p, r) in enumerate(zip(pts, radii)):
        m.add('%s_%d' % (tag, i), mat, cone(p[0], p[1], r, radial))


def write_obj(model, obj_path, mtl_path, materials, glow=(), title=''):
    """단일 오브젝트(o 1개) + 파츠별 g/usemtl. 필요하면 발광 재질에 Ke를 넣는다."""
    R = np.array([[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0]])
    vlines, vnlines, blocks = [], [], []
    voff = 0
    for name, mat, V, F in model.parts:
        V = V @ R.T
        fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
        ln = np.linalg.norm(fn, axis=1, keepdims=True)
        ln[ln == 0] = 1.0
        fn = fn / ln
        vn_acc = np.zeros_like(V)
        for k in range(3):
            np.add.at(vn_acc, F[:, k], fn)
        ln2 = np.linalg.norm(vn_acc, axis=1, keepdims=True)
        ln2[ln2 == 0] = 1.0
        vn_acc = vn_acc / ln2
        for p in V:
            vlines.append('v %.5f %.5f %.5f' % tuple(p))
        for p in vn_acc:
            vnlines.append('vn %.4f %.4f %.4f' % tuple(p))
        fl = ['f ' + ' '.join('%d//%d' % (voff + i + 1, voff + i + 1) for i in tri) for tri in F]
        blocks.append('g %s\nusemtl %s\ns 1\n%s' % (name, mat, '\n'.join(fl)))
        voff += len(V)
    with open(obj_path, 'w', encoding='utf-8') as f:
        f.write('# %s\n' % (title or model.name))
        f.write('# procedural mesh for Blender 5.3.0 / Roblox Studio (MeshPart)\n')
        f.write('# units: 1 unit = 1 m | Y-up (standard OBJ) | front = +Z\n')
        f.write('# one object, parts split by g + usemtl | %d triangles\n'
                % sum(len(F) for _, _, _, F in model.parts))
        f.write('mtllib %s\n' % os.path.basename(mtl_path))
        f.write('\n'.join(vlines) + '\n')
        f.write('\n'.join(vnlines) + '\n')
        f.write('o %s\n' % model.name)
        f.write('\n\n'.join(blocks) + '\n')
    used = []
    for _, mat, _, _ in model.parts:
        if mat not in used:
            used.append(mat)
    with open(mtl_path, 'w', encoding='utf-8') as f:
        f.write('# materials for %s\n' % model.name)
        for mat in used:
            spec = materials[mat]
            kd = spec['kd']
            f.write('\nnewmtl %s\nKa %.4f %.4f %.4f\nKd %.4f %.4f %.4f\n'
                    % (mat, kd[0] * .28, kd[1] * .28, kd[2] * .28, kd[0], kd[1], kd[2]))
            ks = spec.get('ks', 0.15)
            f.write('Ks %.4f %.4f %.4f\nNs %.1f\nd %.4f\nillum 2\n'
                    % (ks, ks, ks, spec.get('ns', 24), spec.get('d', 1.0)))
            if mat in glow:
                f.write('Ke %.4f %.4f %.4f\n' % (kd[0] * spec.get('ke', 0.55),
                                                 kd[1] * spec.get('ke', 0.55),
                                                 kd[2] * spec.get('ke', 0.55)))
    return sum(len(F) for _, _, _, F in model.parts)


# ================================================================ BOSS
BOSS_MATS = {
    'ArmorDark':  {'kd': (0.132, 0.118, 0.168), 'ns': 34, 'ks': 0.30},
    'ArmorPlate': {'kd': (0.290, 0.278, 0.352), 'ns': 62, 'ks': 0.55},
    'ArmorEdge':  {'kd': (0.442, 0.424, 0.500), 'ns': 80, 'ks': 0.65},
    'ArmorTrim':  {'kd': (0.585, 0.075, 0.125), 'ns': 58, 'ks': 0.50},
    'Horn':       {'kd': (0.178, 0.162, 0.208), 'ns': 44, 'ks': 0.40},
    'Claw':       {'kd': (0.930, 0.908, 0.852), 'ns': 58, 'ks': 0.52},
    'WingMembrane': {'kd': (0.395, 0.215, 0.470), 'ns': 40, 'ks': 0.35, 'd': 0.92},
    'CoreGlow':   {'kd': (1.000, 0.290, 0.700), 'ns': 100, 'ks': 0.90, 'ke': 0.75},
    'CoreHot':    {'kd': (1.000, 0.780, 0.900), 'ns': 100, 'ks': 0.95, 'ke': 0.90},
    'Energy':     {'kd': (0.470, 0.900, 1.000), 'ns': 100, 'ks': 0.85, 'ke': 0.65},
}

BOSS_GLOW = ('CoreGlow', 'CoreHot', 'Energy')


def boss_arm(m, tag, sx, sh, el, wr, r0, r1, hsize):
    sh, el, wr = np.array(sh, float), np.array(el, float), np.array(wr, float)
    mid = (sh + el) * 0.5 + np.array([sx * 0.05, 0.03, 0.06])
    m.add(tag + '_ShoulderJoint', 'ArmorDark', ellipsoid(sh, (r0 * 1.12, r0 * 1.06, r0), 10, 5))
    m.add(tag + '_Upper', 'ArmorDark', tube([sh, mid, el], [r0, r0 * 0.80, r1 * 1.25], 10))
    # 상완 장갑판 2장
    d = el - sh
    L = float(np.linalg.norm(d))
    for k, ang in enumerate((0.0, 0.9)):
        n_out = np.array([sx * math.cos(ang) * 0.9, -0.45, math.sin(ang) * 0.6 - 0.1])
        R = limb_frame(d, n_out)
        m.add('%s_UpperArmor_%d' % (tag, k), 'ArmorPlate',
              extrude_poly([(-L * 0.46, -r0 * 0.78), (L * 0.42, -r0 * 0.62),
                            (L * 0.50, 0.0), (L * 0.42, r0 * 0.62),
                            (-L * 0.46, r0 * 0.78)], 0.09, R=R,
                           center=tuple((sh + el) * 0.5 + R[1] * (r0 * 0.92))))
    # 팔꿈치
    m.add(tag + '_Elbow', 'ArmorDark', ellipsoid(el, (r1 * 1.22, r1 * 1.18, r1 * 1.16), 10, 5))
    sp_out = np.array([sx * 0.55, 0.75, 0.35])
    sp_out = sp_out / np.linalg.norm(sp_out)
    m.add(tag + '_ElbowSpike', 'Horn',
          cone(el + sp_out * r1 * 0.9, el + sp_out * (r1 * 0.9 + 0.62), r1 * 0.42, 6))
    # 아래팔
    m.add(tag + '_Forearm', 'ArmorDark', tube([el, (el + wr) * 0.5 + np.array([sx * 0.03, -0.06, 0]), wr],
                                             [r1 * 1.05, r1 * 0.88, r1 * 0.72], 10))
    for k, ang in enumerate((-0.5, 0.6)):
        n_out = np.array([sx * math.cos(ang), -0.75, math.sin(ang)])
        R = limb_frame(wr - el, n_out)
        Lf = float(np.linalg.norm(wr - el))
        m.add('%s_ForearmArmor_%d' % (tag, k), 'ArmorPlate',
              extrude_poly([(-Lf * 0.44, -r1 * 0.85), (Lf * 0.40, -r1 * 0.55),
                            (Lf * 0.48, 0.0), (Lf * 0.40, r1 * 0.55),
                            (-Lf * 0.44, r1 * 0.85)], 0.08, R=R,
                           center=tuple((el + wr) * 0.5 + R[1] * (r1 * 0.80))))
    m.add(tag + '_Wrist', 'ArmorDark', ellipsoid(wr, (r1 * 0.80, r1 * 0.75, r1 * 0.75), 9, 5))

    # ---- 손 + 발톱 ----
    d = wr - el
    d = d / np.linalg.norm(d)
    up = np.array([0.0, 0.0, 1.0])
    side = np.cross(d, up)
    if float(np.linalg.norm(side)) < 1e-6:
        side = np.array([1.0, 0.0, 0.0])
    side = side / np.linalg.norm(side)
    nml = np.cross(d, side)
    R = np.array([d, nml, side]).T
    palm_c = wr + d * (hsize * 0.50)
    m.add(tag + '_Palm', 'ArmorPlate', box(palm_c, (hsize * 1.15, hsize * 0.82, hsize * 1.15), R=R))
    m.add(tag + '_Knuckle', 'ArmorDark',
          box(palm_c + nml * (hsize * 0.42), (hsize * 0.95, hsize * 0.30, hsize * 1.05), R=R))
    for k in range(3):
        off = (k - 1) * hsize * 0.62
        base = palm_c + d * (hsize * 0.55) + side * off + nml * (hsize * 0.12)
        midp = base + d * (hsize * 0.80) + side * (off * 0.18) + np.array([0.0, 0.0, -hsize * 0.34])
        tip = midp + d * (hsize * 0.28) + np.array([0.0, 0.0, -hsize * 0.66])
        m.add('%s_Claw_%d' % (tag, k), 'Claw',
              tube([base, midp, tip], [hsize * 0.30, hsize * 0.19, hsize * 0.02], 6))
    # 엄지
    tb = palm_c + side * (sx * hsize * 0.80) - d * (hsize * 0.05)
    tm = tb + d * (hsize * 0.45) + side * (sx * hsize * 0.30)
    tt = tm + np.array([0.0, -hsize * 0.20, -hsize * 0.58])
    m.add(tag + '_Thumb', 'Claw', tube([tb, tm, tt], [hsize * 0.26, hsize * 0.16, hsize * 0.02], 6))


def boss_leg(m, sx):
    tag = 'Leg_%s' % ('L' if sx < 0 else 'R')
    hip = np.array([sx * 0.68, 0.02, 3.44])
    knee = np.array([sx * 0.92, -0.50, 2.30])
    ankle = np.array([sx * 0.84, 0.24, 0.92])
    m.add(tag + '_Thigh', 'ArmorDark',
          tube([hip, np.array([sx * 0.86, -0.26, 2.92]), knee], [0.52, 0.45, 0.33], 10))
    m.add(tag + '_HipPlate', 'ArmorPlate',
          ellipsoid(hip + np.array([sx * 0.12, -0.10, 0.02]), (0.36, 0.34, 0.30), 9, 5))
    n = np.array([sx * 0.85, -0.45, 0.15])
    R = limb_frame(knee - hip, n)
    L = float(np.linalg.norm(knee - hip))
    m.add(tag + '_ThighArmor', 'ArmorPlate',
          extrude_poly([(-L * 0.46, -0.26), (L * 0.40, -0.20), (L * 0.48, 0.0),
                        (L * 0.40, 0.20), (-L * 0.46, 0.28)], 0.10, R=R,
                       center=tuple((hip + knee) * 0.5 + R[1] * 0.38)))
    m.add(tag + '_Knee', 'ArmorDark', ellipsoid(knee, (0.31, 0.31, 0.29), 10, 5))
    m.add(tag + '_KneeGuard', 'ArmorPlate',
          ellipsoid(knee + np.array([0, -0.16, 0.04]), (0.30, 0.20, 0.26), 8, 5))
    m.add(tag + '_KneeSpike', 'Horn', cone(knee + np.array([0, -0.22, 0.05]),
                                           knee + np.array([0, -0.72, 0.40]), 0.12, 6))
    m.add(tag + '_Shin', 'ArmorDark',
          tube([knee, np.array([sx * 0.90, -0.08, 1.62]), ankle], [0.32, 0.26, 0.19], 10))
    R2 = limb_frame(ankle - knee, np.array([sx * 0.6, -0.85, 0.1]))
    L2 = float(np.linalg.norm(ankle - knee))
    m.add(tag + '_ShinArmor', 'ArmorPlate',
          extrude_poly([(-L2 * 0.46, -0.22), (L2 * 0.38, -0.17), (L2 * 0.46, 0.0),
                        (L2 * 0.38, 0.17), (-L2 * 0.46, 0.23)], 0.09, R=R2,
                       center=tuple((knee + ankle) * 0.5 + R2[1] * 0.26)))
    m.add(tag + '_Ankle', 'ArmorDark', ellipsoid(ankle, (0.21, 0.23, 0.19), 9, 5))
    # 발
    foot_c = np.array([sx * 0.84, -0.06, 0.20])
    m.add(tag + '_Foot', 'ArmorPlate', box(foot_c, (0.50, 0.92, 0.34)))
    m.add(tag + '_Heel', 'Horn', cone(ankle + np.array([0, 0.28, -0.28]),
                                      ankle + np.array([0, 0.62, -0.72]), 0.13, 6))
    for k in (-1, 0, 1):
        base = foot_c + np.array([k * 0.17, -0.40, -0.02])
        midp = base + np.array([k * 0.05, -0.30, -0.10])
        tip = midp + np.array([k * 0.03, -0.22, -0.10])
        m.add('%s_Toe_%d' % (tag, k), 'Claw', tube([base, midp, tip], [0.105, 0.075, 0.012], 6))


def build_boss():
    m = Model('OmegaDestroyerBoss')

    # ---------------- 몸통 ----------------
    torso = [(0.30, 5.80), (0.56, 5.62), (0.86, 5.30), (1.03, 4.96), (0.95, 4.60),
             (0.73, 4.26), (0.62, 4.02), (0.77, 3.84), (0.83, 3.54), (0.66, 3.18),
             (0.28, 3.00)]
    m.add('Torso', 'ArmorDark', revolve(torso, 12))
    m.add('Collar', 'ArmorPlate', revolve([(0.50, 5.74), (0.60, 5.62), (0.50, 5.52)], 12))
    m.add('Belt', 'ArmorTrim', revolve([(0.70, 4.06), (0.76, 3.98), (0.70, 3.90)], 12))

    # 가슴 장갑판 (좌우) — 다각 판재
    for sx in (-1, 1):
        n = np.array([0.34 * sx, -0.90, 0.26])
        R = frame(n)
        pts = [(-0.52, 0.30), (-0.16, 0.48), (0.20, 0.40), (0.46, 0.10),
               (0.34, -0.34), (0.02, -0.50), (-0.40, -0.40), (-0.56, -0.06)]
        m.add('ChestPlate_%s' % ('L' if sx < 0 else 'R'), 'ArmorPlate',
              extrude_poly(pts, 0.14, R=R, center=(sx * 0.46, -0.86, 4.94)))
        # 어깨 위 삼각 장갑
        R2 = frame(np.array([0.55 * sx, -0.55, 0.62]))
        m.add('ChestClav_%s' % ('L' if sx < 0 else 'R'), 'ArmorEdge',
              extrude_poly([(-0.34, 0.20), (0.10, 0.28), (0.34, 0.02),
                            (0.16, -0.22), (-0.30, -0.16)], 0.10, R=R2,
                           center=(sx * 0.62, -0.62, 5.36)))
        # 옆구리 갈비판 3단
        for k in range(3):
            z = 4.62 - k * 0.24
            R3 = frame(np.array([0.90 * sx, -0.40, 0.10]))
            m.add('RibPlate_%s_%d' % ('L' if sx < 0 else 'R', k), 'ArmorTrim',
                  extrude_poly([(-0.30, 0.07), (0.30, 0.07), (0.22, -0.07), (-0.22, -0.07)],
                               0.07, R=R3, center=(sx * 0.80, -0.30, z)))

    # 배 장갑 3단
    for k in range(3):
        z = 4.30 - k * 0.22
        w = 0.40 - k * 0.03
        R = frame(np.array([0.0, -1.0, 0.24]))
        m.add('AbPlate_%d' % k, 'ArmorPlate',
              extrude_poly([(-w, 0.10), (w, 0.10), (w * 0.72, -0.10), (-w * 0.72, -0.10)],
                           0.10, R=R, center=(0.0, -0.68 + k * 0.02, z)))
        m.add('AbVent_%d' % k, 'CoreGlow',
              extrude_poly([(-w * 0.55, 0.022), (w * 0.55, 0.022), (w * 0.55, -0.022),
                            (-w * 0.55, -0.022)], 0.02, R=R,
                           center=(0.0, -0.75 + k * 0.02, z)))

    # 골반 스커트
    for sx in (-1, 1):
        for k in range(2):
            ang = 0.45 + k * 0.55
            R = frame(np.array([sx * math.cos(ang), -math.sin(ang) * 0.9, -0.35]))
            m.add('Skirt_%s_%d' % ('L' if sx < 0 else 'R', k), 'ArmorPlate',
                  extrude_poly([(-0.26, 0.16), (0.26, 0.16), (0.18, -0.20), (-0.18, -0.20)],
                               0.09, R=R, center=(sx * 0.52, -0.42, 3.32)))

    # ---------------- 등 갑각 + 등 스파이크 ----------------
    R = frame(np.array([0.0, 1.0, 0.16]))
    m.add('BackShell', 'ArmorPlate',
          extrude_poly([(-0.62, 0.58), (0.0, 0.72), (0.62, 0.58), (0.72, -0.10),
                        (0.0, -0.42), (-0.72, -0.10)], 0.16, R=R, center=(0.0, 0.62, 4.80)))
    for k in range(5):
        t = k / 4.0
        z = 5.42 - t * 1.70
        y = 0.72 + 0.10 * math.sin(t * math.pi)
        base = np.array([0.0, y, z])
        tip = base + np.array([0.0, 0.42 + 0.22 * math.sin(t * math.pi), 0.30 + 0.35 * (1 - t)])
        m.add('BackSpike_%d' % k, 'Horn', cone(base, tip, 0.15 - 0.04 * t, 6))

    # ---------------- 어깨 견갑 ----------------
    for sx in (-1, 1):
        c = np.array([sx * 1.10, 0.02, 5.34])
        m.add('Pauldron_%s' % ('L' if sx < 0 else 'R'), 'ArmorPlate',
              ellipsoid(c, (0.58, 0.52, 0.40), 10, 6))
        m.add('PauldronRim_%s' % ('L' if sx < 0 else 'R'), 'ArmorTrim',
              torus(major=0.50, minor=0.055, seg=12, tub=5, center=c + np.array([0, 0, -0.16])))
    # 어깨 스파이크
    for sx in (-1, 1):
        for k in range(3):
            ang = -0.45 + k * 0.45
            base = np.array([sx * (1.05 + 0.18 * math.cos(ang)), 0.02 + 0.30 * math.sin(ang), 5.52])
            tip = base + np.array([sx * 0.30, 0.16 * math.sin(ang), 0.62 + 0.12 * k])
            m.add('PauldronSpike_%s_%d' % ('L' if sx < 0 else 'R', k), 'Horn',
                  cone(base, tip, 0.12, 6))

    # ---------------- 발광 코어 ----------------
    core_c = np.array([0.0, -0.94, 4.98])
    m.add('CoreRing', 'ArmorEdge',
          torus(major=0.53, minor=0.075, seg=16, tub=6, center=core_c, R=np.array(
              [[1, 0, 0], [0, 0, 1], [0, -1, 0]])))
    m.add('CoreSphere', 'CoreGlow', ellipsoid(core_c, (0.38, 0.28, 0.43), 12, 7))
    m.add('CoreHot', 'CoreHot', ellipsoid(core_c + np.array([0, -0.12, 0]), (0.22, 0.16, 0.25), 10, 6))
    for k in range(6):
        a = TAU * k / 6 + 0.25
        R2 = frame(np.array([math.cos(a), -1.0, math.sin(a) * 0.9]))
        m.add('CorePetal_%d' % k, 'ArmorTrim',
              extrude_poly([(-0.09, 0.30), (0.09, 0.30), (0.13, 0.0), (0.06, -0.26), (-0.06, -0.26),
                            (-0.13, 0.0)], 0.07, R=R2,
                           center=tuple(core_c + np.array([math.cos(a) * 0.50, -0.02,
                                                           math.sin(a) * 0.54]))))
    # 코어 → 어깨/목 에너지 혈관
    for sx in (-1, 1):
        p0 = core_c + np.array([sx * 0.18, -0.06, 0.18])
        p1 = np.array([sx * 0.52, -0.72, 5.24])
        p2 = np.array([sx * 0.80, -0.42, 5.42])
        m.add('CoreVein_%s' % ('L' if sx < 0 else 'R'), 'Energy', tube([p0, p1, p2], 0.035, 6))
        p3 = core_c + np.array([sx * 0.16, 0.0, -0.24])
        m.add('CoreVeinLow_%s' % ('L' if sx < 0 else 'R'), 'Energy',
              tube([p3, np.array([sx * 0.42, -0.52, 4.42]), np.array([sx * 0.60, -0.30, 4.14])],
                   [0.028, 0.026, 0.018], 6))

    # ---------------- 머리 ----------------
    head_c = np.array([0.0, -0.06, 6.16])
    m.add('Neck', 'ArmorDark', tube([(0, -0.02, 5.72), (0, -0.04, 5.98)], [0.26, 0.23], 10))
    m.add('Head', 'ArmorDark', ellipsoid(head_c, (0.40, 0.44, 0.37), 10, 6))
    # 이마 ~ 정수리 판
    R = frame(np.array([0.0, -0.42, 0.91]))
    m.add('HeadCrest', 'ArmorPlate',
          extrude_poly([(-0.34, 0.34), (0.0, 0.44), (0.34, 0.34), (0.26, -0.30),
                        (0.0, -0.40), (-0.26, -0.30)], 0.10, R=R,
                       center=(0.0, -0.16, 6.44)))
    # 안면 마스크
    m.add('FaceMask', 'ArmorPlate', box((0.0, -0.40, 6.10), (0.52, 0.22, 0.42)))
    m.add('Visor', 'CoreGlow', box((0.0, -0.53, 6.19), (0.54, 0.07, 0.11)))
    for sx in (-1, 1):
        m.add('EyeGlow_%s' % ('L' if sx < 0 else 'R'), 'CoreHot',
              ellipsoid((sx * 0.15, -0.57, 6.19), (0.075, 0.03, 0.05), 8, 5))
    m.add('Brow', 'ArmorTrim', box((0.0, -0.50, 6.30), (0.60, 0.09, 0.075)))
    for sx in (-1, 1):
        m.add('CheekSpike_%s' % ('L' if sx < 0 else 'R'), 'Claw',
              cone((sx * 0.34, -0.24, 6.06), (sx * 0.52, -0.60, 5.88), 0.075, 6))
        m.add('JawFang_%s' % ('L' if sx < 0 else 'R'), 'Claw',
              cone((sx * 0.16, -0.46, 5.94), (sx * 0.17, -0.50, 5.74), 0.055, 5))
    m.add('Jaw', 'ArmorDark', box((0.0, -0.30, 5.90), (0.36, 0.28, 0.16)))

    # ---------------- 왕관 (거대 뿔) ----------------
    m.add('CrownRing', 'ArmorEdge',
          torus(major=0.40, minor=0.075, seg=14, tub=6, center=(0.0, -0.02, 6.40)))
    horns = [
        ((0.16, 0.04, 6.52), (0.40, 0.02, 7.24), (0.72, 0.24, 8.02), 0.195, 0.02),
        ((0.32, 0.02, 6.34), (0.82, 0.04, 6.92), (1.24, 0.18, 7.52), 0.165, 0.02),
        ((0.18, 0.30, 6.32), (0.38, 0.62, 7.02), (0.48, 0.80, 7.64), 0.150, 0.02),
    ]
    for sx in (-1, 1):
        for k, (p0, p1, p2, r0, r1) in enumerate(horns):
            pts = [(sx * p0[0], p0[1], p0[2]), (sx * p1[0], p1[1], p1[2]),
                   (sx * p2[0], p2[1], p2[2])]
            m.add('Horn_%s_%d' % ('L' if sx < 0 else 'R', k), 'Horn',
                  tube(pts, [r0, r0 * 0.55, r1], 8))
        # 뿔 밑동 장식 링
        m.add('HornBase_%s' % ('L' if sx < 0 else 'R'), 'ArmorTrim',
              torus(major=0.20, minor=0.045, seg=10, tub=5,
                    center=(sx * 0.20, 0.02, 6.52), R=frame((sx * 0.3, 0, 1.0))))
    # 왕관 앞 작은 가시 4개
    for k in range(4):
        a = -0.55 + k * 0.37
        base = np.array([math.sin(a) * 0.34, -0.12 + math.cos(a) * 0.10, 6.42])
        tip = base + np.array([math.sin(a) * 0.16, -0.08, 0.40 - 0.10 * abs(k - 1.5)])
        m.add('CrownSpike_%d' % k, 'Claw', cone(base, tip, 0.055, 5))

    # ---------------- 날개 (3층 × 좌우) ----------------
    bones = [
        [(0.55, 0.44, 5.44), (1.55, 0.72, 6.12), (2.95, 0.92, 6.62), (4.05, 1.00, 6.74)],
        [(0.55, 0.54, 5.16), (1.75, 0.90, 5.50), (3.25, 1.06, 5.58), (4.35, 1.12, 5.40)],
        [(0.52, 0.60, 4.90), (1.55, 0.98, 4.60), (2.70, 1.14, 4.28)],
    ]
    for sx in (-1, 1):
        side = 'L' if sx < 0 else 'R'
        wp = [[np.array([sx * x, y, z]) for (x, y, z) in b] for b in bones]
        for bi, b in enumerate(wp):
            radii = [0.18, 0.135, 0.095, 0.032][:len(b)]
            m.add('WingBone_%s_%d' % (side, bi), 'ArmorPlate', tube(b, radii, 8))
        # 층 사이를 잇는 막 (다층 날개 실루엣)
        m.add('WingMembrane_%s_0' % side, 'WingMembrane',
              blade(wp[0][1] + np.array([0, 0.10, -0.10]),
                    wp[2][-1] + np.array([sx * 0.35, 0.16, -0.55]), 1.30, 0.95, 0.03))
        m.add('WingMembrane_%s_1' % side, 'WingMembrane',
              blade(wp[1][1] + np.array([0, 0.16, 0.05]),
                    wp[1][-1] + np.array([sx * 0.15, 0.16, -0.95]), 1.05, 0.70, 0.03))
        plan = [
            (0, 0.24, 0.50, -1.20), (0, 0.40, 0.75, -1.55), (0, 0.56, 0.95, -1.80),
            (0, 0.72, 1.10, -1.98), (0, 0.88, 1.18, -2.06),
            (1, 0.26, 0.62, -1.05), (1, 0.44, 0.88, -1.30), (1, 0.62, 1.08, -1.46),
            (1, 0.80, 1.24, -1.55), (1, 0.95, 1.34, -1.60),
            (2, 0.28, 0.55, -0.95), (2, 0.48, 0.80, -1.06), (2, 0.68, 1.00, -1.14),
            (2, 0.86, 1.14, -1.18), (2, 0.98, 1.20, -1.20),
        ]
        for fi, (bi, t, dx, dz) in enumerate(plan):
            b = wp[bi]
            n = len(b) - 1
            seg = int(t * n)
            frac = t * n - seg
            base = b[seg] * (1 - frac) + b[min(seg + 1, n)] * frac
            tip = base + np.array([sx * dx, 0.18 + 0.05 * (fi % 3), dz])
            m.add('WingFeather_%s_%d' % (side, fi), 'ArmorDark',
                  blade(base, tip, 0.36, 0.32, 0.05))
            m.add('WingFeatherEdge_%s_%d' % (side, fi), 'ArmorTrim',
                  blade(base + (tip - base) * 0.42, tip, 0.13, 0.11, 0.075))
        # 날개 끝 발톱
        for bi, b in enumerate(wp):
            d = b[-1] - b[-2]
            d = d / np.linalg.norm(d)
            m.add('WingClaw_%s_%d' % (side, bi), 'Claw',
                  cone(b[-1], b[-1] + d * 0.34 + np.array([0, 0, -0.14]), 0.055, 5))

    # ---------------- 팔 4개 ----------------
    boss_arm(m, 'ArmUpper_R', 1, (1.10, 0.02, 5.26), (2.02, -0.36, 4.26), (2.28, -0.96, 3.34),
             0.35, 0.24, 0.46)
    boss_arm(m, 'ArmUpper_L', -1, (-1.10, 0.02, 5.26), (-2.02, -0.36, 4.26), (-2.28, -0.96, 3.34),
             0.35, 0.24, 0.46)
    boss_arm(m, 'ArmLower_R', 1, (0.86, 0.14, 4.44), (1.58, -0.56, 3.66), (1.72, -1.02, 2.96),
             0.24, 0.17, 0.33)
    boss_arm(m, 'ArmLower_L', -1, (-0.86, 0.14, 4.44), (-1.58, -0.56, 3.66), (-1.72, -1.02, 2.96),
             0.24, 0.17, 0.33)

    # ---------------- 다리 ----------------
    boss_leg(m, -1)
    boss_leg(m, 1)

    # ---------------- 깨진 헤일로 링 ----------------
    for k, (a0, a1) in enumerate(((0.55, 2.45), (3.25, 5.60))):
        m.add('Halo_%d' % k, 'Energy',
              torus(major=0.92, minor=0.040, seg=14, tub=5, arc=(a0, a1),
                    center=(0.0, 0.06, 7.02), R=np.array(
                        [[1, 0, 0], [0, math.cos(1.32), -math.sin(1.32)],
                         [0, math.sin(1.32), math.cos(1.32)]])))
    return m


# ================================================================ NEXUS
NEXUS_MATS = {
    'Concrete':   {'kd': (0.520, 0.535, 0.560), 'ns': 10, 'ks': 0.10},
    'ArmorBlue':  {'kd': (0.215, 0.275, 0.390), 'ns': 46, 'ks': 0.35},
    'ArmorLight': {'kd': (0.610, 0.665, 0.740), 'ns': 54, 'ks': 0.40},
    'Steel':      {'kd': (0.420, 0.445, 0.480), 'ns': 70, 'ks': 0.55},
    'DarkMetal':  {'kd': (0.085, 0.095, 0.120), 'ns': 40, 'ks': 0.30},
    'GlowCyan':   {'kd': (0.480, 0.940, 1.000), 'ns': 90, 'ks': 0.80, 'ke': 0.80},
    'GlowWhite':  {'kd': (0.900, 0.985, 1.000), 'ns': 90, 'ks': 0.85, 'ke': 0.85},
    'Hazard':     {'kd': (0.930, 0.720, 0.090), 'ns': 30, 'ks': 0.25},
    'Beacon':     {'kd': (1.000, 0.230, 0.180), 'ns': 80, 'ks': 0.60, 'ke': 0.80},
    'RadarWhite': {'kd': (0.860, 0.880, 0.900), 'ns': 44, 'ks': 0.35},
}

NEXUS_GLOW = ('GlowCyan', 'GlowWhite', 'Beacon')


def nexus_turret(m, tag, cx, cy, ang):
    """4모서리 방어 포좌: 기단 + 유선형 포탑 + 2연장 포신"""
    d = np.array([math.cos(ang), math.sin(ang), 0.0])
    base = np.array([cx, cy, 0.0])
    m.add(tag + '_Base', 'Concrete',
          revolve([(0.86, 1.02), (1.02, 0.86), (1.02, 0.42), (1.14, 0.30), (1.14, 0.16)],
                  10, center=tuple(base)))
    m.add(tag + '_Ring', 'ArmorLight',
          revolve([(0.90, 1.14), (0.90, 1.04), (0.80, 1.04), (0.80, 1.14)], 10,
                  center=tuple(base)))
    m.add(tag + '_Neck', 'Steel', revolve([(0.46, 1.46), (0.42, 1.20), (0.50, 1.10)], 8,
                                          center=tuple(base)))
    m.add(tag + '_Housing', 'ArmorBlue',
          revolve([(0.0, 2.02), (0.44, 1.92), (0.66, 1.62), (0.70, 1.34), (0.0, 1.28)],
                  10, center=tuple(base)))
    m.add(tag + '_Visor', 'GlowCyan',
          box(tuple(base + d * 0.60 + np.array([0, 0, 1.62])), (0.44, 0.10, 0.13),
              R=np.array([[d[1], d[0], 0], [-d[0], d[1], 0], [0, 0, 1]])))
    for k in (-1, 1):
        side = np.array([-d[1], d[0], 0.0]) * (0.22 * k)
        m.add('%s_Barrel_%d' % (tag, k), 'Steel',
              tube([base + d * 0.50 + side + np.array([0, 0, 1.52]),
                    base + d * 1.55 + side + np.array([0, 0, 1.50])],
                   [0.105, 0.085], 8))
        m.add('%s_Muzzle_%d' % (tag, k), 'DarkMetal',
              tube([base + d * 1.52 + side + np.array([0, 0, 1.50]),
                    base + d * 1.76 + side + np.array([0, 0, 1.50])],
                   [0.115, 0.115], 8))
    m.add(tag + '_Ammo', 'ArmorLight',
          box(tuple(base - d * 0.52 + np.array([0, 0, 1.50])), (0.46, 0.44, 0.36),
              R=np.array([[d[1], d[0], 0], [-d[0], d[1], 0], [0, 0, 1]])))
    for k in (-1, 1):
        side = np.array([-d[1], d[0], 0.0]) * (0.66 * k)
        m.add('%s_Shield_%d' % (tag, k), 'ArmorLight',
              box(tuple(base + d * 0.10 + side + np.array([0, 0, 1.55])), (0.62, 0.09, 0.42),
                  R=np.array([[d[1], d[0], 0], [-d[0], d[1], 0], [0, 0, 1]])))


def build_nexus():
    m = Model('HumanCommandNexus')

    # ---------------- 지반 패드 ----------------
    m.add('GroundPad', 'Concrete', revolve([(4.98, 0.38), (5.22, 0.18), (4.98, 0.0)], 8))
    m.add('PadTrim', 'ArmorLight', revolve([(5.24, 0.20), (5.24, 0.10)], 8))
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = np.array([math.cos(a), math.sin(a), 0.0])
        R = frame(np.array([d[0], d[1], 0.30]))
        m.add('PadPlate_%d' % k, 'ArmorBlue',
              extrude_poly([(-1.35, -0.13), (1.35, -0.13), (1.20, 0.13), (-1.20, 0.13)],
                           0.10, R=R, center=tuple(d * 4.95 + np.array([0, 0, 0.30]))))
    # 외곽 볼라드 8개
    for k in range(8):
        a = TAU * k / 8
        p = np.array([math.cos(a), math.sin(a), 0.0]) * 5.42
        m.add('Bollard_%d' % k, 'Steel', box(tuple(p + np.array([0, 0, 0.34])), (0.24, 0.24, 0.68)))
        m.add('BollardCap_%d' % k, 'Hazard',
              box(tuple(p + np.array([0, 0, 0.62])), (0.27, 0.27, 0.14)))

    # ---------------- 벙커 본체 (8각 경사 장갑) ----------------
    bunker = [(2.80, 2.66), (3.06, 2.52), (3.86, 1.62), (4.22, 0.95), (4.32, 0.40),
              (4.06, 0.34)]
    m.add('Bunker', 'Concrete', revolve(bunker, 8))

    n_slope = np.array([1.57, 0.0, 1.20])
    n_slope = n_slope / np.linalg.norm(n_slope)
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = np.array([math.cos(a), math.sin(a), 0.0])
        nrm = np.array([n_slope[0] * d[0], n_slope[0] * d[1], n_slope[2]])
        R = frame(nrm)
        m.add('ArmorFrame_%d' % k, 'ArmorLight',
              extrude_poly([(-1.26, -0.80), (1.26, -0.80), (1.10, 0.80), (-1.10, 0.80)],
                           0.13, R=R, center=tuple(d * 3.60 + np.array([0, 0, 1.52]))))
        m.add('ArmorPanel_%d' % k, 'ArmorBlue',
              extrude_poly([(-1.16, -0.72), (1.16, -0.72), (1.00, 0.72), (-1.00, 0.72)],
                           0.19, R=R, center=tuple(d * 3.60 + np.array([0, 0, 1.52]))))
        for bi, (bx, bz) in enumerate(((-1.02, 0.58), (1.02, 0.58), (-1.02, -0.58), (1.02, -0.58))):
            m.add('PanelBolt_%d_%d' % (k, bi), 'Steel',
                  box(tuple(d * 3.60 + np.array([0, 0, 1.52]) + R @ np.array([bx, -0.12, bz])),
                      (0.09, 0.09, 0.09)))
        m.add('ArmorSeam_%d' % k, 'ArmorLight',
              extrude_poly([(-1.02, 0.62), (1.02, 0.62), (0.98, 0.76), (-0.98, 0.76)],
                           0.22, R=R, center=tuple(d * 3.60 + np.array([0, 0, 1.52]))))
        # 하단 검상 띠
        m.add('SkirtBand_%d' % k, 'Hazard',
              extrude_poly([(-1.16, 0.06), (-0.92, 0.06), (-0.92, -0.10), (-1.16, -0.10)],
                           0.20, R=R, center=tuple(d * 3.60 + np.array([0, 0, 1.52]))))
        # 상부 창 (정면은 게이트가 있으니 제외)
        if k not in (5,):
            m.add('Window_%d' % k, 'DarkMetal',
                  extrude_poly([(-0.46, 0.10), (0.46, 0.10), (0.46, -0.10), (-0.46, -0.10)],
                               0.10, R=R, center=tuple(d * 3.30 + np.array([0, 0, 2.02]))))
            m.add('WindowGlow_%d' % k, 'GlowCyan',
                  extrude_poly([(-0.40, 0.035), (0.40, 0.035), (0.40, -0.035), (-0.40, -0.035)],
                               0.16, R=R, center=tuple(d * 3.30 + np.array([0, 0, 2.02]))))

    # ---------------- 루프 데크 + 난간 ----------------
    m.add('RoofDeck', 'Steel', revolve([(3.02, 2.74), (2.98, 2.62), (2.62, 2.60)], 8))
    m.add('RoofInner', 'Concrete', revolve([(2.60, 2.58), (2.60, 2.50)], 8))
    posts = []
    for k in range(8):
        a = TAU * k / 8 + TAU / 16
        p = np.array([math.cos(a), math.sin(a), 0.0]) * 2.86
        posts.append(p)
        m.add('RailPost_%d' % k, 'Steel', box(tuple(p + np.array([0, 0, 3.02])), (0.10, 0.10, 0.62)))
    for k in range(8):
        p0 = posts[k] + np.array([0, 0, 3.28])
        p1 = posts[(k + 1) % 8] + np.array([0, 0, 3.28])
        m.add('RailTop_%d' % k, 'ArmorLight', bar(p0, p1, 0.08, 0.08))
        m.add('RailMid_%d' % k, 'Steel', bar(p0 - np.array([0, 0, 0.22]), p1 - np.array([0, 0, 0.22]),
                                             0.05, 0.05))

    # ---------------- 중앙 에너지 코어 ----------------
    m.add('CorePlatform', 'ArmorLight',
          revolve([(1.42, 3.04), (1.50, 3.12), (1.50, 2.76), (1.26, 2.70)], 8))
    m.add('CoreBase', 'Steel', revolve([(0.72, 3.22), (0.78, 3.06), (0.60, 2.96)], 10))
    m.add('CoreGlowColumn', 'GlowCyan', revolve([(0.30, 4.30), (0.44, 3.90), (0.46, 3.30), (0.40, 3.06)], 10))
    m.add('CoreHotCore', 'GlowWhite', revolve([(0.20, 4.22), (0.22, 3.10)], 8))
    for k, z in enumerate((3.34, 3.72, 4.06)):
        m.add('CoreRing_%d' % k, 'ArmorLight',
              torus(major=0.54, minor=0.045, seg=16, tub=5, center=(0.0, 0.0, z)))
    for k in range(6):
        a = TAU * k / 6
        d = np.array([math.cos(a), math.sin(a), 0.0])
        R = frame(np.array([d[0], d[1], 0.12]))
        m.add('CoreFin_%d' % k, 'ArmorBlue',
              extrude_poly([(-0.16, 0.52), (0.16, 0.52), (0.22, -0.30), (0.0, -0.46), (-0.22, -0.30)],
                           0.09, R=R, center=tuple(d * 0.92 + np.array([0, 0, 3.46]))))
    for k in range(4):
        a = TAU * k / 4 + 0.4
        p = np.array([math.cos(a), math.sin(a), 0.0]) * 1.30
        m.add('CoreStrut_%d' % k, 'Steel',
              bar(tuple(p + np.array([0, 0, 3.02])), (0.0, 0.0, 3.72), 0.09, 0.09))
    m.add('CoreCap', 'ArmorLight', revolve([(0.34, 4.30), (0.24, 4.40), (0.0, 4.48)], 10))
    m.add('CoreTopLight', 'GlowCyan', ellipsoid((0.0, 0.0, 4.52), (0.13, 0.13, 0.11), 8, 5))

    # ---------------- 회전 레이더 디쉬 ----------------
    rad = np.array([0.95, 0.55, 0.0])
    m.add('RadarPedestal', 'ArmorLight',
          revolve([(0.56, 3.16), (0.60, 3.02), (0.72, 2.80), (0.72, 2.66)], 10,
                  center=tuple(rad)))
    m.add('RadarTurnRing', 'Steel',
          torus(major=0.52, minor=0.055, seg=14, tub=5, center=tuple(rad + np.array([0, 0, 3.18]))))
    for k in (-1, 1):
        m.add('RadarYoke_%d' % k, 'Steel',
              bar(tuple(rad + np.array([0.42 * k, 0, 3.18])), tuple(rad + np.array([0.42 * k, 0, 3.68])),
                  0.12, 0.12))
    tilt = 0.62
    Rx = np.array([[1, 0, 0], [0, math.cos(tilt), -math.sin(tilt)],
                   [0, math.sin(tilt), math.cos(tilt)]])
    dish_c = rad + np.array([0.0, 0.06, 3.70])
    dish_prof = [(0.02, 0.30), (0.32, 0.28), (0.72, 0.18), (1.06, 0.02), (1.22, -0.10),
                 (1.14, -0.18), (0.86, -0.05), (0.50, 0.08), (0.02, 0.16)]
    m.add('RadarDish', 'RadarWhite',
          revolve(dish_prof, 20, R=Rx, center=tuple(dish_c)))
    m.add('RadarBack', 'ArmorLight',
          revolve([(0.34, -0.14), (0.30, -0.26), (0.10, -0.30)], 10, R=Rx, center=tuple(dish_c)))
    axis = np.array([0.0, -math.sin(tilt), math.cos(tilt)])
    m.add('RadarFeed', 'Steel',
          tube([tuple(dish_c + axis * 0.10), tuple(dish_c + axis * 0.62)], [0.05, 0.035], 6))
    m.add('RadarFeedHorn', 'ArmorLight',
          cone(tuple(dish_c + axis * 0.58), tuple(dish_c + axis * 0.80), 0.09, 8))
    for k in range(3):
        a = TAU * k / 3 + 0.3
        rim = dish_c + Rx @ np.array([math.cos(a) * 1.02, math.sin(a) * 1.02, 0.02])
        m.add('RadarStrut_%d' % k, 'Steel',
              bar(tuple(rim), tuple(dish_c + axis * 0.55), 0.045, 0.045))
    m.add('RadarCounter', 'DarkMetal',
          box(tuple(dish_c - axis * 0.24), (0.34, 0.34, 0.26), R=Rx))

    # ---------------- 통신 안테나 마스트 ----------------
    mast = np.array([-1.62, -1.10, 0.0])
    m.add('MastBase', 'ArmorLight',
          revolve([(0.40, 2.98), (0.44, 2.80), (0.34, 2.66)], 8, center=tuple(mast)))
    m.add('Mast', 'Steel',
          tube([tuple(mast + np.array([0, 0, 2.86])), tuple(mast + np.array([0, 0, 4.40])),
                tuple(mast + np.array([0, 0, 5.36]))], [0.13, 0.085, 0.055], 6))
    for k, (z, ang, w) in enumerate(((3.50, 0.4, 1.5), (4.16, 1.15, 1.2), (4.78, 0.2, 0.9))):
        d = np.array([math.cos(ang), math.sin(ang), 0.0]) * (w / 2.0)
        p = mast + np.array([0, 0, z])
        m.add('MastArm_%d' % k, 'Steel', bar(tuple(p - d), tuple(p + d), 0.055, 0.055))
        for kk in (-1, 1):
            m.add('MastTip_%d_%d' % (k, kk), 'GlowCyan',
                  ellipsoid(tuple(p + d * kk * 1.02), (0.055, 0.055, 0.07), 6, 4))
    for k, (z, s) in enumerate(((3.86, 0.30), (4.52, 0.24))):
        d = np.array([math.cos(1.9 + 0.5 * k), math.sin(1.9 + 0.5 * k), 0.0])
        m.add('MastDish_%d' % k, 'RadarWhite',
              revolve([(0.02, z + s * 0.5), (s * 0.6, z + s * 0.2), (s, z - s * 0.3),
                       (s * 0.9, z - s * 0.42), (0.02, z - s * 0.30)], 10,
                      R=frame((d[0], d[1], 0.35)), center=tuple(mast)))
    m.add('MastBeacon', 'Beacon', ellipsoid(tuple(mast + np.array([0, 0, 5.44])), (0.11, 0.11, 0.14), 8, 5))
    m.add('MastRod', 'Steel', tube([tuple(mast + np.array([0, 0, 5.40])),
                                   tuple(mast + np.array([0, 0, 5.92]))], [0.03, 0.012], 5))

    # ---------------- 정면 게이트 ----------------
    fy = -3.98
    m.add('GateRecess', 'DarkMetal', box((0.0, fy + 0.60, 1.26), (2.62, 1.20, 2.24)))
    m.add('GateBackWall', 'ArmorBlue', box((0.0, fy + 1.15, 1.26), (2.50, 0.26, 2.18)))
    for sx in (-1, 1):
        m.add('GateFrame_%s' % ('L' if sx < 0 else 'R'), 'ArmorBlue',
              box((sx * 1.58, fy, 1.34), (0.66, 0.98, 2.90)))
        R = frame(np.array([0.0, -1.0, 0.10]))
        m.add('GateFrameCap_%s' % ('L' if sx < 0 else 'R'), 'ArmorLight',
              extrude_poly([(-0.40, 0.30), (0.40, 0.30), (0.30, -0.26), (-0.30, -0.26)],
                           0.18, R=R, center=(sx * 1.58, fy - 0.50, 2.86)))
    m.add('GateLintel', 'ArmorBlue', box((0.0, fy - 0.02, 2.96), (4.10, 0.98, 0.66)))
    m.add('GateLintelLight', 'ArmorLight', box((0.0, fy - 0.52, 2.96), (3.00, 0.08, 0.40)))
    m.add('GateHazard', 'Hazard', box((0.0, fy - 0.58, 2.62), (3.30, 0.06, 0.09)))
    # 휴먼 진영 엠블럼 (게이트 상단)
    R_emb = frame(np.array([0.0, -1.0, 0.0]))
    m.add('GateEmblem', 'GlowWhite',
          extrude_poly(star_pts(5, 0.30, 0.13), 0.06, R=R_emb, center=(0.0, fy - 0.56, 2.94)))
    m.add('GateEmblemRing', 'ArmorLight',
          torus(major=0.40, minor=0.035, seg=16, tub=4, center=(0.0, fy - 0.56, 2.94),
                R=np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]])))
    # 문짝 2장 (바깥으로 활짝 열린 상태)
    for sx in (-1, 1):
        a = sx * 0.62
        Ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0],
                       [-math.sin(a), 0, math.cos(a)]])
        dc = np.array([sx * 0.94, fy - 0.52, 1.16])
        m.add('GateDoor_%s' % ('L' if sx < 0 else 'R'), 'ArmorLight',
              box(tuple(dc), (1.06, 0.13, 1.92), R=Ry))
        m.add('GateDoorPanel_%s' % ('L' if sx < 0 else 'R'), 'ArmorBlue',
              box(tuple(dc + Ry @ np.array([0.0, -0.09, 0.10])), (0.82, 0.05, 1.30), R=Ry))
        m.add('GateDoorHandle_%s' % ('L' if sx < 0 else 'R'), 'Steel',
              box(tuple(dc + Ry @ np.array([sx * 0.42, -0.14, -0.10])), (0.06, 0.10, 0.52), R=Ry))
        for k in range(2):
            m.add('GateDoorHazard_%s_%d' % ('L' if sx < 0 else 'R', k), 'Hazard',
                  box(tuple(dc + Ry @ np.array([sx * (0.20 - 0.40 * k), -0.12, -0.78])),
                      (0.16, 0.05, 0.16), R=Ry))
    # 조명
    for sx in (-1, 1):
        m.add('GateLamp_%s' % ('L' if sx < 0 else 'R'), 'GlowCyan',
              ellipsoid((sx * 1.05, fy - 0.66, 2.36), (0.13, 0.09, 0.10), 8, 5))
    # 진입 램프 + 계단 + 난간
    ramp0 = np.array([0.0, fy - 0.50, 0.38])
    ramp1 = np.array([0.0, fy - 2.05, 0.05])
    m.add('Ramp', 'Concrete', bar(tuple(ramp0), tuple(ramp1), 2.90, 0.18))
    for sx in (-1, 1):
        m.add('RampWall_%s' % ('L' if sx < 0 else 'R'), 'ArmorBlue',
              bar(tuple(ramp0 + np.array([sx * 1.52, 0, 0.22])),
                  tuple(ramp1 + np.array([sx * 1.52, 0, 0.16])), 0.20, 0.52))
        m.add('RampWallTop_%s' % ('L' if sx < 0 else 'R'), 'Hazard',
              bar(tuple(ramp0 + np.array([sx * 1.52, 0, 0.50])),
                  tuple(ramp1 + np.array([sx * 1.52, 0, 0.44])), 0.22, 0.06))
    for k in range(3):
        d = 0.35 + k * 0.45
        y = fy - 0.50 - d
        z = 0.38 - d * 0.22 + 0.12
        m.add('RampStripe_%d' % k, 'Hazard', box((0.0, y, z), (2.55, 0.16, 0.03)))
    # 계단 (램프 위 입구)
    for k in range(3):
        m.add('Step_%d' % k, 'Concrete',
              box((0.0, fy - 0.18 + k * 0.20, 0.44 + k * 0.10), (2.30, 0.26, 0.12)))
    # ---------------- 4모서리 방어 포좌 ----------------
    for i, (cx, cy, ang) in enumerate(((3.05, 3.05, math.pi * 0.25),
                                       (-3.05, 3.05, math.pi * 0.75),
                                       (3.05, -3.05, -math.pi * 0.25),
                                       (-3.05, -3.05, -math.pi * 0.75))):
        nexus_turret(m, 'Turret_%d' % i, cx, cy, ang)

    # ---------------- 지붕 설비 ----------------
    m.add('Vent_0', 'Steel', box((1.75, -1.55, 2.86), (0.94, 0.66, 0.42)))
    m.add('VentGrill_0', 'DarkMetal', box((1.75, -1.55, 3.07), (0.76, 0.50, 0.06)))
    for k in range(3):
        m.add('VentSlat_0_%d' % k, 'ArmorLight',
              box((1.75, -1.74 + k * 0.19, 3.11), (0.70, 0.05, 0.05)))
    m.add('Vent_1', 'Steel', box((-1.95, 1.45, 2.86), (0.80, 0.80, 0.40)))
    m.add('VentGrill_1', 'DarkMetal', box((-1.95, 1.45, 3.06), (0.62, 0.62, 0.06)))
    m.add('Hatch', 'ArmorLight', revolve([(0.44, 2.78), (0.40, 2.68)], 10,
                                        center=(1.55, 1.92, 0.0)))
    m.add('HatchRing', 'Hazard', torus(major=0.48, minor=0.035, seg=12, tub=4,
                                       center=(1.55, 1.92, 2.70)))
    # 케이블 덕트 (루프 가장자리)
    for k in range(2):
        a0 = TAU * (k * 0.5 + 0.05)
        pts = []
        for j in range(5):
            a = a0 + 0.55 * j / 4.0
            pts.append((math.cos(a) * 2.72, math.sin(a) * 2.72, 2.62))
        m.add('CableDuct_%d' % k, 'DarkMetal', tube(pts, 0.075, 5))
    # 방어막 발생기 4개
    for i, (cx, cy) in enumerate(((2.25, 1.35), (-1.15, -2.35), (1.15, 2.35), (-2.25, -1.35))):
        m.add('Emitter_%02d' % i, 'ArmorLight', box((cx, cy, 2.94), (0.30, 0.30, 0.56)))
        m.add('EmitterGlow_%02d' % i, 'GlowCyan', ellipsoid((cx, cy, 3.30), (0.17, 0.17, 0.17), 8, 5))
        m.add('EmitterRing_%02d' % i, 'ArmorBlue', box((cx, cy, 3.04), (0.38, 0.38, 0.07)))
    return m


# ---------------------------------------------------------------- main
def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    models = [
        ('omega_destroyer_boss', build_boss(), BOSS_MATS, BOSS_GLOW,
         'Omega Destroyer - final boss of Turret Defense v3'),
        ('human_command_nexus', build_nexus(), NEXUS_MATS, NEXUS_GLOW,
         'Human Command Nexus - tactical HQ of Turret Defense v3'),
    ]
    for name, model, mats, glow, title in models:
        obj = os.path.join(outdir, name + '.obj')
        mtl = os.path.join(outdir, name + '.mtl')
        tris = write_obj(model, obj, mtl, mats, glow, title)
        v, t = model.stats()
        lo, hi = model.bbox()
        print('%-24s parts=%3d verts=%6d tris=%5d  bbox x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f'
              % (name, len(model.parts), v, t, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
        assert tris < 10000, '%s: %d triangles over the 10k MeshPart limit' % (name, tris)
        # 5종족 본진 명명 규칙(nexus_human)으로 같은 건물을 한 벌 더 만든다
        if name == 'human_command_nexus':
            model.name = 'NexusHuman'
            write_obj(model, os.path.join(outdir, 'nexus_human.obj'),
                      os.path.join(outdir, 'nexus_human.mtl'), mats, glow,
                      'Nexus Human - tactical command bunker (same mesh as human_command_nexus)')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
