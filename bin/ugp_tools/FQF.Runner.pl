#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use autodie;
use IPC::Run qw( run timeout );
use Cwd;

my $usage = "./FQF.Runner.pl <GVCF.cfg> <Final.cfg>\n";

## config files from command.
my $toGVCF  = $ARGV[0];
my $toFinal = $ARGV[1];

die $usage unless ( $toGVCF and $toFinal );

my @status_report;
my $dir = getcwd;
my @path = split /\//, $dir;

## toGVCF
toGVCF();

## check the first step
RECHECK:
my @checkFQF = `../FQF -fc`;

if (@checkFQF) {
    open( my $IN,  '<', 'PROGRESS' );
    open( my $OUT, '>', 'PROGRESS.tmp' );

    foreach my $step (<$IN>) {
        chomp $step;
        next if ( $step =~ /(fastq2bam|bam2gvcf)/ );
        say $OUT $step;
    }
    close $IN;
    close $OUT;
    rename 'PROGRESS.tmp', 'PROGRESS';
    ## rerun first step.
    toGVCF();
    goto RECHECK;
}
mail_me("fastqforward step done, moving on.");

## run final steps
toFinal();

## final message.
map { mail_me($_) } @status_report;

## --------------------------------------------------- ##

sub toGVCF {
    my $toGVCFcmd = sprintf(
        "../FQF -cfg %s -il ../../data/Region_Files/FQF.Region.bed -ql 100 -uid u0413537 -st 20:00:00 --run",
        $toGVCF 
    );
    my $gvcf_run = run $toGVCFcmd;
    run_result( $gvcf_run, 'GVCF step' );
}

## --------------------------------------------------- ##

sub toFinal {
    my $toFinalcmd = sprintf(
        "../FQF -cfg %s -il ../../data/Region_Files/FQF.Region.bed -ql 100 -uid u0413537 -st 20:00:00 --run",
        $toFinal 
    );
    my $final_run = run $toFinalcmd;
    run_result( $final_run, 'Final step' );
}

## --------------------------------------------------- ##

sub mail_me {
    my $message = shift;

    my $to      = 'shawn.rynearson@gmail.com';
    my $from    = 'shawn';
    my $subject = 'FQF Message';

    open( MAIL, "|/usr/sbin/sendmail -t" );

    # Email Header
    print MAIL "To: $to\n";
    print MAIL "From: $from\n";
    print MAIL "Subject: $subject\n\n";

    # Email Body
    print MAIL $message;

    close(MAIL);
}

## --------------------------------------------------- ##

sub run_result {
    my ( $run_result, $step ) = @_;

    if ( !$run_result ) {
        push @status_report, "Project $path[-1] had errors on step $step";
        map { mail_me($_) } @status_report;
        exit(1);
    }
    else {
        push @status_report, "Project $path[-1] completed step $step!";
    }
}

## --------------------------------------------------- ##
