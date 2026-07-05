#!/usr/bin/perl
#
# run_param_sweep.pl — Automate parameter sweep experiments for Tsetlin & LinUCB
#
# Uses a single multi-prefetcher binary for all algorithms.
# The prefetcher type is selected at runtime via --l2c_prefetcher_types
# (already defined in the .exp files).
#
# Usage:
#   source setvars.sh
#
#   # List all experiments by category:
#   ./scripts/run_param_sweep.pl --algo all --list
#
#   # Generate job scripts:
#   ./scripts/run_param_sweep.pl --algo all --output-dir sweep_jobs
#
#   # Generate + run locally with 4 parallel jobs:
#   ./scripts/run_param_sweep.pl --algo all --run --ncores 4 --output-dir sweep_results
#
#   # Run only Tsetlin:
#   ./scripts/run_param_sweep.pl --algo tsetlin --run --ncores 4
#
#   # Slurm mode (submit to cluster):
#   ./scripts/run_param_sweep.pl --algo all --local 0 --partition compute
#
#   # Custom binary path:
#   ./scripts/run_param_sweep.pl --algo all --exe /path/to/perceptron-multi-multi-no-ship-1core

use warnings;
use Getopt::Long;
use Trace;
use Exp;

# =========================================================================
# Defaults
# =========================================================================
my $algo         = "all";
my $local        = 1;
my $ncores       = 4;
my $do_run       = 0;
my $do_list      = 0;
my $output_dir   = ".";
my $slurm_partition = "slurm_part";
my $exe;
my $exclude_list;
my $include_list;
my $extra;

GetOptions(
    'algo=s'      => \$algo,
    'local=s'     => \$local,
    'ncores=s'    => \$ncores,
    'exe=s'       => \$exe,
    'run'         => \$do_run,
    'list'        => \$do_list,
    'output-dir=s' => \$output_dir,
    'partition=s' => \$slurm_partition,
    'exclude=s'   => \$exclude_list,
    'include=s'   => \$include_list,
    'extra=s'     => \$extra,
) or die "
Usage: $0 [options]

Options:
  --algo       tsetlin | linucb | all      (default: all)
  --exe        Path to ChampSim binary     (default: \$PYTHIA_HOME/bin/perceptron-multi-multi-no-ship-1core)
  --run        Execute the generated job scripts
  --list       List all experiments without generating jobs
  --local      1 (local parallel) | 0 (Slurm sbatch)  (default: 1)
  --ncores     Max parallel jobs (local mode) or -c N (Slurm)  (default: 4)
  --output-dir Directory for generated scripts and output files  (default: .)
  --partition  Slurm partition name  (default: slurm_part)
  --exclude    Slurm node exclude list (e.g. '1,2,5')
  --include    Slurm node include list
  --extra      Extra arguments to pass to sbatch

Examples:
  # Show what will be tested:
  $0 --algo all --list

  # Generate job scripts only:
  $0 --algo all --output-dir sweep_jobs

  # Full local run:
  $0 --algo all --run --ncores 4 --output-dir sweep_results

  # Slurm submission:
  $0 --algo tsetlin --local 0 --partition compute
\n";

# =========================================================================
# Validation
# =========================================================================
die "\$PYTHIA_HOME env variable is not defined.\nHave you sourced setvars.sh?\n"
    unless defined $ENV{'PYTHIA_HOME'};

my $PYTHIA_HOME = $ENV{'PYTHIA_HOME'};

# Default binary: single multi-prefetcher build for all algorithms
$exe = "$PYTHIA_HOME/bin/perceptron-multi-multi-no-ship-1core" unless defined $exe;

# Validate algorithm selection
my @algos_to_run;
if ($algo eq "all") {
    @algos_to_run = ('tsetlin', 'linucb');
} elsif ($algo eq "tsetlin" || $algo eq "linucb") {
    @algos_to_run = ($algo);
} else {
    die "Invalid algorithm: '$algo'. Use 'tsetlin', 'linucb', or 'all'.\n";
}

# =========================================================================
# Algorithm Configurations
# =========================================================================
my %algo_configs = (
    'tsetlin' => {
        name       => 'Tsetlin Machine',
        exp_file   => "$PYTHIA_HOME/experiments/param_sweep_tsetlin_1C.exp",
        tlist_file => "$PYTHIA_HOME/experiments/param_sweep_1C.tlist",
        # Category mapping for pretty-printing (extracted from .exp comments)
        categories => {
            'tsetlin_baseline'     => 'Baseline',
            'tsetlin_cls64'        => 'Clause Count',
            'tsetlin_cls256'       => 'Clause Count',
            'tsetlin_s1.5'         => 'Precision (s)',
            'tsetlin_s5.0'         => 'Precision (s)',
            'tsetlin_s10.0'        => 'Precision (s)',
            'tsetlin_T4'           => 'Threshold (T)',
            'tsetlin_T16'          => 'Threshold (T)',
            'tsetlin_st4'          => 'States per TA',
            'tsetlin_st16'         => 'States per TA',
            'tsetlin_eps0.001'     => 'Epsilon',
            'tsetlin_eps0.01'      => 'Epsilon',
            'tsetlin_warmup_ext'   => 'Warmup/Annealing',
            'tsetlin_pt256'        => 'PT Size',
            'tsetlin_nodyn'        => 'Dynamic Degree',
            'tsetlin_dyn_agg'      => 'Dynamic Degree',
            'tsetlin_dyn_cons'     => 'Dynamic Degree',
            'tsetlin_small_fast'   => 'Combined',
            'tsetlin_large_precise'=> 'Combined',
            'tsetlin_explore_hi'   => 'Combined',
        },
    },
    'linucb' => {
        name       => 'LinUCB Contextual Bandit',
        exp_file   => "$PYTHIA_HOME/experiments/param_sweep_linucb_1C.exp",
        tlist_file => "$PYTHIA_HOME/experiments/param_sweep_1C.tlist",
        categories => {
            'linucb_baseline'   => 'Baseline',
            'linucb_a0.5'       => 'Alpha (Exploration)',
            'linucb_a1.0'       => 'Alpha (Exploration)',
            'linucb_a2.5'       => 'Alpha (Exploration)',
            'linucb_a5.0'       => 'Alpha (Exploration)',
            'linucb_l0.1'       => 'Lambda (Regularization)',
            'linucb_l0.5'       => 'Lambda (Regularization)',
            'linucb_l5.0'       => 'Lambda (Regularization)',
            'linucb_l10.0'      => 'Lambda (Regularization)',
            'linucb_eps0.001'   => 'Epsilon',
            'linucb_eps0.01'    => 'Epsilon',
            'linucb_pt128'      => 'PT Size',
            'linucb_pt512'      => 'PT Size',
            'linucb_nodyn'      => 'Dynamic Degree',
            'linucb_dyn_agg'    => 'Dynamic Degree',
            'linucb_dyn_cons'   => 'Dynamic Degree',
            'linucb_greedy'     => 'Combined',
            'linucb_curious'    => 'Combined',
        },
    },
);

# =========================================================================
# Helper: print a separator line
# =========================================================================
sub print_sep {
    my ($char, $width) = @_;
    $char  ||= '=';
    $width ||= 72;
    print "$char" x $width . "\n";
}

# =========================================================================
# Helper: count experiments in a file
# =========================================================================
sub count_experiments {
    my ($exp_file) = @_;
    my @exp_info = Exp::parse($exp_file);
    return scalar @exp_info;
}

# =========================================================================
# Helper: count traces in a file
# =========================================================================
sub count_traces {
    my ($tlist_file) = @_;
    my @trace_info = Trace::parse($tlist_file);
    return scalar @trace_info;
}

# =========================================================================
# List mode: print all experiments with categories
# =========================================================================
if ($do_list) {
    foreach my $a (@algos_to_run) {
        my $cfg = $algo_configs{$a};
        print_sep();
        print "Algorithm: $cfg->{name} ($a)\n";
        print_sep();
        print "\n";

        my @exp_info = Exp::parse($cfg->{exp_file});
        my @trace_info = Trace::parse($cfg->{tlist_file});

        print "Traces (" . scalar(@trace_info) . "):\n";
        foreach my $trace (@trace_info) {
            printf "  %-45s  %s\n", $trace->{"NAME"}, $trace->{"TRACE"};
        }
        print "\n";

        # Group experiments by category
        my %by_category;
        foreach my $exp (@exp_info) {
            my $cat = $cfg->{categories}->{$exp->{"NAME"}} || 'Other';
            push @{$by_category{$cat}}, $exp;
        }

        foreach my $cat (sort keys %by_category) {
            printf "%-28s (%d experiment(s))\n", $cat, scalar @{$by_category{$cat}};
            foreach my $exp (@{$by_category{$cat}}) {
                printf "  %-35s\n", $exp->{"NAME"};
            }
            print "\n";
        }

        my $total_jobs = scalar(@exp_info) * scalar(@trace_info);
        printf "Total: %d experiments × %d traces = %d jobs\n\n",
               scalar(@exp_info), scalar(@trace_info), $total_jobs;
    }
    exit 0;
}

# =========================================================================
# Ensure output directory exists
# =========================================================================
if ($output_dir ne ".") {
    system("mkdir -p $output_dir") == 0
        or die "Cannot create output directory: $output_dir\n";
}

# =========================================================================
# Step 1: Validate binary and parse experiment definitions
# =========================================================================
print_sep();
print "STEP 1: Validating binary & parsing experiment definitions\n";
print_sep();
print "\n";

# Validate the binary exists
if (-f $exe) {
    print "Binary:  $exe  [OK]\n\n";
} else {
    die "Binary not found: $exe\n" .
        "Build it first, or specify a different path with --exe\n";
}

my %parsed;
foreach my $a (@algos_to_run) {
    my $cfg = $algo_configs{$a};
    my $exp_file   = $cfg->{exp_file};
    my $tlist_file = $cfg->{tlist_file};

    # Validate files exist
    die "[$a] Experiment file not found: $exp_file\n"   unless -f $exp_file;
    die "[$a] Trace list file not found: $tlist_file\n"  unless -f $tlist_file;

    my @exp_info   = Exp::parse($exp_file);
    my @trace_info = Trace::parse($tlist_file);
    $parsed{$a} = {
        exp_info   => \@exp_info,
        trace_info => \@trace_info,
    };

    printf "%-8s  %3d experiments  ×  %2d traces  =  %4d jobs\n",
           $a, scalar(@exp_info), scalar(@trace_info),
           scalar(@exp_info) * scalar(@trace_info);
}
print "\n";

# =========================================================================
# Step 2: Generate job scripts
# =========================================================================
print_sep();
print "STEP 2: Generating job scripts\n";
print_sep();
print "\n";

my %job_files;
my $exclude_nodes_list = "";
$exclude_nodes_list = "kratos[$exclude_list]" if defined $exclude_list;
my $include_nodes_list = "";
$include_nodes_list = "kratos[$include_list]" if defined $include_list;

foreach my $a (@algos_to_run) {
    my $cfg        = $algo_configs{$a};
    my $exp_file   = $cfg->{exp_file};
    my $tlist_file = $cfg->{tlist_file};

    my $script_name = "$output_dir/run_${a}_sweep.sh";
    open(my $fh, '>', $script_name) or die "Cannot write $script_name: $!\n";

    my $pd        = $parsed{$a};
    my @exp_info  = @{$pd->{exp_info}};
    my @trace_info = @{$pd->{trace_info}};

    # Script header
    if ($local) {
        print $fh "#!/bin/bash\n";
        print $fh "#\n";
        print $fh "# Parameter Sweep: $cfg->{name} ($a)\n";
        print $fh "# Generated: " . scalar(localtime) . "\n";
        print $fh "#\n";
        print $fh "# Traces:\n";
        foreach my $trace (@trace_info) {
            print $fh "#    $trace->{\"NAME\"}\n";
        }
        print $fh "#\n";
        print $fh "# Experiments:\n";
        foreach my $exp (@exp_info) {
            my $cat = $cfg->{categories}->{$exp->{"NAME"}} || '';
            printf $fh "#    %-35s  [%s]\n", $exp->{"NAME"}, $cat;
        }
        print $fh "#\n";
        print $fh "# Parallel execution: up to $ncores job(s) at a time\n";
        print $fh "#\n\n";

        # Build command list
        my @cmds;
        foreach my $trace (@trace_info) {
            foreach my $exp (@exp_info) {
                my $exp_name   = $exp->{"NAME"};
                my $exp_knobs  = $exp->{"KNOBS"};
                my $trace_name = $trace->{"NAME"};
                my $trace_input = $trace->{"TRACE"};
                my $trace_knobs = $trace->{"KNOBS"};

                my $cmdline = "$exe $exp_knobs $trace_knobs -traces $trace_input > $output_dir/${trace_name}_${exp_name}.out 2>&1";
                $cmdline =~ s/\$\(PYTHIA_HOME\)/$PYTHIA_HOME/g;
                $cmdline =~ s/\$\(EXP\)/$exp_name/g;
                $cmdline =~ s/\$\(TRACE\)/$trace_name/g;
                $cmdline =~ s/\$\(NCORES\)/$ncores/g;
                push @cmds, $cmdline;
            }
        }

        my $cmd_count = scalar @cmds;
        print $fh "# Total jobs: $cmd_count\n\n";
        print $fh "MAX_PROCS=$ncores\n";
        print $fh "completed=0\n";
        print $fh "failed=0\n";
        print $fh "pids=()\n";
        print $fh "declare -A JOB_INFO\n\n";

        foreach my $c (@cmds) {
            # Escape single quotes for bash
            my $escaped = $c;
            $escaped =~ s/'/'"'"'/g;

            print $fh "# Wait for a free slot\n";
            print $fh "while [ \${#pids[\@]} -ge \$MAX_PROCS ]; do\n";
            print $fh "    for i in \"\${!pids[\@]}\"; do\n";
            print $fh "        if ! kill -0 \"\${pids[\$i]}\" 2>/dev/null; then\n";
            print $fh "            wait \"\${pids[\$i]}\"\n";
            print $fh "            rc=\$?\n";
            print $fh "            job_info=\"\${JOB_INFO[\$i]}\"\n";
            print $fh "            if [ \$rc -eq 0 ]; then\n";
            print $fh "                completed=\$((completed + 1))\n";
            print $fh "                echo \"[\$completed/$cmd_count] OK:   \$job_info\"\n";
            print $fh "            else\n";
            print $fh "                failed=\$((failed + 1))\n";
            print $fh "                echo \"[\$completed/$cmd_count] FAIL: \$job_info (rc=\$rc)\" >&2\n";
            print $fh "            fi\n";
            print $fh "            unset 'pids[\$i]'\n";
            print $fh "            unset 'JOB_INFO[\$i]'\n";
            print $fh "        fi\n";
            print $fh "    done\n";
            print $fh "    pids=(\"\${pids[\@]}\")\n";
            print $fh "    [ \${#pids[\@]} -ge \$MAX_PROCS ] && sleep 1\n";
            print $fh "done\n";

            # Extract trace_name_exp_name from the output redirection for progress display
            my ($job_label) = $escaped =~ />\s*(\S+\.out)/;
            $job_label ||= "job";

            print $fh "echo \"[\$((completed + \${#pids[\@]} + 1))/$cmd_count] Starting: $job_label\"\n";
            print $fh "eval '$escaped' &\n";
            print $fh "pid=\$!\n";
            print $fh "pids+=(\$pid)\n";
            print $fh "JOB_INFO[\$pid]=\"$job_label\"\n\n";
        }

        print $fh "# Wait for remaining jobs\n";
        print $fh "for pid in \"\${pids[\@]}\"; do\n";
        print $fh "    wait \"\$pid\"\n";
        print $fh "    rc=\$?\n";
        print $fh "    job_info=\"\${JOB_INFO[\$pid]}\"\n";
        print $fh "    if [ \$rc -eq 0 ]; then\n";
        print $fh "        completed=\$((completed + 1))\n";
        print $fh "        echo \"[\$completed/$cmd_count] OK:   \$job_info\"\n";
        print $fh "    else\n";
        print $fh "        failed=\$((failed + 1))\n";
        print $fh "        echo \"[\$completed/$cmd_count] FAIL: \$job_info (rc=\$rc)\" >&2\n";
        print $fh "    fi\n";
        print $fh "done\n\n";
        print $fh "echo \"\"\n";
        print $fh "echo \"============================================\"\n";
        print $fh "echo \"$cfg->{name} ($a) — Done.\"\n";
        print $fh "echo \"  Completed: \$completed\"\n";
        print $fh "echo \"  Failed:    \$failed\"\n";
        print $fh "echo \"============================================\"\n";
    }
    else {
        # Slurm mode
        print $fh "#!/bin/bash -l\n";
        print $fh "#\n";
        print $fh "# Parameter Sweep: $cfg->{name} ($a)\n";
        print $fh "# Generated: " . scalar(localtime) . "\n";
        print $fh "# Slurm submission script\n";
        print $fh "#\n\n";

        my $job_count = 0;
        foreach my $trace (@trace_info) {
            foreach my $exp (@exp_info) {
                my $exp_name   = $exp->{"NAME"};
                my $exp_knobs  = $exp->{"KNOBS"};
                my $trace_name = $trace->{"NAME"};
                my $trace_input = $trace->{"TRACE"};
                my $trace_knobs = $trace->{"KNOBS"};

                my $out_dir = $output_dir;
                $out_dir = "." if $out_dir eq "";

                my $slurm_cmd = "sbatch -p $slurm_partition --mincpus=1";
                if (defined $include_list) {
                    $slurm_cmd .= " --nodelist=${include_nodes_list}";
                }
                if (defined $exclude_list) {
                    $slurm_cmd .= " --exclude=${exclude_nodes_list}";
                }
                if (defined $extra) {
                    $slurm_cmd .= " $extra";
                }
                $slurm_cmd .= " -c $ncores -J ${trace_name}_${exp_name}";
                $slurm_cmd .= " -o ${out_dir}/${trace_name}_${exp_name}.out";
                $slurm_cmd .= " -e ${out_dir}/${trace_name}_${exp_name}.err";

                my $cmdline = "$slurm_cmd $PYTHIA_HOME/wrapper.sh $exe \"$exp_knobs $trace_knobs -traces $trace_input\"";
                $cmdline =~ s/\$\(PYTHIA_HOME\)/$PYTHIA_HOME/g;
                $cmdline =~ s/\$\(EXP\)/$exp_name/g;
                $cmdline =~ s/\$\(TRACE\)/$trace_name/g;
                $cmdline =~ s/\$\(NCORES\)/$ncores/g;

                print $fh "$cmdline\n";
                $job_count++;
            }
        }
        print $fh "\n# Total Slurm jobs: $job_count\n";
    }

    close($fh);
    chmod 0755, $script_name;
    $job_files{$a} = $script_name;
    printf "%-8s  ->  %s\n", $a, $script_name;
}
print "\n";

# =========================================================================
# Step 3: Optionally run the generated scripts
# =========================================================================
if ($do_run) {
    print_sep();
    print "STEP 3: Running experiments\n";
    print_sep();
    print "\n";

    foreach my $a (@algos_to_run) {
        my $script = $job_files{$a};
        my $cfg    = $algo_configs{$a};

        printf "[%s] Starting: bash %s\n", $a, $script;
        print  "[$a] " . ("-" x 50) . "\n";

        my $ret = system("bash $script");
        my $exit_code = $ret >> 8;

        if ($exit_code == 0) {
            print "[$a] All jobs completed successfully.\n\n";
        } else {
            print "[$a] Some jobs may have failed (script exit code: $exit_code).\n";
            print "[$a] Check individual .out files for errors.\n\n";
        }
    }
}

# =========================================================================
# Summary & Next Steps
# =========================================================================
print_sep();
print "SUMMARY\n";
print_sep();
print "\n";

foreach my $a (@algos_to_run) {
    my $cfg = $algo_configs{$a};
    my $pd  = $parsed{$a};
    my $n_exp   = scalar @{$pd->{exp_info}};
    my $n_trace = scalar @{$pd->{trace_info}};

    printf "%-8s  %s\n", $a, $cfg->{name};
    printf "         %d experiment(s) × %d trace(s) = %d job(s)\n",
           $n_exp, $n_trace, $n_exp * $n_trace;
    printf "         Job script: %s\n", $job_files{$a};

    if (!$do_run) {
        printf "         Run with:  bash %s\n", $job_files{$a};
    }
    print "\n";
}

if ($do_run) {
    print "Output files are in: $output_dir/\n";
    print "\n";
    print "To collect results into a CSV, use rollup.pl:\n";
    foreach my $a (@algos_to_run) {
        my $cfg    = $algo_configs{$a};
        my $exp    = $cfg->{exp_file};
        my $tlist  = $cfg->{tlist_file};
        my $mfile  = "$PYTHIA_HOME/experiments/rollup_1C_base_config.mfile";
        my $out    = "$output_dir/results_${a}.csv";

        print "  $PYTHIA_HOME/scripts/rollup.pl \\\n";
        print "      --tlist $tlist \\\n";
        print "      --exp $exp \\\n";
        print "      --mfile $mfile \\\n";
        print "      --ext out > $out\n";
        print "\n";
    }
}
else {
    print "Next steps:\n";
    print "  1. Run the job script(s) listed above\n";
    print "  2. Use scripts/rollup.pl to collect results into a CSV\n";
}
