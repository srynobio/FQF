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

    my @cmds;
    foreach my $file ( @{$vcf} ) {
        chomp $file;
        next unless ( $file =~ /\.vcf$/ );
        $self->file_store($file);

        ( my $indiv = $file ) =~ s/\.vcf//;
        my $ann_file = "$indiv.ann.vcf";
        my $csv_file = "$indiv.csv";

        my $cmd = sprintf( "SnpEff GRCh37.75 -csvStats %s %s > %s",
            $csv_file, $file, $ann_file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

1;
