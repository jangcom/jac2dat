#!/usr/bin/env bash
set -e

jac=./samples/sample_rand.jac
det=./j2d/det_fitted.j2d
fmts=dat,xlsx
out_path=./samples

perl jac2dat.pl \
  "$jac" \
  --det="$det" \
  --fmts="$fmts" \
  --out_path="$out_path" \
  --nopause
