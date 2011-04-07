#!/bin/sh

qstat -f| perl -MData::Dumper -ne 'if (/^(high|low|basement|interactive)\.q@(\S+)\s+B[IP]+\s+(\S+)\s+(\S+).+[^d]$/o && !/-NA-/o) { $queue{$2}{$1}=[$3, $4]; }'  \
                -e 'END { $,=" "; ' \
                -e ' @hosts= keys %queue;' \
                -e '#print Dumper(\%queue);' \
                -e '#print Dumper(\@hosts);' \
                -e 'printf "%20s %5s %5s %s\n", "Host        ", "Low ", "Hgh ", "Inter", "Basem", "Load";' \
                -e ' foreach $host (sort @hosts) { ' \
                -e '    $l=$queue{$host}{low}[0]; ' \
                -e '    $b=$queue{$host}{basement}[0]; ' \
                -e '    $i=$queue{$host}{interactive}[0]; ' \
                -e '    ($h,$load)=@{$queue{$host}{high}}; ' \
                -e '    map { $_ =~ s/0/./g; } ($l, $h, $b, $i) ; ' \
                -e '    printf "%20s %5s %5s %5s %s\n",  $host, $h, $l, $i, $b, $load; }' \
                -e '}'
#                -e 'while  ( ($k,$v) =each %queue) { print "$k = $v \n";  } }'
#gcr07n26.gc.nih.gov
