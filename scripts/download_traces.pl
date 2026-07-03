#!/usr/bin/perl

use warnings;
use Getopt::Long;
use POSIX ":sys_wait_h";
use File::Basename;

die "\$PYTHIA_HOME env variable is not defined.\nHave you sourced setvars.sh?\n"
    unless defined $ENV{'PYTHIA_HOME'};

my $megatool_exe =
    "$ENV{'PYTHIA_HOME'}/scripts/megatools-1.11.1.20230212-linux-x86_64/megatools";
my $input_file;
my $dir      = ".";
my $tlist_dir;
my $max_jobs = 4;
my $md5_file = "$ENV{'PYTHIA_HOME'}/scripts/artifact_traces.md5";

GetOptions(
    'csv=s'       => \$input_file,
    'dir=s'       => \$dir,
    'tlist-dir=s' => \$tlist_dir,
    'jobs=i'      => \$max_jobs,
    'md5=s'       => \$md5_file,
) or die
    "Usage: $0 --csv <csv file> [--tlist-dir <dir>] [--dir <download dir>] [--jobs <N>] [--md5 <md5file>]\n";

die "Supply csv file with --csv\n" unless defined $input_file;

$tlist_dir = "$ENV{'PYTHIA_HOME'}/experiments" unless defined $tlist_dir;

# 临时日志目录
my $log_dir = "/tmp/pythia_dl_logs_$$";
mkdir $log_dir or die "Cannot create log dir $log_dir: $!\n";

# 进程结束时清理临时日志
END { system("rm -rf $log_dir") if defined $log_dir && -d $log_dir; }

# ----------------------------------------------------------------------
# Helper: 打印覆盖式进度条（STDERR 同一行刷新）
# ----------------------------------------------------------------------
sub print_progress {
    my ($done, $total, $ok, $bad, $label) = @_;
    my $width  = 30;
    my $filled = $total > 0 ? int($width * $done / $total) : 0;
    my $bar    = '=' x $filled . '-' x ($width - $filled);
    printf STDERR "\r%-12s [%s] %d/%d  OK:%-4d FAIL:%-4d",
        $label, $bar, $done, $total, $ok, $bad;
}

# ----------------------------------------------------------------------
# Step 0: Load md5 map
# ----------------------------------------------------------------------
my %md5_map;
if (-f $md5_file) {
    open(my $mfh, '<', $md5_file) or die "Could not open $md5_file\n";
    while (my $line = <$mfh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        if ($line =~ /^([0-9a-fA-F]{32})\s+(\S+)$/) {
            my ($sum, $name) = ($1, $2);
            $name = basename($name);
            $md5_map{$name} = lc($sum);
        }
    }
    close($mfh);
    print "Loaded ", scalar(keys %md5_map), " MD5 entries from $md5_file\n";
} else {
    warn "WARNING: MD5 file not found at $md5_file — integrity checks disabled.\n";
}

sub verify_md5 {
    my ($path) = @_;
    return 0 unless -f $path && -s $path;
    my $name     = basename($path);
    my $expected = $md5_map{$name};
    return 0 unless defined $expected;
    my $out = `md5sum "$path" 2>/dev/null`;
    chomp $out;
    my ($got) = split(/\s+/, $out);
    return (defined $got && lc($got) eq lc($expected)) ? 1 : 0;
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
            while ($line =~ m{/([^/\s]+\.(?:champsimtrace\.xz|trace\.xz))}g) {
                $needed_traces{$1} = 1;
            }
        }
    }
    close($tfh);
}

my $needed_count = scalar(keys %needed_traces);
print "Found $needed_count unique trace files needed by experiments.\n";

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
# Step 3: 逐个校验已有文件，带进度条
# ----------------------------------------------------------------------
print "\nVerifying existing traces...\n";

my @downloads;
my @missing;
my @skipped;
my @resuming;

my $v_done  = 0;
my $v_ok    = 0;
my $v_bad   = 0;
my $v_total = scalar(grep {
    exists $url_map{$_} && -f "$dir/$_"
} keys %needed_traces);

foreach my $trace (sort keys %needed_traces) {
    if (exists $url_map{$trace}) {
        my $path = "$dir/$trace";
        if (-f $path) {
            $v_done++;
            print_progress($v_done, $v_total, $v_ok, $v_bad, "Verifying");
            if (verify_md5($path)) {
                $v_ok++;
                push @skipped, $trace;
            } else {
                $v_bad++;
                push @resuming, $trace;
                push @downloads, {name => $trace, url => $url_map{$trace}, resume => 1};
            }
            print_progress($v_done, $v_total, $v_ok, $v_bad, "Verifying");
        } else {
            push @downloads, {name => $trace, url => $url_map{$trace}, resume => 0};
        }
    } else {
        push @missing, $trace;
    }
}

print STDERR "\n" if $v_total > 0;
print "Verification done: $v_ok OK, $v_bad failed/incomplete",
      " (out of $v_total existing files)\n";

if (@skipped) {
    print scalar(@skipped), " traces already present and MD5-verified, skipping.\n";
}
if (@resuming) {
    print scalar(@resuming), " traces are incomplete/corrupt and will be re-downloaded:\n";
    print "  $_\n" foreach @resuming;
}
if (@missing) {
    print "\nWARNING: ", scalar(@missing),
        " traces needed by experiments but NOT found in CSV.\n";
    print "These must be downloaded manually:\n";
    print "  $_\n" foreach @missing;
}

my $total = scalar(@downloads);
if ($total == 0) {
    print "\nNothing to download — all needed traces are already present and verified.\n";
    exit 0;
}

print "\nWill download/resume $total traces with $max_jobs parallel job(s).\n\n";

# ----------------------------------------------------------------------
# Step 4: Parallel download with fork / wait + 进度条 + 错误日志
# ----------------------------------------------------------------------
my %pids;        # pid => {name, logfile}
my $completed = 0;
my $dl_ok     = 0;
my $dl_fail   = 0;
my @fail_log;   # 收集失败信息，最后统一打印

sub print_dl_progress {
    print_progress($completed, $total, $dl_ok, $dl_fail, "Downloading");
}

sub reap_one {
    my $pid = wait();
    return if $pid <= 0;

    $completed++;
    my $exit_code = $? >> 8;
    my $name      = $pids{$pid}{name};
    my $logfile   = $pids{$pid}{logfile};
    delete $pids{$pid};

    # 读取子进程的错误日志
    my $err_msg = "";
    if (-f $logfile) {
        open(my $lf, '<', $logfile) or do {};
        local $/;
        $err_msg = <$lf> // "";
        close($lf);
        unlink $logfile;
        $err_msg =~ s/^\s+|\s+$//g;   # trim
    }

    my $ok     = 0;
    my $reason = "";

    if ($exit_code != 0) {
        $reason = $err_msg ne "" ? $err_msg : "exit code $exit_code";
    } else {
        if (%md5_map) {
            if (verify_md5("$dir/$name")) {
                $ok = 1;
            } else {
                $reason = "MD5 mismatch after download";
            }
        } else {
            $ok = 1;
        }
    }

    if ($ok) {
        $dl_ok++;
    } else {
        $dl_fail++;
        # 先换行，再打印失败原因，再重绘进度条
        print STDERR "\n";
        printf STDERR "  [FAIL] %-55s  %s\n", $name, $reason;
        push @fail_log, {name => $name, reason => $reason};
    }

    print_dl_progress();
}

print_dl_progress();

for my $dl (@downloads) {
    while (scalar(keys %pids) >= $max_jobs) {
        reap_one();
    }

    my $logfile = "$log_dir/$dl->{name}.log";
    my $pid     = fork();
    die "Fork failed\n" unless defined $pid;

    if ($pid == 0) {
        # --- Child: 把 stdout+stderr 都重定向到日志文件 ---
        open(STDOUT, '>', $logfile) or exit 1;
        open(STDERR, '>&', \*STDOUT)  or exit 1;

        my $cmd;
        if ($dl->{url} =~ /mega\.nz/) {
            unlink "$dir/$dl->{name}" if $dl->{resume};
            # megatools 去掉 -q，让错误输出到日志
            $cmd = "$megatool_exe dl --path=$dir $dl->{url}";
        } else {
            my $resume_flag = $dl->{resume} ? "-c" : "";
            # 去掉 -q，改用 --server-response 获取 HTTP 状态
            $cmd = "wget --no-check-certificate $resume_flag"
                 . " --server-response"
                 . " \"$dl->{url}\" -O \"$dir/$dl->{name}\" 2>&1";
        }
        my $ret = system($cmd);
        exit($ret < 0 ? 1 : $ret >> 8);
    }

    $pids{$pid} = {name => $dl->{name}, logfile => $logfile};
}

while (scalar(keys %pids) > 0) {
    reap_one();
}

print STDERR "\n";

# ----------------------------------------------------------------------
# 失败汇总
# ----------------------------------------------------------------------
if (@fail_log) {
    print "\n";
    print "======== Failed Downloads ========\n";
    printf "  %-55s  %s\n", "File", "Reason";
    print  "  " . "-" x 75 . "\n";
    printf "  %-55s  %s\n", $_->{name}, $_->{reason} foreach @fail_log;
    print "==================================\n";
}

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------
my $total_in_dir = `ls -1 "$dir" 2>/dev/null | wc -l`;
chomp $total_in_dir;

my $newly = scalar(@downloads) - scalar(@resuming);

print "\n";
print "================================\n";
print "Trace downloading completed\n";
printf "  %-40s %d\n",    "Needed by experiments:",         $needed_count;
printf "  %-40s %d\n",    "In CSV:",                        scalar(@downloads) + scalar(@skipped);
printf "  %-40s %d\n",    "Already present & verified:",    scalar(@skipped);
printf "  %-40s %d\n",    "Resumed/re-downloaded:",          scalar(@resuming);
printf "  %-40s %d\n",    "Newly downloaded:",               $newly;
printf "  %-40s %d/%d\n", "Successfully downloaded:",       $dl_ok, $total;
if (@missing) {
    printf "  %-40s %d\n", "Missing from CSV (manual DL):", scalar(@missing);
}
printf "  %-40s %s\n",    "Total files in $dir:",           $total_in_dir;
print "================================\n";

exit($dl_fail > 0 ? 1 : 0);

# ----------------------------------------------------------------------
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s; }
