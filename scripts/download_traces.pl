#!/usr/bin/perl

use warnings;
use Getopt::Long;
use POSIX ":sys_wait_h";

die "\$PYTHIA_HOME env variable is not defined.\nHave you sourced setvars.sh?\n"
    unless defined $ENV{'PYTHIA_HOME'};

my $megatool_exe =
    "$ENV{'PYTHIA_HOME'}/scripts/megatools-1.11.1.20230212-linux-x86_64/megatools";
my $input_file;
my $dir        = ".";
my $tlist_dir;
my $max_jobs   = 4;

GetOptions(
    'csv=s'       => \$input_file,
    'dir=s'       => \$dir,
    'tlist-dir=s' => \$tlist_dir,
    'jobs=i'      => \$max_jobs,
) or die
    "Usage: $0 --csv <csv file> [--tlist-dir <dir>] [--dir <download dir>] [--jobs <N>]\n";

die "Supply csv file with --csv\n" unless defined $input_file;

# Default tlist directory: $PYTHIA_HOME/experiments
$tlist_dir = "$ENV{'PYTHIA_HOME'}/experiments" unless defined $tlist_dir;

# Normalize trailing slashes off the dir path
$dir =~ s{/+$}{};

# Ensure download directory exists (mkdir -p handles nested paths)
unless (-d $dir) {
    system("mkdir -p $dir");
    die "Cannot create download directory '$dir': $!\n" unless -d $dir;
    print "Created download directory: $dir\n";
}

# ----------------------------------------------------------------------
# Step 1: Collect unique trace filenames from all .tlist files
# ----------------------------------------------------------------------
my %needed_traces;
opendir(my $dh, $tlist_dir) or die "Could not open $tlist_dir\n";
my @tlist_files = grep { /\.tlist$/ && -f "$tlist_dir/$_" } readdir($dh);
closedir($dh);

die "No .tlist files found in $tlist_dir\n" unless @tlist_files;
print "Found .tlist files: @tlist_files\n";

foreach my $tfile (@tlist_files) {
    open(my $tfh, '<', "$tlist_dir/$tfile")
        or die "Could not open $tlist_dir/$tfile\n";
    while (my $line = <$tfh>) {
        chomp $line;
        if ($line =~ /^TRACE=/) {
            # Extract trace filenames from TRACE lines.
            # Format: TRACE=$(PYTHIA_HOME)/traces/filename.champsimtrace.xz ...
            while (
                $line =~ m{/([^/\s]+\.(?:champsimtrace\.xz|trace\.xz))}g)
            {
                $needed_traces{$1} = 1;
            }
        }
    }
    close($tfh);
}

print "Found ", scalar(keys %needed_traces),
    " unique trace files needed by experiments.\n";

# ----------------------------------------------------------------------
# Step 2: Read CSV and build URL lookup map
# ----------------------------------------------------------------------
my %url_map;
open(my $fh, '<', $input_file) or die "Could not open $input_file\n";
while (my $line = <$fh>) {
    chomp $line;
    my @tokens = split(',', trim($line));
    my $name   = trim($tokens[0]);
    my $url    = trim($tokens[1]);
    $url_map{$name} = $url;
}
close($fh);

# ----------------------------------------------------------------------
# Step 3: Build download list — only traces that are needed AND in CSV,
#         skipping files that already exist locally.
# ----------------------------------------------------------------------
my @downloads;
my @missing;
my @skipped;

foreach my $trace (sort keys %needed_traces) {
    if (exists $url_map{$trace}) {
        if (-f "$dir/$trace") {
            push @skipped, $trace;
        } else {
            push @downloads, {name => $trace, url => $url_map{$trace}};
        }
    } else {
        push @missing, $trace;
    }
}

if (@skipped) {
    print scalar(@skipped),
        " traces already present in $dir, skipping.\n";
}
if (@missing) {
    print "\n";
    print "WARNING: ", scalar(@missing),
        " traces are needed by experiments but NOT found in CSV.\n";
    print "These must be downloaded manually:\n";
    print "  $_\n" foreach @missing;
}

my $total = scalar(@downloads);
if ($total == 0) {
    print "\nNothing to download — all needed traces are already present.\n";
    exit 0;
}

print "\nWill download $total traces with $max_jobs parallel job(s).\n\n";

# ----------------------------------------------------------------------
# Step 4: Parallel download with fork / wait
# ----------------------------------------------------------------------
my %pids;            # pid => trace_name
my $completed = 0;
my $failed    = 0;

for (my $i = 0 ; $i < @downloads ; $i++) {
    my $dl = $downloads[$i];

    # Throttle: wait for a child to finish if at capacity
    while (scalar(keys %pids) >= $max_jobs) {
        my $pid = wait();
        if ($pid > 0) {
            $completed++;
            $failed++ if ($? != 0);
            printf "[%3d/%3d] %-5s  %s\n",
                $completed, $total,
                ($? == 0 ? "OK" : "FAIL"), $pids{$pid};
        }
        delete $pids{$pid};
    }

    my $pid = fork();
    if (!defined $pid) {
        die "Fork failed\n";
    } elsif ($pid == 0) {
        # --- Child process: execute download ---
        my $cmd;
        if ($dl->{url} =~ /mega\.nz/) {
            $cmd = "$megatool_exe dl --path=$dir $dl->{url}";
        } else {
            $cmd =
                "wget --no-check-certificate -q \"$dl->{url}\" -O \"$dir/$dl->{name}\"";
        }
        my $ret = system($cmd);
        if ($ret < 0) {
            exit 1;
        }
        exit($ret >> 8);
    }

    $pids{$pid} = $dl->{name};
}

# Wait for remaining children
while (scalar(keys %pids) > 0) {
    my $pid = wait();
    if ($pid > 0) {
        $completed++;
        $failed++ if ($? != 0);
        printf "[%3d/%3d] %-5s  %s\n",
            $completed, $total,
            ($? == 0 ? "OK" : "FAIL"), $pids{$pid};
    }
    delete $pids{$pid};
}

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------
my $downloaded = `ls -1 $dir 2>/dev/null | wc -l`;
chomp($downloaded);

print "\n";
print "================================\n";
print "Trace downloading completed\n";
print "  Needed by experiments: ", scalar(keys %needed_traces), "\n";
print "  In CSV:               ", scalar(@downloads) + scalar(@skipped), "\n";
print "  Already present:      ", scalar(@skipped),              "\n";
print "  Downloaded:           ", $total - $failed, "/$total\n";
if (@missing) {
    print "  Missing from CSV (manual download needed): ",
        scalar(@missing), "\n";
}
print "  Total files in $dir:  $downloaded\n";
print "================================\n";

exit($failed > 0 ? 1 : 0);

# ----------------------------------------------------------------------
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s; }
