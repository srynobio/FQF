package FQF;
use Moo;
use Config::Std;
use File::Basename;
use Parallel::ForkManager;
use Cwd;
use File::Slurper 'read_lines';
use File::Temp qw/ tempdir /;
use feature 'say';

extends 'Base';

with qw|
  bam2fastq
  fastqforward
  fastqc
  samtools
  gatk
  igv
  tabix
  wham
  featureCounts
  snpeff
  multiqc
  qualimap
  |;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

##-----------------------------------------------------------
##---------------------- METHODS ----------------------------
##-----------------------------------------------------------

sub output {
    my $self       = shift;
    my $parent_dir = $self->data;
    my $tempdir    = tempdir( DIR => $parent_dir );
    push @{ $self->{temp_dir_stack} }, $tempdir;
    return "$tempdir/";
}

##-----------------------------------------------------------

sub pipeline {
    my $self = shift;

    my %progress_list;
    my $steps = $self->order;

    ## make reference if single step.
    my @single;
    if ( !ref $steps ) {
        push @single, $steps;
    }
    if (@single) {
        $steps = \@single;
    }

    if ( $self->execute ) {
        $self->LOG('config');

        if ( -e 'PROGRESS' and -s 'PROGRESS' ) {
            my @progress = read_lines('PROGRESS');

            map {
                my @prgs = split ":", $_;
                $progress_list{ $prgs[0] } = 'complete'
                  if ( $prgs[1] eq 'complete' );
            } @progress;
        }
    }

    # collect the cmds on stack.
    foreach my $sub ( @{$steps} ) {
        chomp $sub;

        ## next if $sub commands already done.
        if ( $progress_list{$sub} and $progress_list{$sub} eq 'complete' ) {
            next;
        }

        $self->remove_empty_dirs;
        eval { $self->$sub };
        if ($@) {
            $self->ERROR("Error during call to $sub: $@");
        }

        ## check for no commands in bundle
        ## for step which don't run exterior commands.
        if ( !$self->{bundle}->{$sub}[0] ) {
            $self->WARN("No commands or steps for : $sub");
            $self->LOG( 'progress', $sub );
            delete $self->{bundle}->{$sub};
            next;
        }

        ## print stack for review
        if ( !$self->execute ) {
            my $stack = $self->{bundle};

            foreach my $cmd ( @{ $stack->{$sub} } ) {
                say "REVIEW: $cmd";
            }

            ## make command dump for Salvo single runs.
            my $exe = "$sub.Salvo.txt";

            open( my $OUT, '>', $exe );
            foreach my $cmd ( @{ $stack->{$sub} } ) {
                $self->LOG( 'cmd', $cmd );
                say $OUT $cmd;
            }
            close $OUT;
            delete $stack->{$sub};
            $self->remove_empty_dirs;
            next;
        }
        elsif ( $self->execute ) {
            my $stack = $self->{bundle};
            my $exe   = "$sub.FQFexecute.txt";

            open( my $OUT, '>', $exe );
            foreach my $cmd ( @{ $stack->{$sub} } ) {
                $self->LOG( 'cmd', $cmd );
                say $OUT $cmd;
            }
            close $OUT;
            $self->deploy($exe);
            delete $stack->{$sub};
        }
    }
    $self->remove_empty_dirs;
    return;
}

#-----------------------------------------------------------

sub pull {
    my $self = shift;

    # setup the data information in object.
    $self->_build_data_files;

    # get caller info to build opts.
    my $caller = ( caller(1) )[3];
    my ( $package, $sub ) = split /::/, $caller;

    #collect software for caller
    my $path = $self->software->{$package} if $self->software;
    my %programs = ( $package => $path );

    # for caller ease, return one large hashref.
    my %options = ( %{ $self->main }, %programs );

    $self->{class_config} = \%options;
    return $self;
}

##-----------------------------------------------------------

sub bundle {
    my ( $self, $cmd ) = @_;

    # get caller info to create log file.
    my $caller = ( caller(1) )[3];
    my ( $package, $sub ) = split /::/, $caller;

    # what type of call
    my $ref_type = ref $cmd;
    unless ( $ref_type =~ /(ARRAY|SCALAR)/ ) {
        $self->ERROR("bundle method expects reference to array or scalar.");
    }

    my $id;
    my @cmds;
    if ( $ref_type eq 'ARRAY' ) {
        foreach my $i ( @{$cmd} ) {
            my $log     = "$sub.log-" . ++$id;
            my $add_log = $i . " 2> $log";
            $i = $add_log;
            push @cmds, $i;
        }
    }
    else {
        my $i       = $$cmd;
        my $log     = "$sub.log-" . ++$id;
        my $add_log = $i . " 2> $log";
        $i = $add_log;
        push @cmds, $i;
    }
    $self->{bundle}{$sub} = \@cmds;
    return;
}

##-----------------------------------------------------------

sub file_frags {
    my ( $self, $file, $divider ) = @_;
    $divider //= '_';

    my ( $name, $path, $suffix ) = fileparse($file);
    my @file_parts = split( $divider, $name );

    my $result = {
        full  => $file,
        name  => $name,
        path  => $path,
        parts => \@file_parts,
    };
    return $result;
}

##-----------------------------------------------------------

sub clean_up_salvo {
    my $self = shift;
    my $cwd  = getcwd();

    opendir( my $DIR, $cwd ) or $self->ERROR("could not open directory $cwd");

    foreach my $file ( readdir $DIR ) {
        if ( $file =~ /(sbatch|complete$)/ ) {
            unlink $file;
        }
    }
    return;
}

##-----------------------------------------------------------

sub deploy {
    my ( $self, $exeFile ) = @_;

    my @sub  = keys %{ $self->{bundle} };
    my $jpn  = $self->config->{ $sub[0] }->{jps} || '1';
    my $opts = $self->tool_options( $sub[0] );

    ## clean up old sbatch scripts
    $self->clean_up_salvo;

    ## get runtime or set default
    if ( !$opts->{runtime} ) {
        $self->WARN("runtime not given setting default to 10:00:00.");
    }
    my $runtime = $opts->{runtime} || '10:00:00';

    ## set min memory.
    my $min_memory = $opts->{mm} || 20;

    ## set mode to dedicated or idle.
    if ( !$opts->{node} ) {
        $self->WARN(
            "Node not selected for $sub[0] defaulting to ucgd dedicated.");
    }
    my $node = $opts->{node} || 'dedicated';

    ## get jobs per node.
    if ( !$opts->{jps} ) {
        $self->WARN("Setting jps to default of 1.");
    }
    my $jps = $opts->{jps} || 1;

    ## set node per sbatch job
    if ( !$opts->{nps} ) {
        $self->WARN("Setting nps to default of 1.");
    }
    my $nps = $opts->{nps} || 1;

    ## set dedicated or idle cmd.
    my $salvoCmd;
    if ( $node eq 'dedicated' ) {
        $salvoCmd = sprintf(
            "Salvo -cf %s -a ucgd-kp -p ucgd-kp -c kingspeak -m dedicated "
              . "-r %s -ec lonepeak -j %s -jps %s -nps %s -ql %s -mm %d -concurrent -hyperthread",
            $exeFile, $runtime, $sub[0], $jps, $nps, $self->qstat_limit,
            $min_memory );
    }
    else {
        $salvoCmd =
          sprintf( 
              "Salvo -cf %s -m idle "
              . "-r %s -ec lonepeak -j %s -jps %s -nps %s -ql %s -mm %d -concurrent -hyperthread",
            $exeFile, $runtime, $sub[0], $jps, $nps, $self->qstat_limit,
            $min_memory 
        );
    }

    say "Salvo command: $salvoCmd";
    my $run = `$salvoCmd`;
    $self->LOG( 'progress', $sub[0] );
    return;
}

###-----------------------------------------------------------

1;
