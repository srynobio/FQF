package igv;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub igv_index {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('igv_index');
    my $gvcf   = $self->file_retrieve('bam2gvcf');

    if ( !scalar @{$gvcf} > 1 ) {
        $self->ERROR("Files not found to created .idx");
    }

    my @cmds;
    foreach my $vcf ( @{$gvcf} ) {
        next if ( $vcf =~ /g.vcf$/ );

        my $outfile = $vcf . '.idx';
        next if ( $self->file_exist($outfile) );

        my $cmd = sprintf( "%s/igvtools index %s", $config->{igv}, $vcf );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;
