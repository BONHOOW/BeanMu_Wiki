import math, sys
# ---- 파라미터 ----
CX, CY, RX, RY, ROT = 118.0, 136.0, 68.0, 96.0, -24.0   # 원두 타원 (캔버스 좌표계에서 -24° 회전)
CREASE_W = float(sys.argv[1]) if len(sys.argv) > 1 else 18.0  # 틈 너비 (소형 컷은 더 두껍게)
RIB = dict(L=150, R=210, T=18, B=128, apex=104)               # 리본 바깥(홈) 사각형 + V 노치 꼭짓점 y
RIB_IN = dict(L=160, R=200, T=28, B=108, apex=92)             # 리본 안쪽(검정)
GAP_SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0  # 소형 컷: 리본을 키우는 배율 (중심 (180,73) 기준)
th = math.radians(ROT); c, s = math.cos(th), math.sin(th)
def rot(p):
    x, y = p; dx, dy = x - CX, y - CY
    return (CX + dx * c - dy * s, CY + dx * s + dy * c)
def f(v): return f"{v:.2f}".rstrip('0').rstrip('.')
def pt(p): return f"{f(p[0])} {f(p[1])}"
# ---- 원두 외곽: 회전 타원을 호 두 개로 (정확한 기하) ----
top, bot = rot((CX, CY - RY)), rot((CX, CY + RY))
bean = f"M{pt(top)} A{f(RX)} {f(RY)} {f(ROT)} 1 1 {pt(bot)} A{f(RX)} {f(RY)} {f(ROT)} 1 1 {pt(top)} Z"
# ---- 틈: S 곡선 띠 (양쪽 가장자리 = 제어점을 ±w/2 옮긴 큐빅, 끝은 반원 캡). 회전은 제어점에 적용 (아핀 불변) ----
w = CREASE_W / 2
P0, C1, C2, P3 = (CX, 54), (CX, 90), (CX - 26, 110), (CX, 136)          # 위 끝 핸들 수직
Q0, D1, D2, Q3 = (CX, 136), (CX + 26, 162), (CX, 182), (CX, 218)         # 중앙에서 접선 연속, 아래 끝 핸들 수직
def sh(p, dx): return (p[0] + dx, p[1])
left = [sh(p, -w) for p in (P0, C1, C2, P3, D1, D2, Q3)]
right = [sh(p, +w) for p in (Q3, D2, D1, Q0, C2, C1, P0)]
crease = (f"M{pt(rot(left[0]))} C{pt(rot(left[1]))} {pt(rot(left[2]))} {pt(rot(left[3]))} C{pt(rot(left[4]))} {pt(rot(left[5]))} {pt(rot(left[6]))}"
          f" A{f(w)} {f(w)} 0 0 0 {pt(rot(right[0]))}"
          f" C{pt(rot(right[1]))} {pt(rot(right[2]))} {pt(rot(right[3]))} C{pt(rot(right[4]))} {pt(rot(right[5]))} {pt(rot(right[6]))}"
          f" A{f(w)} {f(w)} 0 0 0 {pt(rot(left[0]))} Z")
# ---- 리본 홈: 리본 바깥 모양 ∩ 원두 (볼록 조각 2개로 클리핑, 0.4 겹쳐 이음새 제거) ----
def scaled(r):
    cx0, cy0 = 180, 73
    g = lambda v, c0: c0 + (v - c0) * GAP_SCALE
    return dict(L=g(r['L'], cx0), R=g(r['R'], cx0), T=g(r['T'], cy0), B=g(r['B'], cy0), apex=g(r['apex'], cy0))
R, RI = scaled(RIB), scaled(RIB_IN)
M = (R['L'] + R['R']) / 2
quads = [[(R['L'], R['T']), (M + 0.4, R['T']), (M + 0.4, R['apex']), (R['L'], R['B'])],
         [(M - 0.4, R['T']), (R['R'], R['T']), (R['R'], R['B']), (M - 0.4, R['apex'])]]
ellipse_poly = [rot((CX + RX * math.cos(t), CY + RY * math.sin(t))) for t in [i * 2 * math.pi / 720 for i in range(720)]]
def clip(subject, clipper):
    def inside(p, a, b): return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) <= 0
    def inter(p, q, a, b):
        x1, y1, x2, y2 = p[0], p[1], q[0], q[1]; x3, y3, x4, y4 = a[0], a[1], b[0], b[1]
        d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
        return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))
    out = subject
    for i in range(len(clipper)):
        a, b = clipper[i], clipper[(i + 1) % len(clipper)]; inp = out; out = []
        if not inp: break
        sprev = inp[-1]
        for p in inp:
            if inside(p, a, b):
                if not inside(sprev, a, b): out.append(inter(sprev, p, a, b))
                out.append(p)
            elif inside(sprev, a, b): out.append(inter(sprev, p, a, b))
            sprev = p
    return out
def area(poly): return sum(poly[i][0] * poly[(i+1)%len(poly)][1] - poly[(i+1)%len(poly)][0] * poly[i][1] for i in range(len(poly))) / 2
holes = []
for q in quads:
    if area(q) > 0: q = q[::-1]      # 클리퍼는 시계 방향(=음의 면적) 기준
    poly = clip(ellipse_poly, q)
    if len(poly) >= 3:
        # 점 줄이기: 거의 직선인 점 제거
        simp = [poly[0]]
        for p in poly[1:]:
            if abs(p[0] - simp[-1][0]) + abs(p[1] - simp[-1][1]) > 0.8: simp.append(p)
        holes.append("M" + " L".join(pt(p) for p in simp) + " Z")
inner = f"M{f(RI['L'])} {f(RI['T'])} H{f(RI['R'])} V{f(RI['B'])} L{f(M)} {f(RI['apex'])} L{f(RI['L'])} {f(RI['B'])} Z"
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" aria-labelledby="t">
<title id="t">BeanMuWiki symbol — Bookmark Bean</title>
<g id="symbol">
  <path fill-rule="evenodd" d="{bean} {crease} {' '.join(holes)}"/>
  <path d="{inner}"/>
</g>
</svg>
'''
sys.stdout.write(svg)
