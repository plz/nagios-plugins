#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

my $ISCSI_ADM_CMD = '/sbin/iscsiadm';
my $ISCSI_ADM_ARG = '-m session';
my $DEBUG = 0;
my $VERSION = "0.1";
my $CRIT_THRESHOLD = 4;

my %opts =(h => undef);
getopts('hdc:', \%opts);

if ($opts{'h'}) {
    print "Usage: $0 [options]\n";
    print "  -h: This help message.\n";
    print "  -d: Debug mode, increase verbosity.\n";
    print "  -c: Critical threshold (default = $CRIT_THRESHOLD)\n";
    exit 0;
}
if ($opts{'d'}) {
    $DEBUG = 1;
    print "$0 Executing in DEBUG mode, enjoy the verbosity :)\n";
}
if ($opts{'c'}) {
    if ( looks_like_number($opts{'c'}) ){
        print "Overiding default threshold ($CRIT_THRESHOLD) with ($opts{'c'})\n" if $DEBUG;
        $CRIT_THRESHOLD = $opts{'c'};
    }
    else {
        warn "Threshold ($opts{'c'}) is not a valid number. Using default.\n";
    }
}

if (! -e $ISCSI_ADM_CMD ){
    print "WARNING: $ISCSI_ADM_CMD not found\n";
    exit 1;
}

my $ISCSI_FULL_CMD = $ISCSI_ADM_CMD . " " . $ISCSI_ADM_ARG .  " 2>&1";
print "DEBUG:: Executiing -> $ISCSI_FULL_CMD\n" if $DEBUG;

my @iscsi_adm_output = qx{$ISCSI_FULL_CMD};
my $iscsi_adm_rc = $? >>8;
my %iscsi_targets;

if ( $iscsi_adm_rc == 0 ) {
    # iscsiadm successfully executed, parse output.

    my $iscsi_sessions = scalar @iscsi_adm_output;
    print "DEBUG::" . " Number of iscsi sessions: " . $iscsi_sessions . "\n" if $DEBUG;
    # Parse success.
    for my $line (@iscsi_adm_output) {
        chop $line;
        print "  DEBUG::" . " parse = $line\n" if $DEBUG;
        my @splitted_fields = split(/\s/,$line);
        print "    DEBUG:: Captured Fields " . Dumper(\@splitted_fields) if $DEBUG;
        $iscsi_targets{$splitted_fields[3]}++;
    }
}
else {
    # iscsiadm failed, scream about it.

    print "DEBUG:: " . Dumper(\@iscsi_adm_output) if $DEBUG;
    print "CRITICAL: $iscsi_adm_output[0]";
    exit 1;
}

print "DEBUG::" . Dumper(\%iscsi_targets) if $DEBUG;

my $exit_message;
foreach my $iqn (keys %iscsi_targets) {
    print "  DEBUG::" . " iqn: $iqn - sessions: $iscsi_targets{$iqn} - THRESHOLD $CRIT_THRESHOLD\n" if $DEBUG;
    if ( $iscsi_targets{$iqn} < $CRIT_THRESHOLD ) {
        $exit_message .= "IQN: $iqn - Only $iscsi_targets{$iqn} Sessions";
    }
}

if ($exit_message){
    print "CRITICAL: $exit_message\n";
    exit 2;
}

print "OK: $CRIT_THRESHOLD sessions found for each IQN.\n";
exit 0;
