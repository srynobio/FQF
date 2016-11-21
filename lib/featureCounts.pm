package featureCounts;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub featureCounts_run {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('featureCounts_run');
    my $bams   = $self->file_retrieve;

    ## remove old file if found.
    my @found = grep { $_ =~ /(fcounts|fcounts.summary)/ } @{$bams};
    unlink @found if @found;

    my @cmds;
    foreach my $file ( @{$bams} ) {
        chomp $file;
        next unless ( $file =~ /\.bam$/ );
        next if ( $file =~ /(DNA|theVoid)/ );
        $self->file_store($file);

        ( my $indiv = $file ) =~ s/\.bam//;
        my $output = "$indiv.fcounts";

        my $cmd = sprintf( "featureCounts -a %s -g gene_name -o %s -t exon %s",
            $opts->{gtf_file}, $output, $file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

1;
