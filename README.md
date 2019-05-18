# jac2dat

<?xml version="1.0" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<link rev="made" href="mailto:" />
</head>

<body>



<ul id="index">
  <li><a href="#NAME">NAME</a></li>
  <li><a href="#SYNOPSIS">SYNOPSIS</a></li>
  <li><a href="#DESCRIPTION">DESCRIPTION</a></li>
  <li><a href="#OPTIONS">OPTIONS</a></li>
  <li><a href="#EXAMPLES">EXAMPLES</a></li>
  <li><a href="#REQUIREMENTS">REQUIREMENTS</a></li>
  <li><a href="#SEE-ALSO">SEE ALSO</a></li>
  <li><a href="#AUTHOR">AUTHOR</a></li>
  <li><a href="#COPYRIGHT">COPYRIGHT</a></li>
  <li><a href="#LICENSE">LICENSE</a></li>
</ul>

<h1 id="NAME">NAME</h1>

<p>jac2dat - Convert .jac files to various data formats</p>

<h1 id="SYNOPSIS">SYNOPSIS</h1>

<pre><code>    perl jac2dat.pl [jac_files ...] [-all] [-det=det_file]
                    [-dat_fmts=ext ...] [-dat_path=path]
                    [-nofm] [-nopause]</code></pre>

<h1 id="DESCRIPTION">DESCRIPTION</h1>

<pre><code>    jac2dat converts .jac files to various data formats.
    - JAC file: The gamma spectra format of the Science and Technology Agency
                (now the MEXT), Japan. For details, refer to the catalogue of
                DS-P1001 Gamma Station, SII.
                A .jac file consists of only one column, in which
                gamma counts are stored in ascending order of channels.
                The first three records are &quot;not&quot; gamma counts, and
                are used for special purposes:
                - Record 1: Live time (duration)
                - Record 2: Real time (duration)
                - Record 3: Acquired time
    - DAT file: A plottable text file converted from a .jac file.
                A .dat file consists of multiple columns, in which
                channels, gamma energies, peak FWHMs, peak efficiencies,
                counts, count per second (cps), gammas, and
                gamma per second (gps) are stored.
    - Other supported data formats include tex, csv, xlsx, json, and yaml.</code></pre>

<h1 id="OPTIONS">OPTIONS</h1>

<pre><code>    jac_files ...
        .jac files to be converted.

    -all (short form: -a)
        All .jac files in the current working directory will be converted.

    -detector=det_file (short form: -det)
        A file containing conversion formulas of a detector
        such as channel-to-energy and channel-to-FWHM formulas.
        Key-value pairs contained in this file take precedence
        over the predefined formulas.
        Refer to the sample file &#39;detector.j2d&#39; for the syntax.

    -dat_fmts=ext ... (short: -fmts, default: dat)
        Data formats. Multiple formats are separated by the comma (,).
        all
            All of the following ext&#39;s.
        dat
            Plain text
        tex
            LaTeX tabular environment
        csv
            comma-separated value
        xlsx
            Microsoft Excel 2007
        json
            JavaScript Object Notation
        yaml
            YAML

    -dat_path=path (short: -path, default: current working directory)
        The path in which the converted data files will be stored.

    -nofm
        Do not show the front matter at the beginning of the program.

    -nopause
        Do not pause the shell at the end of the program.</code></pre>

<h1 id="EXAMPLES">EXAMPLES</h1>

<pre><code>    perl jac2dat.pl 1200s.jac -fmts=dat,xlsx -nopause
    perl jac2dat.pl -all -fmts=all -det=det_fitted.j2d
    perl jac2dat.pl sample_rand.jac -nopause</code></pre>

<h1 id="REQUIREMENTS">REQUIREMENTS</h1>

<pre><code>    Perl 5
        Text::CSV, Excel::Writer::XLSX, JSON, YAML</code></pre>

<h1 id="SEE-ALSO">SEE ALSO</h1>

<p><a href="https://github.com/jangcom/jac2dat">jac2dat on GitHub</a></p>

<h1 id="AUTHOR">AUTHOR</h1>

<p>Jaewoong Jang &lt;jangj@korea.ac.kr&gt;</p>

<h1 id="COPYRIGHT">COPYRIGHT</h1>

<p>Copyright (c) 2019 Jaewoong Jang</p>

<h1 id="LICENSE">LICENSE</h1>

<p>This software is available under the MIT license; the license information is found in &#39;LICENSE&#39;.</p>


</body>

</html>
