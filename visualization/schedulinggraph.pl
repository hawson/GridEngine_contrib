#!/usr/bin/perl -w
# Scheduling tree grapher...

use strict;
use GraphViz;
use Carp;
use Data::Dumper;

my %replacements = (
	COLOR_COMPUTED => 'black',
	COLOR_CONFIG   => 'blue',
	COLOR_USER     => 'darkgreen',
	COLOR_FINAL    => 'red3',
);


my %qconf;

my $qconf_bin = "qconf";

my $graph_template = <<'END_TEMPLATE';
digraph priority {

//Colors:
//  COLOR_COMPUTED = computed
//  COLOR_CONFIG  = SGE configuration
//  COLOR_USER = User modifiable
//  COLOR_FINAL = Final priority

	style="invis";

	samehead=true;
	sametail=true;
	concentrate=true;
	rankdir="BT";
	center=true;
	//splines="polylines";

	urg        [ label="Urgency (urg)" ];
	tckts      [ label="Tickets (tckts)" ];

	npprior    [ label="Priority\n(npprior)" ];
	nurg       [ label="Urgency\n(nurg)" ];
	ntckts     [ label="Tickets\n(ntckts)" ];

	prio       [ label="Final Priority\n(prior)" shape="box" color=COLOR_FINAL ];

	rrcontr    [ label="Resource\nRequirement\n(rrcontr)"  color=COLOR_CONFIG ];
	wtcontr    [ label="Wait time\nRequirement\n(wtcontr)" color=COLOR_CONFIG ];
	dlcontr    [ label="Deadline\nRequirement\n(dlcontr)"  color=COLOR_CONFIG ];
	
	hhr        [ label="Hard resource\nrequest\n(hhr)" color=COLOR_USER ];
	wait_time  [ label="Waiting time\n(wait_time)"           color=COLOR_USER ];
	deadline   [ label="Deadline time\n(deadline)"          color=COLOR_USER ];
	
	stckt      [ label="Share Tickets\nWEIGHT_TICKETS_SHARE\n(stkct)"           color=COLOR_CONFIG ];
	ftckt      [ label="Functional Tickets\nWEIGHT_TICKETS_FUNCTIONAL\n(ftkct)" color=COLOR_CONFIG ];
	otckt      [ label="Override Tickets\nTICKETS_OVERRIDE\n(otckt)"            color=COLOR_CONFIG ];
	
	pprio      [ label="User set\nPriority\n(pprio)" color=COLOR_USER ];
	
	
	subgraph cluster_urgency_sources { 
		rank="same";
		wait_time;
		deadline;
		hhr;
	} 
	
	subgraph cluster_priority_sources {
		rank="source";
	}
	
	subgraph cluster_urgency {
		rrcontr -> urg;
		wtcontr -> urg;
		dlcontr -> urg;
		
		wait_time -> wtcontr [ label="Weighted\nby WEIGHT_WAITING_TIME" ];
		deadline  -> dlcontr [ label="Deadline weight (WEIGHT_DEADLINE) /\nTime left" ];
		
		hhr -> rrcontr       [ label="Resource\nurgency" color=COLOR_CONFIG ];
		//hhr -> rrcontr       [ label="Cumulative\n* # slots" ];
	}

/* 
	subgraph ticket_sources {
		jobs_ftckt -> ftckt ;
		user_ftckt -> ftckt ;
		project_ftckt -> ftckt ;
		dept_ftckt -> ftckt ;

		jobs_stckt -> stckt ;
		user_stckt -> stckt ;
		project_stckt -> stckt ;
		dept_stckt -> stckt ;
	}
*/
	subgraph cluster_tickets {
		ftckt -> tckts;
		otckt -> tckts;
		stckt -> tckts;
	}

	subgraph cluster_summation {
		npprior -> prio ;
		nurg    -> prio ;
		ntckts  -> prio ; 
	}

	subgraph cluster_normalized {
		pprio -> npprior [ label="(normalize)\nWeight=WEIGHT_PRIORITY" ];
		urg   -> nurg    [ label="(normalize)\nWeight=WEIGHT_URGENCY" ];
		tckts -> ntckts  [ label="(normalize)\nWeight=WEIGHT_TICKET" ];
	}
		
}
END_TEMPLATE

#########################################################################
#########################################################################
sub HumanTime {
	
	my $sec=shift;
	my ($min,$hour,$day);

	$min = int ( $sec / 60 );
	$hour = int ( $min / 60 );
	$day = int ( $hour / 24 );
	
	$sec %= 60;
	$min %= 60;
	$hour %= 24;

	my $t = '';
	
	$t  = $day.'d ' if ($day);
	$t .= sprintf ('%02d:%02d:02d', $hour,$min,$day);

	return $t;
}
#########################################################################


foreach my $config_option ( qw (-ssconf -sconf) ) {

	open ( QCONF , "$qconf_bin $config_option |") || croak "Failed to run qconf: $!";

	my ($key,$value);
	while (my $line = <QCONF>) {

		next if $line =~ /^\s*$/;

		chomp $line;
		print STDERR "[$line]\n";
		
		
		if ( $line =~ /^(\S+)\s+([^\\]+)(?: \\)?/ ) {
		
			$qconf{$key} = $value if defined $value;
			($key,$value) = ($1,$2);
		
		} elsif ( $line =~ /^\s+(.+)/) { 
		
			$value .= $1;			
		
		} 
	}
	close QCONF;

	$qconf{$key} = $value;
}

my (@active_users, $override_tickets, $functional_tickets);
open ( QCONF , "$qconf_bin -suserl|") || croak "Failed to run qconf: $!";
@active_users=<QCONF>;
close QCONF;

$override_tickets = $functional_tickets = 0;
foreach my $user (@active_users) {
	open ( QCONF , "$qconf_bin -suserl|") || croak "Failed to run qconf: $!";
	while (<QCONF>) {
		if (/^oticket\s+(\d+)/) {
			$override_tickets+=$1;
			next;
		}
		if (/^fticket\s+(\d+)/) {
			$functional_tickets+=$1;
			next;
		}
	}
	close QCONF;
	
}

$replacements{TICKETS_OVERRIDE}=$override_tickets;



# Clean up some of the data before replacements
foreach (grep (/weight/, keys %qconf)) {
	if ($qconf{$_} =~ /^-?0*\d+(\.\d+)$/) {
		$replacements{uc($_)} = sprintf "%.2f", $qconf{$_};
	} else {
		$replacements{uc($_)} = $qconf{$_};
	}
}




my $output = $graph_template;
study $output;

print STDERR Dumper(\%replacements);
foreach my $key (keys %replacements) {
	$output =~ s/$key/$replacements{$key}/gmsx;
}


print $output;


####################################################################
####################################################################
####################################################################
####################################################################
####################################################################

#
#
#my $g=GraphViz->new(
#	directed => 1,
#	layout => 'dot', 
#	style => 'invis',
#	samehead => 'true',
#	sametail => 'true',
#	concentrate => 'true',
#	rankdir => 0,
#	center => 'true',
#	splines => 'polylines',
#	overlap => 'false', 
#);
#
#my %nodes =( 
#	wait_time => { 
#		label    => 'Waiting time',
#		type     => 'user',
#		cluster  => 
#		},
#	deadline => { 
#		label => 'Deadline time',
#		type => 'user', 
#		cluster  => 
#		},
#	hhr => { 
#		label => "Hard Resource\nRequest",
#		type => 'user', 
#		cluster  => 
#		},
#
#	pprio => { 
#		label => 'User Priority',
#		type => 'user',
#		cluster  => 
#		},
#
#	wait_time => { 
#		label => 'Waiting time',
#		type => 'user', 
#		cluster  => 
#		},
#	deadline => { 
#		label => 'Deadline time',
#		type => 'user', 
#		cluster  => 
#		},
#	hhr => { 
#		label => "Hard Resource\nRequest",
#		type => 'user', 
#		cluster  => 
#		},
#);
#
#
#sub print_header {
#	return <<END_HEADER
#digraph priority {
#
#//Colors:
#//  $color{computed} = computed
#//  $color{config}  = SGE configuration
#//  $color{user} = User modifiable
#
#
#	style="invis";
#
#	samehead=true;
#	sametail=true;
#	concentrate=true;
#	rankdir="BT";
#	center=true;
#	splines="polylines";
#
#END_HEADER
#
#}

#########################################################

