package wham;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

has seqid_skip => (
    is      => 'rw',
    builder => 1,
);

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub _build_seqid_skip {
    my $self = shift;

    my @record;
    while ( my $data = <DATA> ) {
        chomp $data;
        push @record, $data;
    }
    my $ids = join( ",", @record );
    $self->seqid_skip($ids);
}

##-----------------------------------------------------------

sub whamg_svtyper {
    my $self = shift;
    $self->pull;

    my $config   = $self->class_config;
    my $opts     = $self->tool_options('whamg_svtyper');
    my $files    = $self->file_retrieve;
    my $skip_ids = $self->seqid_skip;
    my $output   = $self->output;

    my @cmds;
    foreach my $bam ( @{$files} ) {
        chomp $bam;

        next unless ( $bam =~ /bam$/ );
        next if ( $bam =~ /(DNA|theVoid)/ );

        my $file      = $self->file_frags($bam);
        my $wham_name = $file->{parts}[0] . ".unfiltered.genotype.wham.vcf";
        $wham_name =~ s/\.bam//g;

        my $found = $self->file_exist($wham_name);
        if ($found) {
            $self->file_store($wham_name);
            next;
        }

        my $output_file = $output . $wham_name;
        $self->file_store($output_file);

        my $threads;
        ( $opts->{x} ) ? ( $threads = $opts->{x} ) : ( $threads = 1 );

        ## create temp.
        ( my $temp_bam = $output_file ) =~ s/unfiltered.genotype/temp/;
        ( my $temp_log = $output_file ) =~ s/$/\.log/;

        my $cmd = sprintf(
            "whamg -a %s -x %s -f %s -e %s > %s 2> %s && svtyper -B %s -i %s -o %s && rm %s",
            $config->{fasta}, $threads,  $bam, $skip_ids,
            $temp_bam,        $temp_log, $bam, $temp_bam,
            $output_file,     $temp_bam
        );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

sub wham_pbgzip_tabix {
    my $self = shift;
    $self->pull;

    my $config     = $self->class_config;
    my $opts       = $self->tool_options('wham_bgzip');
    my $typer_file = $self->file_retrieve('whamg_svtyper');

    my @cmds;
    foreach my $vcf ( @{$typer_file} ) {
        chomp $vcf;
        next unless ( $vcf =~ /unfiltered.genotype.wham.vcf/ );

        my $output_file = $vcf . '.gz';
        $self->file_store($output_file);

        my $cmd = sprintf( "pbgzip -p %s %s ; tabix -p vcf %s",
            $config->{processors}, $vcf, $output_file
        );
        push @cmds, $cmd;
    }

    if ( !@cmds ) {
        $self->ERROR("Could not created wham_zip_tabix files.");
    }
    $self->bundle( \@cmds );
}

##-----------------------------------------------------------

1;

__DATA__
GL000207.1
GL000226.1
GL000229.1
GL000231.1
GL000210.1
GL000239.1
GL000235.1
GL000201.1
GL000247.1
GL000245.1
GL000197.1
GL000203.1
GL000246.1
GL000249.1
GL000196.1
GL000248.1
GL000244.1
GL000238.1
GL000202.1
GL000234.1
GL000232.1
GL000206.1
GL000240.1
GL000236.1
GL000241.1
GL000243.1
GL000242.1
GL000230.1
GL000237.1
GL000233.1
GL000204.1
GL000198.1
GL000208.1
GL000191.1
GL000227.1
GL000228.1
GL000214.1
GL000221.1
GL000209.1
GL000218.1
GL000220.1
GL000213.1
GL000211.1
GL000199.1
GL000217.1
GL000216.1
GL000215.1
GL000205.1
GL000219.1
GL000224.1
GL000223.1
GL000195.1
GL000212.1
GL000222.1
GL000200.1
GL000193.1
GL000194.1
GL000225.1
GL000192.1
NC_007605
hs37d5
phix
