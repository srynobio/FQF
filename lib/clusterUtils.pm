package clusterUtils;
use Moo::Role;

##-----------------------------------------------------------
##---------------------- ATTRIBUTES -------------------------
##-----------------------------------------------------------

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

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t 72:00:00
#SBATCH -N 1
#SBATCH -A ucgd-kp
#SBATCH -p ucgd-kp
#SBATCH -o $step\_%A.out 

source /uufs/chpc.utah.edu/common/home/yandell-group1/shell/bashrc
# source /uufs/chpc.utah.edu/common/home/u0413537/.bashrc

# clean up before start
find /scratch/local/ -user u0413537 -exec rm -rf {} \\; 

$cmdNode

wait

# clean up after finish.
find /scratch/local/ -user u0413537 -exec rm -rf {} \\; 

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
        push @cmds, "$ele &";
    }
    my $cmdNode = join( "\n", @cmds );

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t 72:00:00
#SBATCH -N 14
#SBATCH -A ucgd-kp
#SBATCH -p ucgd-kp
#SBATCH -o $step\_%A.out 

source /uufs/chpc.utah.edu/common/home/yandell-group1/shell/bashrc
module load fastqforward

# source /uufs/chpc.utah.edu/common/home/u0413537/.bashrc

# clean up before start
find /scratch/local/ -user u0413537 -exec rm -rf {} \\; 

$cmdNode

wait

# clean up after finish.
find /scratch/local/ -user u0413537 -exec rm -rf {} \\; 

EOM
    return $sbatch;
}

##-----------------------------------------------------------


sub guest {
    my ( $self, $commands, $step ) = @_;

    $self->ERROR("Required commands not found")
      unless ($commands);

    my ( @cmds, @copies );
    foreach my $ele ( @{$commands} ) {
        push @cmds, "$ele &";
    }
    my $cmdNode = join( "\n", @cmds );

    my $sbatch = <<"EOM";
#!/bin/bash
#SBATCH -t 72:00:00
#SBATCH -N 1
#SBATCH -A owner-guest
#SBATCH -p kingspeak-guest
#SBATCH -o $step\_%A.out 

source /uufs/chpc.utah.edu/common/home/u0413537/.bashrc

# clean up before start
find /scratch/local/ -user u0413537 -exec rm -rf {} \\; 

$cmdNode

wait

# clean up after finish.
find /scratch/local/ -user u0413537 -exec rm -rf {} \\; 

EOM
    return $sbatch;
}

##-----------------------------------------------------------

1;

