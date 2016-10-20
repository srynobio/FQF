package Base;
use Moo;
use Config::Std;
use File::Basename;
use IO::Dir;
use Cwd 'abs_path';
use Storable 'dclone';
use File::Slurper 'read_lines';
use feature 'say';

#-----------------------------------------------------------
#---------------------- ATTRIBUTES -------------------------
#-----------------------------------------------------------

has commandline => (
    is       => 'rw',
    required => 1,
    default  => sub {
        die "commandline options were not given\n";
    },
);

has config => (
    is      => 'rw',
    builder => '_build_config',
);

has main => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->config->{main};
    },
);

has software => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->config->{software};
    },
);

has data => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->config->{main}->{data} || '.';
    },
);

has order => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->config->{order}->{command_order};
    },
);

has workers => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        my $workers = $self->main->{workers} || '1';
        return $workers + 1;
    },
);

has execute => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->commandline->{run} || 0;
    },
);

has step => (
    is => 'ro',
    default => sub {
        my $self = shift;
        return $self->commandline->{step};
    },
);

has pipeline_version => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->commandline->{pipeline_version};
    },
);

#-----------------------------------------------------------
#---------------------- METHODS ----------------------------
#-----------------------------------------------------------

sub _build_data_files {
    my $self = shift;

    my $data_path    = $self->data;
    my $command_file = $self->{commandline}->{file};

    if ( !-d $data_path ) {
        $self->WARN("Data directory not found or $data_path not a directory");
        unless ($command_file) {
            $self->ERROR(
                "Data directory or file list not found, -f option must be used."
            );
        }
    }

    my @file_path_list;
    if ($data_path and ! $command_file) {
        $data_path =~ s/$/\//;

        #update path data
        $self->{data} = $data_path;

        my $DIR = IO::Dir->new($data_path);
        foreach my $file ( $DIR->read ) {
            chomp $file;
            next if ( -d $file );
            push @file_path_list, abs_path($file);
        }
        $DIR->close;
    }

    ## file from the command line.
    if ($command_file) {
        @file_path_list = read_lines($command_file);
    }
    my @sorted_files = sort @file_path_list;

    if ( ! @sorted_files ) {
        $self->ERROR("Data path or -f option not found.");
    }
    my ( $name, $path ) = fileparse( $sorted_files[0]);
####    $self->{output_path} = $path;
    $self->{start_files} = \@sorted_files;
    return;
}

#-----------------------------------------------------------

#sub _build_data_files {
#    my $self = shift;
#
#    my $data_path = $self->data;
#
#    unless ( -d $data_path ) {
#        $self->WARN("Data directory not found or $data_path not a directory");
#        unless ( $self->{commandline}->{file} ) {
#            $self->ERROR("Data path or -f option must be used.");
#        }
#    }
#
#    my @file_path_list;
#    if ($data_path) {
#        unless ( $data_path =~ /\/$/ ) {
#            $data_path =~ s/$/\//;
#        }
#
#        #update path data
#        $self->{data} = $data_path;
#
#        ## check for output directory.
#        ## or add default.
#        if ( !$self->main->{output} ) {
#            $self->main->{output} = $data_path;
#        }
#        elsif ( $self->main->{output} ) {
#            my $out = $self->main->{output};
#            unless ( $out =~ /\/$/ ) {
#                $out =~ s/$/\//;
#                $self->main->{output} = $out;
#            }
#        }
#
#        my $DIR = IO::Dir->new($data_path);
#        foreach my $file ( $DIR->read ) {
#            chomp $file;
#            next if ( -d $file );
#            push @file_path_list, "$data_path$file";
#        }
#        $DIR->close;
#    }
#
#    ## file from the command line.
#    if ( $self->{commandline}->{file} ) {
#        @file_path_list = read_lines( $self->{commandline}->{file} );
#
#        if ( !$self->main->{output} ) {
#            my ( $name, $path ) = fileparse( $file_path_list[0] );
#            $self->main->{output} = $path;
#        }
#        elsif ( $self->main->{output} ) {
#            my $out = $self->main->{output};
#            unless ( $out =~ /\/$/ ) {
#                $out =~ s/$/\//;
#                $self->main->{output} = $out;
#            }
#        }
#    }
#    my @sorted_files = sort @file_path_list;
#
#    if ( !@sorted_files ) {
#        $self->ERROR("data path or -f option not found.");
#    }
#    $self->{start_files} = \@sorted_files;
#    return;
#}

#-----------------------------------------------------------

sub _build_config {
    my $self = shift;

    my $config = $self->commandline->{config};
    $self->ERROR('config file required') unless $config;

    read_config $config => my %config;
    $self->config( \%config );
}

#-----------------------------------------------------------

sub tool_options {
    my ( $self, $tool ) = @_;
    return $self->config->{$tool};
}

#-----------------------------------------------------------

sub timestamp {
    my $self = shift;
    my $time = localtime;
    return $time;
}

#-----------------------------------------------------------

sub file_store {
    my ( $self, $file ) = @_;

    my $caller = ( caller(1) )[3];
    my ( $class, $method ) = split "::", $caller;

    push @{ $self->{file_store}{$method} }, $file;
    return;
}

#-----------------------------------------------------------

sub file_retrieve {
    my ( $self, $class, $exact ) = @_;

    if ( !$class ) {
        return $self->{start_files};
    }
    if ($class) {
        if ( $self->{file_store}{$class} ) {
            my $copy = dclone( $self->{file_store} );
            return $copy->{$class};
        }
        else {
            ($exact) ? (return) : ( return $self->{start_files} );
        }
    }
}

#-----------------------------------------------------------

sub file_exist {
    my ( $self, $filename ) = @_;

    my $exist = 0;
    if ( $filename =~ /\// ) {
        if ( -e $filename and -s $filename ) {
            $exist = 1;
        }
    }
    else {
        my $path_file = $self->output . $filename;
        if ( -e $path_file and -s $path_file ) {
            $exist = 1;
        }
    }
    return $exist;
}

#-----------------------------------------------------------

sub _make_store {
    my ( $self, $class ) = @_;
    my $list = $self->{commandline}->{file};

    open( my $FH, '<', $list )
      or $self->ERROR("File $list can not be opened");

    foreach my $file (<$FH>) {
        chomp $file;
        push @{ $self->{file_store}{$class} }, $file;
    }
    $FH->close;
    return;
}

#-----------------------------------------------------------

sub WARN {
    my ( $self, $message ) = @_;
    open( my $WARN, '>>', 'WARN.log' );

    print $WARN "[WARN] $message\n";
    return;
}

#-----------------------------------------------------------

sub ERROR {
    my ( $self, $message ) = @_;
    open( my $ERROR, '>>', 'FATAL.log' );

    say $ERROR $self->timestamp, " [ERROR] $message";
    say "Fatal error occured please check FATAL.log file";
    $ERROR->close;
    exit(0);
}

#-----------------------------------------------------------

sub LOG {
    my ( $self, $type, $message ) = @_;
    $message //= 'Pipeline';

    my @time = split /\s+/, $self->timestamp;
    my $log_time = "$time[1]_$time[2]_$time[4]";
    my $default_log =
      'FQF_Pipeline.GVCF.' . $self->pipeline_version . "_$log_time-log.txt";

    my $log_file = $self->main->{log} || $default_log;
    $self->{log_file} = $log_file;
    open( my $LOG, '>>', $log_file );

    if ( $type eq 'config' ) {
        print $LOG "-" x 55;
        print $LOG "\n----- FQF Pipeline -----\n";
        print $LOG "-" x 55;
        print $LOG "\nRan on ", $self->timestamp;
        print $LOG "\nUsing the following programs:\n";
        print $LOG "\nFQF Pipeline Version: ", $self->pipeline_version, "\n";
        print $LOG "BWA: " . $self->main->{bwa_version},               "\n";
        print $LOG "GATK: " . $self->main->{gatk_version},             "\n";
        print $LOG "SamTools: " . $self->main->{samtools_version},     "\n";
        print $LOG "Samblaster: " . $self->main->{samblaster_version}, "\n";
        print $LOG "Sambamba: " . $self->main->{sambamba_version},     "\n";
        print $LOG "FastQC: " . $self->main->{fastqc_version},         "\n";
        print $LOG "Tabix: " . $self->main->{tabix_version},           "\n";
        print $LOG "WHAM: " . $self->main->{wham_version},             "\n";
        print $LOG "-" x 55, "\n";
    }
    elsif ( $type eq 'start' ) {
        print $LOG "Started process $message at ", $self->timestamp, "\n";
    }
    elsif ( $type eq 'cmd' ) {
        print $LOG "command started at ", $self->timestamp, " ==> $message\n";
    }
    elsif ( $type eq 'finish' ) {
        print $LOG "Process finished $message at ", $self->timestamp, "\n";
        print $LOG "-" x 55, "\n";
    }
    elsif ( $type eq 'progress' ) {
        my $PROG = IO::File->new( 'PROGRESS', 'a+' );
        print $PROG "$message:complete\n";
        $PROG->close;
    }
    else {
        $self->ERROR("Requested LOG message type unknown\n");
    }
    $LOG->close;
    return;
}

#-----------------------------------------------------------

1;
