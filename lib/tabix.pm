package tabix;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub bgzip {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('bgzip');

    my $combine_file = $self->file_retrieve('CombineVariants');
    my $output_file  = "$combine_file->[0]" . '.gz';

    $self->file_store($output_file);

    my $cmd = sprintf( "bgzip -c %s > %s", $combine_file->[0], $output_file );
    $self->bundle( \$cmd );
}

##-----------------------------------------------------------

sub tabix {
    my $self = shift;
    $self->pull;

    my $config = $self->class_config;
    my $opts   = $self->tool_options('tabix');

    my $combine_file = $self->file_retrieve('bgzip');

    my $cmd = sprintf( "tabix -p vcf %s", $combine_file->[0] );
    $self->bundle( \$cmd );
}

##-----------------------------------------------------------

1;
