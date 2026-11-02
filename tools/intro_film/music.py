"""오또 소개 영상 배경음악 + 효과음 합성 (27초, 96BPM, 따뜻한 로파이 톤)."""
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
from scipy.io import wavfile

SR = 44100
DUR = 27.0
N = int(SR * DUR)
BPM = 96
BEAT = 60 / BPM
T = {'s1': 0, 's2': 3.2, 's3': 6.6, 's4': 11.2, 's5': 15.6, 's6': 20.0, 's7': 23.6}
rng = np.random.default_rng(7)


def hz(m): return 440 * 2 ** ((m - 69) / 12)
def lp(x, f, o=2): return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, 'high', fs=SR, output='sos'), x)
def bp(x, a, b, o=2): return sosfilt(butter(o, [a, b], 'band', fs=SR, output='sos'), x)


def place(buf, sig, t, g=1.0):
    i = int(t * SR)
    if i >= len(buf): return
    s = sig[:len(buf) - i]
    buf[i:i + len(s)] += s * g


def env(n, a, d, s_lvl, r, total):
    t = np.arange(total) / SR
    e = np.where(t < a, t / max(a, 1e-4), s_lvl + (1 - s_lvl) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip((total / SR - t) / max(r, 1e-4), 0, 1)
    return e * rel


def epiano(m, dur, vel=1.0):
    n = int((dur + 1.2) * SR); t = np.arange(n) / SR; f = hz(m)
    idx = 1.8 * np.exp(-t * 6) + 0.25
    mod = np.sin(2 * np.pi * f * t) * idx
    car = np.sin(2 * np.pi * f * t + mod)
    tine = np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 18) * 0.25
    e = np.exp(-t * 1.6) * np.clip((dur + 1.2 - t) / 0.4, 0, 1) * np.clip(t / 0.004, 0, 1)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.2 * t)
    return (car + tine) * e * trem * vel * 0.16


def pad(ms, dur):
    n = int((dur + 2.0) * SR); t = np.arange(n) / SR; out = np.zeros(n)
    for m in ms:
        for det in (-0.07, 0.0, 0.07):
            f = hz(m + det)
            for h, a in ((1, 1), (2, .45), (3, .22), (4, .12), (5, .07)):
                out += a * np.sin(2 * np.pi * f * h * t + rng.uniform(0, 6.28))
    e = np.clip(t / 1.2, 0, 1) * np.clip((dur + 2.0 - t) / 1.8, 0, 1)
    return lp(out * e, 1400) * 0.018


def pluck(m, vel=1.0):
    n = int(1.6 * SR); t = np.arange(n) / SR; f = hz(m)
    x = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 9) + 0.12 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 14))
    return x * np.exp(-t * 4.5) * np.clip(t / 0.002, 0, 1) * vel * 0.11


def bass(m, dur):
    n = int((dur + .3) * SR); t = np.arange(n) / SR; f = hz(m)
    x = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 2 * t)
    return x * np.clip(t / 0.01, 0, 1) * np.clip((dur + .3 - t) / .25, 0, 1) * np.exp(-t * .6) * 0.22


def kick():
    n = int(.45 * SR); t = np.arange(n) / SR
    f = 48 + 70 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * 0.55


def snap():
    n = int(.3 * SR); t = np.arange(n) / SR
    x = bp(rng.standard_normal(n), 1200, 5200) * np.exp(-t * 26)
    x += np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * .4
    return x * 0.18


def shaker():
    n = int(.12 * SR); t = np.arange(n) / SR
    return hp(rng.standard_normal(n), 6000) * np.exp(-t * 45) * 0.05


def pop(f=880):
    n = int(.25 * SR); t = np.arange(n) / SR
    fr = f * (1 + .6 * np.exp(-t * 40))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 22) * 0.10


def whoosh(d=0.7, up=True):
    n = int(d * SR); t = np.arange(n) / SR
    x = rng.standard_normal(n); out = np.zeros(n); seg = 512
    for i in range(0, n, seg):
        p = i / n; c = (400 + 5000 * p) if up else (5400 - 5000 * p)
        out[i:i + seg] = bp(x[i:i + seg], c * .7, min(c * 1.3, 18000))
    e = np.sin(np.pi * t / d) ** 2
    return out * e * 0.09


def chime():  # 엔딩 반짝임
    out = np.zeros(int(2.5 * SR))
    for k, m in enumerate([84, 88, 91, 96]):
        s = pluck(m, .9); place(out, s, k * .07)
    return out


# 화성 진행 (F장조, 마디 = 4박)
prog = [
    ([53, 57, 60, 64], 41),   # Fmaj7
    ([52, 55, 59, 62], 40),   # Em7
    ([50, 53, 57, 60], 38),   # Dm7
    ([48, 52, 55, 59], 36),   # Cmaj7
    ([46, 50, 53, 57], 34),   # Bbmaj7
    ([45, 48, 52, 55], 33),   # Am7
    ([50, 53, 57, 60], 38),   # Dm7
    ([43, 47, 50, 53], 31),   # G7 → 해결 준비
    ([48, 52, 55, 59], 36),   # Cmaj7
    ([53, 57, 60, 64], 41),   # Fmaj7 (엔딩)
    ([53, 57, 60, 64], 41),
]
BAR = BEAT * 4
mus = np.zeros(N + SR * 3)
drums = np.zeros_like(mus)
sfx = np.zeros_like(mus)

for b, (ch, root) in enumerate(prog):
    t0 = b * BAR
    if t0 >= DUR: break
    place(mus, pad(ch, BAR), t0, 1.0)
    # 일렉트릭 피아노: 1박 + 2.5박 리듬
    vel = .75 if t0 < T['s3'] else 1.0
    for off, v in ((0, 1.0), (BEAT * 1.5, .7), (BEAT * 2.5, .8)):
        tt = t0 + off
        if tt < DUR - .5:
            for m in ch: place(mus, epiano(m + 12 if m < 52 else m, BEAT * .9, v * vel), tt, 1.0)
    # 베이스 (S3부터)
    if t0 >= T['s3'] - .1:
        place(mus, bass(root, BEAT * 1.8), t0); place(mus, bass(root, BEAT * 1.4), t0 + BEAT * 2.5, .8)
    # 오르골 아르페지오 (S3부터, S5에서는 비워 여백)
    if t0 >= T['s3'] - .1:
        arp = [ch[0] + 24, ch[2] + 12, ch[3] + 12, ch[1] + 24, ch[3] + 24, ch[2] + 12, ch[1] + 24, ch[0] + 24]
        for k, m in enumerate(arp):
            tt = t0 + k * BEAT / 2
            if T['s5'] + .2 < tt < T['s6'] - .3 or tt > DUR - 1.2: continue
            place(mus, pluck(m, .55 + .25 * (k % 2 == 0)), tt)

# 드럼: S3~S5, S6~S7 / S5에서는 킥만 남겨 '물러서는' 느낌
nb = int(DUR / BEAT)
for i in range(nb):
    tt = i * BEAT
    if tt < T['s3'] - .05 or tt > DUR - 1.8: continue
    in_s5 = T['s5'] <= tt < T['s6']
    if i % 4 in (0, 2) and not (in_s5 and i % 4 == 2): place(drums, kick(), tt, .9 if not in_s5 else .55)
    if i % 4 in (1, 3) and not in_s5: place(drums, snap(), tt)
    if not in_s5:
        place(drums, shaker(), tt + BEAT / 2, 1.0); place(drums, shaker(), tt, .5)

# 효과음: 장면 전환 휙, 카드/칩 등장 팝
for k in ('s2', 's3', 's4', 's5', 's6', 's7'):
    place(sfx, whoosh(.6), T[k] - .35)
for i in range(8): place(sfx, pop(700 + i * 60), T['s2'] + .35 + i * .12, .55)
place(sfx, pop(980), T['s3'] + .35)
for i in range(3): place(sfx, pop(760 + i * 120), T['s4'] + .7 + i * .28)
place(sfx, pop(1180), T['s4'] + 2.85)
place(sfx, pop(1050), T['s6'] + .6)
place(sfx, pop(660), T['s6'] + .9)  # 하트
place(sfx, chime(), T['s7'] + .5, .9)
place(sfx, pop(520), 1.0, .8)  # 빼꼼

# 리버브(지수 감쇠 노이즈 IR)
irn = int(2.4 * SR); it = np.arange(irn) / SR
ir = rng.standard_normal(irn) * np.exp(-it * 2.6); ir = lp(ir, 5000); ir /= np.sqrt((ir ** 2).sum())
wet_m = fftconvolve(mus, ir)[:len(mus)]
wet_s = fftconvolve(sfx, ir)[:len(sfx)]
mix = mus * .78 + wet_m * .38 + drums * .8 + lp(drums, 2500) * .0 + sfx * .7 + wet_s * .25
# 테이프 질감: 은은한 노이즈 + 아주 약한 피치 흔들림 대신 저역 정리
mix += lp(rng.standard_normal(len(mix)), 3000) * 0.0025
mix = hp(mix, 35)
mix = mix[:N]
# 페이드
fi = int(.08 * SR); fo = int(1.6 * SR)
mix[:fi] *= np.linspace(0, 1, fi); mix[-fo:] *= np.linspace(1, 0, fo) ** 1.5
# 소프트 클립 + 정규화
mix = np.tanh(mix * 1.3) / np.tanh(1.3)
mix *= 0.89 / np.abs(mix).max()
st = np.stack([mix, np.roll(mix, int(.012 * SR)) * .97 + mix * .03], 1)  # 살짝 넓은 스테레오
wavfile.write('out/music.wav', SR, (st * 32767).astype(np.int16))
print('ok', len(mix) / SR, 'rms', np.sqrt((mix ** 2).mean()))
