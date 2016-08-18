#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use autodie;
use File::Copy;
use Getopt::Long;
use Cwd 'abs_path';

my $usage = << "EOU";

     "project_id|pi=s",
     "data_path|dp=s",
     "help|h",
      \$c_opts{background_version} 
      Longevity or 1000G 
EOU

my %c_opts = ();
GetOptions( \%c_opts, "project_name|pn=s", "data_path|dp=s",
    "background_version|bv=s", "help|h", );
die $usage if $c_opts{help};
die $usage unless ( $c_opts{project_name} and $c_opts{data_path} );

## make directory
say "Making project directory...";
mkdir $c_opts{project_name};
chdir $c_opts{project_name};

## update data path
my $data_path    = abs_path( $c_opts{data_path} );
my $current_path = abs_path('.');

## Copy config files.
my @cfg_orig =
  glob "/uufs/chpc.utah.edu/common/home/u0413537/FQF/data/Config_Files/*cfg";
foreach my $file (@cfg_orig) {
    next if ( $file =~ /master/i );
    copy( $file, $current_path );
}

## collect fqf_id and project epoch
my $epoch = time;
my $backgrounds = $c_opts{background_version} || '1000G';
$backgrounds =~ s/$/-Backgrounds/;

my $out_filename =
  'FQF-1.2.1_' . $c_opts{project_name} . '_' . $backgrounds . '_' . $epoch;

## collect cfg files and update path to data
my @cfgs = glob "*cfg";

foreach my $config (@cfgs) {
    my $data_cmd = sprintf("perl -p -i -e 's|^data:|data:$data_path|' $config");
    my $fqf_cmd =
      sprintf("perl -p -i -e 's|^fqf_id:|fqf_id:$out_filename|' $config");
    system $data_cmd;
    system $fqf_cmd;
}
say "Finished...!";
