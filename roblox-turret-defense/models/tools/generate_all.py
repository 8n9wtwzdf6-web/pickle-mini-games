#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""models/ 폴더의 모든 .obj/.mtl 을 한 번에 다시 만든다: python3 tools/generate_all.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_faction_models as faction  # noqa: E402
import generate_omega_nexus as omega  # noqa: E402


def main():
    outdir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print('== 최종 보스 · 휴먼 지휘소 ==')
    omega.main(outdir)
    print('== 종족 본진 4종 · 유닛 10종 · 몬스터 2종 ==')
    faction.main(outdir)


if __name__ == '__main__':
    main()
