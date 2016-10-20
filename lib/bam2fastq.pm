package bam2fastq;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub bam2fastq {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('bam2fastq');
    my $bams   = $self->file_retrieve;

    if ( !$self->execute ) {
        $self->WARN("bam2fastq will does not generate review commands.");
        return;
    }

    my @cmds;
    foreach my $file ( @{$bams} ) {
        chomp $file;
        my $output = $self->output;
        next unless ( $file =~ /bam$/ );

        my $cmd = sprintf(
            "%s/bam2fastq.pl %s %s -c %s %s",
            $config->{bam2fastq}, $file, $opts->{command_string},
            $opts->{cpu}, $output
        );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

sub nantomics_bam2fastq {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('nantomics_bam2fastq');
    my $bams   = $self->file_retrieve;

    my @cmds;
    foreach my $bam ( @{$bams} ) {
        chomp $bam;
        my $output = $self->output;
        next unless ( $bam =~ /bam$/ );

        my $file     = $self->file_frags($bam);
        my $filename = $file->{name};

        ( my $id, undef ) = split /--/, $filename;

        my $pair1 = $output . $id . '_1.fastq.gz';
        my $pair2 = $output . $id . '_2.fastq.gz';
        $self->file_store($pair1);
        $self->file_store($pair2);

        ##next if ( $self->file_exist($pair1) );
        ##next if ( $self->file_exist($pair2) );
        my $cmd = sprintf(
            "%s/bam2fastq.pl %s %s -fq %s -fq2 %s",
            $config->{bam2fastq}, $bam, $opts->{command_string},
            $pair1, $pair2
        );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

sub uncompress {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('uncompress');
    my $fastqs = $self->file_retrieve('fastqc_run');

    my $source = $opts->{source};
    unless ($source) {
        $self->ERROR("uncompress requires source option of bam2fastq or other");
    }

    my @cmds;
    if ( $source eq 'bam2fastq' ) {
        foreach my $file ( @{$fastqs} ) {
            chomp $file;
            next unless ( $file =~ /gz$/ );
            my $cmd = sprintf( "pbgzip -d -p 24 %s", $file );
            push @cmds, $cmd;
        }
    }
    elsif ( $source eq 'other' ) {
        foreach my $file ( @{$fastqs} ) {
            chomp $file;
            next unless ( $file =~ /gz$/ );
            ( my $output = $file ) =~ s/\.gz//;
            if ( $output !~ /fastq/ ) {
                $output =~ s/$/.fastq/;
            }
            $self->file_store($output);
            my $cmd = sprintf( "gzip -d -c %s > %s", $file, $output );
            push @cmds, $cmd;
        }
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;
