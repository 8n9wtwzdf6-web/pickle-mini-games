#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「매직 하트핑」 루비하트핑 요정 3D 모델 생성기 (.obj + .mtl)

Blender 5.3.0 / Roblox Studio 에서 바로 열리는 Wavefront OBJ.
- Z축 위, 얼굴은 -Y (블렌더 정면 뷰 = 숫자패드 1)
- 1 unit = 1 m, 발바닥 z=0
- 파츠마다 o/g 이름 + usemtl 재질이 나뉘어 있음
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshlib import (TAU, Model, ellipsoid, extrude_poly, hair_shell, heart_pts,
                     rot, revolve, star_pts, torus, tube, xform)

# ------------------------------------------------------------------ palette
C = {
    'Skin':       (1.000, 0.812, 0.741),
    'Hair':       (1.000, 0.435, 0.569),
    'HairLight':  (1.000, 0.659, 0.741),
    'Dress':      (1.000, 0.757, 0.839),
    'DressTrim':  (1.000, 0.980, 0.992),
    'Ribbon':     (1.000, 0.310, 0.545),
    'Shoes':      (0.878, 0.314, 0.498),
    'Eye':        (0.227, 0.129, 0.251),
    'EyeShine':   (1.000, 1.000, 1.000),
    'EyeShinePink': (1.000, 0.839, 0.925),
    'Blush':      (1.000, 0.694, 0.776),
    'Mouth':      (0.788, 0.290, 0.447),
    'Wing':       (0.815, 0.900, 1.000),
    'Gold':       (1.000, 0.820, 0.400),
    'StarGold':   (1.000, 0.878, 0.400),
    'GemPink':    (1.000, 0.310, 0.545),
    'GemCyan':    (0.498, 0.890, 1.000),
    'Pearl':      (1.000, 0.957, 0.973),
}


def M(kd, **kw):
    spec = {'kd': kd}
    spec.update(kw)
    return spec


MATERIALS = {
    'Skin': M(C['Skin'], ns=18),
    'Hair': M(C['Hair'], ns=36, ks=0.22),
    'HairLight': M(C['HairLight'], ns=36),
    'Dress': M(C['Dress'], ns=30, ks=0.18),
    'DressTrim': M(C['DressTrim'], ns=40, ks=0.25),
    'Ribbon': M(C['Ribbon'], ns=40, ks=0.3),
    'Shoes': M(C['Shoes'], ns=45, ks=0.35),
    'Eye': M(C['Eye'], ns=70, ks=0.55),
    'EyeShine': M(C['EyeShine'], ns=80, ks=0.6),
    'EyeShinePink': M(C['EyeShinePink'], ns=70, ks=0.5),
    'Blush': M(C['Blush'], ns=14),
    'Mouth': M(C['Mouth'], ns=30),
    'Wing': M(C['Wing'], ns=60, ks=0.5, d=0.52),
    'Gold': M(C['Gold'], ns=90, ks=0.85),
    'StarGold': M(C['StarGold'], ns=80, ks=0.7),
    'GemPink': M(C['GemPink'], ns=95, ks=0.9),
    'GemCyan': M(C['GemCyan'], ns=95, ks=0.9),
    'Pearl': M(C['Pearl'], ns=60, ks=0.5),
}


# ------------------------------------------------------------------ fairy
def build_fairy():
    m = Model('Heartping_Fairy')

    head_c = (0.0, 0.0, 1.55)
    # --- 머리 -----------------------------------------------------------
    m.add('Head', 'Skin', ellipsoid(head_c, (0.500, 0.468, 0.490), 26, 14))
    m.add('Neck', 'Skin', tube([(0, 0, 1.02), (0, 0, 1.15)], [0.105, 0.095], 12))

    # --- 뒤머리(헤어 캡) -----------------------------------------------
    m.add('Hair_Back', 'Hair',
          ellipsoid((0.0, 0.108, 1.574), (0.549, 0.470, 0.532), 26, 13))

    # --- 앞머리 (5갈래 + 옆머리 2) --------------------------------------
    def fringe_theta(psi):
        side = 0.14 * (abs(psi) / 2.0) ** 2
        return 1.185 + side + 0.055 * math.sin(2.4 * psi + 0.30)

    m.add('Hair_Bangs', 'Hair',
          hair_shell((0.0, 0.0, 1.550),
                     (0.500 * 1.080, 0.468 * 1.080, 0.490 * 1.080),
                     (0.500 * 1.012, 0.468 * 1.012, 0.490 * 1.012),
                     2.0, fringe_theta, cols=46, rows=6))
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Hair_Side_%s' % side, 'Hair',
              ellipsoid((sx * 0.430, -0.180, 1.700), (0.098, 0.128, 0.200),
                        13, 8, R=rot(x=-0.12, y=sx * 0.55)))

    # --- 양갈래 늘어진 요정 귀(머리 갈래) -------------------------------
    for side, sx in (('L', -1), ('R', 1)):
        path = [(sx * 0.310, 0.090, 1.760),
                (sx * 0.500, 0.060, 1.660),
                (sx * 0.595, 0.000, 1.450),
                (sx * 0.600, -0.055, 1.235),
                (sx * 0.548, -0.100, 1.070)]
        rads = [0.150, 0.152, 0.134, 0.094, 0.034]
        geo = tube(path, rads, 12)
        c = np.array([sx * 0.55, -0.02, 1.45])
        V = (geo[0] - c) * np.array([1.0, 0.80, 1.0]) + c
        m.add('Hair_Ear_%s' % side, 'Hair', (V, geo[1]))
        inner = [(sx * 0.520, -0.062, 1.660),
                 (sx * 0.588, -0.104, 1.470),
                 (sx * 0.585, -0.138, 1.285)]
        geo2 = tube(inner, [0.056, 0.064, 0.024], 9)
        V2 = (geo2[0] - c) * np.array([1.0, 0.80, 1.0]) + c
        m.add('Hair_EarInner_%s' % side, 'HairLight', (V2, geo2[1]))
        m.add('Hair_EarTie_%s' % side, 'Ribbon',
              torus(major=0.140, minor=0.024, seg=16, tub=6,
                    center=(sx * 0.470, 0.062, 1.706),
                    R=rot(x=0.62, y=sx * 0.40)))

    # --- 눈 -------------------------------------------------------------
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Eye_%s' % side, 'Eye',
              ellipsoid((sx * 0.170, -0.428, 1.582), (0.108, 0.058, 0.138),
                        16, 10, R=rot(z=sx * 0.07)))
        m.add('EyeShine_%s' % side, 'EyeShine',
              ellipsoid((sx * 0.205, -0.470, 1.632), (0.034, 0.028, 0.040), 10, 7))
        m.add('EyeShineLow_%s' % side, 'EyeShinePink',
              ellipsoid((sx * 0.140, -0.468, 1.540), (0.026, 0.022, 0.026), 8, 6))

    # --- 볼터치 ---------------------------------------------------------
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Cheek_%s' % side, 'Blush',
              ellipsoid((sx * 0.318, -0.332, 1.442), (0.068, 0.024, 0.038),
                        12, 7, R=rot(y=sx * 0.45)))

    # --- 입 (스마일 호) --------------------------------------------------
    m.add('Mouth', 'Mouth',
          torus(major=0.052, minor=0.0115, seg=18, tub=6,
                arc=(math.radians(203), math.radians(337)),
                R=rot(x=math.pi / 2), center=(0.0, -0.452, 1.398)))

    # --- 몸통 (원피스 상의) ---------------------------------------------
    m.add('Body_Bodice', 'Dress',
          tube([(0, 0, 0.925), (0, 0, 0.995), (0, 0, 1.075), (0, 0, 1.135)],
               [0.195, 0.228, 0.205, 0.150], 20))
    m.add('Collar_Frill', 'DressTrim',
          torus(major=0.166, minor=0.038, seg=22, tub=6,
                center=(0, 0, 1.128)))
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Puff_Sleeve_%s' % side, 'DressTrim',
              ellipsoid((sx * 0.208, 0.0, 1.055), (0.088, 0.088, 0.082), 13, 8))

    # --- 가슴 하트 -------------------------------------------------------
    m.add('Chest_Heart', 'DressTrim',
          extrude_poly(heart_pts(30, 0.135), 0.030, center=(0, -0.235, 1.020)))

    # --- 스커트 (프릴 원피스 치마) --------------------------------------
    def skirt_mod(a, r, z):
        t = max(0.0, min(1.0, (0.935 - z) / 0.40))
        wave = 1.0 + 0.034 * t * math.sin(13 * a)
        return r * wave, z + 0.016 * t * math.sin(13 * a + 0.7)

    skirt_profile = [
        (0.192, 0.935), (0.240, 0.862), (0.320, 0.752), (0.410, 0.632),
        (0.466, 0.556),
        (0.446, 0.546), (0.392, 0.640), (0.300, 0.760), (0.220, 0.862),
        (0.172, 0.935), (0.192, 0.935),
    ]
    m.add('Skirt', 'Dress',
          revolve(skirt_profile, 40, mod=skirt_mod, caps=(False, False)))

    def frill_mod(a, r, z):
        t = max(0.0, min(1.0, (0.915 - z) / 0.39))
        return r * (1.0 + 0.038 * t * math.sin(10 * a + 0.4)), \
            z + 0.012 * t * math.sin(10 * a + 1.1)

    frill_profile = [
        (0.187, 0.915), (0.250, 0.800), (0.345, 0.660), (0.474, 0.500),
        (0.458, 0.488), (0.330, 0.660), (0.236, 0.800), (0.168, 0.915),
        (0.187, 0.915),
    ]
    m.add('Skirt_Frill', 'DressTrim',
          revolve(frill_profile, 40, mod=frill_mod, caps=(False, False)))

    # --- 허리 리본 -------------------------------------------------------
    m.add('Waist_Ribbon', 'Ribbon',
          torus(major=0.213, minor=0.031, seg=26, tub=6, center=(0, 0, 0.948)))
    m.add('Back_Bow_Knot', 'Ribbon',
          ellipsoid((0.0, 0.238, 0.952), (0.045, 0.042, 0.045), 12, 8))
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Back_Bow_%s' % side, 'Ribbon',
              ellipsoid((sx * 0.098, 0.238, 0.978), (0.098, 0.044, 0.062),
                        12, 8, R=rot(y=sx * 0.45)))

    # --- 팔 -------------------------------------------------------------
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Arm_%s' % side, 'Skin',
              tube([(sx * 0.195, 0.0, 1.070), (sx * 0.300, -0.020, 0.965),
                    (sx * 0.390, -0.050, 0.862)],
                   [0.060, 0.049, 0.043], 12))
        m.add('Hand_%s' % side, 'Skin',
              ellipsoid((sx * 0.412, -0.060, 0.833), (0.064, 0.058, 0.064), 12, 8))

    # --- 다리 & 신발 -----------------------------------------------------
    for side, sx in (('L', -1), ('R', 1)):
        m.add('Leg_%s' % side, 'Skin',
              tube([(sx * 0.115, 0.0, 0.580), (sx * 0.115, -0.008, 0.390),
                    (sx * 0.115, 0.002, 0.175)],
                   [0.078, 0.064, 0.060], 12))
        m.add('Shoe_%s' % side, 'Shoes',
              ellipsoid((sx * 0.115, -0.040, 0.092), (0.090, 0.138, 0.088), 14, 9))

    # --- 하트 요정 날개 (반투명) -----------------------------------------
    wings = [
        ('Wing_Upper_L', -1, 0.420, (-0.415, 0.320, 1.120), -0.66, -0.62),
        ('Wing_Upper_R', 1, 0.420, (0.415, 0.320, 1.120), 0.66, 0.62),
        ('Wing_Lower_L', -1, 0.300, (-0.350, 0.340, 0.895), -0.28, -0.48),
        ('Wing_Lower_R', 1, 0.300, (0.350, 0.340, 0.895), 0.28, 0.48),
    ]
    for name, sx, s, c, tilt, sweep in wings:
        pts = heart_pts(32, s, yshift=0.10)
        m.add(name, 'Wing', extrude_poly(pts, 0.014,
                                         R=rot(z=sweep) @ rot(y=tilt), center=c))

    return m


# ------------------------------------------------------------------ accessories
def build_accessories():
    m = Model('Heartping_Tiara_Wand')

    # ===== 티아라 =====================================================
    # 헤어 캡(중심 y=0.108, z=1.574, 반지름 0.549/0.470/0.532) 위에 얹히도록
    band_z = 1.858
    band_cy = 0.040
    rx, ry = 0.472, 0.452
    V, F = torus(major=1.0, minor=0.026, seg=40, tub=7,
                 center=(0, 0, band_z), R=rot(x=math.radians(-6)))
    V = np.column_stack([V[:, 0] * rx, V[:, 1] * ry, V[:, 2] - band_z])
    V[:, 2] += band_z
    V[:, 1] += band_cy
    m.add('Tiara_Band', 'Gold', (V, F))

    def band_point(ang_deg, z_off=0.0):
        a = math.radians(-90.0 + ang_deg)
        return np.array([rx * math.cos(a) * 0.99,
                         band_cy + ry * math.sin(a) * 0.99,
                         band_z + z_off])

    # 앞쪽 왕관 뾰족이 5개 (-Y 가 정면), 머리 쪽으로 살짝 누운 형태
    spikes = [(0.0, 0.205, 0.028), (-20.0, 0.165, 0.024), (20.0, 0.165, 0.024),
              (-40.0, 0.125, 0.019), (40.0, 0.125, 0.019)]
    for k, (ang, h, w) in enumerate(spikes):
        base = band_point(ang)
        tip = base + 0.30 * np.array([-base[0], band_cy - base[1], 0.0]) + \
            np.array([0.0, 0.0, h])
        m.add('Tiara_Spike_%d' % (k + 1), 'Gold',
              tube([base + np.array([0, 0, 0.012]), tip], [w, 0.0035], 4))

    # 앞 가운데 하트 보석 (밴드에 딱 붙게)
    m.add('Tiara_Gem_Heart', 'GemPink',
          extrude_poly(heart_pts(26, 0.055), 0.026,
                       center=(0.0, band_cy - ry * 0.99 - 0.012, band_z + 0.014)))
    # 뾰족이 끝 보석
    for sx in (-1, 1):
        base = band_point(sx * 20.0)
        tip = base + 0.30 * np.array([-base[0], band_cy - base[1], 0.0]) + \
            np.array([0.0, 0.0, 0.165])
        m.add('Tiara_Gem_Cyan_%s' % ('L' if sx < 0 else 'R'), 'GemCyan',
              ellipsoid(tuple(tip + np.array([0, 0, 0.006])),
                        (0.023, 0.023, 0.023), 12, 8))

    # 작은 별빛
    for k, (ang, h, s2) in enumerate(((-56.0, 0.055, 0.020), (56.0, 0.055, 0.020),
                                      (0.0, 0.255, 0.024), (-152.0, 0.085, 0.018),
                                      (152.0, 0.085, 0.018))):
        p0 = band_point(ang, h)
        m.add('Tiara_Spark_%d' % k, 'StarGold',
              extrude_poly(star_pts(4, s2, s2 * 0.36), 0.012, center=tuple(p0)))

    # ===== 마법 지팡이 =================================================
    handle = [(0.300, 0.010, 0.660), (0.375, -0.025, 0.800),
              (0.455, -0.060, 0.955), (0.520, -0.095, 1.110),
              (0.560, -0.118, 1.215)]
    m.add('Wand_Handle', 'Pearl', tube(handle, [0.033, 0.028, 0.026, 0.024, 0.022], 12))
    for k, idx in enumerate((1, 3)):
        p = np.array(handle[idx])
        d = np.array(handle[idx + 1]) - np.array(handle[idx - 1])
        d = d / np.linalg.norm(d)
        # 링을 지팡이 축에 수직으로
        z_axis = np.array([0, 0, 1.0])
        v = np.cross(z_axis, d)
        vn = np.linalg.norm(v)
        if vn < 1e-6:
            R = np.eye(3)
        else:
            v = v / vn
            ang = math.acos(max(-1.0, min(1.0, np.dot(z_axis, d))))
            K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
            R = np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * (K @ K)
        m.add('Wand_Ring_%d' % (k + 1), 'Gold',
              torus(major=0.034, minor=0.010, seg=16, tub=6, center=p, R=R))

    # 별 (5각) - 몸 정면(-Y)을 바라보게 XZ 평면
    star_c = (0.618, -0.140, 1.315)
    m.add('Wand_Star', 'StarGold',
          extrude_poly(star_pts(5, 0.150, 0.062), 0.040, R=rot(y=0.18), center=star_c))
    m.add('Wand_Star_Gem', 'GemPink',
          ellipsoid((star_c[0] + 0.005, star_c[1] - 0.028, star_c[2]),
                    (0.036, 0.022, 0.036), 12, 8))
    # 별 주위 반짝이
    for k, (dx, dz, s) in enumerate(((-0.150, 0.110, 0.036), (0.140, 0.075, 0.028),
                                     (-0.075, -0.150, 0.026), (0.120, -0.120, 0.022))):
        m.add('Wand_Spark_%d' % k, 'StarGold',
              extrude_poly(star_pts(4, s, s * 0.36), 0.012,
                           center=(star_c[0] + dx, star_c[1] - 0.010, star_c[2] + dz)))

    return m


# ------------------------------------------------------------------ main
def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    fairy = build_fairy()
    acc = build_accessories()

    f_tris = fairy.write_obj(os.path.join(outdir, 'Heartping_Fairy.obj'),
                             os.path.join(outdir, 'Heartping_Fairy.mtl'), MATERIALS)
    a_tris = acc.write_obj(os.path.join(outdir, 'Heartping_Tiara_Wand.obj'),
                           os.path.join(outdir, 'Heartping_Tiara_Wand.mtl'), MATERIALS)

    for name, model, tris in (('Heartping_Fairy', fairy, f_tris),
                              ('Heartping_Tiara_Wand', acc, a_tris)):
        v, t = model.stats()
        lo, hi = model.bbox()
        print('%-22s parts=%2d verts=%5d tris=%5d  bbox=%.2f..%.2f / %.2f..%.2f / %.2f..%.2f'
              % (name, len(model.parts), v, t, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'out')
