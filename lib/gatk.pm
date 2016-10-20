package gatk;
use Moo::Role;
use IO::File;
use IO::Dir;
use File::Path qw(make_path);

#-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

has 'intervals' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_intervals',
);

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub _build_intervals {
    my $self = shift;
    my $itv  = $self->commandline->{interval_list};
    my $output = $self->output;

    # create, print and store regions.
    my $REGION = IO::File->new( $itv, 'r' )
      or
      $self->ERROR('Interval file not found or not provided on command line.');

    my %regions;
    foreach my $reg (<$REGION>) {
        chomp $reg;
        my @chrs    = split /\t/, $reg;
        my $start   = $chrs[1] + 1;
        my $end     = $chrs[2] - 1;
        my $section = "$chrs[0]:$start-$end";
        push @{ $regions{ $chrs[0] } }, $section;
    }

    my @inv_file;
    foreach my $chr ( keys %regions ) {
        my $output_reg = $output . "chr$chr" . "_region_file.list";
        #my $output_reg = $self->output . "chr$chr" . "_region_file.list";

        if ( -e $output_reg ) {
            push @inv_file, $output_reg;
            next;
        }
        else {
            my $LISTFILE = IO::File->new( $output_reg, 'w' );

            foreach my $list ( @{ $regions{$chr} } ) {
                print $LISTFILE "$list\n";
            }
            push @inv_file, $output_reg;
        }
    }
    my @sort_inv = sort @inv_file;
    return \@sort_inv;
}

##-----------------------------------------------------------

sub SelectVariants {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('SelectVariants');
    my $fqf    = $self->file_retrieve('bam2gvcf');
    my @gvcfs  = grep { /g.vcf$/ } @{$fqf};

    my @cmds;
    foreach my $vcf (@gvcfs) {
        chomp $vcf;
        my $f_parts = $self->file_frags($vcf);
        my $output  = $self->output;

        foreach my $region ( @{ $self->intervals } ) {
            my @parts = split /\//, $region;
            my ( $chr, undef ) = split /_/, $parts[-1];

            my $filename = "$chr\_" . $f_parts->{name};
            my $chrdir   = $output . "$chr/";
            make_path($chrdir);
            ####mkdir $chrdir if (!-d $chrdir);
            my $final_output = $chrdir . $filename;
            $self->file_store($final_output);

            my $cmd = sprintf(
                "java -jar -Xmx%sg -XX:ParallelGCThreads=%s %s/GenomeAnalysisTK.jar "
                  . " -T SelectVariants -R %s "
                  . "--disable_auto_index_creation_and_locking_when_reading_rods "
                  . "--variant %s -L %s -o %s",
                $opts->{xmx}, $opts->{gc_threads}, $config->{gatk},
                $config->{fasta}, $vcf, $region, $final_output );
            push @cmds, $cmd;
        }
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub CombineGVCF {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('CombineGVCF');
    my $output = $self->output;

    my $gvcf = $self->file_retrieve('SelectVariants');
    my @iso = grep { /vcf$/ } @{$gvcf};

    ## will make chr based groupings.
    my %chr_groups;
    foreach my $c_vcf (@iso) {
        chomp $c_vcf;

        my $f_parts = $self->file_frags($c_vcf);
        my ( $chr, $indiv ) = split /_/, $f_parts->{name};
        push @{ $chr_groups{$chr} }, $c_vcf;
    }

    my @cmds;
    foreach my $select ( keys %chr_groups ) {
        chomp $select;

        my $variant = join( " --variant ", @{ $chr_groups{$select} } );
        my $chrdir = $output . "$select/";
        make_path($chrdir);

        my $final_output = $chrdir . "$select.combined.g.vcf.gz";
        $self->file_store($final_output);

        my $cmd = sprintf(
            "java -jar -Xmx%sg -XX:ParallelGCThreads=%s %s/GenomeAnalysisTK.jar "
              . " -T CombineGVCFs -R %s "
              . "--disable_auto_index_creation_and_locking_when_reading_rods "
              . "--variant %s -o %s",
            $opts->{xmx}, $opts->{gc_threads}, $config->{gatk},
            $config->{fasta}, $variant, $final_output );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub GenotypeGVCF {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('GenotypeGVCF');
    my $output = $self->output;

    my $files = $self->file_retrieve('CombineGVCF');
    my @gvcfs = grep { $_ =~ /g.vcf.gz$/ } @{$files};

    # collect the 1k backgrounds.
    my (@backs);
    if ( $config->{backgrounds} ) {
        my $BK = IO::Dir->new( $config->{backgrounds} )
          or $self->ERROR('Could not find/open background directory');

        foreach my $back ( $BK->read ) {
            next unless ( $back =~ /Background.vcf$/ );
            chomp $back;
            my $fullpath = $config->{backgrounds} . "/$back";
            push @backs, $fullpath;
        }
        $BK->close;
    }
    my $back_variants = join( " --variant ", @backs );

    my %grouped;
    foreach my $gvcf (@gvcfs) {
        chomp $gvcf;
        my @path = split /\//, $gvcf;
        my ( $chr, undef ) = split /\./, $path[-1];
        push @{ $grouped{$chr} }, $gvcf;
    }

    my $intv = $self->intervals;
    my @cmds;
    foreach my $chrom ( keys %grouped ) {
        my $input = join( " --variant ", @{ $grouped{$chrom} } );
        my @region = grep { $_ =~ /$chrom\_/ } @{$intv};

        my $final_output = $output . $chrom . '_genotyped.vcf';
        ###my $output = $self->output . $chrom . '_genotyped.vcf';
        $self->file_store($final_output);
        ####$self->file_store($output);

        my $cmd;
        if ($back_variants) {
            $cmd = sprintf(
                "java -jar -Xmx%sg -XX:ParallelGCThreads=%s -Djava.io.tmpdir=%s "
                  . "%s/GenomeAnalysisTK.jar -T GenotypeGVCFs -R %s "
                  . "--disable_auto_index_creation_and_locking_when_reading_rods --num_threads %s "
                  . "--variant %s --variant %s -L %s -o %s",
                $opts->{xmx},    $opts->{gc_threads}, $config->{tmp},
                $config->{gatk}, $config->{fasta},    $opts->{num_threads},
                $input,          $back_variants,      shift @region,
                $final_output
                ###$output
            );
        }
        else {
            $cmd = sprintf(
                "java -jar -Xmx%sg -XX:ParallelGCThreads=%s -Djava.io.tmpdir=%s "
                  . "%s/GenomeAnalysisTK.jar -T GenotypeGVCFs -R %s "
                  . "--disable_auto_index_creation_and_locking_when_reading_rods "
                  . "--num_threads %s --variant %s -L %s -o %s",
                $opts->{xmx},    $opts->{gc_threads}, $config->{tmp},
                $config->{gatk}, $config->{fasta},    $opts->{num_threads},
                $input,          shift @region,       $final_output
                ####$input,          shift @region,       $output
            );
        }
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub CatVariants_Genotype {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $vcf    = $self->file_retrieve('GenotypeGVCF');
    my @iso    = grep { /genotyped.vcf$/ } @{$vcf};
    my $output = $self->output;

    my %indiv;
    my $path;
    my @cmds;
    foreach my $file (@iso) {
        chomp $file;

        my $frags = $self->file_frags($file);
        $path = $frags->{path};

        my $key = $frags->{parts}[0];
        push @{ $indiv{$key} }, $file;
    }

    # put the file in correct order.
    my @ordered_list;
    for ( 1 .. 22, 'X', 'Y', 'MT' ) {
        my $chr = 'chr' . $_;
        push @ordered_list, $indiv{$chr}->[0];
    }

    my $variant = join( " -V ", @ordered_list );
    $variant =~ s/^/-V /;

    my $final_output = $output . $config->{fqf_id} . '_cat_genotyped.vcf';
    ###my $output = $self->output . $config->{fqf_id} . '_cat_genotyped.vcf';
    $self->file_store($final_output);
    ###$self->file_store($output);

    my $cmd = sprintf(
        "java -cp %s/GenomeAnalysisTK.jar org.broadinstitute.gatk.tools.CatVariants -R %s "
          . "--assumeSorted  %s -out %s",
        $config->{gatk}, $config->{fasta}, $variant, $final_output );
    ####$config->{gatk}, $config->{fasta}, $variant, $output );
    push @cmds, $cmd;
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub VariantRecalibrator_SNP {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('VariantRecalibrator_SNP');

    my $genotpd = $self->file_retrieve('CatVariants_Genotype');

    my $recalFile =
      '-recalFile ' . $self->output . $config->{fqf_id} . '_snp_recal';
    my $tranchFile =
      '-tranchesFile ' . $self->output . $config->{fqf_id} . '_snp_tranches';
    my $rscriptFile =
      '-rscriptFile ' . $self->output . $config->{fqf_id} . '_snp_plots.R';

    $self->file_store($recalFile);
    $self->file_store($tranchFile);

    my $resource = $config->{resource_SNP};
    my $anno     = $config->{use_annotation_SNP};

    my @cmds;
    my $cmd = sprintf(
        "java -jar -Xmx%sg -XX:ParallelGCThreads=%s -Djava.io.tmpdir=%s %s/GenomeAnalysisTK.jar "
          . " -T VariantRecalibrator -R %s --minNumBadVariants %s --num_threads %s "
          . "--disable_auto_index_creation_and_locking_when_reading_rods "
          . "-resource:%s -an %s -input %s %s %s %s -mode SNP",
        $opts->{xmx},     $opts->{gc_threads},
        $config->{tmp},   $config->{gatk},
        $config->{fasta}, $opts->{minNumBadVariants},
        $opts->{num_threads}, join( ' -resource:', @$resource ),
        join( ' -an ', @$anno ), @$genotpd,
        $recalFile, $tranchFile,
        $rscriptFile
    );
    push @cmds, $cmd;
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub VariantRecalibrator_INDEL {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('VariantRecalibrator_INDEL');

    my $genotpd = $self->file_retrieve('CatVariants_Genotype');

    my $recalFile =
      '-recalFile ' . $self->output . $config->{fqf_id} . '_indel_recal';
    my $tranchFile =
      '-tranchesFile ' . $self->output . $config->{fqf_id} . '_indel_tranches';
    my $rscriptFile =
      '-rscriptFile ' . $self->output . $config->{fqf_id} . '_indel_plots.R';

    $self->file_store($recalFile);
    $self->file_store($tranchFile);

    my $resource = $config->{resource_INDEL};
    my $anno     = $config->{use_annotation_INDEL};

    my @cmds;
    my $cmd = sprintf(
        "java -jar -Xmx%sg -XX:ParallelGCThreads=%s -Djava.io.tmpdir=%s "
          . "%s/GenomeAnalysisTK.jar -T VariantRecalibrator "
          . "--disable_auto_index_creation_and_locking_when_reading_rods "
          . "-R %s --minNumBadVariants %s --num_threads %s -resource:%s "
          . "-an %s -input %s %s %s %s -mode INDEL",
        $opts->{xmx},     $opts->{gc_threads},
        $config->{tmp},   $config->{gatk},
        $config->{fasta}, $opts->{minNumBadVariants},
        $opts->{num_threads}, join( ' -resource:', @$resource ),
        join( ' -an ', @$anno ), @$genotpd,
        $recalFile, $tranchFile,
        $rscriptFile
    );
    push @cmds, $cmd;
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub ApplyRecalibration_SNP {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('ApplyRecalibration_SNP');

    my $recal_files = $self->file_retrieve('VariantRecalibrator_SNP');
    my $get         = $self->file_retrieve('CatVariants_Genotype');
    my $genotpd     = shift @{$get};

    # need to add a copy because it here.
    ( my $output = $genotpd ) =~ s/_genotyped.vcf$/_recal_SNP.vcf/g;
    $self->file_store($output);

    my @cmds;
    my $cmd = sprintf(
        "java -jar -Xmx%sg -Djava.io.tmpdir=%s %s/GenomeAnalysisTK.jar "
          . "-T ApplyRecalibration "
          . "--disable_auto_index_creation_and_locking_when_reading_rods "
          . "-R %s --ts_filter_level %s --num_threads %s --excludeFiltered "
          . "-input %s %s %s -mode SNP -o %s",
        $opts->{xmx},             $config->{tmp},
        $config->{gatk},          $config->{fasta},
        $opts->{ts_filter_level}, $opts->{num_threads},
        $genotpd,                 shift @{$recal_files},
        shift @{$recal_files},    $output
    );
    push @cmds, $cmd;
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub ApplyRecalibration_INDEL {
    my $self = shift;
    $self->pull;

    my $config      = $self->class_config;
    my $opts        = $self->tool_options('ApplyRecalibration_INDEL');
    my $recal_files = $self->file_retrieve('VariantRecalibrator_INDEL');
    my $get         = $self->file_retrieve('CatVariants_Genotype');
    my $genotpd     = shift @{$get};

    # need to add a copy because it here.
    ( my $output = $genotpd ) =~ s/_genotyped.vcf$/_recal_INDEL.vcf/g;
    $self->file_store($output);

    my @cmds;
    my $cmd = sprintf(
        "java -jar -Xmx%sg -Djava.io.tmpdir=%s %s/GenomeAnalysisTK.jar "
          . "-T ApplyRecalibration "
          . "--disable_auto_index_creation_and_locking_when_reading_rods "
          . "-R %s --ts_filter_level %s --num_threads %s --excludeFiltered "
          . "-input %s %s %s -mode INDEL -o %s",
        $opts->{xmx},             $config->{tmp},
        $config->{gatk},          $config->{fasta},
        $opts->{ts_filter_level}, $opts->{num_threads},
        $genotpd,                 shift @{$recal_files},
        shift @{$recal_files},    $output
    );
    push @cmds, $cmd;
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub CombineVariants {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('CombineVariants');

    my $snp_files   = $self->file_retrieve('ApplyRecalibration_SNP');
    my $indel_files = $self->file_retrieve('ApplyRecalibration_INDEL');

    my @app_snp = map { "--variant $_ " } @{$snp_files};
    my @app_ind = map { "--variant $_ " } @{$indel_files};

    my $output = $config->{output} . $config->{fqf_id} . ".vcf";
    $self->file_store($output);

    my @cmds;
    my $cmd = sprintf(
        "java -jar -Xmx%sg -Djava.io.tmpdir=%s %s/GenomeAnalysisTK.jar "
          . "-T CombineVariants -R %s "
          . "--disable_auto_index_creation_and_locking_when_reading_rods "
          . "--num_threads %s --genotypemergeoption %s %s %s -o %s",
        $opts->{xmx},         $config->{tmp},
        $config->{gatk},      $config->{fasta},
        $opts->{num_threads}, $opts->{genotypemergeoption},
        join( " ", @app_snp ), join( " ", @app_ind ),
        $output
    );
    push @cmds, $cmd;
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;
