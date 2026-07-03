#!/usr/bin/perl

use warnings;
use Getopt::Long;
use Trace;
use Exp;

# defaults
my $tlist_file;
my $exp_file;
my $exe;
my $local = "0";
my $ncores = 1;
my $slurm_partition = "slurm_part";
my $exclude_list;
my $include_list;
my $extra;

GetOptions('tlist=s' => \$tlist_file,
	   'exp=s' => \$exp_file,
	   'exe=s' => \$exe,
	   'ncores=s' => \$ncores,
	   'local=s' => \$local,
	   'exclude=s' => \$exclude_list,
	   'partition=s' => \$slurm_partition,
	   'exclude=s' => \$exclude_list,
	   'include=s' => \$include_list,
	   'extra=s' => \$extra,
) or die "Usage: $0 --exe <executable> --exp <exp file> --tlist <trace list>\n";

die "\$PYTHIA_HOME env variable is not defined.\nHave you sourced setvars.sh?\n" unless defined $ENV{'PYTHIA_HOME'};

die "Supply exe\n" unless defined $exe;
die "Supply tlist\n" unless defined $tlist_file;
die "Supply exp\n" unless defined $exp_file;

my $exclude_nodes_list = "";
$exclude_nodes_list = "kratos[$exclude_list]" if defined $exclude_list;
my $include_nodes_list = "";
$include_nodes_list = "kratos[$include_list]" if defined $include_list;

my @trace_info = Trace::parse($tlist_file);
my @exp_info = Exp::parse($exp_file);
if($ncores == 0)
{
	print "have to supply -ncores\n";
	exit 1;
}

# preamble for sbatch script
if($local eq "0")
{
	print "#!/bin/bash -l\n";
	print "#\n";
	print "#\n";
}
else
{
	print "#!/bin/bash\n";
	print "#\n";
	print "#\n";
}

print "#\n";
print "# Traces:\n";
foreach $trace (@trace_info)
{
	my $trace_name = $trace->{"NAME"};
	print "#    $trace_name\n";
}
print "#\n";

print "#\n";
print "# Experiments:\n";
foreach $exp (@exp_info)
{
	my $exp_name = $exp->{"NAME"};
	my $exp_knobs = $exp->{"KNOBS"};
	print "#    $exp_name: $exp_knobs\n";
}
print "#\n";
if($local)
{
	print "# Parallel execution: up to $ncores job(s) at a time\n";
}
print "#\n";
print "#\n";
print "#\n";

if($local)
{
	# --- Local mode: parallel job pool via bash for-loop (avoids xargs ARG_MAX limit) ---
	my @cmds;
	foreach $trace (@trace_info)
	{
		foreach $exp (@exp_info)
		{
			my $exp_name = $exp->{"NAME"};
			my $exp_knobs = $exp->{"KNOBS"};
			my $trace_name = $trace->{"NAME"};
			my $trace_input = $trace->{"TRACE"};
			my $trace_knobs = $trace->{"KNOBS"};

			my $cmdline = "$exe $exp_knobs $trace_knobs -traces $trace_input > ${trace_name}_${exp_name}.out 2>&1";
			$cmdline =~ s/\$\(PYTHIA_HOME\)/$ENV{'PYTHIA_HOME'}/g;
			$cmdline =~ s/\$\(EXP\)/$exp_name/g;
			$cmdline =~ s/\$\(TRACE\)/$trace_name/g;
			$cmdline =~ s/\$\(NCORES\)/$ncores/g;
			push @cmds, $cmdline;
		}
	}
	my $cmd_count = scalar @cmds;
	print "# Total jobs: $cmd_count\n\n";
	print "MAX_PROCS=$ncores\n";
	print "pids=()\n\n";

	foreach my $c (@cmds)
	{
		# Escape single quotes for bash: replace ' with '\''
		my $escaped = $c;
		$escaped =~ s/'/'"'"'/g;
		print "while [ \${#pids[\@]} -ge \$MAX_PROCS ]; do\n";
		print "    for i in \"\${!pids[\@]}\"; do\n";
		print "        if ! kill -0 \"\${pids[\$i]}\" 2>/dev/null; then\n";
		print "            unset 'pids[\$i]'\n";
		print "        fi\n";
		print "    done\n";
		print "    pids=(\"\${pids[\@]}\")\n";
		print "    [ \${#pids[\@]} -ge \$MAX_PROCS ] && sleep 1\n";
		print "done\n";
		print "eval '$escaped' &\n";
		print "pids+=(\$!)\n\n";
	}
	print "# Wait for remaining jobs to finish\n";
	print "wait\n";
	print "echo \"All jobs done.\"\n";
}
else
{
	# --- Slurm mode: sbatch is non-blocking, all jobs submitted simultaneously ---
	foreach $trace (@trace_info)
	{
		foreach $exp (@exp_info)
		{
			my $exp_name = $exp->{"NAME"};
			my $exp_knobs = $exp->{"KNOBS"};
			my $trace_name = $trace->{"NAME"};
			my $trace_input = $trace->{"TRACE"};
			my $trace_knobs = $trace->{"KNOBS"};

			my $slurm_cmd = "sbatch -p $slurm_partition --mincpus=1";
			if (defined $include_list)
			{
				$slurm_cmd = $slurm_cmd." --nodelist=${include_nodes_list}";
			}
			if (defined $exclude_list)
			{
				$slurm_cmd = $slurm_cmd." --exclude=${exclude_nodes_list}";
			}
			if (defined $extra)
			{
				$slurm_cmd = $slurm_cmd." $extra";
			}
			$slurm_cmd = $slurm_cmd." -c $ncores -J ${trace_name}_${exp_name} -o ${trace_name}_${exp_name}.out -e ${trace_name}_${exp_name}.err";
			my $cmdline = "$slurm_cmd $ENV{'PYTHIA_HOME'}/wrapper.sh $exe \"$exp_knobs $trace_knobs -traces $trace_input\"";

			$cmdline =~ s/\$\(PYTHIA_HOME\)/$ENV{'PYTHIA_HOME'}/g;
			$cmdline =~ s/\$\(EXP\)/$exp_name/g;
			$cmdline =~ s/\$\(TRACE\)/$trace_name/g;
			$cmdline =~ s/\$\(NCORES\)/$ncores/g;

			print "$cmdline\n";
		}
	}
}
