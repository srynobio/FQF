#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use autodie;

## stable.
my $GVCF_PATH     = '/UGP/VCF/GVCFs';
my $ANALYSIS_PATH = '/scratch/ucgd/lustre/ugpuser/Repository/AnalysisData';

my $analysis_id = $ARGV[0] or die "Please enter Analysis id.";

my $find_cmd = "find $ANALYSIS_PATH -name \"$analysis_id\"";
my @result   = `$find_cmd`;

if ( !@result ) {
    say "Analysis $analysis_id not found.";
}

foreach my $path (@result) {
    chomp $path;
    my $gvcf_cmd = "ln -s $path/*$GVCF_PATH/* .";
    `$gvcf_cmd`;
}
