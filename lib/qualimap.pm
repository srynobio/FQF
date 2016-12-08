package qualimap;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub qualimap_run {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('qualimap_run');
    my $bams   = $self->file_retrieve;
    my $output = $self->output;

    my @cmds;
    foreach my $file ( @{$bams} ) {
        chomp $file;
        next unless ( $file =~ /\.bam$/ );
        next if ( $file =~ /(DNA|theVoid)/ );

        ( my $indiv = $file ) =~ s/\.bam//;
        my $oc = $output . "$indiv.qualimap.coverage.txt";

        my $cmd = sprintf( 
            "qualimap bamqc -bam %s -c -gff %s -oc %s "
            ."-outdir %s -outformat PDF:HTML",
            $file, $opts->{gtf_file}, $oc, $output
        );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

1;
