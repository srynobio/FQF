package samtools;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub stats {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $sorted = $self->file_retrieve('fastq2bam');

    ## remove found stats files.
    my @found = grep { $_ =~ /stats$/ } @{$sorted};
    unlink @found if @found;

    my @cmds;
    foreach my $bam ( @{$sorted} ) {
        next unless ( $bam =~ /\.bam$/ );
        next if ( $bam =~ /(DNA|theVoid)/ );
        ( my $stat_file = $bam ) =~ s/\.bam/\.stats/;
        $self->file_store($stat_file);

        next if ( $self->file_exist($stat_file) );
        my $cmd = sprintf( "samtools stats %s > %s", $bam, $stat_file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub flagstat {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $files  = $self->file_retrieve('fastq2bam');

    ## remove found stats files.
    my @found = grep { $_ =~ /flagstat$/ } @{$files};
    unlink @found if @found;

    my @cmds;
    foreach my $sort ( @{$files} ) {
        next unless ( $sort =~ /\.bam$/ );
        next if ( $sort =~ /(DNA|theVoid)/ );
        ( my $flag_file = $sort ) =~ s/\.bam/.flagstat/;

        next if ( $self->file_exist($flag_file) );
        my $cmd = sprintf( "samtools flagstat %s > %s", $sort, $flag_file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;
