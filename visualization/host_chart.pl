#!/usr/bin/perl


=head1 SYNOPSIS

host_chart.pl [-h] [-v] [-d <stripdomain>] [-c [-t <delimiter]]

=head1 DESCRIPTION

host_chart.pl is a short script to aid SGE admins in configuring hosts
and host groups.  It provides a "visual" display of what exechosts are
part of which host groups, in a format suitable for display on screen,
and also in CSV output.

=head1 OPTIONS

=over 4

=item B<-h|--help>

Displays full help text.

=item B<-v|--verbose>

Increase the verbosity of the output, and can be used multiple times.
Used for debugging.

=item B<-d|--domain <domain>>

Strip the text I<<domain>> from the hostnames when displayed.  This tends to shorten the width of the display substantially.

=item B<-c|--csv>

Output a CSV file, to make it easier to import into your spreadsheet software, or other mechanical parsing programs.

=item B<-t|--delimiter <delimstring>>

Change the CSV delimiter from a single comma character "," into the value of I<<delimstring>>.  This value can be any string, not just a single character.

=item B<-o|--dot [<dotchar>]>

Print I<<dotchar>> instead of the hostname in the output matrix.  A value for I<<dotchar>> is optional, and defaults to "*" if omitted.


=head1 AUTHOR

Jesse Becker

=head1 LICENSE

 Copyright (c) 2011, Jesse becker
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.  
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * The names of its contributors may not be used to endorse or promote 
      products derived from this software without specific prior written 
      permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use File::Basename;
use List::Util qw(max);
use Pod::Usage;

my $verbose = 0;
my $domain = 'gc.nih.gov';
my $csv;
my $delimiter = ',';
my $help = 0;
my $dots_not_hostnames =undef;

my $rc  = GetOptions (
                "verbose|v+"    => \$verbose,
                'help|h'        => \$help,
                "domain|d=s"    => \$domain,
                'csv|c'         => \$csv,
                'delimiter|t=s' => \$delimiter,
                'dot|o:s'         => \$dots_not_hostnames,
            );

if ($help) {
    pod2usage ( { -exitval => 1,
                  -verbose => $help+1,
                } );
    exit;
}

$domain=regexify_domain($domain);

my @exechost = `qconf -sel`;
my @hgrps    = `qconf -shgrpl`;
my (%hgrp,%rawhgrp,%exechost,%missing);

map { chomp } @exechost, @hgrps;

my $order = 1;
foreach (sort @exechost) { $exechost{$_} = [$order++, 0]; }

foreach my $hgrp (@hgrps) {
    my $out = `qconf -shgrp $hgrp`;
    my ($rawhostlist) = $out =~ /^hostlist(.+)$/ms;
#    debug("$out");
    $rawhgrp{$hgrp} =  [ split(' ', $rawhostlist) ];
}

foreach my $hgrp (keys %rawhgrp) {

    my @hosts = recurse_hgrps($hgrp,\%rawhgrp,0);

    foreach my $host (@hosts) {
        if(exists $exechost{$host}) {
            $exechost{$host}->[1]++;
            push @{$hgrp{$hgrp}}, $host;
        } else {
            $missing{$host}++;
        }

    }
}

#debug('Exec='.Dumper(\%exechost),1);
debug('Hgrp='.Dumper(\%hgrp),1);
#debug('Missing='.Dumper(\%missing),1);

##############################################################################################


my @columns = sort {$a cmp $b} keys %hgrp;
my @col_width;

my @rows    = map { strip_domain($_) } 
              sort { $exechost{$a}->[0] <=> $exechost{$b}->[0] } 
              keys %exechost;

my @grid = ( ['ExecHost', @rows] );

push @col_width, max(map {length} @rows,'ExecHost');

foreach my $col (@columns) {
    my @list;
    my $len = 0;
    
    push @list,$col;
    
    foreach my $group (sort @list) {

        debug("GRID: group=$group",2);
        $len = max(length($group),$len);

        foreach my $host (sort @{$hgrp{$group}}) {
            debug("GRID:   host=$host",2);
            if (exists $exechost{$host}) {
                my $uqhost = strip_domain($host);
                my $val = defined($dots_not_hostnames) ? $dots_not_hostnames || '*' : $uqhost;
                $len = max(length($val),$len);
                $list[$exechost{$host}->[0]] = $val;
            }
        }
    }
    push @col_width,$len;

    $#list = scalar keys %exechost; # Force list length
    @list = map { 
                    if (!defined($_)) {
                        '';
                    } elsif ($csv) {
                        $_;
                    } else {
                        center_text($_,$len);
                    }
                } @list;
                    
    #debug(Dumper(\@list),2);
    push @grid, [@list];
    
}

#debug(Dumper(\@grid),2);
#debug(Dumper(\@col_width),2);

my $fmt ='';

$fmt = join(' ', map { '%-'.$_.'s' } @col_width)."\n";


debug($fmt,2);

my @t=transpose(@grid);
#debug(Dumper(\@t));

foreach my $row_r (@t) {
    if ($csv) {
        print join($delimiter,@{$row_r}),"\n";
    } else {
        printf $fmt, @{$row_r}
    }
}


##############################################################################################
##############################################################################################

sub center_text {
    my ($text,$width) = @_;
    return $text if !$text;
    my $strlen=length($text);
    my $num_pad = int (($width-$strlen)/2-0.49);
    
    debug("Centering [$text] into [$width], pad with [$num_pad]",2);
    my $centered = (' ' x $num_pad) . $text;
    return $centered;
}

sub recurse_hgrps {
    my ($group,$hgrp_ref,$level) = @_;
    my @hosts;
    my $indent = ('  ' x $level);
    debug($indent."Recursing on $group ($level)");
    foreach my $host (@{$hgrp_ref->{$group}}) {
        debug($indent."Checking [$host]",2);
        push @hosts, ($host =~ /^@/) 
                        ? recurse_hgrps($host, $hgrp_ref,$level+1)
                        : $host;
    }
    @hosts = sort @hosts;
    debug($indent."[$group] = @hosts",3);
    debug($indent."Done on [$group]",2);
    return @hosts;
}


sub transpose {
    my @m = @_;
    my @t;   
    foreach my $j (0..$#{$m[0]}) {
        push(@t, [map $_->[$j], @m]);
    } 
    return @t;
}

sub strip_domain {
    my ($host) = @_;
    $host =~ s/$domain//g;
    return $host;
}

sub regexify_domain {
    my ($domain) = @_;

    debug("Domain (orig)      =[$domain]",1);

    if ($domain !~ /^\./) {
        $domain = ".$domain";
    }
    debug("Domain(leading dot)=[$domain]",1);

    $domain =~ s/(?<!\\)\./\\./g;
    debug("Domain(escape dot) =[$domain]",1);

    $domain = qr($domain);
    debug("Domain(qr)         =[$domain]",1);

    return $domain;
}



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

