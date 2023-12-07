#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use utf8;
use File::Basename qw(basename);
use feature qw(say state);
use Carp qw(croak);
use Cwd qw(getcwd);
use Data::Dump qw(dump);
use List::Util qw(first maxstr);
use DateTime;
use constant ARRAY => ref [];
use constant HASH  => ref {};


our $VERSION = '1.05';
our $LAST    = '2023-12-06';
our $FIRST   = '2019-02-04';


#----------------------------------My::Toolset----------------------------------
sub show_front_matter {
    # """Display the front matter."""

    my $prog_info_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be a hash ref!"
        unless ref $prog_info_href eq HASH;

    # Subroutine optional arguments
    my(
        $is_prog,
        $is_auth,
        $is_usage,
        $is_timestamp,
        $is_no_trailing_blkline,
        $is_no_newline,
        $is_copy,
    );
    my $lead_symb = '';
    foreach (@_) {
        $is_prog                = 1  if /prog/i;
        $is_auth                = 1  if /auth/i;
        $is_usage               = 1  if /usage/i;
        $is_timestamp           = 1  if /timestamp/i;
        $is_no_trailing_blkline = 1  if /no_trailing_blkline/i;
        $is_no_newline          = 1  if /no_newline/i;
        $is_copy                = 1  if /copy/i;
        # A single non-alphanumeric character
        $lead_symb              = $_ if /^[^a-zA-Z0-9]$/;
    }
    my $newline = $is_no_newline ? "" : "\n";

    #
    # Fill in the front matter array.
    #
    my @fm;
    my $k = 0;
    my $border_len = $lead_symb ? 69 : 70;
    my %borders = (
        '+' => $lead_symb.('+' x $border_len).$newline,
        '*' => $lead_symb.('*' x $border_len).$newline,
    );

    # Top rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }

    # Program info, except the usage
    if ($is_prog) {
        $fm[$k++] = sprintf(
            "%s%s - %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{expl},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%s%s v%s (%s)%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{vers},
            $prog_info_href->{date_last},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%sPerl %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $^V,
            $newline,
        );
    }

    # Timestamp
    if ($is_timestamp) {
        my %datetimes = construct_timestamps('-');
        $fm[$k++] = sprintf(
            "%sCurrent time: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $datetimes{ymdhms},
            $newline,
        );
    }

    # Author info
    if ($is_auth) {
        $fm[$k++] = $lead_symb.$newline if $is_prog;
        $fm[$k++] = sprintf(
            "%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{auth}{$_},
            $newline,
        ) for (
            'name',
#            'posi',
#            'affi',
            'mail',
        );
    }

    # Bottom rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }

    # Program usage: Leading symbols are not used.
    if ($is_usage) {
        $fm[$k++] = $newline if $is_prog or $is_auth;
        $fm[$k++] = $prog_info_href->{usage};
    }

    # Feed a blank line at the end of the front matter.
    if (not $is_no_trailing_blkline) {
        $fm[$k++] = $newline;
    }

    #
    # Print the front matter.
    #
    if ($is_copy) {
        return @fm;
    }
    else {
        print for @fm;
        return;
    }
}


sub validate_argv {
    # """Validate @ARGV against %cmd_opts."""

    my $argv_aref     = shift;
    my $cmd_opts_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be an array ref!"
        unless ref $argv_aref eq ARRAY;
    croak "The 2nd arg of [$sub_name] must be a hash ref!"
        unless ref $cmd_opts_href eq HASH;

    # For yn prompts
    my $the_prog = (caller(0))[1];
    my $yn;
    my $yn_msg = "    | Want to see the usage of $the_prog? [y/n]> ";

    #
    # Terminate the program if the number of required arguments passed
    # is not sufficient.
    #
    my $argv_req_num = shift;  # (OPTIONAL) Number of required args
    if (defined $argv_req_num) {
        my $argv_req_num_passed = grep $_ !~ /-/, @$argv_aref;
        if ($argv_req_num_passed < $argv_req_num) {
            printf(
                "\n    | You have input %s nondash args,".
                " but we need %s nondash args.\n",
                $argv_req_num_passed,
                $argv_req_num,
            );
            print $yn_msg;
            while ($yn = <STDIN>) {
                system "perldoc $the_prog" if $yn =~ /\by\b/i;
                exit if $yn =~ /\b[yn]\b/i;
                print $yn_msg;
            }
        }
    }

    #
    # Count the number of correctly passed command-line options.
    #

    # Non-fnames
    my $num_corr_cmd_opts = 0;
    foreach my $arg (@$argv_aref) {
        foreach my $v (values %$cmd_opts_href) {
            if ($arg =~ /$v/i) {
                $num_corr_cmd_opts++;
                next;
            }
        }
    }

    # Fname-likes
    my $num_corr_fnames = 0;
    $num_corr_fnames = grep $_ !~ /^-/, @$argv_aref;
    $num_corr_cmd_opts += $num_corr_fnames;

    # Warn if "no" correct command-line options have been passed.
    if (not $num_corr_cmd_opts) {
        print "\n    | None of the command-line options was correct.\n";
        print $yn_msg;
        while ($yn = <STDIN>) {
            system "perldoc $the_prog" if $yn =~ /\by\b/i;
            exit if $yn =~ /\b[yn]\b/i;
            print $yn_msg;
        }
    }

    return;
}


sub reduce_data {
    # """Reduce data and generate reporting files."""

    my $sets_href = shift;
    my $cols_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be a hash ref!"
        unless ref $sets_href eq HASH;
    croak "The 2nd arg of [$sub_name] must be a hash ref!"
        unless ref $cols_href eq HASH;

    #
    # Available formats
    # [1] dat
    #   - Plottable text file
    #   - Created by this routine's architecture
    # [2] tex
    #   - Wrapped in the LaTeX tabular environment
    #   - Created by this routine's architecture
    # [3] csv
    #   - Comma-separated values (sep char can however be changed)
    #   - Created by the Text::CSV module
    # [4] xlsx
    #   - MS Excel >2007
    #   - Created by the Excel::Writer::XLSX module "in binary"
    # [5] json
    #   - Arguably the most popular data interchange language
    #   - Created by the JSON module
    # [6] yaml
    #   - An increasingly popular data interchange language
    #   - Created by the YAML module
    #
    # Accordingly, the lines of code for
    # > [1] and [2] are almost the same.
    # > [3] and [4] are essentially their modules' interfaces.
    # > [5] and [6] are a simple chunk of their modules' data dumping commands.
    #

    #
    # Default attributes
    #
    my %flags = (  # Available data formats
        dat  => qr/^dat$/i,
        tex  => qr/^tex$/i,
        csv  => qr/^csv$/i,
        xlsx => qr/^xlsx$/i,
        json => qr/^json$/i,
        yaml => qr/^yaml$/i,
    );
    my %sets = (
        out_encoding => 'UTF-8',
        rpt_formats  => ['dat', 'tex'],
        rpt_path     => "./",
        rpt_bname    => "rpt",
        begin_msg    => "generating data reduction reports...",
    );
    my %cols;
    my %rows;
    my %strs = (  # Not to be modified via the user arguments
        symbs    => {dat => "#",    tex => "%"   },
        eofs     => {dat => "#eof", tex => "%eof"},
        nan      => {
            dat  => "NaN",
            tex  => "{}",
            csv  => "",
            xlsx => "",
            json => "",  # Not related to its 'null'
            yaml => "",  # Not related to its '~'
        },
        newlines => {
            dat => "\n",
            tex => " \\\\\n",
            csv => "\n",
        },
        dataset_seps => {
            dat => "\n\n",  # wrto gnuplot dataset structure
        },
        indents  => {dat => "", tex => "  "},
        rules    => {
            dat  => {},  # To be constructed
            tex  => {    # Commands of the booktabs package
                top => "\\toprule",
                mid => "\\midrule",
                bot => "\\bottomrule",
            },
            xlsx => {  # Border indices (not borders)
                # Refer to the following URL for the border indices:
                # https://metacpan.org/pod/Excel::Writer::XLSX#set_border()
                none    => 0,
                top     => 2,
                mid     => 2,
                bot     => 2,
                mid_bot => 2,  # For single-rowed data
            },
        },
    );
    # Override the attributes of %sets and %cols for given keys.
    # (CAUTION: Not the whole hashes!)
    $sets{$_} = $sets_href->{$_} for keys %$sets_href;
    $cols{$_} = $cols_href->{$_} for keys %$cols_href;

    #
    # Data format validation
    #
    @{$sets{rpt_formats}} = (keys %flags)
        if first { /all/i } @{$sets{rpt_formats}};  # 'all' format
    foreach my $rpt_format (@{$sets{rpt_formats}}) {
        next if (first { $rpt_format =~ $_ } values %flags);
        croak "[$sub_name]: [$rpt_format]".
              " is not a valid element of rpt_formats.\n".
              "Available formats are: ".
              join(", ", sort keys %flags)."\n";
    }

    #
    # Column size validation
    #
    croak "[$sub_name]: Column size must be provided via the size key."
        unless defined $cols{size};
    croak "[$sub_name]: Column size must be a positive integer."
        if $cols{size} <= 0 or $cols{size} =~ /[.]/;
    foreach (qw(heads subheads data_arr_ref)) {
        unless (@{$cols{$_}} % $cols{size} == 0) {
            croak
                "[$sub_name]\nColumn size [$_] is found to be".
                " [".@{$cols{$_}}."].\n".
                "It must be [$cols{size}] or its integer multiple!";
        }
    }

    #
    # Create some default key-val pairs.
    #
    # > Needless to say, a hash ref argument, if given, replaces
    #   an original hash ref. If some key-val pairs were assigned
    #   in the "Default attributes" section at the beginning of
    #   this routine but were not specified by the user arguments,
    #   those pairs would be lost:
    #   Original: space_bef => {dat => " ", tex => " "}
    #   User-arg: space_bef => {dat => " "}
    #   Defined:  space_bef => {dat => " "}
    #   The tex => " " pair would not be available hereafter.
    # > To avoid such loss, default key-val pairs are defined
    #   altogether below.
    # > This also allows the TeX separators, which must be
    #   the ampersand (&), immutable. That is, even if the following
    #   arguments are passed, the TeX separators will remain unchanged:
    #   User-arg: heads_sep => {dat => "|", csv => ";", tex => "|"}
    #             data_sep  => {dat => " ", csv => ";", tex => " "}
    #   Defined:  heads_sep => {dat => "|", csv => ";", tex => "&"}
    #             data_sep  => {dat => " ", csv => ";", tex => "&"}
    # > Finally, the headings separators for DAT and TeX are
    #   enclosed with the designated space characters.
    #   (i.e. space_bef and space_aft)
    # > CSV separators can be set via the user arguments,
    #   as its module defines such a method,
    #   but are not surrounded by any space characters.
    # > XLSX, as written in binaries, has nothing to do here.
    #

    # dat
    $cols{space_bef}{dat} = " " unless exists $cols{space_bef}{dat};
    $cols{heads_sep}{dat} = "|" unless exists $cols{heads_sep}{dat};
    $cols{space_aft}{dat} = " " unless exists $cols{space_aft}{dat};
    $cols{data_sep}{dat}  = " " unless exists $cols{data_sep}{dat};
    # TeX
    $cols{space_bef}{tex} = " " unless exists $cols{space_bef}{tex};
    $cols{heads_sep}{tex} = "&";  # Immutable
    $cols{space_aft}{tex} = " " unless exists $cols{space_aft}{tex};
    $cols{data_sep}{tex}  = "&";  # Immutable
    # DAT, TeX
    foreach (qw(dat tex)) {
        next if $cols{heads_sep}{$_} =~ /\t/; # Don't add spaces around a tab.
        $cols{heads_sep}{$_} =
            $cols{space_bef}{$_}.$cols{heads_sep}{$_}.$cols{space_aft}{$_};
    }
    # CSV
    $cols{heads_sep}{csv} = "," unless exists $cols{heads_sep}{csv};
    $cols{data_sep}{csv}  = "," unless exists $cols{data_sep}{csv};
    #+++++debugging+++++#
#    dump(\%cols);
#    pause_shell();
    #+++++++++++++++++++#

    #
    # Convert the data array into a "rowwise" columnar structure.
    #
    my $i = 0;
    for (my $j=0; $j<=$#{$cols{data_arr_ref}}; $j++) {
        push @{$cols{data_rowwise}[$i]}, $cols{data_arr_ref}[$j];
        #+++++debugging+++++#
#        say "At [\$i: $i] and [\$j: $j]: the modulus is: ",
#            ($j + 1) % $cols{size};
        #+++++++++++++++++++#
        $i++ if ($j + 1) % $cols{size} == 0;
    }

    #
    # Define row and column indices to be used for iteration controls.
    #
    $rows{idx_last}     = $#{$cols{data_rowwise}};
    $cols{idx_multiple} = $cols{size} - 1;

    # Obtain columnar data sums.
    if ($cols{sum_idx_multiples} and @{$cols{sum_idx_multiples}}) {
        for (my $i=0; $i<=$rows{idx_last}; $i++) {
            for (my $j=0; $j<=$cols{idx_multiple}; $j++) {
                    if (first { $j == $_ } @{$cols{sum_idx_multiples}}) {
                        $cols{data_sums}[$j] +=
                            $cols{data_rowwise}[$i][$j] // 0;
                }
            }
        }
    }
    #+++++debugging+++++#
#    dump(\%cols);
#    pause_shell();
    #+++++++++++++++++++#

    #
    # Notify the beginning of the routine.
    #
    say "\n#".('=' x 69);
    say "#"." [$sub_name] $sets{begin_msg}";
    say "#".('=' x 69);

    #
    # Multiplex outputting
    # IO::Tee intentionally not used for avoiding its additional installation
    #

    # Define filehandle refs and corresponding filenames.
    my($dat_fh, $tex_fh, $csv_fh, $xlsx_fh);
    my %rpt_formats = (
        dat  => {fh => $dat_fh,  fname => $sets{rpt_bname}.".dat" },
        tex  => {fh => $tex_fh,  fname => $sets{rpt_bname}.".tex" },
        csv  => {fh => $csv_fh,  fname => $sets{rpt_bname}.".csv" },
        xlsx => {fh => $xlsx_fh, fname => $sets{rpt_bname}.".xlsx"},
        json => {fh => $xlsx_fh, fname => $sets{rpt_bname}.".json"},
        yaml => {fh => $xlsx_fh, fname => $sets{rpt_bname}.".yaml"},
    );

    # Multiple invocations of the writing routine
    my $cwd = getcwd();
    mkdir $sets{rpt_path} if not -e $sets{rpt_path};
    chdir $sets{rpt_path};
    foreach (@{$sets{rpt_formats}}) {
        my $rpt_fh_mode = sprintf(">:encoding(%s)", $sets{out_encoding});
        open $rpt_formats{$_}{fh}, $rpt_fh_mode, $rpt_formats{$_}{fname};
        reduce_data_writing_part(
            $rpt_formats{$_}{fh},
            $_,  # Flag
            \%flags,
            \%sets,
            \%strs,
            \%cols,
            \%rows,
        );
        printf(
            "[%s%s%s] generated.\n",
            $sets{rpt_path},
            ($sets{rpt_path} =~ /\/$/ ? '' : '/'),
            $rpt_formats{$_}{fname},
        );
    }
    chdir $cwd;

    #
    # The writing routine (nested)
    #
    sub reduce_data_writing_part {
        my $_fh    = $_[0];
        my $_flag  = $_[1];
        my %_flags = %{$_[2]};
        my %_sets  = %{$_[3]};
        my %_strs  = %{$_[4]};
        my %_cols  = %{$_[5]};
        my %_rows  = %{$_[6]};

        #
        # [CSV][XLSX] Load modules and instantiate classes.
        #

        # [CSV]
        my $csv;
        if ($_flag =~ $_flags{csv}) {
            require Text::CSV;  # vendor lib || cpanm
            $csv = Text::CSV->new( { binary => 1 } )
                or die "Cannot instantiate Text::CSV! ".Text::CSV->error_diag();

            $csv->eol($_strs{newlines}{$_flag});
        }

        # [XLSX]
        my($workbook, $worksheet, %xlsx_formats);
        my($xlsx_row, $xlsx_col, $xlsx_col_init, $xlsx_col_scale_factor);
        $xlsx_row                  = 1;    # Starting row number
        $xlsx_col = $xlsx_col_init = 1;    # Starting col number
        $xlsx_col_scale_factor     = 1.2;  # Empirically determined
        if ($_flag =~ $_flags{xlsx}) {
            require Excel::Writer::XLSX;  # vendor lib || cpanm
            binmode($_fh);  # fh can now be R/W in binary as well as in text
            $workbook = Excel::Writer::XLSX->new($_fh);

            # Define the worksheet name using the bare filename of the report.
            # If the bare filename contains a character that is invalid
            # as an Excel worksheet name or lengthier than 32 characters,
            # the default worksheet name is used (i.e. Sheet1).
            eval {
                $worksheet = $workbook->add_worksheet(
                    (split /\/|\\/, $_sets{rpt_bname})[-1]
                )
            };
            $worksheet = $workbook->add_worksheet() if $@;

            # As of Excel::Writer::XLSX v0.98, a format property
            # can be added in the middle, but cannot be overridden.
            # The author of this routine therefore uses cellwise formats
            # to specify "ruled" and "aligned" cells.
            foreach my $rule (keys %{$_strs{rules}{$_flag}}) {
                foreach my $align (qw(none left right)) {
                    $xlsx_formats{$rule}{$align}= $workbook->add_format(
                        top    => $rule =~ /top|mid/i ?
                            $_strs{rules}{$_flag}{$rule} : 0,
                        bottom => $rule =~ /bot/i ?
                            $_strs{rules}{$_flag}{$rule} : 0,
                        align  => $align,
                    );
                }
            }
            #+++++debugging+++++#
#            dump(\%xlsx_formats);
#            pause_shell();
            #+++++++++++++++++++#

            # Panes freezing
            # Added on 2018-11-23
            if ($_cols{freeze_panes}) {
                $worksheet->freeze_panes(
                    ref $_cols{freeze_panes} eq HASH ?
                        ($_cols{freeze_panes}{row}, $_cols{freeze_panes}{col}) :
                        $_cols{freeze_panes}
                );
            }
        }

        #
        # Data construction
        #

        # [DAT] Prepend comment symbols to the first headings.
        if ($_flag =~ $_flags{dat}) {
            $_cols{heads}[0]    = $_strs{symbs}{$_flag}." ".$_cols{heads}[0];
            $_cols{subheads}[0] = $_strs{symbs}{$_flag}." ".$_cols{subheads}[0];
        }
        if ($_flag !~ $_flags{dat}) {  # Make it unaffected by the prev dat call
            $_cols{heads}[0]    =~ s/^[^\w] //;
            $_cols{subheads}[0] =~ s/^[^\w] //;
        }

        #
        # Define widths for columnar alignment.
        # (1) Take the lengthier one between headings and subheadings.
        # (2) Take the lengthier one between (1) and the data.
        # (3) Take the lengthier one between (2) and the data sum.
        #

        # (1)
        for (my $j=0; $j<=$#{$_cols{heads}}; $j++) {
            $_cols{widths}[$j] =
                length($_cols{heads}[$j]) > length($_cols{subheads}[$j]) ?
                length($_cols{heads}[$j]) : length($_cols{subheads}[$j]);
        }
        # (2)
        for (my $i=0; $i<=$_rows{idx_last}; $i++) {
            for (my $j=0; $j<=$#{$_cols{widths}}; $j++) {
                $_cols{widths}[$j] =
                    length($_cols{data_rowwise}[$i][$j] // $_strs{nan}{$_flag})
                    > $_cols{widths}[$j] ?
                    length($_cols{data_rowwise}[$i][$j] // $_strs{nan}{$_flag})
                    : $_cols{widths}[$j];
            }
        }
        # (3)
        if ($_cols{sum_idx_multiples} and @{$_cols{sum_idx_multiples}}) {
            foreach my $j (@{$_cols{sum_idx_multiples}}) {
                $_cols{widths}[$j] =
                    length($_cols{data_sums}[$j]) > $_cols{widths}[$j] ?
                    length($_cols{data_sums}[$j]) : $_cols{widths}[$j];
            }
        }

        #
        # [DAT] Border construction
        #
        if ($_flag =~ $_flags{dat}) {
            $_cols{border_widths}[0] = 0;
            $_cols{border_widths}[1] = 0;
            for (my $j=0; $j<=$#{$_cols{widths}}; $j++) {
                # Border width 1: Rules
                $_cols{border_widths}[0] += (
                    $_cols{widths}[$j] + length($_cols{heads_sep}{$_flag})
                );
                # Border width 2: Data sums label
                if (
                    $_cols{sum_idx_multiples}
                    and @{$_cols{sum_idx_multiples}}
                ) {
                    if ($j < $_cols{sum_idx_multiples}[0]) {
                        $_cols{border_widths}[1] += (
                                     $_cols{widths}[$j]
                            + length($_cols{heads_sep}{$_flag})
                        );
                    }
                }
            }
            $_cols{border_widths}[0] -=
                (
                      length($_strs{symbs}{$_flag})
                    + length($_cols{space_aft}{$_flag})
                );
            $_cols{border_widths}[1] -=
                (
                      length($_strs{symbs}{$_flag})
                    + length($_cols{space_aft}{$_flag})
                );
            $_strs{rules}{$_flag}{top} =
            $_strs{rules}{$_flag}{mid} =
            $_strs{rules}{$_flag}{bot} =
                $_strs{symbs}{$_flag}.('-' x $_cols{border_widths}[0]);
        }

        #
        # Begin writing.
        # [JSON][YAML]: Via their dumping commands.
        # [DAT][TeX]:   Via the output filehandle.
        # [CSV][XLSX]:  Via their output methods.
        #

        # [JSON][YAML][DAT][TeX] Change the output filehandle from STDOUT.
        select($_fh);

        #
        # [JSON][YAML] Load modules and dump the data.
        #

        # [JSON]
        if ($_flag =~ $_flags{json}) {
            use JSON;  # vendor lib || cpanm
            print to_json(\%_cols, { pretty => 1 });
        }

        # [YAML]
        if ($_flag =~ $_flags{yaml}) {
            use YAML;  # vendor lib || cpanm
            print Dump(\%_cols);
        }

        # [DAT][TeX] OPTIONAL blocks
        if ($_flag =~ /$_flags{dat}|$_flags{tex}/) {
            # Prepend the program information, if given.
            if ($_sets{prog_info}) {
                show_front_matter(
                    $_sets{prog_info},
                    'prog',
                    'auth',
                    'timestamp',
                    ($_strs{symbs}{$_flag} // $_strs{symbs}{dat}),
                );
            }

            # Prepend comments, if given.
            if ($_sets{cmt_arr}) {
                if (@{$_sets{cmt_arr}}) {
                    say $_strs{symbs}{$_flag}.$_ for @{$_sets{cmt_arr}};
                    print "\n";
                }
            }
        }

        # [TeX] Wrapping up - begin
        if ($_flag =~ $_flags{tex}) {
            # Document class
            say "\\documentclass{article}";

            # Package loading with kind notice
            say "%";
            say "% (1) The \...rule commands are defined by".
                " the booktabs package.";
            say "% (2) If an underscore character is included as text,";
            say "%     you may want to use the underscore package.";
            say "%";
            say "\\usepackage{booktabs,underscore}";

            # document env - begin
            print "\n";
            say "\\begin{document}";
            print "\n";

            # tabular env - begin
            print "\\begin{tabular}{";
            for (my $j=0; $j<=$#{$_cols{heads}}; $j++) {
                print(
                    (first { $j == $_ } @{$_cols{ragged_left_idx_multiples}}) ?
                        "r" : "l"
                );
            }
            print "}\n";
        }

        # [DAT][TeX] Top rule
        print $_strs{indents}{$_flag}, $_strs{rules}{$_flag}{top}, "\n"
            if $_flag =~ /$_flags{dat}|$_flags{tex}/;

        #
        # Headings and subheadings
        #

        # [DAT][TeX]
        for (my $j=0; $j<=$#{$_cols{heads}}; $j++) {
            if ($_flag =~ /$_flags{dat}|$_flags{tex}/) {
                print $_strs{indents}{$_flag} if $j == 0;
                $_cols{conv} = '%-'.$_cols{widths}[$j].'s';
                if ($_cols{heads_sep}{$_flag} !~ /\t/) {
                    printf(
                        "$_cols{conv}%s",
                        $_cols{heads}[$j],
                        $j == $#{$_cols{heads}} ? '' : $_cols{heads_sep}{$_flag}
                    );
                }
                elsif ($_cols{heads_sep}{$_flag} =~ /\t/) {
                    printf(
                        "%s%s",
                        $_cols{heads}[$j],
                        $j == $#{$_cols{heads}} ? '' : $_cols{heads_sep}{$_flag}
                    );
                }
                print $_strs{newlines}{$_flag} if $j == $#{$_cols{heads}};
            }
        }
        for (my $j=0; $j<=$#{$_cols{subheads}}; $j++) {
            if ($_flag =~ /$_flags{dat}|$_flags{tex}/) {
                print $_strs{indents}{$_flag} if $j == 0;
                $_cols{conv} = '%-'.$_cols{widths}[$j].'s';
                if ($_cols{heads_sep}{$_flag} !~ /\t/) {
                    printf(
                        "$_cols{conv}%s",
                        $_cols{subheads}[$j],
                        $j == $#{$_cols{subheads}} ?
                            '' : $_cols{heads_sep}{$_flag}
                    );
                }
                elsif ($_cols{heads_sep}{$_flag} =~ /\t/) {
                    printf(
                        "%s%s",
                        $_cols{subheads}[$j],
                        $j == $#{$_cols{subheads}} ?
                            '' : $_cols{heads_sep}{$_flag}
                    );
                }
                print $_strs{newlines}{$_flag} if $j == $#{$_cols{subheads}};
            }
        }

        # [CSV][XLSX]
        if ($_flag =~ $_flags{csv}) {
            $csv->sep_char($_cols{heads_sep}{$_flag});
            $csv->print($_fh, $_cols{heads});
            $csv->print($_fh, $_cols{subheads});
        }
        if ($_flag =~ $_flags{xlsx}) {
            $worksheet->write_row(
                $xlsx_row++,
                $xlsx_col,
                $_cols{heads},
                $xlsx_formats{top}{none}  # top rule formatted
            );
            $worksheet->write_row(
                $xlsx_row++,
                $xlsx_col,
                $_cols{subheads},
                $xlsx_formats{none}{none}
            );
        }

        # [DAT][TeX] Middle rule
        print $_strs{indents}{$_flag}, $_strs{rules}{$_flag}{mid}, "\n"
            if $_flag =~ /$_flags{dat}|$_flags{tex}/;

        #
        # Data
        #
        # > [XLSX] is now handled together with [DAT][TeX]
        #   to allow columnwise alignment. That is, the write() method
        #   is used instead of the write_row() one.
        # > Although MS Excel by default aligns numbers ragged left,
        #   the author wanted to provide this routine with more flexibility.
        # > According to the Excel::Writer::XLSX manual,
        #   AutoFit can only be performed from within Excel.
        #   By the use of write(), however, pseudo-AutoFit is also realized:
        #   The author has created this routine initially for gnuplot-plottable
        #   text file and TeX tabular data, and for them he added an automatic
        #   conversion creation functionality. Utilizing the conversion width,
        #   approximate AutoFit can be performed.
        #   To see how it works, look up:
        #     - 'Define widths for columnar alignment.' and the resulting
        #       values of $_cols{widths}
        #     - $xlsx_col_scale_factor
        #
        for (my $i=0; $i<=$_rows{idx_last}; $i++) {
            # [CSV]
            if ($_flag =~ $_flags{csv}) {
                $csv->sep_char($_cols{data_sep}{$_flag});
                $csv->print(
                    $_fh,
                    $_cols{data_rowwise}[$i] // $_strs{nan}{$_flag}
                );
            }
            # [DAT] Dataset separator
            # > Optional
            # > If designated, gnuplot dataset separator, namely a pair of
            #   blank lines, is inserted before beginning the next dataset.
            if (
                $_flag =~ $_flags{dat} and
                $_sets{num_rows_per_dataset} and  # Make this loop optional.
                $i != 0 and                       # Skip the first row.
                $i % $_sets{num_rows_per_dataset} == 0
            ) {
                print $_strs{dataset_seps}{$_flag};
            }
            # [DAT][TeX][XLSX]
            $xlsx_col = $xlsx_col_init;
            for (my $j=0; $j<=$_cols{idx_multiple}; $j++) {
                # [DAT][TeX]
                if ($_flag =~ /$_flags{dat}|$_flags{tex}/) {
                    # Conversion (i): "Ragged right"
                    # > Default
                    # > length($_cols{space_bef}{$_flag})
                    #   is "included" in the conversion.
                    $_cols{conv} =
                        '%-'.
                        (
                                     $_cols{widths}[$j]
                            + length($_cols{space_bef}{$_flag})
                        ).
                        's';

                    # Conversion (ii): "Ragged left"
                    # > length($_cols{space_bef}{$_flag})
                    #   is "appended" to the conversion.
                    if (first { $j == $_ } @{$_cols{ragged_left_idx_multiples}})
                    {
                        $_cols{conv} =
                            '%'.
                            $_cols{widths}[$j].
                            's'.
                            (
                                $j == $_cols{idx_multiple} ?
                                    '' : ' ' x length($_cols{space_bef}{$_flag})
                            );
                    }

                    # Columns
                    print $_strs{indents}{$_flag} if $j == 0;
                    if ($_cols{data_sep}{$_flag} !~ /\t/) {
                        printf(
                            "%s$_cols{conv}%s",
                            ($j == 0 ? '' : $_cols{space_aft}{$_flag}),
                            $_cols{data_rowwise}[$i][$j] // $_strs{nan}{$_flag},
                            (
                                $j == $_cols{idx_multiple} ?
                                    '' : $_cols{data_sep}{$_flag}
                            )
                        );
                    }
                    elsif ($_cols{data_sep}{$_flag} =~ /\t/) {
                        printf(
                            "%s%s",
                            $_cols{data_rowwise}[$i][$j] // $_strs{nan}{$_flag},
                            (
                                $j == $_cols{idx_multiple} ?
                                    '' : $_cols{data_sep}{$_flag}
                            )
                        );
                    }
                    print $_strs{newlines}{$_flag}
                        if $j == $_cols{idx_multiple};
                }
                # [XLSX]
                if ($_flag =~ $_flags{xlsx}) {
                    # Pseudo-AutoFit
                    $worksheet->set_column(
                        $xlsx_col,
                        $xlsx_col,
                        $_cols{widths}[$j] * $xlsx_col_scale_factor
                    );

                    my $_align = (
                        first { $j == $_ } @{$_cols{ragged_left_idx_multiples}}
                    ) ? 'right' : 'left';
                    $worksheet->write(
                        $xlsx_row,
                        $xlsx_col,
                        $_cols{data_rowwise}[$i][$j] // $_strs{nan}{$_flag},
                        ($i == 0 and $i == $_rows{idx_last}) ?
                            $xlsx_formats{mid_bot}{$_align} :  # For single-rowed
                        $i == 0 ?
                            $xlsx_formats{mid}{$_align} :  # mid rule formatted
                        $i == $_rows{idx_last} ?
                            $xlsx_formats{bot}{$_align} :  # bot rule formatted
                            $xlsx_formats{none}{$_align}   # Default: no rule
                    );
                    $xlsx_col++;
                    $xlsx_row++ if $j == $_cols{idx_multiple};
                }
            }
        }

        # [DAT][TeX] Bottom rule
        print $_strs{indents}{$_flag}, $_strs{rules}{$_flag}{bot}, "\n"
            if $_flag =~ /$_flags{dat}|$_flags{tex}/;

        #
        # Append the data sums.
        #
        if ($_cols{sum_idx_multiples} and @{$_cols{sum_idx_multiples}}) {
            #
            # [DAT] Columns "up to" the beginning of the data sums
            #
            if ($_flag =~ $_flags{dat}) {
                my $sum_lab         = "Sum: ";
                my $sum_lab_aligned = sprintf(
                    "%s%s%s%s",
                    $_strs{indents}{$_flag},
                    $_strs{symbs}{$_flag},
                    ' ' x ($_cols{border_widths}[1] - length($sum_lab)),
                    $sum_lab
                );
                print $sum_lab_aligned;
            }

            #
            # Columns "for" the data sums
            #

            # [DAT][TeX][XLSX]
            my $the_beginning = $_flag !~ $_flags{dat} ?
                0 : $_cols{sum_idx_multiples}[0];
            $xlsx_col = $xlsx_col_init;
            for (my $j=$the_beginning; $j<=$_cols{sum_idx_multiples}[-1]; $j++)
            {
                # [DAT][TeX]
                if ($_flag =~ /$_flags{dat}|$_flags{tex}/) {
                    # Conversion (i): "Ragged right"
                    # > Default
                    # > length($_cols{space_bef}{$_flag})
                    #   is "included" in the conversion.
                    $_cols{conv} =
                        '%-'.
                        (
                                     $_cols{widths}[$j]
                            + length($_cols{space_bef}{$_flag})
                        ).
                        's';

                    # Conversion (ii): "Ragged left"
                    # > length($_cols{space_bef}{$_flag})
                    #   is "appended" to the conversion.
                    if (first { $j == $_ } @{$_cols{ragged_left_idx_multiples}})
                    {
                        $_cols{conv} =
                            '%'.
                            $_cols{widths}[$j].
                            's'.
                            (
                                $j == $_cols{idx_multiple} ?
                                    '' : ' ' x length($_cols{space_bef}{$_flag})
                            );
                    }

                    # Columns
                    print $_strs{indents}{$_flag} if $j == 0;
                    if ($_cols{data_sep}{$_flag} !~ /\t/) {
                        printf(
                            "%s$_cols{conv}%s",
                            ($j == 0 ? '' : $_cols{space_bef}{$_flag}),
                            $_cols{data_sums}[$j] // $_strs{nan}{$_flag},
                            (
                                $j == $_cols{sum_idx_multiples}[-1] ?
                                    '' : $_cols{data_sep}{$_flag}
                            )
                        );
                    }
                    elsif ($_cols{data_sep}{$_flag} =~ /\t/) {
                        printf(
                            "%s%s",
                            $_cols{data_sums}[$j] // $_strs{nan}{$_flag},
                            (
                                $j == $_cols{sum_idx_multiples}[-1] ?
                                    '' : $_cols{data_sep}{$_flag}
                            )
                        );
                    }
                    print $_strs{newlines}{$_flag}
                        if $j == $_cols{sum_idx_multiples}[-1];
                }
                # [XLSX]
                if ($_flag =~ $_flags{xlsx}) {
                    my $_align = (
                        first { $j == $_ } @{$_cols{ragged_left_idx_multiples}}
                    ) ? 'right' : 'left';

                    $worksheet->write(
                        $xlsx_row,
                        $xlsx_col,
                        $_cols{data_sums}[$j] // $_strs{nan}{$_flag},
                        $xlsx_formats{none}{$_align}
                    );

                    $xlsx_col++;
                    $xlsx_row++ if $j == $_cols{sum_idx_multiples}[-1];
                }
            }

            # [CSV]
            if ($_flag =~ $_flags{csv}) {
                $csv->print(
                    $_fh,
                    $_cols{data_sums} // $_strs{nan}{$_flag}
                );
            }
        }

        # [TeX] Wrapping up - end
        if ($_flag =~ $_flags{tex}) {
            # tabular env - end
            say '\\end{tabular}';

            # document env - end
            print "\n";
            say "\\end{document}";
        }

        # [DAT][TeX] EOF
        print $_strs{eofs}{$_flag} if $_flag =~ /$_flags{dat}|$_flags{tex}/;

        # [JSON][YAML][DAT][TeX] Restore the output filehandle to STDOUT.
        select(STDOUT);

        # Close the filehandle.
        # the XLSX filehandle must be closed via its close method!
        close $_fh         if $_flag !~ $_flags{xlsx};
        $workbook->close() if $_flag =~ $_flags{xlsx};
    }

    return;
}


sub show_elapsed_real_time {
    # """Show the elapsed real time."""

    my @opts = @_ if @_;

    # Parse optional arguments.
    my $is_return_copy = 0;
    my @del;  # Garbage can
    foreach (@opts) {
        if (/copy/i) {
            $is_return_copy = 1;
            # Discard the 'copy' string to exclude it from
            # the optional strings that are to be printed.
            push @del, $_;
        }
    }
    my %dels = map { $_ => 1 } @del;
    @opts = grep !$dels{$_}, @opts;

    # Optional strings printing
    print for @opts;

    # Elapsed real time printing
    my $elapsed_real_time = sprintf("Elapsed real time: [%s s]", time - $^T);

    # Return values
    if ($is_return_copy) {
        return $elapsed_real_time;
    }
    else {
        say $elapsed_real_time;
        return;
    }
}


sub pause_shell {
    # """Pause the shell."""

    my $notif = $_[0] ? $_[0] : "Press enter to exit...";

    print $notif;
    while (<STDIN>) { last; }

    return;
}


sub construct_timestamps {
    # """Construct timestamps."""

    # Optional setting for the date component separator
    my $date_sep  = '';

    # Terminate the program if the argument passed
    # is not allowed to be a delimiter.
    my @delims = ('-', '_');
    if ($_[0]) {
        $date_sep = $_[0];
        my $is_correct_delim = grep $date_sep eq $_, @delims;
        croak "The date delimiter must be one of: [".join(', ', @delims)."]"
            unless $is_correct_delim;
    }

    # Construct and return a datetime hash.
    my $dt  = DateTime->now(time_zone => 'local');
    my $ymd = $dt->ymd($date_sep);
    my $hms = $dt->hms($date_sep ? ':' : '');
    (my $hm = $hms) =~ s/[0-9]{2}$//;

    my %datetimes = (
        none   => '',  # Used for timestamp suppressing
        ymd    => $ymd,
        hms    => $hms,
        hm     => $hm,
        ymdhms => sprintf("%s%s%s", $ymd, ($date_sep ? ' ' : '_'), $hms),
        ymdhm  => sprintf("%s%s%s", $ymd, ($date_sep ? ' ' : '_'), $hm),
    );

    return %datetimes;
}


sub rm_duplicates {
    # """Remove duplicate items from an array."""

    my $aref = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be an array ref!"
        unless ref $aref eq ARRAY;

    my(%seen, @uniqued);
    @uniqued = grep !$seen{$_}++, @$aref;
    @$aref = @uniqued;

    return;
}
#-------------------------------------------------------------------------------


sub parse_argv {
    # """@ARGV parser"""

    my(
        $argv_aref,
        $cmd_opts_href,
        $run_opts_href,
    ) = @_;
    my %cmd_opts = %$cmd_opts_href;  # For regexes

    # Parser: Overwrite default run options if requested by the user.
    my $field_sep = ',';
    foreach (@$argv_aref) {
        # Input .jac/.jca files
        if (/[.]j[ac]/i) {
            push @{$run_opts_href->{jac_files}}, $_;
        }

        # Read in all .jac/.jca files in the current working directory.
        if (/$cmd_opts{jac_all}/) {
            push @{$run_opts_href->{jac_files}}, glob '*.jac *.jca';
        }

        # The encoding of input .jac/.jca files
        if (/$cmd_opts{inp_encoding}/i) {
            s/$cmd_opts{inp_encoding}//i;
            $run_opts_href->{inp_encoding} = $_;
        }

        # A file containing conversion functions of a detector
        if (/$cmd_opts{det}/i) {
            s/$cmd_opts{det}//i;
            $run_opts_href->{det} = $_ if -e;
            if (not -e) {
                print "Detector file [$_] NOT found in the CWD.";
                print " Default conversion functions will be used.\n\n";
            }
        }

        # The encoding of output converted files
        if (/$cmd_opts{out_encoding}/i) {
            s/$cmd_opts{out_encoding}//i;
            $run_opts_href->{out_encoding} = $_;
        }

        # Output formats
        if (/$cmd_opts{out_fmts}/i) {
            s/$cmd_opts{out_fmts}//i;
            @{$run_opts_href->{out_fmts}} = split /$field_sep/;
        }

        # Output path
        if (/$cmd_opts{out_path}/i) {
            s/$cmd_opts{out_path}//i;
            $run_opts_href->{out_path} = $_;
        }

        # Prepending flag
        if (/$cmd_opts{out_prepend}/i) {
            s/$cmd_opts{out_prepend}//i;
            $run_opts_href->{out_prepend} = $_;
        }

        # Appending flag
        if (/$cmd_opts{out_append}/i) {
            s/$cmd_opts{out_append}//i;
            $run_opts_href->{out_append} = $_;
        }

        # The program will run without prompting a y/n selection message.
        if (/$cmd_opts{noyn}/) {
            $run_opts_href->{is_noyn} = 1;
        }

        # The front matter won't be displayed at the beginning of the program.
        if (/$cmd_opts{nofm}/) {
            $run_opts_href->{is_nofm} = 1;
        }

        # The shell won't be paused at the end of the program.
        if (/$cmd_opts{nopause}/) {
            $run_opts_href->{is_nopause} = 1;
        }
    }
    rm_duplicates($run_opts_href->{jac_files});

    return;
}


sub read_in_det {
    # """Read in the conversion functions of a detector."""

    my(
        $run_opts_href,
        $det_href,
    ) = @_;
    my $det     = $run_opts_href->{det};
    my $det_sep = $run_opts_href->{det_sep};

    open my $det_fh, '<', $det;
    foreach (<$det_fh>) {
        chomp;
        next if /^\s*#/;
        next if /^$/;
        next if not /$det_sep/;

        my($k, $v) = (split /\s*$det_sep\s*/)[0, 1];
        $v =~ s/\s*#.*//;  # Suppress an inline comment.

        # Nonfitted efficiency
        if ($k =~ /eff\([0-9.]+\)/i) {
            (my $manual_nrg = $k) =~ s/
                eff\(
                (?<manual_nrg>[0-9.]+)
                \)
            /$+{manual_nrg}/ix;
            $det_href->{nonfitted_effs}{$manual_nrg} = $v;
        }

        # All else
        else { $det_href->{$k} = $v }
    }
    close $det_fh;
    print "[$det] read in.\n\n";

    return;
}


sub calc_nrg_fwhm_eff_using {
    # """Calculate the energy, FWHM, and peak efficiency using channels."""

    my($ch, $det_href) = @_;

    # (1) Energy: f($ch)
    my $nrg = eval($det_href->{nrg});

    # (2) FWHM: f($nrg)
    my $fwhm = eval($det_href->{fwhm});

    # (3) Peak efficiency: f($nrg)
    my $eff;

    # (3-1) Nonfitted
    state $seen_href = {};
    my $close_nrg = 0;
    if ($det_href->{eff_expr} =~ /nonfit(?:ted)?/i) {
        foreach my $manual_nrg (keys %{$det_href->{nonfitted_effs}}) {
            $close_nrg = $manual_nrg if abs($nrg - $manual_nrg) < 0.3;
        }
        if ($close_nrg and not $seen_href->{$close_nrg}) {
            $eff = eval($det_href->{nonfitted_effs}{$close_nrg});
            $seen_href->{$close_nrg}++;
        }
        else { $eff = 'NaN' }
    }

    # (3-2) Fitted
    elsif ($det_href->{eff_expr} =~ /\bfit(?:ted)?/i) {
        $eff = $nrg < $det_href->{knee} ?
            eval($det_href->{eff_bef_knee}) :
            eval($det_href->{eff_from_knee});
    }

    return {
        nrg_formula           => $det_href->{nrg},
        nrg                   => $nrg,
        fwhm_formula          => $det_href->{fwhm},
        fwhm                  => $fwhm,
        eff_bef_knee_formula  => $det_href->{eff_bef_knee},
        eff_from_knee_formula => $det_href->{eff_from_knee},
        eff                   => $eff,
    };
}


sub conv_jac_to_dat {
    # """ Convert .jac/.jca files to various output formats. """

    my(
        $prog_info_href,
        $run_opts_href,
    ) = @_;

    #---------------------------------------------------------------------------
    # Detector data
    # > Channel must be expressed as $ch in a string, which will be 'eval'ed
    #   in calc_nrg_fwhm_eff_using() ($ch is declared in that routine).
    # > Likewise, express energy as $nrg.
    #---------------------------------------------------------------------------
    my %det = (
        id    => 'det01',
        model => 'GEM (manufacturer: ORTEC, distributor: Seiko EG&G)',
        # ene_u8.pdf
        nrg_calib_date  => '2018-04-19 14:19:21',
        nrg             => '6.942824E-001 + 4.994878E-001*$ch'.
                           ' + 6.919887E-008*$ch**2',
        fwhm            => '2.076851E+000 + 8.814739E-003*sqrt($nrg)'.
                           ' + 1.204853E-003*$nrg',
        # eff_u8.pdf
        eff_calib_date  => '2018-04-19 14:22:21',
        eff_expr        => 'fitted',  # fitted, nonfitted
        nonfitted_effs  => {},
        knee            => 180,  # keV
        eff_bef_knee    => 'exp(-3.824022E+001 + 1.427534E+001*log($nrg)'.
                           ' - 1.452642E+000*log($nrg)**2)',
        eff_from_knee   => 'exp(1.470955E+000 - 1.018902E+000*log($nrg)'.
                           ' + 1.995309E-002*log($nrg)**2)',
    );
    read_in_det($run_opts_href, \%det) if -e $run_opts_href->{det};

    print "Calibration conditions";
    printf(
        " (%s)",
        -e $run_opts_href->{det} ? $run_opts_href->{det} : 'default'
    );
    say ":";
    say "-" x 70;
    foreach (sort keys %det) {
        printf(
            '%-'.length(maxstr keys %det).'s'." => %s\n",
            $_,
            $det{$_},
        );
    }
    say "-" x 70;
    say "";

    # Notification
    if (not $run_opts_href->{jac_files}[0]) {
        print "No .jac/.jca file found.\n\n";
        return;
    }
    printf(
        "The following JAC file%s will be converted to [%s%s]:\n",
        $run_opts_href->{jac_files}[1] ? 's' : '',
        $run_opts_href->{out_path},
        $run_opts_href->{out_path} =~ /\/$/ ? '' : '/',
    );
    say "-" x 70;
    say "[$_]" for @{$run_opts_href->{jac_files}};
    say "-" x 70;

    # yn prompt
    unless ($run_opts_href->{is_noyn}) {
        my $yn_msg = "Run? (y/n)> ";
        print $yn_msg;
        while (chomp(my $yn = <STDIN>)) {
            last   if $yn =~ /\by\b/i;
            return if $yn =~ /\bn\b/i;
            print $yn_msg;
        }
    }

    # Work on the JAC files.
    my %fmt_specifiers = (
        nrg   => '%.7f',  # Energy
        fwhm  => '%.7f',
        eff   => '%.10f',
        cps   => '%.5f',  # Count per second
        gamma => '%.5f',
        gps   => '%.5f',  # Gamma per second
    );
    foreach my $jac (@{$run_opts_href->{jac_files}}) {
        my(@counts, @gammas);

        # Read in the content of a .jac/.jca file.
        # Use chomp() to remove newlines before storing the lines
        # to the counts array.
        my $jac_fh_mode = sprintf(
            "<:encoding(%s)",
            $run_opts_href->{inp_encoding},
        );
        open my $jac_fh, $jac_fh_mode, $jac;
        push @counts, chomp() for <$jac_fh>;
        close $jac_fh;

        # Inspect the number of records in the .jac/.jca file and warn
        # if it is not an integer multiple of 4096.
        my $counts_size = @counts;
        print(
            "!!! Warning !!!\n".
            "The number of records in [$jac], [$counts_size],".
            " is not an integer multiple of 4096."
        ) if $counts_size != 0 and $counts_size % 4096 != 0;

        # Construct columnar data.
        my($ch, %ret, %times, $cmt_in_jac);
        my $arr_ref_to_data = [];
        for (my $ch_idx=0; $ch_idx<=$#counts; $ch_idx++) {
            #
            # The first four records contain data other than gamma-ray counts,
            # the first three of which are time information and the last of
            # which is a comment embedded in the .jac/jca file.
            # If there was no comment in the corresponding binary file of
            # a .jac/jca file, the fourth record will be empty, but not undef.
            # Retrieve the four non-count records which will be mirrored in
            # the converted files, and assign zero to their indices to avoid
            # errors in calc_nrg_fwhm_eff_using().
            # e.g.
            # [0] 1200
            # [1] 1206
            # [2] 2019-01-17 09:21:52
            # [3] some_comment
            #
            if ($ch_idx =~ /\b[0-3]\b/) {
                $times{live_time} = $counts[$ch_idx] if $ch_idx == 0;
                $times{real_time} = $counts[$ch_idx] if $ch_idx == 1;
                $times{acqu_time} = $counts[$ch_idx] if $ch_idx == 2;
                $cmt_in_jac = $counts[$ch_idx] if $ch_idx == 3;
                $counts[$ch_idx] = 0;
#                say "\$counts[$ch_idx]: $counts[$ch_idx]"; # For debugging
            }

            #
            # Data construction
            #
            $ch = $ch_idx + 1;
            (
                $ret{nrg_formula},
                $ret{nrg},
                $ret{fwhm_formula},
                $ret{fwhm},
                $ret{eff_bef_knee_formula},
                $ret{eff_from_knee_formula},
                $ret{eff},
            ) = @{calc_nrg_fwhm_eff_using($ch, \%det)}{
                qw/
                    nrg_formula
                    nrg
                    fwhm_formula
                    fwhm
                    eff_bef_knee_formula
                    eff_from_knee_formula
                    eff
                /
            };

            # gamma = cnt / (cnt gamma^{-1})
            $gammas[$ch_idx] = eval { $counts[$ch_idx] / $ret{eff} } // 'NaN';
            print "\$counts[\$ch_idx] indivisible by \$ret{eff}: $@" if $@;

            # The base of the Perl log command is the number e.
            # To avoid confusion, substitute log for ln used as comments,
            # but not for calculation.
            $ret{$_} =~ s/log/ln/gi for keys %ret;

            #
            # Data assignment
            #
            push @$arr_ref_to_data, (
                $ch, # ch
                sprintf("$fmt_specifiers{nrg}", $ret{nrg}),    # f(ch)
                sprintf("$fmt_specifiers{fwhm}", $ret{fwhm}),  # f(nrg)
                sprintf("$fmt_specifiers{eff}", $ret{eff}),    # f(nrg)
                $counts[$ch_idx],
                sprintf(
                    "$fmt_specifiers{cps}",
                    $counts[$ch_idx] / $times{live_time}
                ),
                sprintf(
                    "$fmt_specifiers{gamma}",
                    $gammas[$ch_idx],
                ),
                sprintf(
                    "$fmt_specifiers{gps}",
                    $gammas[$ch_idx] / $times{live_time},
                ),
            );
        }

        # Write to output files.
        my $rpt_bname = basename($jac);
        $rpt_bname =~ s/[.][\w]+$//;  # An extensionless filename
        $rpt_bname = sprintf(
            "%s%s%s",
            $run_opts_href->{out_prepend},
            $rpt_bname,
            $run_opts_href->{out_append},
        );
        my %convs = (
            cmt1  => '%-15s',
            cmt2a => '%-14s',
            cmt2b => '%-6s',
            cmt2c => '%-27s',
            cmt3  => '%-21s',
        );
        my @eff_comment;
        if ($det{eff_expr} =~ /nonfit(?:ted)?/i) {
            my @ascending = sort { $a <=> $b } keys %{$det{nonfitted_effs}};
            foreach my $manual_nrg (@ascending) {
                push @eff_comment, sprintf(
                    " $convs{cmt2b} = %s",
                    $manual_nrg,
                    $det{nonfitted_effs}{$manual_nrg},
                );
            }
        }
        elsif ($det{eff_expr} =~ /\bfit(?:ted)?/i) {
            push @eff_comment,
                sprintf(
                    " det_eff_knee: %s keV",
                    $det{knee},
                ),
                sprintf(
                    " $convs{cmt2c} = %s",
                    'det_eff_bef_knee (cnt/gam)',
                    $ret{eff_bef_knee_formula},
                ),
                sprintf(
                    " $convs{cmt2c} = %s",
                    'det_eff_from_knee (cnt/gam)',
                    $ret{eff_from_knee_formula},
                );
        }
        reduce_data(
            {  # Settings
                out_encoding => $run_opts_href->{out_encoding},
                rpt_formats  => $run_opts_href->{out_fmts},
                rpt_path     => $run_opts_href->{out_path},
                rpt_bname    => $rpt_bname,
                begin_msg    => "collecting spectrometry results...",
                prog_info    => $prog_info_href,
                cmt_arr      => [
                    #
                    # Comment 1: Gamma-ray detector information
                    #
                    "-" x 69,
                    " Gamma-ray detector",
                    "-" x 69,
                    sprintf(
                        " $convs{cmt1} %s",
                        'Detector ID:',
                        $det{id},
                    ),
                    sprintf(
                        " $convs{cmt1} %s",
                        'Detector model:',
                        $det{model},
                    ),
                    "-" x 69,
                    #
                    # Comment 2: Conversion functions
                    #
                    "-" x 69,
                    " Calibration functions",
                    "-" x 69,
                    sprintf(
                        " Energy calibration date: %s",
                        $det{nrg_calib_date},
                    ),
                    sprintf(
                        " $convs{cmt2a} = %s",
                        'Energy (keV)',
                        $ret{nrg_formula},
                    ),
                    sprintf(
                        " $convs{cmt2a} = %s",
                        'Peak FWHM (ch)',
                        $ret{fwhm_formula},
                    ),
                    '',
                    sprintf(
                        " Efficiency calibration date: %s",
                        $det{eff_calib_date},
                    ),
                    sprintf(
                        " Efficiency expression: %s",
                        $det{eff_expr},
                    ),
                    @eff_comment,
                    "-" x 69,
                    #
                    # Comment 3: Time information
                    #
                    "-" x 69,
                    " Time information",
                    "-" x 69,
                    sprintf(
                        " $convs{cmt3} %s s",
                        'Live time (duration):',
                        $times{live_time},
                    ),
                    sprintf(
                        " $convs{cmt3} %s s",
                        'Real time (duration):',
                        $times{real_time},
                    ),
                    sprintf(
                        " $convs{cmt3} %s",
                        'Acquired time:',
                        $times{acqu_time},
                    ),
                    "-" x 69,
                    #
                    # Comment 4: A comment, if any, in the .jac/.jca file
                    #
                    "-" x 69,
                    " Comment embedded in .jac/.jca",
                    "-" x 69,
                    " $cmt_in_jac",
                    "-" x 69,
                ],
            },
            {  # Columnar
                size => 8,  # Used for column size validation
                heads => [
                    "Channel",
                    "Gamma energy",     # f(ch)
                    "Peak FWHM",        # f(nrg)
                    "Peak efficiency",  # f(nrg)
                    "Count",
                    "Count per second or \"cps\"",
                    "Gamma",
                    "Gamma per second or \"gps\"",
                ],
                subheads => [
                    "(ch)",
                    "(keV)",
                    "(ch)",
                    "(cnt gam^{-1})",
                    "(cnt)",
                    "(cnt sec^{-1})",
                    "(gam)",
                    "(gam sec^{-1})",
                ],
                data_arr_ref => $arr_ref_to_data,
                ragged_left_idx_multiples => [1..7],
                freeze_panes => 'C4', # Alt: {row => 3, col => 2}
                space_bef    => {dat => " ", tex => " "},
                heads_sep    => {dat => "|", csv => ","},
                space_aft    => {dat => " ", tex => " "},
                data_sep     => {dat => " ", csv => ","},
            }
        );
    }

    return;
}


sub jac2dat {
    # """jac2dat main routine"""

    if (@ARGV) {
        my %prog_info = (
            titl       => basename($0, '.pl'),
            expl       => "Convert .jac/.jca files to various data formats",
            vers       => $VERSION,
            date_last  => $LAST,
            date_first => $FIRST,
            auth       => {
                name => 'Jaewoong Jang',
#                posi => '',
#                affi => '',
                mail => 'jangj@korea.ac.kr',
            },
        );
        my %cmd_opts = (  # Command-line opts
            jac_all      => qr/-?-a(?:ll)?/i,
            inp_encoding => qr/-?-inp_encoding\s*=\s*/i,
            det          => qr/-?-det(?:ector)?\s*=\s*/i,
            # dat_: For backward compatibility
            out_encoding => qr/-?-(dat|out)_encoding\s*=\s*/i,
            out_fmts     => qr/-?-(?:dat_|out_)?fmts?\s*=\s*/i,
            out_path     => qr/-?-(?:dat_|out_)?path\s*=\s*/i,
            out_prepend  => qr/-?-(?:dat_|out_)?prep(?:end)?\s*=\s*/i,
            out_append   => qr/-?-(?:dat_|out_)?app(?:end)?\s*=\s*/i,
            noyn         => qr/-?-noyn/,
            nofm         => qr/-?-nofm/,
            nopause      => qr/-?-nopause/i,
        );
        my %run_opts = (  # Program run opts
            jac_files    => [],
            inp_encoding => 'UTF-8',
            det          => '',
            det_sep      => '=',
            out_encoding => 'UTF-8',
            out_fmts     => ['dat'],
            out_path     => '.',
            out_prepend  => '',
            out_append   => '',
            is_noyn      => 0,
            is_nofm      => 0,
            is_nopause   => 0,
        );

        # ARGV validation and parsing
        validate_argv(\@ARGV, \%cmd_opts);
        parse_argv(\@ARGV, \%cmd_opts, \%run_opts);

        # Notification - beginning
        show_front_matter(\%prog_info, 'prog', 'auth')
            unless $run_opts{is_nofm};

        # Main
        conv_jac_to_dat(\%prog_info, \%run_opts);

        # Notification - end
        show_elapsed_real_time();
        pause_shell()
            unless $run_opts{is_nopause};
    }

    system("perldoc \"$0\"") if not @ARGV;

    return;
}


jac2dat();
__END__

=head1 NAME

jac2dat - Convert .jac/.jca files to various data formats

=head1 SYNOPSIS

    perl jac2dat.pl [jac_files ...] [--all] [--inp_encoding]
                    [--det=det_file] [--out_encoding]
                    [--out_fmts=ext ...] [--out_path=path]
                    [--out_prepend=flag] [--out_append=flag]
                    [--noyn] [--nofm] [--nopause]

=head1 DESCRIPTION

    jac2dat converts .jac/.jca files to various data formats.
    - JAC file: The gamma spectra format of MEXT (previously the Science and
                Technology Agency), Japan. For details, refer to the catalogue
                of DS-P1001 Gamma Station, SII.
                A .jac/.jca file consists of only one column, in which
                gamma counts are stored in ascending order of channels.
                The first four records are "not" gamma counts, and
                are used for special purposes:
                - Record 1: Live time (duration)
                - Record 2: Real time (duration)
                - Record 3: Acquired time
                - Record 4: Comment
    - DAT file: A plain text file converted from a .jac/.jca file.
                A .dat file consists of multiple columns, in which
                channels, gamma energies, peak FWHMs, peak efficiencies,
                counts, count per second (cps), gammas, and
                gamma per second (gps) are stored.
    - Other supported data formats include tex, csv, xlsx, json, and yaml.

=head1 OPTIONS

    jac_files ...
        .jac/.jca files to be converted.

    --all (short: -a)
        All .jac/.jca files in the current working directory will be converted.

    --inp_encoding (default: UTF-8)
        Specify the encoding of .jac/.jca files to be converted.
        Use one of the supported encodings listed in the following URL.
        https://perldoc.perl.org/Encode::Supported#Supported-Encodings
        Use cp932 for .jac/.jca files encoded in Shift JIS.

    --detector=det_file (short: --det)
        A file containing conversion functions of a detector
        such as channel-to-energy and channel-to-FWHM functions.
        Key-value pairs contained in this file take precedence
        over the predefined functions.
        Refer to the sample file 'detector.j2d' for the syntax.

    --out_encoding (default: UTF-8)
        Specify the encoding of converted files.
        Use one of the supported encodings listed in the following URL.
        https://perldoc.perl.org/Encode::Supported#Supported-Encodings
        Use UTF-8 unless you specifically need a different encoding.

    --out_fmts=ext ... (short: --fmts, default: dat)
        Output formats. Multiple formats are separated by the comma (,).
        all
            All of the following ext's.
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

    --out_path=path (short: --path, default: current working directory)
        The output path.

    --out_prepend=flag (short: --prep, default: empty)
        A flag to be prepended to the names of output files.

    --out_append=flag (short: --app, default: empty)
        A flag to be appended to the names of output files.

    --noyn
        Run the program without prompting a y/n selection message.

    --nofm
        Do not show the front matter at the beginning of the program.

    --nopause
        Do not pause the shell at the end of the program.

=head1 EXAMPLES

    perl jac2dat.pl lt1200s.jac --fmts=dat,xlsx
    perl jac2dat.pl ./samples/sample_rand.jac --det=./j2d/det_fitted.j2d
    perl jac2dat.pl ./samples/sample_rand.jac --nopause

=head1 REQUIREMENTS

    Perl 5
        Text::CSV, Excel::Writer::XLSX, JSON, YAML

=head1 SEE ALSO

L<jac2dat on GitHub|https://github.com/jangcom/jac2dat>

=head1 AUTHOR

Jaewoong Jang <jangj@korea.ac.kr>

=head1 COPYRIGHT

Copyright (c) 2019-2023 Jaewoong Jang

=head1 LICENSE

This software is available under the MIT license;
the license information is found in 'LICENSE'.

=cut
