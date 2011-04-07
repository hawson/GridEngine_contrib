#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

$,=" "; 

my ($standalone, $loop, $queues, $no_def_queues, $helpme);
my $delay = 10;

my @queues = qw(low production);

GetOptions(
    'l|loop'        => \$loop,
    'd|delay=i'     => \$delay,
    'q|queues=s'    => \$queues,
    'n|nodefqueues' => \$no_def_queues,
    'h|help'        => \$helpme,
);

if ($helpme) {
    print <<"END_HELP";
Displays queue counts, across multiple hosts.
Options:

    -h|--help        This help.
    -d|--delay <sec> Delay between iterations, when using --loop.
                     Default is $delay seconds;
    -l|--loop        Loop, displaying updated stats each time.
    -n|--nodefqueues Do not include the default queues:
                     (@queues)
    -q|--queues <q>  List of queues to display.  May be comma-delimited.
    
END_HELP

    exit 1;

}

#################################################################################

sub parse_data {
    my ($queue_regex, @data) = @_;
    my %queue;
    my %total;
    foreach my $line (@data) {
        next if !$line;
        if ( $line =~ /^($queue_regex)(?:\.q)?@(\S+)\s+[BIP]+\s+(\S+)\s+(\S+).+[^d]$/o and  $line !~ /-NA-/o) { 
            #print STDERR "valid=[$line]\n";
            my ( $queue, $host, $slots, $load) = ($1,$2,$3,$4);
            $host =~ s/\.gc.nih.*//;
            $queue{$host}{$queue}=$slots;
            $queue{$host}{__load__} = $load unless exists $queue{$host}{__load__}; 

            my ($resrv, $used, $total) = split (/\//, $slots);
            $total{$queue}{resrv} += $resrv;
            $total{$queue}{used}  += $used;
            $total{$queue}{total} += $total;
            
            $total{__global__}{resrv} += $resrv;
            $total{__global__}{used}  += $used;
            $total{__global__}{total} += $total;
            
        }
    }
    return (\%queue, \%total);
}

sub get_data {
    # get the data ourselves
    my @qstat_output = `qstat -f -s r`;
    map { chomp $_ } @qstat_output;
    @qstat_output = grep { !/^-+$/ } @qstat_output;
    return @qstat_output;
}

sub display_hosts {
    my ($sformat, $queues_r, $abbr_r, $queue_r, $total_r, $loop, @hosts) = @_;
    
    print "\n" if $loop;
    printf $sformat, 'Host', (map { ucfirst $abbr_r->{$_} } @{$queues_r}), 'Load';

    foreach my $host (@hosts) { 
        my $load = $queue_r->{$host}{__load__};
        $load = '-NA-' eq $load ? '-NA-' : sprintf "%2.2f", $load;
        my @slots = map { $_ || '-/-/-' } @{$queue_r->{$host}}{@$queues_r};
    #    print Dumper(\@slots);
        printf $sformat, $host, @slots, $load;

    }
    
    print '-' x (13+5+1+11*(1+$#{$queues_r})), "\n";
    my %new_totals;
    foreach my $queue (@{$queues_r}, '__global__') {
        if (!exists $total_r->{$queue}) {
            $new_totals{$queue} = '-/-/-';
        } else {
            $new_totals{$queue} = join('/', map { $total_r->{$queue}{$_} } qw(resrv used total));
        }
    }
    
    printf $sformat, 'Totals(r/u/t)', (map { $new_totals{$_} } @$queues_r, '__global__') , '-  ';
#    printf $sformat, 'Totals', map { $total_r->{$_}{qw(resrv used total)} } @{$queues_r}, '';
    
}

#################################################################################
my @new_queues =  split(/[,|]/ , $queues || '');
if ($no_def_queues) {
    @queues = @new_queues
} else {
    push @queues, @new_queues;
}

my $queue_regex = join('|', @queues);

$queue_regex = qr($queue_regex);

my @qstat_output = get_data();

my ($queue_r, $total_r) = parse_data($queue_regex, @qstat_output);


#Make abbreviations for queues
my %abbr;
foreach my $queue (@queues) {
    $abbr{$queue} = $queue;
    next if (length $queue <= 6);
    my $first=substr($queue,0,1);
    my $tmp=substr($queue,1);
    $tmp =~ s/[aeiou]//ig;
    $tmp = substr($tmp, 0, 6);
    $abbr{$queue} = "$first$tmp";
    
}

my @hosts= sort keys %{$queue_r};


my ($load,$host,@slots);


my $sformat = join(' ',
        '%-13s',
        (map { '%10s' } @queues),
        '%5s',
        "\n"
    );



#printf "%20s %5s %5s %s\n", "Host        ", "Low ", "Hgh ", "Inter", "Basem", "Load";
#print Dumper(\$queue_regex);
#print Dumper(\@qstat_output);
#print Dumper(\@hosts);
#print Dumper(\@queues);
#print Dumper(\%queue);
#print Dumper(\%total);
#print Dumper(\%abbr);
#print $format,"\n";


display_hosts($sformat, \@queues, \%abbr, $queue_r, $total_r, $loop, @hosts);

while($loop) {

    sleep $delay;
    ($queue_r, $total_r) = parse_data($queue_regex, get_data());
    display_hosts($sformat, \@queues, \%abbr, $queue_r, $total_r, $loop, @hosts);
    
}

