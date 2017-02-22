package fastqc;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub fastqc_run {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('fastqc_run');
    my $gz     = $self->file_retrieve;

    ## check and remove found fastqc files.
    my @found = grep { $_ =~ /fastqc/ } @{$gz};
    unlink @found if @found;

    my $output = $self->output;

    my @cmds;
    foreach my $file ( @{$gz} ) {
        chomp $file;
        next unless ( $file =~ /fastq.gz$/ );
        $self->file_store($file);

        my $cmd = sprintf( "fastqc --threads %s -o %s -f fastq %s",
            $opts->{threads}, $output, $file );
        push @cmds, $cmd;
    }
    $self->bundle( \@cmds );
    return;
}

##-----------------------------------------------------------

1;
