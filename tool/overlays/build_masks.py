"""Строит маски затемнения из пар скриншотов Canva «с затемнением / без».

Карта T = (с затемнением) / (без) — доля света, прошедшего через чёрные
градиенты. Текст, значки, линии и логотип (они есть на обоих снимках)
маскируются и заполняются по соседям, затем карта сглаживается.
Результат: PNG 3:4, чёрный цвет, альфа = 1 − T.

Запуск: python3 build_masks.py <with.jpg> <without.jpg> <out.png> [--logo]
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

X0, Y0, W, H = 35, 489, 1009, 1346   # холст Canva на скриншоте 1080×2400
OUT_W, OUT_H = 378, 504


def load(path):
    im = Image.open(path).convert("RGB").crop((X0, Y0, X0 + W, Y0 + H))
    return np.array(im).astype(float).sum(2)


def to8(x, k):
    return Image.fromarray(np.clip(x * k, 0, 255).astype(np.uint8))


def main(with_path, without_path, out_path):
    a, b = load(with_path), load(without_path)
    r = np.clip((a + 3) / (b + 3), 0, 1.2)

    # Тонкие детали, которые есть на обоих снимках (текст, значки, линии),
    # дают выбросы относительно медианы окрестности.
    med = np.array(to8(r, 200).filter(ImageFilter.MedianFilter(21))) / 200
    bad = np.abs(r - med) > 0.035
    bad |= (b < 25 * 3) | (b > 250 * 3)          # слишком тёмно / пересвет
    # Логотип: прямоугольник по замеру позиции (+ запас).
    lw = W * 0.1984
    lx, ly = W * 0.0516, W * 0.0498
    bad[int(ly) - 6:int(ly + lw * 0.502) + 6, int(lx) - 6:int(lx + lw) + 6] = True
    bad[:3, :] = bad[-3:, :] = bad[:, :3] = bad[:, -3:] = True   # края скриншота
    bad = np.array(to8(bad.astype(float), 255).filter(ImageFilter.MaxFilter(5))) > 0

    # Заполнение выколотых мест: диффузия на уменьшенной сетке.
    s = 2
    rs = np.array(to8(np.where(bad, 0, r), 200).resize((W // s, H // s), Image.BILINEAR)) / 200
    ms = np.array(to8(bad.astype(float), 255).resize((W // s, H // s), Image.BILINEAR)) > 20
    t = rs.copy()
    t[ms] = rs[~ms].mean()
    for _ in range(4000):
        nb = (np.roll(t, 1, 0) + np.roll(t, -1, 0) + np.roll(t, 1, 1) + np.roll(t, -1, 1)) / 4
        nb[0, :], nb[-1, :] = t[1, :], t[-2, :]
        nb[:, 0], nb[:, -1] = t[:, 1], t[:, -2]
        t[ms] = nb[ms]
    t = np.clip(t, 0, 1)

    img = to8(t, 255).filter(ImageFilter.GaussianBlur(3)).resize((OUT_W, OUT_H), Image.LANCZOS)
    tt = np.array(img).astype(float) / 255
    rgba = np.zeros((OUT_H, OUT_W, 4), np.uint8)
    rgba[..., 3] = np.round((1 - tt) * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(out_path, optimize=True)
    print(out_path, "alpha min/max", rgba[..., 3].min(), rgba[..., 3].max())


if __name__ == "__main__":
    main(*sys.argv[1:4])
