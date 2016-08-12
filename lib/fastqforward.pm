package fastqforward;
use Moo::Role;
use File::Basename;

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
    my $knowns = $self->class_config->{known_indels};

    $self->ERROR('Issue building known indels from file') unless ($knowns);

    my $k_indels = join(',', @{$knowns});
    $self->indels($k_indels);
}

##-----------------------------------------------------------

sub _build_snps {
    my $self   = shift;
    my $knowns = $self->class_config->{known_dbsnp};

    $self->ERROR('Issue building known snp from file') unless ($knowns);
    $self->snps($knowns);
}

##-----------------------------------------------------------

sub fastq2bam {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('fastq2bam');
    my $files  = $self->file_retrieve('uncompress');

    my %id_list;
    foreach my $fq ( @{$files} ) {
        chomp $fq;
        next if ( $fq !~ /(fq$|fastq$)/ );
        my ($filename, $dirs) = fileparse($fq);

        if ( $filename =~ /\_/ ) {
            my ( $indiv, undef ) = split /_/, $filename;
            push @{ $id_list{$indiv} }, $fq;
        }
        elsif ( $filename !~ /_/ ) {
            my ( $indiv, undef ) = split /\./, $filename;
            push @{ $id_list{$indiv} }, $fq;
        }
    }

    my @cmds;
    my $id_count;
    foreach my $people ( keys %id_list ) {
        chomp $people;

        my $fileref = $id_list{$people};
        my @s_files = sort @$fileref;

        if ( ! $opts->{type} ) {
            $self->ERROR("config fastqforward option for type not given");
        }

        ## unpaired files
        if ( $opts->{type} eq 'unpaired' ) {

            my $single = shift @s_files;
            my $pair1  = shift @s_files;
            my $pair2  = shift @s_files;

            my $file1 = $self->file_frags($pair1);

            # collect tag and uniquify the files.
            my $tags = $file1->{parts}[0];

            ## FQF will make these output files for you.
            ## created here to add to object.
            my $path     = $config->{output} . $tags;
            my $path_bam = $path . ".bam";

            # store the output files.
            $self->file_store($path_bam);

            $id_count++;
            my $uniq_id = $file1->{parts}[0] . "_" . $id_count;
            my $r_group =
                "\@RG\\tID:$uniq_id\\tSM:$tags\\tPL:ILLUMINA\\tLB:$tags\\tPU:ILLUMINA_$id_count";

            my $single_format =
              "-align \'Files=$single;Type=UNPAIRED;RG=$r_group\'";
            my $pair_format =
              "-align \'Files=$pair1,$pair2;Type=PAIRED;RG=$r_group\'";

            next if ( $self->file_exist($path_bam) );
            my $cmd = sprintf(
                "ibrun FastQforward.pl fastq2bam %s %s"
                  . "-ref %s -known_indels %s -o %s -hyperthread",
                $pair_format,  $single_format, $config->{fasta},
                $self->indels, $path_bam
            );
            push @cmds, $cmd;
        }

        ## paired files
        elsif ( $opts->{type} eq 'paired' ) {

            if ( scalar @s_files % 2 ) {
                $self->ERROR("Individual $people must be matching pairs.");
            }

            my $pair1 = shift @s_files;
            my $pair2 = shift @s_files;

            my $file1 = $self->file_frags($pair1);

            # collect tag and uniquify the files.
            my $tags = $file1->{parts}[0];

            ## FQF will make these output files for you.
            ## created here to add to object.
            my $path     = $config->{output} . $tags;
            my $path_bam = $path . ".bam";

            # store the output files.
            $self->file_store($path_bam);

            $id_count++;
            my $uniq_id = $file1->{parts}[0] . "_" . $id_count;
            my $r_group =
                "\@RG\\tID:$uniq_id\\tSM:$tags\\tPL:ILLUMINA\\tLB:$tags\\tPU:ILLUMINA_$id_count";

            my $pair_format =
              "-align \'Files=$pair1,$pair2;Type=PAIRED;RG=$r_group\'";

            next if ( $self->file_exist($path_bam) );
            my $cmd =
              sprintf( "ibrun FastQforward.pl fastq2bam %s "
                  . "-ref %s -known_indels %s -o %s -hyperthread",
                $pair_format, $config->{fasta}, $self->indels, $path_bam );
            push @cmds, $cmd;
        }

        ## multi lane samples
        elsif ( $opts->{type} eq 'multi' ) {

            if ( scalar @s_files % 2 ) {
                $self->ERROR("Individual $people must be matching pairs.");
            }

            my @multi_aligns;
            my $path_bam;
            while (@s_files) {
                my $pair1 = shift @s_files;
                my $pair2 = shift @s_files;

                my $file1 = $self->file_frags($pair1);

                # collect tag and uniquify the files.
                my $tags = $file1->{parts}[0];

                $id_count++;
                my $uniq_id = $file1->{parts}[0] . "_" . $id_count;
                my $r_group =
                    "\@RG\\tID:$uniq_id\\tSM:$tags\\tPL:ILLUMINA\\tLB:$tags\\tPU:ILLUMINA_$id_count";

                ## FQF will make these output files for you.
                ## created here to add to object.
                my $bam = $config->{output} . $tags;
                $path_bam = $bam . ".bam";

                my $multi_format =
                  "-align \'Files=$pair1,$pair2;Type=PAIRED;RG=$r_group\'";

                push @multi_aligns, $multi_format;
            }

            # store the output files.
            $self->file_store($path_bam);
            my $m_format = join( " ", @multi_aligns );

            next if ( $self->file_exist($path_bam) );
            my $cmd =
              sprintf( "ibrun FastQforward.pl fastq2bam %s "
                  . "-ref %s -known_indels %s -o %s -hyperthread",
                $m_format, $config->{fasta}, $self->indels, $path_bam );
            push @cmds, $cmd;
        }
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

#sub fastq2bam {
#    my $self = shift;
#    $self->pull;
#
#    my $config = $self->class_config;
#    my $opts   = $self->tool_options('fqf');
#    my $files  = $self->file_retrieve('uncompress');
#
#    my @seq_files;
#    foreach my $file ( @{$files} ) {
#        chomp $file;
#        next unless ( $file =~ /(fastq$|fq$|txt)/ );
#        push @seq_files, $file;
#    }
#
#    # must have matching pairs.
#    if ( scalar @seq_files % 2 ) {
#        $self->ERROR( "FQ files must be matching pairs. " );
#    }
#
#    my @cmds;
#    my $id   = '1';
#    my $pair = '1';
#    while (@seq_files) {
#        my $file1 = $self->file_frags( shift @seq_files );
#        my $file2 = $self->file_frags( shift @seq_files );
#
#        # collect tag and uniquify the files.
#        my $tags     = $file1->{parts}[0];
#
#        ## FQF will make these output files for you.
#        ## created here to add to object.
#        my $path = $config->{output} . $tags;
#        my $path_bam = $path . ".bam";
#
#        # store the output files.
#        $self->file_store($path_bam);
#        
#        my $uniq_id = $file1->{parts}[0] . "_" . $id;
#        my $r_group =
#          '\'@RG' . "\\tID:$uniq_id\\tSM:$tags\\tPL:ILLUMINA\\tLB:$tags\\tPU:ILLUMINA_$id\'";
#
#        next if ( $self->file_exist($path_bam) );
#        my $cmd = sprintf(
#           "ibrun FastQforward.pl fastq2bam -rg %s -fq %s -fq2 %s "
#           . "-ref %s -known_indels %s -o %s -hyperthread",
#            $r_group,                    
#            $file1->{full},              
#            $file2->{full},
#            $config->{fasta},
#            $self->indels,
#            $path_bam
#        );
#        push @cmds, $cmd;
#        $id++;
#    }
#    $self->bundle( \@cmds );
#    return;
#}

##----------------------------------------------------------

sub bam2gvcf {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('bam2gvcf');
    my $files  = $self->file_retrieve('fastq2bam');

    my @cmds;
    foreach my $bam ( @{$files} ) {
        chomp $bam;
        next if ( !$bam =~ /bam$/ );

        ( my $gvcf = $bam ) =~ s/\.bam//;

        ## FQF will make these output files for you.
        ## created here to add to object.
        my $path_gvcf = $gvcf . ".g.vcf";
        $self->file_store($path_gvcf);

        next if ( $self->file_exist($path_gvcf) );
        my $cmd = sprintf(
            "ibrun FastQforward.pl bam2gvcf -ref %s -i %s -o %s"
              . " -include %s -known_snps %s -hyperthread",
            $config->{fasta}, $bam, $path_gvcf,
            $self->commandline->{interval_list},
            $self->snps
        );
        push @cmds, $cmd;
    }

    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub fastq2gvcf {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('fqf');
    my $files  = $self->file_retrieve('uncompress');
    #my $files  = $self->file_retrieve('nantomics_bam2fastq');

    my @seq_files;
    foreach my $file ( @{$files} ) {
        chomp $file;
        next unless ( $file =~ /(fastq$|fq$)/ );
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

sub lossless_valadate {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('lossless_valadate');
    my $files  = $self->file_retrieve('fastq2bam');

    my @cmds;
    foreach my $bam ( @{$files} ) {
        chomp $bam;

        next if ( !$bam =~ /bam$/ );
        $bam =~ s/\.bam$//g;

        my $cmd = sprintf( "lossless_validator.pl -c %s %s %s %s > %s",
            $opts->{cpu}, "$bam.bam", 
            "$bam\_1.fastq", "$bam\_2.fastq",
            "$bam.lossless.result" 
        );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------


1;
