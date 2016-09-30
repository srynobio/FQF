package FQF;
use Moo;
use Config::Std;
use File::Basename;
use Parallel::ForkManager;
use IO::File;
use File::Slurper 'read_lines';
use feature 'say';

extends 'Base';

with qw|
  bam2fastq
  bwa
  fastqforward
  fastqc
  samtools
  gatk
  igv
  tabix
  wham
  clusterUtils
  featureCounts
  snpeff
  multiqc
  |;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

has class_config => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->{class_config};
    }
);

has output => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->main->{output};
    },
);

has qstat_limit => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->commandline->{qstat_limit} || '10';
    },
);

has uid => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $ENV{USER};
    },
);

##-----------------------------------------------------------
##---------------------- METHODS ----------------------------
##-----------------------------------------------------------

sub pipeline {
    my $self = shift;

    my %progress_list;
    my $steps = $self->order;

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

        eval { $self->$sub };
        if ($@) {
            $self->ERROR("Error during call to $sub: $@");
        }

        ## check for no commands in bundle
        ## for step which don't run exterior commands.
        if ( !$self->{bundle} ) {
            $self->WARN("No command for step: $sub.");
            delete $self->{bundle};
            next;
        }

        ## next if $sub commands already done.
        if ( $progress_list{$sub} and $progress_list{$sub} eq 'complete' ) {
            delete $self->{bundle};
            next;
        }

        ## print stack for review
        if ( !$self->execute ) {
            my $stack = $self->{bundle};

            open( my $OUT, '>', "$sub.cmd.txt" );

            map { say $OUT $_ } @{ $stack->{$sub} }
              if ( $self->commandline->{command_dump} );
            map { say "Review $_" } @{ $stack->{$sub} };

            delete $stack->{$sub};
            close $OUT;
            next;
        }
        else {
            if ( scalar @{ $self->{bundle}->{$sub} } < 1 ) {
                delete $self->{bundle}->{$sub};
                next;
            }
            $self->_cluster;
        }
    }
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
    my $path = $self->software->{$package};
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

sub node_setup {
    my ( $self, $step ) = @_;

    my $opts = $self->{config}->{$step};
    my $node = $opts->{node} || 'ucgd';

    ## jpn need higher values for default.
    my $jpn;
    if ( $step =~ /fastq2bam|bam2gvcf/ ) {
        ( $opts->{jpn} )
          ? ( $jpn = $opts->{jpn} )
          : ( $jpn = '4' );
    }
    else {
        $jpn = $opts->{jpn} || '1';
    }
    return $jpn, $node;
}

##-----------------------------------------------------------

sub _cluster {
    my ( $self, $stack ) = @_;

    # command information.
    my @sub      = keys %{ $self->{bundle} };
    my @stack    = values %{ $self->{bundle} };
    my @commands = map { @$_ } @stack;

    return if ( !@commands );

    # jobs per node per step and options
    my $jpn = $self->config->{ $sub[0] }->{jpn} || '1';
    my $opts = $self->tool_options( $sub[0] );

    if ( !$opts->{node} ) {
        $self->WARN("Node not selected for $sub[0] task defaulting to ucgd");
    }
    my $node = $opts->{node} || 'ucgd';

    my $id;
    my @slurm_stack;
    $self->LOG( 'start', $sub[0] );
    while (@commands) {
        my $slurm_file = $sub[0] . "_" . ++$id . ".sbatch";

        my $RUN = IO::File->new( $slurm_file, 'w' )
          or $self->ERROR('Can not create needed slurm file [cluster]');

        # don't go over total file amount.
        if ( $jpn > scalar @commands ) {
            $jpn = scalar @commands;
        }

        # get the right collection of files
        my @cmd_chunk = splice( @commands, 0, $jpn );

        # write out the commands not copies.
        map { $self->LOG( 'cmd', $_ ) } @cmd_chunk;

        # call to create sbatch script.
        my $batch = $self->$node( \@cmd_chunk, $sub[0] );

        print $RUN $batch;
        push @slurm_stack, $slurm_file;
        $RUN->close;
    }

    open( my $FH, '>>', 'launch.index' );
    my $running = 0;
    foreach my $launch (@slurm_stack) {
        if ( $running >= $self->qstat_limit ) {
            my $status = $self->_jobs_status($node);
            if ( $status eq 'add' ) {
                $running--;
                redo;
            }
            elsif ( $status eq 'wait' ) {
                sleep(10);
                redo;
            }
        }
        else {
            print $FH "$launch\t";
            system "sbatch $launch >> launch.index";
            $running++;
            next;
        }
    }

    ## give smaller stacks time to start.
    sleep(30);

    # check the status of current sbatch jobs
    # before moving on.
    $self->_wait_all_jobs( $node, $sub[0] );
    $self->_error_check;
    unlink('launch.index');

    delete $self->{bundle};
    $self->LOG( 'finish',   $sub[0] );
    $self->LOG( 'progress', $sub[0] );
    return;
}

##-----------------------------------------------------------

sub _jobs_status {
    my ( $self, $node ) = @_;

    my $partition = $self->_which_node($node);
    my $id        = $self->uid;
    my $state     = `squeue -A $partition -u $id -h | wc -l`;

    if ( $state >= $self->qstat_limit ) {
        return 'wait';
    }
    else {
        return 'add';
    }
}

##-----------------------------------------------------------

## method used when using preemptable nodes.

sub _relaunch {
    my $self = shift;

    my @error = `grep -i error *.out`;
    chomp @error;
    if ( !@error ) { return }

    my %relaunch;
    my @error_files;
    foreach my $cxl (@error) {
        chomp $cxl;

        if ( $cxl =~ /TIME LIMIT/ ) {
            say "[WARN] a job was canceled due to time limit";
            next;
        }

        next unless ( $cxl =~ /PREEMPTION/ );

        my @ids = split /\s/, $cxl;

        ## collect error files.
        my ( $sbatch, undef ) = split /:/, $ids[0];
        push @error_files, $sbatch;

        ## record launch id.
        $relaunch{ $ids[4] }++;
    }

    open( my $FH, '>>', 'launch.index' );

    my @indexs = read_lines 'launch.index';
    foreach my $line (@indexs) {
        chomp $line;
        my @parts = split /\s/, $line;

        ## find in lookup and dont re-relaunch.
        if ( $relaunch{ $parts[-1] } ) {
            print $FH "$parts[0]\t";
            system "sbatch $parts[0] >> launch.index";
            $self->WARN("Relaunching job $parts[0]");
        }
    }

    ## remove error files.
    unlink @error_files;
}

##-----------------------------------------------------------

sub _wait_all_jobs {
    my ( $self, $node, $sub ) = @_;

    my $process;
    do {
        sleep(60);
        $self->_relaunch;
        sleep(60);
        $process = $self->_process_check( $node, $sub );
    } while ($process);
}

##-----------------------------------------------------------

sub _process_check {
    my ( $self, $node, $sub ) = @_;

    my $partition = $self->_which_node($node);
    my $id        = $self->uid;

    my @processing = `squeue -A $partition -u $id -h --format=%A`;
    chomp @processing;
    if ( !@processing ) { return 0 }

    ## check run specific processing.
    ## make lookup of what is running.
    my %running;
    foreach my $active (@processing) {
        chomp $active;
        $active =~ s/\s+//g;
        $running{$active}++;
    }

    ## check what was launched.
    open( my $LAUNCH, '<', 'launch.index' )
      or $self->ERROR("Can't find needed launch.index file.");

    my $current = 0;
    foreach my $launched (<$LAUNCH>) {
        chomp $launched;
        my @result = split /\s+/, $launched;

        if ( $running{ $result[-1] } ) {
            $current++;
        }
    }
    ($current) ? ( return 1 ) : ( return 0 );
}

##-----------------------------------------------------------

sub _which_node {
    my ( $self, $node ) = @_;

    if ( $node =~ /\bucgd\b/ ) {
        return 'ucgd-kp';
    }
    elsif ( $node =~ /\bfqf\b/ ) {
        return 'ucgd-kp';
    }
    elsif ( $node =~ /(fqf_ember|ember)/ ) {
        return 'yandell-em';
    }
    elsif ( $node =~
        /(kingspeak_guest|fqf_kingspeak_guest|ember_guest|fqf_ember_guest)/ )
    {
        return 'owner-guest';
    }
}

##-----------------------------------------------------------

sub _error_check {
    my $self = shift;

    my @error = `grep -i error *.out`;
    chomp @error;

    if ( !@error ) { return }
    else {
        $self->WARN("Some errors found (possibly non-fatal) plese review.");
    }
}

##-----------------------------------------------------------

1;
