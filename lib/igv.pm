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
    my $gvcf   = $self->file_retrieve;

    if ( scalar @{$gvcf} < 1 ) {
        $self->ERROR("Files not found to created .idx");
    }

    my @cmds;
    foreach my $vcf ( @{$gvcf} ) {
        next if ( $vcf !~ /g.vcf$/ );
        next if ( $vcf =~ /chr.*g.vcf$/ );
        next if ( $vcf =~ /thevoid/i );
        
        my $outfile = $vcf . '.idx';

        my $found = $self->file_exist($outfile);
        if ($found) {
            $self->file_store( @{$found} );
            next;
        }
        $self->file_store($outfile);

        my $cmd = sprintf( "%s/igvtools index %s", $config->{igv}, $vcf );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;
