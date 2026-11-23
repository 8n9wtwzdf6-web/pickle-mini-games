"""Tiny procedural mesh library (numpy only) for the Heartping 3D models.

Everything is built as closed parts so that face orientation can be fixed by the
signed volume of the part.  A part = (name, material, verts(N,3), faces(M,3)).
"""
import math
import numpy as np

TAU = 2 * math.pi


# ---------------------------------------------------------------- transforms
def rot(x=0.0, y=0.0, z=0.0):
    cx, sx = math.cos(x), math.sin(x)
    cy, sy = math.cos(y), math.sin(y)
    cz, sz = math.cos(z), math.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def xform(verts, R=None, t=(0, 0, 0)):
    V = np.asarray(verts, float)
    if R is not None:
        V = V @ np.asarray(R, float).T
    return V + np.asarray(t, float)


# ---------------------------------------------------------------- primitives
def ellipsoid(center, radii, segs=24, rings=14, R=None):
    verts = []
    rx, ry, rz = radii
    for j in range(rings + 1):
        v = math.pi * j / rings
        sv, cv = math.sin(v), math.cos(v)
        for i in range(segs):
            u = TAU * i / segs
            verts.append([math.cos(u) * sv * rx, math.sin(u) * sv * ry, cv * rz])
    V = np.array(verts)
    if R is not None:
        V = V @ np.asarray(R, float).T
    V = V + np.asarray(center, float)
    faces = []
    for j in range(rings):
        for i in range(segs):
            i2 = (i + 1) % segs
            a, b = j * segs + i, j * segs + i2
            c, d = (j + 1) * segs + i2, (j + 1) * segs + i
            faces += [(a, b, c), (a, c, d)]
    return V, np.array(faces)


def tube(points, radii, radial=12, caps=True, up=(0, 0, 1)):
    P = np.asarray(points, float)
    radii = np.broadcast_to(np.asarray(radii, float), (len(P),))
    n = len(P)
    T = []
    for i in range(n):
        if i == 0:
            t = P[1] - P[0]
        elif i == n - 1:
            t = P[-1] - P[-2]
        else:
            t = P[i + 1] - P[i - 1]
        norm = np.linalg.norm(t)
        T.append(t / norm if norm > 1e-9 else np.array([0, 0, 1.0]))
    ref = np.asarray(up, float)
    N = ref - np.dot(ref, T[0]) * T[0]
    if np.linalg.norm(N) < 1e-6:
        ref = np.array([1.0, 0, 0])
        N = ref - np.dot(ref, T[0]) * T[0]
    N = N / np.linalg.norm(N)
    frames = []
    for i in range(n):
        N = N - np.dot(N, T[i]) * T[i]
        n_norm = np.linalg.norm(N)
        N = N / n_norm if n_norm > 1e-9 else np.array([1.0, 0, 0])
        frames.append((N, np.cross(T[i], N)))
    verts = []
    for i in range(n):
        N, B = frames[i]
        for k in range(radial):
            a = TAU * k / radial
            verts.append(P[i] + radii[i] * (math.cos(a) * N + math.sin(a) * B))
    faces = []
    for i in range(n - 1):
        for k in range(radial):
            k2 = (k + 1) % radial
            a = i * radial + k
            b = i * radial + k2
            c = (i + 1) * radial + k2
            d = (i + 1) * radial + k
            faces += [(a, b, c), (a, c, d)]
    if caps:
        c0 = len(verts)
        verts.append(P[0])
        c1 = len(verts)
        verts.append(P[-1])
        for k in range(radial):
            k2 = (k + 1) % radial
            faces.append((c0, k2, k))
            faces.append((c1, (n - 1) * radial + k, (n - 1) * radial + k2))
    return np.array(verts), np.array(faces)


def revolve(profile, segs=40, mod=None, caps=(True, True), R=None, center=(0, 0, 0)):
    """profile: [(r, z), ...] top -> bottom. mod(angle, r, z) -> (r, z)."""
    verts = []
    for (r, z) in profile:
        for i in range(segs):
            a = TAU * i / segs
            rr, zz = (mod(a, r, z) if mod else (r, z))
            verts.append([rr * math.cos(a), rr * math.sin(a), zz])
    V = np.array(verts)
    faces = []
    n = len(profile)
    for j in range(n - 1):
        for i in range(segs):
            i2 = (i + 1) % segs
            a, b = j * segs + i, j * segs + i2
            c, d = (j + 1) * segs + i2, (j + 1) * segs + i
            faces += [(a, b, c), (a, c, d)]
    if caps[0]:
        ci = len(V)
        V = np.vstack([V, [[0, 0, profile[0][1]]]])
        for i in range(segs):
            faces.append((ci, (i + 1) % segs, i))
    if caps[1]:
        ci = len(V)
        V = np.vstack([V, [[0, 0, profile[-1][1]]]])
        base = (n - 1) * segs
        for i in range(segs):
            faces.append((ci, base + i, base + (i + 1) % segs))
    if R is not None:
        V = V @ np.asarray(R, float).T
    return V + np.asarray(center, float), np.array(faces)


def torus(major=0.3, minor=0.03, seg=28, tub=8, arc=(0.0, TAU), R=None,
          center=(0, 0, 0), caps=True):
    a0, a1 = arc
    closed = abs((a1 - a0) - TAU) < 1e-6
    n_major = seg if closed else seg + 1
    verts = []
    for i in range(n_major):
        a = a0 + (a1 - a0) * (i / seg)
        ca, sa = math.cos(a), math.sin(a)
        for k in range(tub):
            b = TAU * k / tub
            verts.append([(major + minor * math.cos(b)) * ca,
                          (major + minor * math.cos(b)) * sa,
                          minor * math.sin(b)])
    faces = []
    steps = n_major if closed else n_major - 1
    for i in range(steps):
        i2 = (i + 1) % n_major
        for k in range(tub):
            k2 = (k + 1) % tub
            a = i * tub + k
            b = i * tub + k2
            c = i2 * tub + k2
            d = i2 * tub + k
            faces += [(a, b, c), (a, c, d)]
    if not closed and caps:
        for i, rev in ((0, True), (n_major - 1, False)):
            ci = len(verts)
            verts.append([major * math.cos(a0 if i == 0 else a1),
                          major * math.sin(a0 if i == 0 else a1), 0.0])
            for k in range(tub):
                k2 = (k + 1) % tub
                if rev:
                    faces.append((ci, i * tub + k2, i * tub + k))
                else:
                    faces.append((ci, i * tub + k, i * tub + k2))
    V = np.array(verts)
    if R is not None:
        V = V @ np.asarray(R, float).T
    return V + np.asarray(center, float), np.array(faces)


# ---------------------------------------------------------------- 2D helpers
def heart_pts(n=44, s=1.0, yshift=0.0):
    pts = []
    for i in range(n):
        t = TAU * i / n
        x = 16 * math.sin(t) ** 3
        y = (13 * math.cos(t) - 5 * math.cos(2 * t)
             - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((x / 17.0 * s, y / 17.0 * s + yshift))
    return pts


def star_pts(points=5, outer=1.0, inner=0.44, rot_deg=90.0):
    out = []
    for i in range(2 * points):
        a = math.radians(rot_deg) + math.pi * i / points
        r = outer if i % 2 == 0 else inner
        out.append((r * math.cos(a), r * math.sin(a)))
    return out


def _area2(pts):
    n = len(pts)
    return sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1]
               for i in range(n))


def _pt_in_tri(p, a, b, c):
    def cross(u, v, w):
        return (v[0] - u[0]) * (w[1] - u[1]) - (v[1] - u[1]) * (w[0] - u[0])
    d1, d2, d3 = cross(a, b, p), cross(b, c, p), cross(c, a, p)
    neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (neg and pos)


def poly_tris(pts):
    """Ear clipping triangulation of a simple polygon (list of 2D points)."""
    pts = list(pts)
    if _area2(pts) < 0:
        pts = pts[::-1]
    idx = list(range(len(pts)))
    tris = []
    guard = 0
    while len(idx) > 3 and guard < 20000:
        guard += 1
        found = False
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            cr = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            if cr <= 1e-12:
                continue
            if any(_pt_in_tri(pts[m], a, b, c) for m in idx if m not in (i0, i1, i2)):
                continue
            tris.append((i0, i1, i2))
            idx.pop(k)
            found = True
            break
        if not found:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    return tris


def extrude_poly(pts2d, thickness, R=None, center=(0, 0, 0), bevel=0.0):
    """Extrude a simple polygon given in local (x, z) with thickness along local y."""
    n = len(pts2d)
    tris = poly_tris(pts2d)
    h = thickness / 2.0
    verts = []
    for y in (-h, h):
        for (x, z) in pts2d:
            verts.append([x, y, z])
    faces = []
    for (a, b, c) in tris:
        faces.append((a, b, c))
    for (a, b, c) in tris:
        faces.append((n + a, n + c, n + b))
    for i in range(n):
        i2 = (i + 1) % n
        faces += [(i, i2, n + i2), (i, n + i2, n + i)]
    V = np.array(verts)
    if R is not None:
        V = V @ np.asarray(R, float).T
    return V + np.asarray(center, float), np.array(faces)


# ---------------------------------------------------------------- model parts
class Model:
    def __init__(self, name):
        self.name = name
        self.parts = []  # (part_name, material, V, F)

    def add(self, part_name, material, geo):
        V, F = geo
        V = np.asarray(V, float)
        F = np.asarray(F, int)
        # drop degenerate triangles
        p0, p1, p2 = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
        area = np.linalg.norm(np.cross(p1 - p0, p2 - p0), axis=1)
        F = F[area > 1e-10]
        V, F = self._dedupe(V, F)
        if len(F) == 0:
            return
        # orient by signed volume
        vol = np.einsum('ij,ij->i', V[F[:, 0]], np.cross(V[F[:, 1]], V[F[:, 2]])).sum() / 6.0
        if vol < 0:
            F = F[:, ::-1]
        self.parts.append((part_name, material, V, F))

    @staticmethod
    def _dedupe(V, F):
        key = np.round(V, 5)
        _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
        # keep original ordering of the unique rows as they first appear
        order = np.argsort(first)
        remap = np.empty_like(order)
        remap[order] = np.arange(len(order))
        Vu = key[first[order]]
        Fu = remap[inv][F]
        Fu = Fu.reshape(-1, 3)
        ok = ((Fu[:, 0] != Fu[:, 1]) & (Fu[:, 1] != Fu[:, 2]) & (Fu[:, 0] != Fu[:, 2]))
        return Vu.astype(float), Fu[ok]

    # ---- output -------------------------------------------------------
    def stats(self):
        tris = sum(len(F) for _, _, _, F in self.parts)
        verts = sum(len(V) for _, _, V, _ in self.parts)
        return verts, tris

    def bbox(self):
        V = np.vstack([V for _, _, V, _ in self.parts])
        return V.min(axis=0), V.max(axis=0)

    def write_obj(self, obj_path, mtl_path, materials, scale=1.0):
        # 저작 좌표(Z-up, 얼굴 -Y) → 표준 OBJ 좌표(Y-up, 얼굴 +Z)
        #   (x, y, z) -> (x, z, -y)
        R = np.array([[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0]])
        vlines, vnlines, blocks = [], [], []
        voff = vnoff = 0
        for name, mat, V, F in self.parts:
            V = (V * scale) @ R.T
            # smooth vertex normals inside the part
            fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
            ln = np.linalg.norm(fn, axis=1, keepdims=True)
            ln[ln == 0] = 1
            fn = fn / ln
            vn_acc = np.zeros_like(V)
            for k in range(3):
                np.add.at(vn_acc, F[:, k], fn)
            ln2 = np.linalg.norm(vn_acc, axis=1, keepdims=True)
            ln2[ln2 == 0] = 1
            vn_acc = vn_acc / ln2
            for p in V:
                vlines.append('v %.5f %.5f %.5f' % tuple(p))
            for p in vn_acc:
                vnlines.append('vn %.4f %.4f %.4f' % tuple(p))
            fl = []
            for tri in F:
                fl.append('f ' + ' '.join('%d//%d' % (voff + i + 1, vnoff + i + 1)
                                          for i in tri))
            blocks.append('o %s\ng %s\nusemtl %s\ns 1\n%s'
                          % (name, name, mat, '\n'.join(fl)))
            voff += len(V)
            vnoff += len(V)
        with open(obj_path, 'w', encoding='utf-8') as f:
            f.write('# %s - procedural model for Blender 5.3 / Roblox Studio\n' % self.name)
            f.write('# units: 1 unit = 1 m | Y-up (standard OBJ), character faces +Z\n')
            f.write('# parts are split with o/g names, one usemtl per material\n')
            f.write('mtllib %s\n' % mtl_path.split('/')[-1])
            f.write('\n'.join(vlines) + '\n')
            f.write('\n'.join(vnlines) + '\n')
            f.write('\n\n'.join(blocks) + '\n')
        used = []
        for _, m, _, _ in self.parts:
            if m not in used:
                used.append(m)
        with open(mtl_path, 'w', encoding='utf-8') as f:
            f.write('# materials for %s\n' % self.name)
            for m in used:
                spec = materials[m]
                kd = spec['kd']
                f.write('\nnewmtl %s\nKa %.4f %.4f %.4f\nKd %.4f %.4f %.4f\n'
                        % (m, kd[0] * .3, kd[1] * .3, kd[2] * .3, kd[0], kd[1], kd[2]))
                ks = spec.get('ks', 0.15)
                f.write('Ks %.4f %.4f %.4f\nNs %.1f\nd %.4f\nillum 2\n'
                        % (ks, ks, ks, spec.get('ns', 24), spec.get('d', 1.0)))
        return sum(len(F) for _, _, _, F in self.parts)


def hair_shell(center, r_out, r_in, psi_max, theta_fn, cols=36, rows=7,
               theta_mid=0.86):
    """Front hair fringe: spherical band around -Y with a scalloped lower edge.

    psi: azimuth from the front (-Y), theta: polar angle from +Z.
    """
    def surf(r):
        rx, ry, rz = (r if isinstance(r, (tuple, list)) else (r, r, r))
        V = []
        for j in range(rows + 1):
            for i in range(cols + 1):
                psi = -psi_max + 2 * psi_max * i / cols
                if j < rows:
                    th = theta_mid * (j / rows)
                else:
                    th = theta_fn(psi)
                V.append([rx * math.sin(th) * math.sin(psi),
                          -ry * math.sin(th) * math.cos(psi),
                          rz * math.cos(th)])
        return V

    outer = surf(r_out)
    inner = surf(r_in)
    n = len(outer)
    verts = outer + inner
    faces = []

    def grid(base, flip=False):
        for j in range(rows):
            for i in range(cols):
                a = base + j * (cols + 1) + i
                b = a + 1
                c = base + (j + 1) * (cols + 1) + i + 1
                d = base + (j + 1) * (cols + 1) + i
                if flip:
                    faces.append((a, c, b))
                    faces.append((a, d, c))
                else:
                    faces.append((a, b, c))
                    faces.append((a, c, d))

    grid(0, False)
    grid(n, True)
    # 아래 스캘럽 테두리
    for i in range(cols):
        a = rows * (cols + 1) + i
        b = a + 1
        faces.append((a, n + a, n + b))
        faces.append((a, n + b, b))
    # 옆 테두리
    for j in range(rows):
        a = j * (cols + 1)
        b = (j + 1) * (cols + 1)
        faces.append((a, b, n + b))
        faces.append((a, n + b, n + a))
        a2 = a + cols
        b2 = b + cols
        faces.append((a2, n + b2, b2))
        faces.append((a2, n + a2, n + b2))

    V = np.array(verts) + np.asarray(center, float)
    return V, np.array(faces)
