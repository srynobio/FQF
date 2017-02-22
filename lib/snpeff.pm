package snpeff;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub snpeff_run {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('snpeff_run');
    my $vcf    = $self->file_retrieve;

    ## find old version of snpeff runs.
    my @found = grep { $_ =~ /(ann.vcf$|csv$|genes.txt$)/ } @{$vcf};
    unlink @found if @found;

    my @cmds;
    foreach my $file ( @{$vcf} ) {
        chomp $file;
        next unless ( $file =~ /FQF-.*\_(\d+).vcf$/ );
        $self->file_store($file);

        ( my $indiv = $file ) =~ s/\.vcf//;
        my $ann_file = "$indiv.ann.vcf";
        my $csv_file = "$indiv.csv";

        my $cmd =
          sprintf( 
              "java -jar -Xmx10g %s/snpEff.jar"
              . " GRCh37.75 -csvStats %s %s > %s",
            $config->{snpeff}, $csv_file, $file, $ann_file 
        );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

1;
