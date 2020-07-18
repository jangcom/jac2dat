@echo off
set jac=./samples/sample_rand.jac
set det=./j2d/det_fitted.j2d
set fmts=dat,xlsx
set out_path=./samples
perl jac2dat.pl %jac% --det=%det% --fmts=%fmts% --out_path=%out_path% --nopause
