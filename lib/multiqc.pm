package multiqc;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub multiqc_run {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('multiqc_run');

    my $work_dir    = $self->output;
    my $output_file = $config->{fqf_id} . ".multiqc.report";

    my $cmd = sprintf( "multiqc %s --force --no-data-dir --filename %s",
        $work_dir, $output_file );

    $self->bundle( \$cmd );
    return;
}

##-----------------------------------------------------------

1;

