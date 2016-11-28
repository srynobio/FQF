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
        next unless ( $file =~ /bam$/ );
        chomp $file;

        my $output = $self->output;

        my $cmd = sprintf(
            "bam2fastq.pl %s %s -c %s %s",
            $file, $opts->{command_string},
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
        next unless ( $bam =~ /.*DNA.*bam$/ );
        my $output = $self->output;

        my $file     = $self->file_frags($bam);
        my $filename = $file->{name};

        ( my $id, undef ) = split /--/, $filename;

        my $file1 = $id . '_1.fastq.gz';
        my $file2 = $id . '_2.fastq.gz';

        my $found1 = $self->file_exist($file1);
        my $found2 = $self->file_exist($file2);

        ## search for existing pair files.
        if ( $found1 and $found2 ) {
            $self->WARN(
                "found previous bam2fastq files: $file1 $file2"
            );
            $self->file_store( @{$found1} );
            $self->file_store( @{$found2} );
            next;
        }
        elsif ( $found1 and !$found2 ) {
            unlink $found1;
        }
        elsif ( $found2 and !$found1 ) {
            unlink $found2;
        }

        my $path1 = $output . $file1;
        my $path2 = $output . $file2;
        $self->file_store($path1);
        $self->file_store($path2);

        my $cmd = sprintf(
            "bam2fastq.pl %s %s -fq %s -fq2 %s",
            $bam, $opts->{command_string},
            $path1, $path2
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
    my $fastqs = $self->file_retrieve;

    my @cmds;
    foreach my $file ( @{$fastqs} ) {
        chomp $file;
        next unless ( $file =~ /(fastq.gz|fq.gz)/ );
        ( my $output = $file ) =~ s/\.gz//;

        my $found = $self->file_exist($output);
        if ($found) {
            $self->file_store( @{$found} );
            next;
        }

        if ( $output !~ /fastq/ ) {
            $output =~ s/$/.fastq/;
        }
        $self->file_store($output);
        my $cmd = sprintf( "gzip -d -c %s > %s", $file, $output );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;
