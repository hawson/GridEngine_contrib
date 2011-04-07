#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use GraphViz;
use Getopt::Long;

my $verbose = 0;
my $all_jobs = 0;
my $rc  = GetOptions (
              "verbose|v+"  => \$verbose,
              'all|a'       => \$all_jobs,
            );


$ENV{SGE_ARCH} =  exists $ENV{SGE_ARCH} ? $ENV{SGE_ARCH}
                : $ENV{HOSTNAME} =~ /saturn/ ? 'lx24-amd64' : 'lx26-amd64';
                

my $qstat = "$ENV{SGE_ROOT}/bin/$ENV{SGE_ARCH}/qstat";

debug ("qstat bin at:  [$qstat]",1);
die "Can't execute [$qstat]: $!" if ! -x $qstat;

open (QSTAT, "$qstat -j '*' | ") || die "Failed to start qstat: $!";

my ($job, @deps,$name);
my (%deps,%named, %names, %state);
my $g = GraphViz->new( directed => 1, rankdir=>1, concentrate=> 1 );

while (my $line = <QSTAT>) {
    chomp $line;
    debug("line=[$line]",3);
    
    if ($line =~ /^job_number:\s+(\d+)/o) { 
        $job = $1;
        $state{$job} = 'q';
        debug("Job [$job] new job, setting state [q]",1);
    } elsif ( $line =~ /^jid_predecessor_list:\s+(\S+)/ ) {
        my @deps = split (/,/, $1);
        $deps{$job} = [ @deps ];
        $state{$job} = 'hq';
        debug("Job [$job] has predecessor(s): [@deps], setting state [hq]",1);
    } elsif ( $line =~ /^job_name:\s+(.+)/ ) {
        $names{$job} = $1;
        debug("Job [$job] jobname is [$1]",1);
    } elsif ( $line =~ /^usage/ ) {
        $state{$job} = 'r';
        debug("Job [$job] is running, setting state [r]",1);
    } else {
        debug("Nothing matched for this line.",3);
    }
    
}

close QSTAT;

#print STDERR Dumper(\%deps);
debug("Done collecting job information.",1);
debug('Dumping state information:'.Dumper(\%state),2);
debug('Dumping dep information:'.Dumper(\%deps),2);
debug('Dumping name information:'.Dumper(\%names),2);

my %alljobs;

debug("Building jobID list.",1);

if ($all_jobs) {
    foreach (keys %state) {
        $alljobs{$_}++;
    }
} else {
    foreach my $job (keys %deps) {
        $alljobs{$job}++;
        foreach my $dep (@{$deps{$job}}) {
            $alljobs{$dep}++;
        }
    }
}

my @alljobs = sort { $b <=> $a } keys %alljobs;
debug('Joblist: '.Dumper(\@alljobs),2);

foreach my $job (grep { $state{$_} eq 'r' } @alljobs) {
    debug("Adding GV node for [$job] (running)",1);
    $g->add_node($job, 
                label => "$names{$job}\n($job)" || $job, 
                style => 'filled',
                fillcolor => get_color($state{$job}),
                fontsize => 10,
                );
}

foreach my $job (grep { $state{$_} eq 'q' } @alljobs) {
    debug("Adding GV node for [$job] (queued)",1);
    $g->add_node($job, 
                label => "$names{$job}\n($job)" || $job, 
                style => 'filled',
                fillcolor => get_color($state{$job}),
                fontsize => 10,
                );
}

foreach my $job (grep { $state{$_} eq 'hq' } @alljobs) {
    debug("Adding GV node for [$job] (held)",1);
    $g->add_node($job, 
                label => "$names{$job}\n($job)" || $job, 
                style => 'filled',
                fillcolor => get_color($state{$job}),
                fontsize => 10,
                );
}

foreach my $job (keys %deps) {
    my $cluster = {
        name => $job,
        bgcolor=> 'lightgrey',
        style=> 'setlinewidth(1)',
    };
    foreach my $dep (@{$deps{$job}}) {
        debug("Adding edge $dep -> $job",2);
        $g->add_edge($dep => $job, dir => 'back', cluster => $cluster );
    }
}

debug ("Printing .dot file to STDOUT.",2);
print $g->as_text;


###############################################################################3

sub get_color {
    my ($state) = @_;
    return '#99ff55' if $state eq 'r';
    return '#ff4466' if $state eq 'q';
    return '#66aacc' if $state eq 'hq';
    return '#ffffff';
}

=head2 debug($message,$level,$suppress_newline)

A standard debugging function that writes the scalar $message to STDERR,
but only IFF $level exceeds the value in $verbose.  The $verbose variable
is used to set a global default debugging level.  If no $level is given,
a default of "1" is used.  Normally a "\n" is appended to the end of
$message.  If $suppress_newline is present, and evaluates to a true value,
the "\n" character will B<not> be appended.  It is expected the programmer
will make subsequent calls to debug() that will eventually tack on a "\n".

EXAMPLES:

    debug(;This message defaults to level 1');    # standard message
    debug("There were $count entries found.",1);  # explict level, embedded variable
    debug(Dumper(\%hash,2));                      # Any scalar value is allowed
    debug("Output of Run $runid is:  ",1,1);      # an "\n" will not be added

=cut


sub debug {
    my ($msg,$code, $suppress_newline)=@_;
    $code=defined($code) ? $code : 1;
    return unless $code <= $verbose;

    if ($verbose < 3) {
        print STDERR "$msg";
        print STDERR "\n" unless $suppress_newline;
    } else {
        my ($p,$f,$l) = caller;
        if ($verbose <5) {
            $f = basename($f);
            $f =~ s/.*?(\S{1,12})(?:\.p[lm])?$/$1/;
        }

        my $header = sprintf "%12s:%-4d| ", $f, $l;
        my $padding = ' ' x length $header;
        $msg =~ s/\n/\n$padding/sg;
        print STDERR $header, $msg;
        print STDERR "\n" unless $suppress_newline;
    }
}

