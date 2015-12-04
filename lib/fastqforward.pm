package fastqforward;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

has indels => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_indels',
);

has snps => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_snps',
);

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub _build_indels {
    my $self   = shift;
    #my $knowns = $self->options->{known_indels};
    my $knowns = $self->class_config->{known_indels};

    $self->ERROR('Issue building known indels from file') unless ($knowns);

    my $k_indels = join(',', @{$knowns});
    $self->indels($k_indels);
}

##-----------------------------------------------------------

sub _build_snps {
    my $self   = shift;
    my $knowns = $self->class_config->{known_dbsnp};
    #my $knowns = $self->options->{known_dbsnp};

    $self->ERROR('Issue building known snp from file') unless ($knowns);

    $self->snps($knowns);
}

##-----------------------------------------------------------

sub fastqforward {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('fqf');
    my $files  = $self->file_retrieve;

    my @seq_files;
    foreach my $file ( @{$files} ) {
        chomp $file;
        next unless ( $file =~ /(gz$|bz2$|fastq$|fq$)/ );
        push @seq_files, $file;
    }

    # must have matching pairs.
    if ( scalar @seq_files % 2 ) {
        $self->ERROR( "FQ files must be matching pairs. " );
    }

    my @cmds;
    my $id   = '1';
    my $pair = '1';
    while (@seq_files) {
        my $file1 = $self->file_frags( shift @seq_files );
        my $file2 = $self->file_frags( shift @seq_files );

        # collect tag and uniquify the files.
        my $tags     = $file1->{parts}[0];

        ## FQF will make these output files for you.
        ## created here to add to object.
        my $path = $config->{output} . $tags;
        my $path_bam = $path . ".bam";
        my $path_vcf = $path . ".g.vcf";

        # store the output files.
        $self->file_store($path_bam);
        $self->file_store($path_vcf);
        
        my $uniq_id = $file1->{parts}[0] . "_" . $id;
        my $r_group =
          '\'@RG' . "\\tID:$uniq_id\\tSM:$tags\\tPL:ILLUMINA\\tLB:$tags\\tPU:ILLUMINA_$id\'";

        my $cmd = sprintf(
           "ibrun FastQforward.pl fastq2vcf -rg %s -fq %s -fq2 %s "
           . "-ref %s -known_snps %s -known_indels %s -o %s -hyperthread",
            $r_group,                    
            $file1->{full},              
            $file2->{full},
            $config->{fasta},
            $self->snps,
            $self->indels,
            $path
        );
        push @cmds, $cmd;
        $id++;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

1;
