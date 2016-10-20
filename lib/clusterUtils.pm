package clusterUtils;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

has sbatch_time => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->commandline->{sbatch_time};
    },
);

##-----------------------------------------------------------
##------------------------ METHODS --------------------------
##-----------------------------------------------------------

sub ucgd {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele &";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '72:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 1
#SBATCH -A ucgd-kp
#SBATCH -p ucgd-kp
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun
module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub kingspeak_guest {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele &";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '3:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 1
#SBATCH -x kp[001-095,168-195,200-227]
#SBATCH -A owner-guest
#SBATCH -p kingspeak-guest
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun
module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub fqf {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '4:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 7
#SBATCH -A ucgd-kp
#SBATCH -p ucgd-kp
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub fqf_kingspeak_guest {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '5:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 7
#SBATCH -x kp[001-095,168-195,200-227]
#SBATCH -A owner-guest
#SBATCH -p kingspeak-guest
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub ember {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele &";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '72:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 1
#SBATCH -A yandell-em
#SBATCH -p yandell-em
#SBATCH -o $step\_%A.out

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub fqf_ember {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '3:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 8 
#SBATCH -A yandell-em
#SBATCH -p yandell-em
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub ember_guest {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele &";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '72:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 1
#SBATCH -x em[023-024,032,025-031]
#SBATCH -A owner-guest
#SBATCH -p ember-guest
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

sub fqf_ember_guest {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele";
    }
    my $cmdNode = join( "\n", @cmds );

    ## get user id from commandline
    my $user = $self->uid;

    ## set runtime
    my $runtime = $self->sbatch_time || '72:00:00';

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t $runtime
#SBATCH -N 1
#SBATCH -x em[023-024,032,025-031]
#SBATCH -A owner-guest
#SBATCH -p ember-guest
#SBATCH -o $step\_%A.out 

source /scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

module load ucgd_modules

# clean up before start
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_prerun

$cmdNode

wait

# clean up after finish.
/scratch/ucgd/lustre/ugpuser/shell/slurm_job_postrun

EOM
    return $sbatch;
}

##-----------------------------------------------------------

1;

