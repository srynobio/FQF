package samtools;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub samtools_index {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;

    my $cmd =
      sprintf( "%s/samtools faidx %s\n", $config->{samtools},
        $config->{fasta} );
    $self->bundle( \$cmd );
}

##-----------------------------------------------------------

sub stats {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $sorted = $self->file_retrieve('fastqforward');

    my @cmds;
    foreach my $bam ( @{$sorted} ) {
        next unless ( $bam =~ /\.bam$/ );
        ( my $stat_file = $bam ) =~ s/\.bam/\.stats/;
        $self->file_store($stat_file);

        my $cmd = sprintf( "%s/samtools stats %s > %s",
            $config->{samtools}, $bam, $stat_file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub flagstat {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $files  = $self->file_retrieve('fastqforward');

    my @cmds;
    foreach my $sort ( @{$files} ) {
        next unless ( $sort =~ /\.bam/ );
        ( my $flag_file = $sort ) =~ s/\.bam/.flagstat/;

        my $cmd = sprintf( "%s/samtools flagstat %s > %s",
            $config->{samtools}, $sort, $flag_file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;